#!/usr/bin/env bash
#
# Run ON THE VPS (not from Cursor). After you connect with your own SSH:
#   ssh root@72.61.148.117
#   cd /path/to/pdf-editor/deploy
#
# Diagnose only (needs root for nginx -T):
#   sudo bash vps-diagnose-fix-400.sh
#
# Diagnose + apply nginx + Let's Encrypt fix (same as setup-pdfforge-on-vps.sh):
#   sudo bash vps-diagnose-fix-400.sh --apply your-email@example.com
#
# Cursor/agents cannot SSH to your host without your SSH key; this script is what you run there.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP="${SCRIPT_DIR}/setup-pdfforge-on-vps.sh"

apply() {
  local email="${1:-}"
  if [[ -z "${email}" ]]; then
    echo "Usage: sudo $0 --apply your-email@example.com"
    exit 1
  fi
  if [[ ! -f "${SETUP}" ]]; then
    echo "Missing ${SETUP}"
    exit 1
  fi
  exec bash "${SETUP}" "${email}"
}

if [[ "${1:-}" == "--apply" ]]; then
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "Re-run with sudo: sudo $0 --apply ${2:-}"
    exit 1
  fi
  apply "${2:-}"
fi

echo "========== pdfforge.store / 400 diagnose =========="
echo "Hostname: $(hostname -f 2>/dev/null || hostname)"
echo ""

echo "--- TLS cert file (pdfforge) if present ---"
if [[ -f /etc/letsencrypt/live/pdfforge.store/fullchain.pem ]]; then
  openssl x509 -in /etc/letsencrypt/live/pdfforge.store/fullchain.pem -noout -subject -ext subjectAltName 2>/dev/null || true
else
  echo "(no /etc/letsencrypt/live/pdfforge.store/fullchain.pem yet)"
fi
echo ""

echo "--- nginx: lines mentioning pdfforge (need 443 ssl + server_name) ---"
if command -v nginx >/dev/null; then
  nginx -T 2>/dev/null | grep -nE 'pdfforge|server_name|listen.*443' | head -60 || true
else
  echo "nginx not found"
fi
echo ""

echo "--- sites-enabled ---"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true
echo ""

echo "--- static root ---"
ROOT="${SITE_ROOT:-/var/www/pdfforge.store}"
ls -la "${ROOT}/index.html" 2>/dev/null || echo "Missing ${ROOT}/index.html (run ./deployment.sh from laptop)"
echo ""

echo "--- HTTPS to self with SNI (should be 200 after fix) ---"
if command -v curl >/dev/null; then
  curl -skSI --resolve pdfforge.store:443:127.0.0.1 "https://pdfforge.store/" 2>&1 | head -12 || true
else
  echo "curl not installed"
fi
echo ""

echo "If you see 400 above and no pdfforge cert, apply fix:"
echo "  sudo bash ${SCRIPT_DIR}/vps-diagnose-fix-400.sh --apply your-email@example.com"
echo "(same as: sudo bash ${SETUP} your-email@example.com)"
