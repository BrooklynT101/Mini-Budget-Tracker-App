# this virtual machine will be holding the PostgreSQL database that the other VMs
# will perform CRUD operations to, communication via the api.sh VM.

#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Suggested guard to prevent locks
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "[db] apt/dpkg locked...waiting"; sleep 5; done
apt-get update -y
apt-get install -y postgresql postgresql-contrib

# Ensure Postgres listens on the host-only/NAT network and allows API VM
sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/*/main/postgresql.conf
if ! grep -q "10.10.10.11/32" /etc/postgresql/*/main/pg_hba.conf; then
	echo "host all all 10.10.10.11/32 md5" >>/etc/postgresql/*/main/pg_hba.conf
fi
systemctl restart postgresql

# Create role/db if missing, schema, and seeds
sudo -u postgres psql -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'user') THEN
    CREATE ROLE user LOGIN PASSWORD 'supersecretpassword';
  END IF;
END$$;
SQL

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='budget'" | grep -q 1 ||
	sudo -u postgres createdb -O user budget

sudo -u postgres psql -v ON_ERROR_STOP=1 -d budget <<'SQL'
CREATE TABLE IF NOT EXISTS transactions(
  id SERIAL PRIMARY KEY,
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW(),
  description TEXT NOT NULL,
  amount_cents INT NOT NULL
);

INSERT INTO transactions (id, description, amount_cents) VALUES
  (1,'Seeded item A', -100),
  (2,'Seeded item B', 2500)
ON CONFLICT (id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('transactions','id'),
              COALESCE((SELECT MAX(id) FROM transactions), 0), true);
SQL
