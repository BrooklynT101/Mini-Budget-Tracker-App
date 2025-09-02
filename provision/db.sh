# this virtual machine will be holding the PostgreSQL database that the other VMs 
# will perform CRUD operations to, communication via the api.sh VM.

#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y postgresql postgresql-contrib

# Create DB and simple table with seed rows
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'appuser') THEN
    CREATE ROLE appuser LOGIN PASSWORD 'appsecret';
  END IF;
END$$;
CREATE DATABASE budget WITH OWNER appuser;
\c budget
CREATE TABLE IF NOT EXISTS transactions(
  id SERIAL PRIMARY KEY,
  description TEXT NOT NULL,
  amount_cents INT NOT NULL
);
INSERT INTO transactions (description, amount_cents)
VALUES ('Seeded item A', -100), ('Seeded item B', 2500)
ON CONFLICT DO NOTHING;
SQL