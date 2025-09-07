-- This script is shared with the database VM to apply any new migrations on boot, or additionally by running the ./scripts/db-migrate.sh script on the host.
-- additionally adding ON CONFLICT (column) DO NOTHING ensures that the insert is safe to run multiple times.


SET ROLE appuser; -- ensure this is set to the appuser so it has permission to alter the table

INSERT INTO transactions (name, description, amount_cents, occurred_at) VALUES
  ('Fancy Cheeses', 'Monthly Cheese Budget', 10000, NOW())
ON CONFLICT (name) DO NOTHING;
