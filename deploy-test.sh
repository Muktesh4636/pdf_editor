#!/usr/bin/env bash
# Convenience wrapper for the test VPS (same defaults as deploy.sh).
# Override: DEPLOY_HOST=... DEPLOY_REMOTE=... ./deploy-test.sh
set -euo pipefail
cd "$(dirname "$0")"
exec ./deploy.sh "$@"
