#!/usr/bin/env bash
#
# PDF Forge — deploy static site to your VPS (rsync over SSH).
#
# Host default: root@72.61.148.117 → /var/www/pdf.pravoo.in/
# (pdfforge.store and pdf.pravoo.in nginx both use root /var/www/pdf.pravoo.in —
# syncing to pdfforge.store/ would leave the live site stale.)
#
# SECURITY — read this:
# • Never commit secrets. Optional local file .env.deploy is gitignored.
# • Prefer SSH keys: ssh-copy-id -i ~/.ssh/id_ed25519.pub root@72.61.148.117
# • If you pasted a password in chat anywhere, rotate it on the server.
#
# Password-based deploy (not recommended): install sshpass, put ONLY in .env.deploy:
#   export SSHPASS='your-password-here'
# Then run ./deploy.sh  (Uses: sshpass -e ssh ...)
#
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${DIR}/.env.deploy" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${DIR}/.env.deploy"
  set +a
fi

DEPLOY_HOST="${DEPLOY_HOST:-root@72.61.148.117}"
DEPLOY_REMOTE="${DEPLOY_REMOTE:-/var/www/pdf.pravoo.in/}"

# RSYNC_RSH: ssh for rsync. Set RSYNC_RSH in .env.deploy to force (e.g. custom -i key).
if [[ -n "${RSYNC_RSH:-}" ]]; then
  :
elif [[ -n "${SSHPASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
  RSYNC_RSH="sshpass -e ssh -o StrictHostKeyChecking=accept-new -o PreferredAuthentications=password -o PubkeyAuthentication=no"
elif [[ -n "${SSHPASS:-}" ]] && ! command -v sshpass >/dev/null 2>&1; then
  echo "SSHPASS is set but sshpass is not installed. Install: brew install sshpass / apt install sshpass" >&2
  echo "Or remove SSHPASS from .env.deploy and use ssh-copy-id instead." >&2
  exit 1
else
  RSYNC_RSH="ssh -o StrictHostKeyChecking=accept-new"
fi

print_help() {
  cat <<'EOF'
PDF Forge — static deployment (rsync → SSH)

Default remote: root@72.61.148.117:/var/www/pdf.pravoo.in/

Usage:
  ./deploy.sh                    # rsync files
  ./deploy.sh --dry-run | -n     # list what would be sent
  ./deploy.sh -h | --help

Optional file (ignored by git):  pdf-editor/.env.deploy
  export DEPLOY_REMOTE=/var/www/pdf.pravoo.in/
  # Optional — only if you refuse SSH keys:
  export SSHPASS='your-ssh-password'
  # Optional — custom key:
  # export RSYNC_RSH='ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new'

Prefer passwordless login:
  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@72.61.148.117

Rotate any password that may have leaked (chat, screenshots, repos).
EOF
}

case "${1:-}" in
  -h|--help) print_help; exit 0 ;;
esac

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
  install-banner.js
  sw.js
)

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]]; then
  DRY_RUN=1
fi

RSYNC_BASE=(rsync -avz --progress -e "$RSYNC_RSH")
if [[ "$DRY_RUN" == 1 ]]; then
  RSYNC_BASE+=(--dry-run)
  echo "Dry run — nothing will be written on the remote."
fi

PATHS=()
MISSING=0
for f in "${FILES[@]}"; do
  if [[ ! -f "${DIR}/${f}" ]]; then
    echo "Missing file (abort): ${DIR}/${f}" >&2
    MISSING=1
  else
    PATHS+=("${DIR}/${f}")
  fi
done
[[ "$MISSING" == 1 ]] && exit 1

echo "→ ${DEST}"
echo "   ${#FILES[@]} files"

"${RSYNC_BASE[@]}" "${PATHS[@]}" "${DEST}"

if [[ "$DRY_RUN" == 0 ]]; then
  echo "✅ Deploy complete → ${DEST}"
else
  echo "✅ Dry run finished (no files changed)."
fi
