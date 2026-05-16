#!/usr/bin/env bash
# model-swtich local hot start.
#
# No arguments are required. This starts the Tauri dev app and lets the
# configured beforeDevCommand run the Vite renderer at http://localhost:3000.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

log() {
  printf '[hot-start] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[hot-start] missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_cmd node
require_cmd pnpm
require_cmd cargo

if [[ ! -f package.json || ! -f src-tauri/tauri.conf.json ]]; then
  printf '[hot-start] run this script from the model-swtich project root.\n' >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  log "node_modules not found; installing dependencies..."
  pnpm install
fi

log "starting Tauri dev mode..."
exec pnpm tauri dev
