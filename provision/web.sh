# this VM serves a static web page via Nginx that will be the user interface for
# the budgeting stuff, allowing users to store and retrieve budget items

#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# avoid apt lock races
systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer || true
systemctl disable unattended-upgrades apt-daily.service apt-daily-upgrade.service apt-daily.timer apt-daily-upgrade.timer || true
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ||
	fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
	echo "[web] apt/dpkg locked...waiting"
	sleep 5
done

apt-get update -y
apt-get install -y nginx

# Vagrantfile syncs ./web -> /var/www/html
systemctl enable --now nginx
