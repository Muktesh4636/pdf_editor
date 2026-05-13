#!/usr/bin/env bash
#
# PDF Forge — static site deployment (rsync over SSH).
#
# Usage:
#   ./deployment.sh
#   ./deployment.sh --dry-run
#   ./deployment.sh --help
#
# Environment (optional):
#   DEPLOY_HOST     default: root@72.61.148.117
#   DEPLOY_REMOTE   default: /var/www/pdfforge.store/
#   RSYNC_RSH       default: ssh -o StrictHostKeyChecking=accept-new
#                   example: RSYNC_RSH='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new'
#
# One-time on your laptop:
#   ssh-copy-id -i ~/.ssh/id_ed25519.pub "${DEPLOY_HOST:-root@72.61.148.117}"

set -euo pipefail

DEPLOY_HOST="${DEPLOY_HOST:-root@72.61.148.117}"
DEPLOY_REMOTE="${DEPLOY_REMOTE:-/var/www/pdfforge.store/}"
RSYNC_RSH="${RSYNC_RSH:-ssh -o StrictHostKeyChecking=accept-new}"

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${DEPLOY_HOST}:$(echo "${DEPLOY_REMOTE}" | sed 's:/*$::')/"

FILES=(
  index.html
  edit-pdf.html
  merge-pdf.html
  compress-pdf.html
  remove-pages.html
  remove-pdf-password.html
  bank-transactions.html
  img-to-pdf.html
  pdf-to-img.html
  word-to-pdf.html
  excel-to-pdf.html
  pptx-to-pdf.html
  epub-to-pdf.html
  pdf-to-word.html
  pdf-to-excel.html
  pdf-to-pptx.html
  pdf-to-epub.html
  sitemap.xml
  robots.txt
  manifest.json
  favicon.ico
  icon-16.png
  icon-32.png
  icon-192.png
  icon-512.png
)

RSYNC_BASE=(rsync -avz --progress -e "$RSYNC_RSH")
if [[ "${1:-}" == "--dry-run" ]]; then
  RSYNC_BASE+=(--dry-run)
  echo "Dry run — no files will be written on the server."
fi

PATHS=()
for f in "${FILES[@]}"; do
  if [[ ! -f "${DIR}/${f}" ]]; then
    echo "Missing file (abort): ${DIR}/${f}" >&2
    exit 1
  fi
  PATHS+=("${DIR}/${f}")
done

echo "→ ${DEST}"
echo "   ${#FILES[@]} files · override with DEPLOY_HOST / DEPLOY_REMOTE"

"${RSYNC_BASE[@]}" "${PATHS[@]}" "${DEST}"

echo "✅ Deploy complete → ${DEST}"
