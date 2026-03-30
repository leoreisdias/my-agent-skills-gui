#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/version.env"
fi

DISPLAY_NAME="${DISPLAY_NAME:-AI Skills Companion}"
DMG_NAME="${DMG_NAME:-${DISPLAY_NAME}.dmg}"
DIST_DIR="${DIST_DIR:-dist}"
DMG_CONTENTS_DIR="$DIST_DIR/dmg"
APP_BUNDLE="${DISPLAY_NAME}.app"

log() { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$DIST_DIR"

"$ROOT_DIR/build-app.sh" release

[[ -d "$APP_BUNDLE" ]] || fail "Expected ${APP_BUNDLE} to exist after packaging."

log "🧹 Preparing DMG contents..."
rm -rf "$DMG_CONTENTS_DIR"
mkdir -p "$DMG_CONTENTS_DIR"

cp -R "$APP_BUNDLE" "$DMG_CONTENTS_DIR/"
ln -s /Applications "$DMG_CONTENTS_DIR/Applications"

log "📀 Creating DMG..."
rm -f "$DIST_DIR/$DMG_NAME"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$DMG_CONTENTS_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$DMG_NAME"

[[ -f "$DIST_DIR/$DMG_NAME" ]] || fail "DMG creation did not produce ${DIST_DIR}/${DMG_NAME}."

log "✅ Built: $DIST_DIR/$DMG_NAME"
