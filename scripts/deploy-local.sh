#!/usr/bin/env bash
# Builds ScreenCap, installs it to /Applications, and launches it.
#
# Using a fixed install path + a real Developer certificate keeps the
# code-signing designated requirement stable across builds, so TCC
# (Accessibility, Screen Recording, Notifications) remembers previously
# granted permissions and does not re-prompt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$SCRIPT_DIR")/ScreenCap.xcodeproj"
SCHEME="ScreenCap"
CONFIG="Debug"
APP_NAME="ScreenCap.app"
INSTALL_PATH="/Applications/$APP_NAME"

# Prefer a real Developer cert for a stable TCC identity; fall back to ad-hoc.
# Ad-hoc (-) ties identity to the binary hash, so TCC will re-prompt after
# every build. Avoid it if any Developer cert is available.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Apple Development|Developer ID/{print $2; exit}')
if [[ -z "$IDENTITY" ]]; then
  echo "WARNING: No Developer certificate found -- falling back to ad-hoc signing."
  echo "         TCC may re-prompt for permissions after each build."
  IDENTITY="-"
fi

echo "==> Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
  | awk '/^ *BUILT_PRODUCTS_DIR/{print $3}')

if pgrep -x ScreenCap &>/dev/null; then
  echo "==> Stopping running instance..."
  killall ScreenCap
  sleep 0.5
fi

echo "==> Installing to $INSTALL_PATH"
# rsync updates in place rather than replacing the bundle, keeping the
# install path stable in TCC even if permissions were already granted.
rsync -a --delete "$BUILD_DIR/$APP_NAME/" "$INSTALL_PATH/"

echo "==> Signing with: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" "$INSTALL_PATH"

echo "==> Launching..."
open "$INSTALL_PATH"
echo "Done."
