#!/usr/bin/env bash
#
# Static site → VPS over rsync (passwordless SSH only — no secrets in this file).
#
# Defaults match the test / pdfforge host. Override any time:
#   DEPLOY_HOST=root@1.2.3.4 DEPLOY_REMOTE=/var/www/html/ ./deploy.sh
#   RSYNC_RSH='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new' ./deploy.sh
#
# First-time setup on your machine:
#   ssh-copy-id -i ~/.ssh/id_ed25519.pub "${DEPLOY_HOST:-root@72.61.148.117}"
#
# Dry run (no writes on server):
#   ./deploy.sh --dry-run

set -euo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-root@72.61.148.117}"
DEPLOY_REMOTE="${DEPLOY_REMOTE:-/var/www/pdfforge.store/}"
RSYNC_RSH="${RSYNC_RSH:-ssh -o StrictHostKeyChecking=accept-new}"

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${DEPLOY_HOST}:$(echo "${DEPLOY_REMOTE}" | sed 's:/*$::')/"

RSYNC_BASE=(rsync -avz --progress -e "$RSYNC_RSH")
if [[ "${1:-}" == "--dry-run" ]]; then
  RSYNC_BASE+=(--dry-run)
  echo "Dry run — no files will be written."
fi

echo "→ ${DEST}"
echo "   (set DEPLOY_HOST / DEPLOY_REMOTE to change target)"

"${RSYNC_BASE[@]}" \
  "$DIR/index.html" \
  "$DIR/edit-pdf.html" \
  "$DIR/merge-pdf.html" \
  "$DIR/compress-pdf.html" \
  "$DIR/remove-pages.html" \
  "$DIR/remove-pdf-password.html" \
  "$DIR/bank-transactions.html" \
  "$DIR/img-to-pdf.html" \
  "$DIR/pdf-to-img.html" \
  "$DIR/word-to-pdf.html" \
  "$DIR/excel-to-pdf.html" \
  "$DIR/pptx-to-pdf.html" \
  "$DIR/epub-to-pdf.html" \
  "$DIR/pdf-to-word.html" \
  "$DIR/pdf-to-excel.html" \
  "$DIR/pdf-to-pptx.html" \
  "$DIR/pdf-to-epub.html" \
  "$DIR/sitemap.xml" \
  "$DIR/robots.txt" \
  "$DIR/manifest.json" \
  "$DIR/favicon.ico" \
  "$DIR/icon-16.png" \
  "$DIR/icon-32.png" \
  "$DIR/icon-192.png" \
  "$DIR/icon-512.png" \
  "$DEST"

echo "✅ Deploy complete → ${DEST}"
