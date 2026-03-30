#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/version.env"
fi

APP_NAME="${APP_NAME:-myAgentSkills}"
DISPLAY_NAME="${DISPLAY_NAME:-AI Skills Companion}"
APP_BUNDLE="$ROOT_DIR/${DISPLAY_NAME}.app"
RUN_TESTS=0
CONFIG="release"
MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for arg in "$@"; do
  case "$arg" in
    --test|-t) RUN_TESTS=1 ;;
    --debug) CONFIG="debug" ;;
    --release) CONFIG="release" ;;
    --help|-h)
      log "Usage: $(basename "$0") [--test] [--debug|--release]"
      exit 0
      ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

log "==> Killing existing ${APP_NAME} instances"
pkill -f "${DISPLAY_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
pkill -x "${APP_NAME}" 2>/dev/null || true

if [[ "$RUN_TESTS" == "1" ]]; then
  log "==> swift test"
  mkdir -p "$MODULE_CACHE_DIR"
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swift test
fi

log "==> Packaging app (${CONFIG})"
"$ROOT_DIR/build-app.sh" "$CONFIG"

[[ -d "$APP_BUNDLE" ]] || fail "Expected app bundle at ${APP_BUNDLE}"

log "==> Launching ${DISPLAY_NAME}"
if ! open "$APP_BUNDLE"; then
  log "WARN: open failed; launching the binary directly."
  "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 &
  disown
fi

for _ in {1..10}; do
  if pgrep -x "${APP_NAME}" >/dev/null 2>&1 || pgrep -f "${DISPLAY_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1; then
    log "OK: ${DISPLAY_NAME} is running."
    exit 0
  fi
  sleep 0.4
done

fail "The app exited immediately. Check Console.app for crash logs."
