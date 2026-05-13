#!/usr/bin/env bash
# Wrapper — full script is deployment.sh
set -euo pipefail
cd "$(dirname "$0")"
exec ./deployment.sh "$@"
