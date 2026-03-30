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
BUNDLE_ID="${BUNDLE_ID:-com.myagentskills.app}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MACOS_MIN_VERSION="${MACOS_MIN_VERSION:-13.0}"
MENU_BAR_APP="${MENU_BAR_APP:-1}"
SIGNING_MODE="${SIGNING_MODE:-adhoc}"
APP_IDENTITY="${APP_IDENTITY:-}"
CONF="${1:-release}"
APP_DIR="$ROOT_DIR/${DISPLAY_NAME}.app"
INFO_PLIST_SOURCE="$ROOT_DIR/Sources/${APP_NAME}/Resources/Info.plist"
INFO_PLIST_TARGET="$APP_DIR/Contents/Info.plist"
MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

for command_name in swift codesign plutil file; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Missing required command: $command_name"
done

build_product_path() {
  local arch="$1"
  local arch_specific="$ROOT_DIR/.build/${arch}-apple-macosx/${CONF}/${APP_NAME}"
  local fallback="$ROOT_DIR/.build/${CONF}/${APP_NAME}"

  if [[ -f "$arch_specific" ]]; then
    printf '%s\n' "$arch_specific"
    return 0
  fi

  if [[ -f "$fallback" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  return 1
}

prepare_arch_list() {
  if [[ -n "${ARCHES:-}" ]]; then
    read -r -a ARCH_LIST <<< "${ARCHES}"
  else
    ARCH_LIST=("$(uname -m)")
  fi
}

build_products() {
  mkdir -p "$MODULE_CACHE_DIR"
  for arch in "${ARCH_LIST[@]}"; do
    log "🔨 Building ${APP_NAME} (${CONF}, ${arch})..."
    CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" swift build -c "$CONF" --arch "$arch"
  done
}

install_binary() {
  local destination="$APP_DIR/Contents/MacOS/${APP_NAME}"
  local built_binaries=()

  for arch in "${ARCH_LIST[@]}"; do
    local source_binary
    source_binary="$(build_product_path "$arch")" || fail "Could not find the SwiftPM output for ${arch}."
    built_binaries+=("$source_binary")
  done

  if [[ "${#built_binaries[@]}" -gt 1 ]]; then
    command -v lipo >/dev/null 2>&1 || fail "lipo is required for multi-architecture builds."
    lipo -create "${built_binaries[@]}" -output "$destination"
  else
    cp "${built_binaries[0]}" "$destination"
  fi

  chmod +x "$destination"
}

copy_optional_bundles() {
  local search_directories=(
    "$ROOT_DIR/.build/${CONF}"
    "$ROOT_DIR/.build/${ARCH_LIST[0]}-apple-macosx/${CONF}"
  )

  shopt -s nullglob
  for directory in "${search_directories[@]}"; do
    for bundle in "$directory"/*.bundle; do
      cp -R "$bundle" "$APP_DIR/Contents/Resources/"
    done
    for framework in "$directory"/*.framework; do
      cp -R "$framework" "$APP_DIR/Contents/Frameworks/"
    done
  done
  shopt -u nullglob
}

prepare_info_plist() {
  [[ -f "$INFO_PLIST_SOURCE" ]] || fail "Missing Info.plist template at ${INFO_PLIST_SOURCE}"

  cp "$INFO_PLIST_SOURCE" "$INFO_PLIST_TARGET"

  local git_commit build_timestamp lsui_value
  git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  build_timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  lsui_value="YES"
  if [[ "$MENU_BAR_APP" != "1" ]]; then
    lsui_value="NO"
  fi

  plutil -replace CFBundleDisplayName -string "$DISPLAY_NAME" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleExecutable -string "$APP_NAME" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleIconFile -string "AppIcon" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleName -string "$DISPLAY_NAME" "$INFO_PLIST_TARGET"
  plutil -replace CFBundlePackageType -string "APPL" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$INFO_PLIST_TARGET"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$INFO_PLIST_TARGET"
  plutil -replace LSMinimumSystemVersion -string "$MACOS_MIN_VERSION" "$INFO_PLIST_TARGET"
  plutil -replace LSUIElement -bool "$lsui_value" "$INFO_PLIST_TARGET"
  plutil -replace BuildTimestamp -string "$build_timestamp" "$INFO_PLIST_TARGET"
  plutil -replace GitCommit -string "$git_commit" "$INFO_PLIST_TARGET"
}

copy_static_resources() {
  if [[ -d "$ROOT_DIR/Sources/${APP_NAME}/Resources" ]]; then
    if [[ -f "$ROOT_DIR/Sources/${APP_NAME}/Resources/AppIcon.icns" ]]; then
      cp "$ROOT_DIR/Sources/${APP_NAME}/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    fi
  fi
}

sign_bundle() {
  xattr -cr "$APP_DIR"
  find "$APP_DIR" -name '._*' -delete

  if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
    log "🔏 Applying ad-hoc signature..."
    codesign --force --sign - "$APP_DIR"
    return 0
  fi

  log "🔏 Signing with ${APP_IDENTITY}..."
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" "$APP_DIR"
}

validate_bundle() {
  local executable="$APP_DIR/Contents/MacOS/${APP_NAME}"
  [[ -d "$APP_DIR/Contents" ]] || fail "Missing app bundle contents."
  [[ -x "$executable" ]] || fail "Missing bundled executable at ${executable}."

  log "🔎 Verifying bundled executable..."
  file "$executable"

  log "🔎 Inspecting code signature..."
  codesign -dv --verbose=4 "$APP_DIR"

  if command -v spctl >/dev/null 2>&1; then
    log "🔎 Running Gatekeeper assessment..."
    if ! spctl_output="$(spctl --assess --type execute --verbose "$APP_DIR" 2>&1)"; then
      warn "Gatekeeper assessment did not pass in this environment."
      printf '%s\n' "$spctl_output"
    else
      printf '%s\n' "$spctl_output"
    fi
  fi
}

prepare_arch_list
build_products

log "📦 Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"

install_binary
prepare_info_plist
copy_static_resources
copy_optional_bundles
sign_bundle
validate_bundle

log "✅ Built: $APP_DIR"
log ""
log "To install:"
log "  cp -r \"$APP_DIR\" /Applications/"
log ""
log "To run:"
log "  open \"$APP_DIR\""
