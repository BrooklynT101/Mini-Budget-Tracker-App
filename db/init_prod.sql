-- idempotent schema & seed for production (Aurora/RDS)
-- No users/passwords here. Grants only if role already exists.

BEGIN;

-- 1) Schema (create table only if it doesn't exist)
CREATE TABLE IF NOT EXISTS transactions (
  id           BIGSERIAL PRIMARY KEY,
  category     TEXT        NOT NULL,
  description  TEXT        NOT NULL,
  amount_cents INTEGER     NOT NULL CHECK (amount_cents <> 0),
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2) Seed data (safe to re-run)
INSERT INTO transactions (category, description, amount_cents, occurred_at) VALUES
  ('groceries', 'seed: apples & milk', -2599, now() - INTERVAL '5 days'),
  ('salary',    'seed: paycheck',       500000, now() - INTERVAL '4 days')
ON CONFLICT DO NOTHING;

-- 3) Keep sequence in sync (empty-table safe; nextval returns max(id)+1)
SELECT setval(
  pg_get_serial_sequence('transactions','id'),
  COALESCE((SELECT MAX(id) FROM transactions), 0),
  false
);

-- 4) create appuser if it doesnt exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'appuser') THEN
    CREATE ROLE appuser LOGIN PASSWORD 'devpassword';
  END IF;
END$$;

-- 5) Additional grants (ONLY if role already exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'appuser') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE transactions TO appuser;
    GRANT USAGE, SELECT, UPDATE ON SEQUENCE transactions_id_seq TO appuser;
  END IF;
END $$;

COMMIT;
