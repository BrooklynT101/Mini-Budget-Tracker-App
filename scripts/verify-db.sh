# Smoke test to verify the db VM database is reachable and has the expected schema
# and constraints, as well as being interactable.
# LLMs were used to help with SQL queries (for accessing metadata) and some bash syntax.
#!/usr/bin/env bash
set -euo pipefail

DB="${DB:-budget}" # default database name

ok=0
fail=0
pass() {
	echo "PASS - $*"
	ok=$((ok + 1))
}
failf() {
	echo "FAIL - $*"
	fail=$((fail + 1))
}

# run SQL on the DB VM as postgres; ON_ERROR_STOP makes psql exit non-zero on errors
psql_db() {
	local sql="$1"
	vagrant ssh db -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -tA -d \"$DB\" -c \"$sql\"" |
		tr -d $'\r'
}

echo "=== Verifying database '$DB' in DB VM ==="
# 1) Can we reach the DB at all?
if psql_db "SELECT 1"; then
	pass "DB reachable"
else
	failf "DB not reachable"
fi

# 2) Core table exists
res="$(psql_db "SELECT to_regclass('public.transactions') IS NOT NULL")" || true
if [ "$res" = "t" ]; then
	pass "transactions table exists"
else
	failf "transactions table missing"
fi

# 3) Required columns exist (id, occurred_at, name, amount_cents)
for col in id occurred_at name amount_cents; do
	res="$(psql_db "SELECT EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema='public'
             AND table_name='transactions'
             AND column_name='${col}'
         )")"
	[[ "$res" == "t" ]] && pass "column ${col} present" || failf "column ${col} missing"
done

# 4) Primary key present on id
has_pk="$(psql_db \
	"SELECT EXISTS (
   SELECT 1
   FROM pg_constraint c
   JOIN pg_class t ON t.oid=c.conrelid
   JOIN pg_namespace n ON n.oid=t.relnamespace
   WHERE c.contype='p' AND n.nspname='public' AND t.relname='transactions'
 )")"
[[ "$has_pk" == "t" ]] && pass "primary key exists" || failf "primary key missing"

# 5) App user can connect over TCP from API VM
if vagrant ssh api -c "PGPASSWORD=appsecret psql -h 192.168.56.13 -U appuser -d \"$DB\" -tA -c 'select 1'" >/dev/null 2>&1; then
	pass "appuser can connect from API VM over TCP"
else
	failf "appuser cannot connect from API VM"
fi

# 6) Insert works
if psql_db "BEGIN;
              INSERT INTO transactions(name, description, amount_cents)
              VALUES ('_SMOKE_', 'tmp', 1);
            ROLLBACK;"; then
	pass "insert/rollback ok"
else
	failf "insert failed (constraints?)"
fi

# 7) Invalid data is rejected (NULL name should fail)
if vagrant ssh db -c "sudo -u postgres psql -v ON_ERROR_STOP=1 -d \"$DB\" -c \
   \"BEGIN; INSERT INTO transactions(name, amount_cents) VALUES (NULL, 1); ROLLBACK;\"" >/dev/null 2>&1; then
	failf "NULL name was accepted (should be NOT NULL)"
else
	pass "NULL name correctly rejected"
fi

# 8) Invalid data is rejected (non-integer amount should fail)
echo "=== Summary ==="
echo "Passed: $ok   Failed: $fail"
exit $((fail > 0))
