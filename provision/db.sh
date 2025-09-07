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


# Listen only on the private IP of the DB VM
if ! grep -q "listen_addresses = '192.168.56.13'" "$PGCONF"; then
  sed -ri "s|^#?listen_addresses\s*=.*|listen_addresses = '192.168.56.13'|" "$PGCONF"
fi

# Remove any broad subnet allows and only allow the API VM
sed -i '/192\.168\.56\.0\/24/d' "$PGHBA"
if ! grep -q "192.168.56.11/32" "$PGHBA"; then
  echo "host all all 192.168.56.11/32 md5" >> "$PGHBA"
fi

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
  name VARCHAR(100) NOT NULL,
  description TEXT,
  amount_cents INT NOT NULL,
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Seed once with stable ids
INSERT INTO transactions (id, name, description, amount_cents, occurred_at) VALUES
  (1,'Coffee', 'Coffee from cafe', 400, NOW()),
  (2,'Groceries', 'Weekly groceries', 78291, NOW()),
  (3,'Rent', 'Monthly rent', 120000, '2024-05-01 08:30:00'),
  (4,'Internet', '', 6000, NOW()),
  (5,'Electricity', 'Monthly electricity bill', 15000, '2024-05-28 10:00:00')
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

# --- explicit firewall with ufw ---
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.56.11 to any port 5432 proto tcp   # API -> DB only
ufw allow "OpenSSH"                                          # keep Vagrant ssh working
ufw --force enable

# Had ChatGPT help with this part, to apply any new migrations on boot
# Apply migrations if present (idempotent)
if ls /db/migrations.sql >/dev/null 2>&1; then
  echo "Found migrations, applying..."
  for f in /db/migrations.sql; do
    echo "Applying migration: $f"
    sudo -u postgres psql -d budget -f "$f"
  done
fi