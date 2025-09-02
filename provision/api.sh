#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

APP_SRC=/opt/api        # shared folder from host (Windows)
APP_DIR=/srv/api        # native ext4 dir inside VM

# --- avoid dpkg/apt lock races on Ubuntu 24.04 ---
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer || true
systemctl disable unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer || true
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
   || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
  echo "[api] apt/dpkg locked...waiting"; sleep 5
done

# --- packages ---
apt-get update -y
apt-get install -y curl ca-certificates gnupg rsync

# Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# --- copy app to ext4 and install deps there ---
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
rsync -a --delete "$APP_SRC/" "$APP_DIR/"

cd "$APP_DIR"
if [ -f package-lock.json ]; then
  npm ci --omit=dev --no-audit --no-fund
else
  npm install --omit=dev --no-audit --no-fund
fi

# --- systemd service (runs from /srv/api) ---
cat >/etc/systemd/system/hello-api.service <<'UNIT'
[Unit]
Description=Hello API
After=network.target

[Service]
WorkingDirectory=/srv/api
Environment=PORT=3000
ExecStart=/usr/bin/node /srv/api/server.js
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now hello-api
systemctl restart hello-api
systemctl status --no-pager --lines=50 hello-api || true
