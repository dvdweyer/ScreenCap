#!/usr/bin/env bash
# Builds ScreenCap, signs it with the Apple Development certificate, installs
# it to /Applications, and launches it.
#
# Signing happens on the DerivedData copy BEFORE rsyncing to /Applications.
# This means the binary in /Applications always carries the same stable
# designated requirement (Apple Development cert), so TCC remembers
# Accessibility / Screen Recording / Notifications across builds.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(dirname "$SCRIPT_DIR")/ScreenCap.xcodeproj"
SCHEME="ScreenCap"
CONFIG="Debug"
APP_NAME="ScreenCap.app"
INSTALL_PATH="/Applications/$APP_NAME"

# Prefer a real Developer cert; fall back to ad-hoc with a warning.
# Ad-hoc ties the designated requirement to the binary hash, which changes
# every build and causes TCC to re-prompt.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Apple Development|Developer ID/{print $2; exit}')
if [[ -z "$IDENTITY" ]]; then
  echo "WARNING: No Developer certificate found -- falling back to ad-hoc signing."
  echo "         TCC will re-prompt for permissions after each build."
  IDENTITY="-"
fi

echo "==> Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build \
  2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
  | awk '/^ *BUILT_PRODUCTS_DIR/{print $3}')
BUILT_APP="$BUILD_DIR/$APP_NAME"

# Sign the DerivedData copy BEFORE installing.
# Signing after rsync would invalidate any TCC entry that was created for
# the previously-installed signature.
if [[ "$IDENTITY" != "-" ]]; then
  echo "==> Signing with: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" --options runtime "$BUILT_APP"
fi

if pgrep -x ScreenCap &>/dev/null; then
  echo "==> Stopping running instance..."
  killall ScreenCap
  sleep 0.5
fi

echo "==> Installing to $INSTALL_PATH"
rsync -a --delete "$BUILT_APP/" "$INSTALL_PATH/"

echo "==> Launching..."
open "$INSTALL_PATH"
echo "Done."
