#!/usr/bin/env bash
set -euo pipefail

if command -v umao-sync-calamares-config >/dev/null 2>&1; then
  umao-sync-calamares-config
fi
