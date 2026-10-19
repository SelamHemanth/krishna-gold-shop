#!/usr/bin/env bash
# One-time setup of an Ubuntu 24.04 cloud server (safe to run again).
# Installs Node.js 22, Caddy (automatic HTTPS), a swap file, a service user and the systemd service.
# Usage (as root): server-setup.sh <domain>
set -euo pipefail

DOMAIN="${1:?usage: server-setup.sh <domain>}"
APP=/opt/krishna-gold-shop
VAR=/var/lib/krishna-gold-shop
ENV_FILE=/etc/krishna-gold-shop.env
export DEBIAN_FRONTEND=noninteractive

# Small (1 GB) servers run out of memory while installing packages without swap.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

apt-get update -q
apt-get install -y -q ca-certificates curl gnupg rsync sqlite3 build-essential python3 unattended-upgrades \
  debian-keyring debian-archive-keyring apt-transport-https

if ! node --version 2>/dev/null | grep -q '^v22\.'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y -q nodejs
fi

if ! command -v caddy >/dev/null; then
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt >/etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q
  apt-get install -y -q caddy
fi

id kgs >/dev/null 2>&1 || useradd --system --home-dir "$VAR" --shell /usr/sbin/nologin kgs
mkdir -p "$APP" "$VAR/data" "$VAR/backups"
chown -R kgs:kgs "$VAR"
chmod 750 "$VAR"

# Settings for the app. Created once; the first owner password is random and must be changed at first sign-in.
if [ ! -f "$ENV_FILE" ]; then
  first_password="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-12)"
  cat >"$ENV_FILE" <<EOF
NODE_ENV=production
HOST=127.0.0.1
PORT=8787
HTTPS_PORT=0
TRUST_PROXY=true
COOKIE_SECURE=true
DATA_DIR=$VAR/data
BACKUP_DIR=$VAR/backups
SHOP_USERNAME=owner
SHOP_PASSWORD=$first_password
SHOP_PASSWORD_TEMPORARY=true
EOF
  chmod 600 "$ENV_FILE"
  echo "$first_password" >/root/krishna-gold-shop-first-password
  chmod 600 /root/krishna-gold-shop-first-password
fi

cat >/etc/systemd/system/krishna-gold-shop.service <<EOF
[Unit]
Description=Krishna Gold Shop
After=network-online.target
Wants=network-online.target

[Service]
User=kgs
Group=kgs
WorkingDirectory=$APP
EnvironmentFile=$ENV_FILE
ExecStart=$APP/node_modules/.bin/tsx server/index.ts
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$VAR

[Install]
WantedBy=multi-user.target
EOF

cat >/etc/caddy/Caddyfile <<EOF
$DOMAIN {
	encode gzip
	request_body {
		max_size 15MB
	}
	header Strict-Transport-Security "max-age=31536000"
	reverse_proxy 127.0.0.1:8787
}
EOF

systemctl daemon-reload
systemctl enable krishna-gold-shop >/dev/null
systemctl enable caddy >/dev/null
systemctl reload-or-restart caddy
echo "Server setup done for https://$DOMAIN"
