#!/usr/bin/env bash
# Run ON THE VPS (or anywhere that can reach the origin) to narrow down HTTP 400.
# Usage: bash deploy/diagnose-site.sh [HOST]
#   HOST defaults to pdfforge.store

set -euo pipefail
HOST="${1:-pdfforge.store}"
ROOT="${ROOT:-/var/www/pdfforge.store}"

echo "=== 1) HTTPS GET / (expect HTTP/2 200 or 301) ==="
curl -sS -o /dev/null -w "%{http_code} %{url_effective}\n" "https://${HOST}/" || true

echo "=== 2) HTTPS GET /index.html ==="
curl -sS -o /dev/null -w "%{http_code}\n" "https://${HOST}/index.html" || true

echo "=== 3) HTTP on port 80 (expect 301 to https) ==="
curl -sS -o /dev/null -w "%{http_code} redirect-> %{redirect_url}\n" "http://${HOST}/" || true

echo "=== 4) Plain HTTP request to port 443 (often 400 — proves wrong scheme/port) ==="
curl -sS -o /dev/null -w "%{http_code}\n" "http://${HOST}:443/" || true

echo "=== 5) Local static file (expect 200 if root has index) ==="
if [[ -r "${ROOT}/index.html" ]]; then
  head -c 20 "${ROOT}/index.html" | od -An -tx1 | head -1
  echo "OK: ${ROOT}/index.html exists"
else
  echo "MISSING or unreadable: ${ROOT}/index.html (fix root= in nginx + deploy path)"
fi

echo "=== 6) PDF archive API (expect JSON 200) ==="
curl -sS "http://127.0.0.1:3847/api/health" | head -c 200 || echo "(API not running or wrong port — static pages can still work)"

echo ""
echo "If (4) is 400 but (1) is 200: problem was HTTP-on-443, not your HTML."
echo "If (1) is 400: check nginx -T for duplicate server blocks, wrong ssl_listen, or WAF in front."
echo "Tail errors: sudo tail -50 /var/log/nginx/error.log"
