#!/usr/bin/env bash
set -euo pipefail

DB="${1:-budget}"   # pass 'budget_test' to target the test DB
GUEST_FILE="/opt/db/migrations.sql"

if ! vagrant status db | grep -q running; then
  echo "DB VM is not running. Start it first: vagrant up db" >&2
  exit 1
fi

# Copy migrations.sql to the DB VM - ChatGPT helped with syntax issues and annoying specfic quirks
vagrant ssh db -c "bash -lc '
set -euo pipefail
if [ -f \"$GUEST_FILE\" ]; then
  echo Applying migrations from $GUEST_FILE to $DB
  sudo -u postgres psql -v ON_ERROR_STOP=1 -d \"$DB\" -f \"$GUEST_FILE\"
  echo Done.
else
  echo \"No migrations.sql present at $GUEST_FILE\" >&2
  exit 2
fi
'"
