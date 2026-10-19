#!/usr/bin/env bash
# Copies the cloud server's database backups and photos to this computer (./backups/cloud-<date>.tar.gz).
# Usage: ./deploy/download-backup.sh <server-public-ip> <path/to/key.pem>
set -euo pipefail

IP="${1:?usage: ./deploy/download-backup.sh <server-public-ip> <path/to/key.pem>}"
KEY="${2:?usage: ./deploy/download-backup.sh <server-public-ip> <path/to/key.pem>}"
cd "$(dirname "$0")/.."
mkdir -p backups
out="backups/cloud-$(date +%Y-%m-%d-%H%M).tar.gz"
ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "ubuntu@$IP" \
  "sudo tar -C /var/lib/krishna-gold-shop -czf - backups data/photos" >"$out"
echo "Saved $out ($(du -h "$out" | cut -f1))"
