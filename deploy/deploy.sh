#!/usr/bin/env bash
# Builds the app here and installs it on the cloud server over SSH. Run again to update.
# Usage: ./deploy/deploy.sh <server-public-ip> <path/to/key.pem> [domain]
# Without a domain the one used last time is kept, or https://<ip-with-dashes>.sslip.io the first time.
set -euo pipefail

USAGE="usage: ./deploy/deploy.sh <server-public-ip> <path/to/key.pem> [domain]"
IP="${1:?$USAGE}"
KEY="${2:?$USAGE}"
DOMAIN="${3:-}"
IP_DOMAIN="${IP//./-}.sslip.io"
REMOTE="ubuntu@$IP"

# SSH refuses keys that others can read; files under /mnt/c (Windows) cannot be made private.
mkdir -p ~/.ssh
if [ "$KEY" != ~/.ssh/krishna-gold-shop.pem ]; then
  install -m 600 "$KEY" ~/.ssh/krishna-gold-shop.pem
fi
KEY=~/.ssh/krishna-gold-shop.pem
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

cd "$(dirname "$0")/.."

if [ -z "$DOMAIN" ]; then
  DOMAIN="$(ssh "${SSH_OPTS[@]}" "$REMOTE" 'cat /etc/krishna-gold-shop.domain 2>/dev/null' || true)"
  DOMAIN="${DOMAIN:-$IP_DOMAIN}"
fi

echo "==> Building"
npm run build

echo "==> Uploading to $IP"
rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
  --exclude node_modules --exclude .git --exclude data --exclude backups --exclude logs \
  --exclude .run --exclude .env --exclude '*.log' \
  ./ "$REMOTE:/tmp/kgs-release/"

echo "==> Setting up the server (first time takes a few minutes)"
ssh "${SSH_OPTS[@]}" "$REMOTE" "sudo bash /tmp/kgs-release/deploy/server-setup.sh '$DOMAIN' '$IP_DOMAIN' && sudo bash /tmp/kgs-release/deploy/server-install.sh"

echo
echo "Open: https://$DOMAIN"
# Shown only until the owner has signed in and set their own password.
first="$(ssh "${SSH_OPTS[@]}" "$REMOTE" 'sudo bash -s' <<'EOF'
f=/root/krishna-gold-shop-first-password
db=/var/lib/krishna-gold-shop/data/shop.db
[ -f "$f" ] || exit 0
if [ "$(sqlite3 "$db" "SELECT must_change_password FROM users WHERE username = 'owner'")" = "1" ]; then cat "$f"; else rm -f "$f"; fi
EOF
)"
if [ -n "$first" ]; then
  echo "Username: owner"
  echo "First password: $first   (you will be asked to set your own password at the first sign-in)"
fi
