#!/usr/bin/env bash
# model-swtich arm64 DMG build.
#
# No arguments are required. This builds the renderer, creates the arm64
# macOS app bundle via Tauri, then packages a DMG with hdiutil.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

TARGET_TRIPLE="aarch64-apple-darwin"

log() {
  printf '[build-arm64-dmg] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[build-arm64-dmg] missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_cmd node
require_cmd pnpm
require_cmd cargo
require_cmd rustup
require_cmd hdiutil

if [[ ! -f package.json || ! -f src-tauri/tauri.conf.json ]]; then
  printf '[build-arm64-dmg] run this script from the model-swtich project root.\n' >&2
  exit 1
fi

if [[ ! -d node_modules ]]; then
  log "node_modules not found; installing dependencies..."
  pnpm install
fi

if ! rustup target list --installed 2>/dev/null | grep -qx "$TARGET_TRIPLE"; then
  log "installing Rust target $TARGET_TRIPLE..."
  rustup target add "$TARGET_TRIPLE"
fi

log "building arm64 app bundle..."
pnpm tauri build \
  --target "$TARGET_TRIPLE" \
  --bundles app \
  --config '{"bundle":{"createUpdaterArtifacts":false}}'

APP_BUNDLE="$(find src-tauri/target/"$TARGET_TRIPLE"/release/bundle/macos -maxdepth 1 -name '*.app' -type d 2>/dev/null | sort | tail -n 1 || true)"
if [[ -z "$APP_BUNDLE" ]]; then
  printf '[build-arm64-dmg] app bundle was not found under src-tauri/target/%s/release/bundle/macos\n' "$TARGET_TRIPLE" >&2
  exit 1
fi

PRODUCT_NAME="$(node -e "const c=require('./src-tauri/tauri.conf.json'); process.stdout.write(c.productName)")"
PRODUCT_VERSION="$(node -e "const c=require('./src-tauri/tauri.conf.json'); process.stdout.write(c.version)")"
DMG_DIR="src-tauri/target/$TARGET_TRIPLE/release/bundle/dmg"
DMG_PATH="$DMG_DIR/${PRODUCT_NAME}_${PRODUCT_VERSION}_aarch64.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/model-swtich-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

log "packaging DMG..."
hdiutil create "$DMG_PATH" \
  -volname "$PRODUCT_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO

log "DMG ready: $DMG_PATH"
