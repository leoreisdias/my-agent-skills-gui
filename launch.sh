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

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -d "$APP_BUNDLE" ]] || fail "App bundle not found at ${APP_BUNDLE}. Run ./build-app.sh first."

log "==> Killing existing ${APP_NAME} instances"
pkill -f "${DISPLAY_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
pkill -x "${APP_NAME}" 2>/dev/null || true

log "==> Launching ${DISPLAY_NAME}"
open -n "$APP_BUNDLE"

sleep 1
if pgrep -x "${APP_NAME}" >/dev/null 2>&1 || pgrep -f "${DISPLAY_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1; then
  log "OK: ${DISPLAY_NAME} is running."
else
  fail "The app exited immediately. Check Console.app for crash logs."
fi
