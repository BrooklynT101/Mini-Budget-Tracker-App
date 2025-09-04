#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

APP_SRC=/opt/api        # shared folder from host (Windows)
APP_DIR=/srv/api        # native ext4 dir inside VM

# Stop/disable/mask background apt to avoid dpkg lock contention
# suggested by ChatGPT due to numerous issues surrounding these
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service 2>/dev/null || true
systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl disable unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

apt_wait() {
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ||         fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "[apt] locked, waiting..."
    sleep 3
  done
}
apt_wait
DEBIAN_FRONTEND=noninteractive apt-get update -y

DEBIAN_FRONTEND=noninteractive apt-get install -y curl rsync ca-certificates gnupg

# Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

install -d -m 0755 "$APP_DIR"

# --- copy app to ext4 and install deps there ---
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
rsync -a --delete "$APP_SRC/" "$APP_DIR/"

cd "$APP_DIR"
if [ -f package-lock.json ]; then 	
  npm ci --omit=dev
else
  npm install --omit=dev
fi

# --- systemd service (runs from /srv/api) ---
cat >/etc/systemd/system/hello-api.service <<'UNIT'
[Unit]
Description=Hello API
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/srv/api
Environment=PORT=3000
ExecStart=/usr/bin/node /srv/api/server.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now hello-api
