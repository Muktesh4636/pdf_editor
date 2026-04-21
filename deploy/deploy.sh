#!/usr/bin/env bash
# Sync static site + API to the VPS, install deps, restart service.
# Usage: ./deploy/deploy.sh
# Requires: passwordless SSH to the host, or run: ssh-add
set -euo pipefail
HOST="${DEPLOY_HOST:-root@72.61.148.117}"
REMOTE="${DEPLOY_REMOTE:-/var/www/pdf.pravoo.in}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "→ $HOST:$REMOTE"
rsync -avz "$ROOT/index.html" "$HOST:$REMOTE/"
rsync -avz \
  "$ROOT/server/package.json" \
  "$ROOT/server/package-lock.json" \
  "$ROOT/server/index.js" \
  "$HOST:$REMOTE/server/"
ssh "$HOST" "cd $REMOTE/server && npm install --omit=dev && systemctl restart pdf-archive"
ssh "$HOST" "curl -sS http://127.0.0.1:3847/api/health; echo"
echo "OK. Public: curl -sS https://pdf.pravoo.in/api/health"
