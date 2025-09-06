#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Stop/disable/mask background apt to avoid dpkg lock contention
# suggested by ChatGPT due to numerous issues surrounding these services
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs rsync

# Deploy app to /srv/api
rm -rf /srv/api
mkdir -p /srv/api
rsync -a --delete /opt/api/ /srv/api/

cd /srv/api
npm install --omit=dev

# systemd service
cat >/etc/systemd/system/budget-api.service <<'UNIT'
[Unit]
Description=Budget API
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/srv/api
Environment=PORT=3000 DB_HOST=192.168.56.13 DB_USER=appuser DB_PASS=appsecret DB_NAME=budget
ExecStart=/usr/bin/node /srv/api/server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now budget-api
