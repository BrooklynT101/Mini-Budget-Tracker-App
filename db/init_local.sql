-- Initial database setup script
-- Run once on first boot to create the schema and seed data (seed data opptional, used for demo/testing)
-- idempotent with IF NOT EXISTS and ON CONFLICT DO NOTHING to allow safe re-runs
-- Note: this file is copied to /opt/db/init_local.sql in the DB VM by the Vagrantfile

CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  amount_cents INT NOT NULL,
  occurred_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Keep sequence in sync
SELECT setval(
  pg_get_serial_sequence('transactions','id'),
  COALESCE((SELECT MAX(id) FROM transactions), 0) + 1,
  false
);

-- Create appuser if it doesnt exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'appuser') THEN
    CREATE ROLE appuser LOGIN PASSWORD 'devpassword';
  END IF;
END$$;

-- Ensure API user owns and can use the data it needs
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE transactions TO appuser;
GRANT USAGE, SELECT, UPDATE ON SEQUENCE transactions_id_seq TO appuser;
ALTER TABLE transactions OWNER TO appuser;
ALTER SEQUENCE transactions_id_seq OWNER TO appuser;

-- Seed once with stable ids
INSERT INTO transactions (id, name, description, amount_cents, occurred_at) VALUES
  (1,'Coffee', 'Coffee from cafe', 400, NOW()),
  (2,'Groceries', 'Weekly groceries', 78291, NOW()),
  (3,'Rent', 'Monthly rent', 120000, '2024-05-01 08:30:00'),
  (4,'Internet', '', 6000, NOW()),
  (5,'Electricity', 'Monthly electricity bill', 15000, '2024-05-28 10:00:00')
ON CONFLICT (id) DO NOTHING;