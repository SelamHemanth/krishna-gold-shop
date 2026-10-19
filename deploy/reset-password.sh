#!/usr/bin/env bash
# Sets a new login password on the cloud server (for a forgotten password).
# Usage: ./deploy/reset-password.sh <server-public-ip> <path/to/key.pem> [user]
set -euo pipefail

USAGE="usage: ./deploy/reset-password.sh <server-public-ip> <path/to/key.pem> [user]"
IP="${1:?$USAGE}"
KEY="${2:?$USAGE}"
USER_NAME="${3:-owner}"

[ -t 0 ] || { echo "Run this in a terminal so the password can be typed." >&2; exit 1; }
read -rsp "New password for '$USER_NAME' (min 8 characters): " p1; echo
read -rsp "Type it again: " p2; echo
[ "$p1" = "$p2" ] || { echo "Passwords do not match." >&2; exit 1; }

# The password goes over stdin so it never shows up in a process list on the server.
printf '%s\n' "$p1" | ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$IP" \
  "cd /opt/krishna-gold-shop && sudo -u kgs sh -c 'read -r RESET_PASSWORD; export RESET_PASSWORD RESET_USER=\"$USER_NAME\" \
    DATA_DIR=/var/lib/krishna-gold-shop/data BACKUP_DIR=/var/lib/krishna-gold-shop/backups; \
    exec node_modules/.bin/tsx scripts/reset-password.ts >/dev/null'" \
  && echo "Password changed for '$USER_NAME'." \
  || { echo "Password not changed." >&2; exit 1; }
