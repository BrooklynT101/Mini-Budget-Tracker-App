# this VM serves a static web page via Nginx that will be the user interface for
# the budgeting stuff, allowing users to store and retrieve budget items

#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# attempt to apt race conditions
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true

apt-get update -y
apt-get install -y nginx
systemctl enable --now nginx

# --- explicit firewall with ufw ---
apt-get install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow "OpenSSH"
ufw allow "Nginx HTTP"   # browser -> web: least privilege: only 80
ufw --force enable

# Reverse proxy to avoid CORS (same-origin /api)
cat >/etc/nginx/sites-available/default <<'NG'
server {
  listen 80 default_server;
  root /var/www/html;
  index index.html;
  location / {
    try_files $uri $uri/ =404;
  }
  location /api/ {
    proxy_pass http://192.168.56.11:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
NG
nginx -t && systemctl reload nginx
