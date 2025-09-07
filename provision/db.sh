# this virtual machine will be holding the PostgreSQL database that the other VMs
# will perform CRUD operations to, communication via the api.sh VM.

#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y postgresql postgresql-contrib

# after installing postgres, start/enable it
systemctl enable --now postgresql || true

# LLM suggested fix for "psql: could not connect to server: No such file or directory"
# resolve real config paths (avoids the fragile */main globs)
CONF="$(sudo -u postgres psql -tAqc "SHOW config_file" || true)"
HBA="$(sudo -u postgres psql -tAqc "SHOW hba_file" || true)"
# Listen only on the private IP (if the file exists)
if [ -n "${CONF:-}" ] && [ -f "$CONF" ]; then
	if ! grep -q "listen_addresses = '192.168.56.13'" "$CONF"; then
		sed -ri "s|^#?listen_addresses\s*=.*|listen_addresses = '192.168.56.13'|" "$CONF"
	fi
fi
# Tighten HBA only if it exists
if [ -n "${HBA:-}" ] && [ -f "$HBA" ]; then
	sed -i '/192\.168\.56\.0\/24/d' "$HBA"
	grep -q "192\.168\.56\.11/32" "$HBA" || echo "host all all 192.168.56.11/32 md5" >>"$HBA"
fi

# apply changes
systemctl restart postgresql

# Create role if missing
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='appuser'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE ROLE appuser LOGIN PASSWORD 'appsecret';"
fi

# Create database if missing (MUST be outside DO/transaction)
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='budget'" | grep -q 1; then
	sudo -u postgres psql -c "CREATE DATABASE budget OWNER appuser;"
fi

# Initial setup if init.sql is present (only on first boot)
if [ -f /opt/db/init.sql ]; then
	echo "Beginning initial setup from /opt/db/init.sql"
	sudo -u postgres psql -d budget -f /opt/db/init.sql
fi

# --- explicit firewall with ufw ---
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.56.11 to any port 5432 proto tcp # API -> DB only
ufw allow "OpenSSH"                                     # keep Vagrant ssh working
ufw --force enable
