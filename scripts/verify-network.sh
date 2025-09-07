#!/usr/bin/env bash
set -euo pipefail

ok=0; fail=0
pass(){ echo "PASS - $*"; ok=$((ok+1)); }
failf(){ echo "FAIL - $*"; fail=$((fail+1)); }

# Helpers - LLM helped with adding necessary modifiers for the various ssh commands, as while i understand the concepts/logic, the exact syntax is tricky
sshvm(){ vagrant ssh "$1" -c "$2"; }

echo "=== Host -> WEB should work ==="
if curl -fsS http://localhost:8080 >/dev/null; then pass "host can reach WEB :8080"; else failf "host cannot reach WEB"; fi

echo "=== Host -> API should fail (no port-forward) ==="
if curl -fsS http://localhost:3000/health >/dev/null 2>&1; then failf "host reached API (should be blocked)"; else pass "host blocked from API"; fi

echo "=== WEB -> API allowed ==="
if sshvm web 'curl -fsS http://192.168.56.11:3000/health | grep -q "\"ok\":true"'; then pass "WEB can hit API /health"; else failf "WEB cannot hit API"; fi

echo "=== WEB -> DB blocked ==="
# Using bash /dev/tcp trick + timeout; expect failure
if sshvm web 'bash -lc "! timeout 2 bash -c \"</dev/tcp/192.168.56.13/5432\" 2>/dev/null"'; then pass "WEB cannot connect to DB:5432"; else failf "WEB reached DB (should be blocked)"; fi

echo "=== WEB -> API /transactions triggers API->DB ==="
# If DB were blocked, API likely returns 5xx; -f makes curl fail on 4xx/5xx
if sshvm web 'curl -fsS http://192.168.56.11:3000/transactions >/dev/null'; then pass "API can reach DB via /transactions"; else failf "API->DB likely blocked (transactions failed)"; fi

echo "=== DB -> API blocked ==="
if sshvm db 'bash -lc "! timeout 2 bash -c \"</dev/tcp/192.168.56.11/3000\" 2>/dev/null"'; then pass "DB cannot connect to API:3000"; else failf "DB reached API (should be blocked)"; fi

echo "=== WEB proxy -> API ==="
if curl -fsS http://localhost:8080/api/health | grep -q '"ok":true'; then pass "WEB proxy to API works"; else failf "WEB proxy broken"; fi

echo "=== Summary ==="
echo "Passed: $ok   Failed: $fail"
exit $(( fail > 0 ))