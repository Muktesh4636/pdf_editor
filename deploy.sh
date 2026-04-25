#!/usr/bin/env bash
# deploy.sh — push all pdf.pravoo.in files to the VPS
# Usage: ./deploy.sh
# First time: run  ssh-copy-id root@72.61.148.117  to authorise your key

set -e
SERVER="root@72.61.148.117"
REMOTE="/var/www/pdf.pravoo.in/"
DIR="$(cd "$(dirname "$0")" && pwd)"

rsync -avz --progress \
  -e "ssh -o StrictHostKeyChecking=no" \
  "$DIR/index.html" \
  "$DIR/edit-pdf.html" \
  "$DIR/merge-pdf.html" \
  "$DIR/compress-pdf.html" \
  "$DIR/remove-pages.html" \
  "$DIR/remove-pdf-password.html" \
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
  "$SERVER:$REMOTE"

echo "✅ Deploy complete"
