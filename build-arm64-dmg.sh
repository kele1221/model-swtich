#!/usr/bin/env bash
# model-swtich arm64 DMG build.
#
# No arguments are required. This builds the renderer, creates the arm64
# macOS app bundle via Tauri, then packages a DMG with hdiutil.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

TARGET_TRIPLE="aarch64-apple-darwin"
LOCAL_STATE_DIR="$ROOT_DIR/.cc-switch"
LOCAL_VERSION_FILE="$LOCAL_STATE_DIR/build-arm64-dmg.version"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"

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
require_cmd pgrep
require_cmd rsync
require_cmd osascript

next_local_version() {
  local current major minor patch

  current="0.0.0"
  if [[ -f "$LOCAL_VERSION_FILE" ]]; then
    current="$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE")"
  fi

  if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf '[build-arm64-dmg] invalid local build version in %s: %s\n' "$LOCAL_VERSION_FILE" "$current" >&2
    exit 1
  fi

  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  printf '%s.%s.%s' "$major" "$minor" "$((patch + 1))"
}

save_local_version() {
  mkdir -p "$LOCAL_STATE_DIR"
  printf '%s\n' "$1" > "$LOCAL_VERSION_FILE"
}

kill_running_app() {
  local product_name="$1"
  local pids

  osascript >/dev/null 2>&1 <<OSA || true
tell application "$product_name"
  if it is running then quit
end tell
OSA

  pids="$(
    {
      pgrep -x "$product_name" 2>/dev/null || true
      pgrep -f "/$product_name.app/Contents/MacOS/" 2>/dev/null || true
    } | sort -u | grep -v "^$$$" || true
  )"

  if [[ -z "$pids" ]]; then
    return 0
  fi

  log "stopping running app: $product_name"
  kill -TERM $pids 2>/dev/null || true
  sleep 2

  pids="$(
    {
      pgrep -x "$product_name" 2>/dev/null || true
      pgrep -f "/$product_name.app/Contents/MacOS/" 2>/dev/null || true
    } | sort -u | grep -v "^$$$" || true
  )"

  if [[ -n "$pids" ]]; then
    log "force killing running app: $product_name"
    kill -KILL $pids 2>/dev/null || true
  fi
}

replace_installed_app() {
  local app_bundle="$1"
  local product_name="$2"
  local installed_app="$INSTALL_DIR/$product_name.app"
  local temp_app="$INSTALL_DIR/.$product_name.app.tmp.$$"

  kill_running_app "$product_name"

  log "replacing installed app: $installed_app"
  if [[ -w "$INSTALL_DIR" ]]; then
    rm -rf "$temp_app"
    mkdir -p "$temp_app"
    rsync -a --delete "$app_bundle/" "$temp_app/"
    rm -rf "$installed_app"
    mv "$temp_app" "$installed_app"
    xattr -dr com.apple.quarantine "$installed_app" 2>/dev/null || true
  else
    require_cmd sudo
    sudo rm -rf "$temp_app"
    sudo mkdir -p "$temp_app"
    sudo rsync -a --delete "$app_bundle/" "$temp_app/"
    sudo rm -rf "$installed_app"
    sudo mv "$temp_app" "$installed_app"
    sudo xattr -dr com.apple.quarantine "$installed_app" 2>/dev/null || true
  fi
}

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
rm -rf dist
pnpm tauri build \
  --target "$TARGET_TRIPLE" \
  --bundles app \
  --config '{"bundle":{"createUpdaterArtifacts":false}}'

if ! grep -R "Claude CN" dist >/dev/null 2>&1; then
  printf '[build-arm64-dmg] renderer verification failed: dist does not contain Claude CN\n' >&2
  exit 1
fi

PRODUCT_NAME="$(node -e "const c=require('./src-tauri/tauri.conf.json'); process.stdout.write(c.productName)")"
LOCAL_BUILD_VERSION="$(next_local_version)"
APP_BUNDLE="src-tauri/target/$TARGET_TRIPLE/release/bundle/macos/$PRODUCT_NAME.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  printf '[build-arm64-dmg] expected app bundle was not found: %s\n' "$APP_BUNDLE" >&2
  exit 1
fi
DMG_DIR="src-tauri/target/$TARGET_TRIPLE/release/bundle/dmg"
DMG_PATH="$DMG_DIR/${PRODUCT_NAME}_${LOCAL_BUILD_VERSION}_aarch64.dmg"
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

save_local_version "$LOCAL_BUILD_VERSION"
replace_installed_app "$APP_BUNDLE" "$PRODUCT_NAME"

log "DMG ready: $DMG_PATH"
log "installed app updated: $INSTALL_DIR/$PRODUCT_NAME.app"
