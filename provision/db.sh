# this virtual machine will be holding the PostgreSQL database that the other VMs
# will perform CRUD operations to, communication via the api.sh VM.

#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Reduce apt lock flakiness on first boot
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y postgresql postgresql-contrib

PGCONF=/etc/postgresql/*/main/postgresql.conf
PGHBA=/etc/postgresql/*/main/pg_hba.conf

# Listen on all interfaces, allow the 192.168.56.0/24 host-only network
sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" $PGCONF
if ! grep -q "192.168.56.0/24" $PGHBA; then
  echo "host all all 192.168.56.0/24 md5" >> $PGHBA
fi
systemctl restart postgresql

# Create role if missing
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='appuser'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE ROLE appuser LOGIN PASSWORD 'appsecret';"
fi

# Create database if missing (MUST be outside DO/transaction)
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='budget'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE budget OWNER appuser;"
fi

# Schema + seeds
sudo -u postgres psql -v ON_ERROR_STOP=1 -d budget <<'SQL'
CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW(),
  description TEXT NOT NULL,
  amount_cents INT NOT NULL
);

-- Seed once with stable ids
INSERT INTO transactions (id, description, amount_cents) VALUES
  (1,'Seeded item A', -100),
  (2,'Seeded item B', 2500)
ON CONFLICT (id) DO NOTHING;

-- Keep sequence in sync
SELECT setval(pg_get_serial_sequence('transactions','id'),
              COALESCE((SELECT MAX(id) FROM transactions), 0), true);
SQL

# Ensure API user owns and can use the data it needs
sudo -u postgres psql -d budget <<'SQL'
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE transactions TO appuser;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE transactions_id_seq TO appuser;
ALTER TABLE transactions OWNER TO appuser;
ALTER SEQUENCE transactions_id_seq OWNER TO appuser;
SQL