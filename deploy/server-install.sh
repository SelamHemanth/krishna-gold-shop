#!/usr/bin/env bash
# Installs the uploaded release (in /tmp/kgs-release) and restarts the app. Run as root.
set -euo pipefail

APP=/opt/krishna-gold-shop
ENV_FILE=/etc/krishna-gold-shop.env

rsync -a --delete --exclude node_modules /tmp/kgs-release/ "$APP/"
cd "$APP"
npm ci --no-audit --no-fund --loglevel=error
chown -R root:root "$APP"

systemctl restart krishna-gold-shop
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8787/api/health >/dev/null 2>&1; then
    # The owner account exists now, so the first password no longer needs to be kept in the settings file.
    sed -i '/^SHOP_PASSWORD=/d' "$ENV_FILE"
    echo "App is running."
    exit 0
  fi
  sleep 1
done
echo "The app did not start. Last log lines:" >&2
journalctl -u krishna-gold-shop -n 40 --no-pager >&2
exit 1
