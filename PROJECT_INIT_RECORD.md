# model-swtich Init Record

## Repository

- Fork source: `farion1231/cc-switch`
- Fork target: `kele1221/model-swtich`
- Local path: `/Users/k/code/exploratory-code/model-swtich`
- Default branch: `main`

## Added Local Scripts

- `./hot-start.sh`
  - Starts local Tauri dev mode with no arguments.
  - Installs `node_modules` first if missing.

- `./build-arm64-dmg.sh`
  - Builds an Apple Silicon DMG with no arguments.
  - Ensures the `aarch64-apple-darwin` Rust target is installed.
  - Builds the Tauri `.app` bundle with updater artifacts disabled for local packaging.
  - Packages the final DMG with macOS `hdiutil` and prints the generated path.

## Feature Summary

Implemented first-stage `claude-cn` model switching support:

- Adds a separate `claude-cn` app slot.
- Keeps `claude` writing to `~/.claude/settings.json`.
- Writes `claude-cn` to `~/.claude-cn/settings.json`.
- Keeps provider namespaces and current provider state independent.
- Reuses existing Claude provider form and live settings sanitizer.
- Keeps MCP, Skills, Prompt, and Proxy support intentionally minimal/no-op for this stage.

## Verification Notes

The final main-thread verification should be treated as the source of truth for the current checkout. Earlier delegation artifacts include intermediate failures and rework rounds.

The root DMG script was executed successfully and produced:

- `src-tauri/target/aarch64-apple-darwin/release/bundle/dmg/CC Switch_3.15.0_aarch64.dmg`
