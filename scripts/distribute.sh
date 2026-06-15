#!/usr/bin/env bash
# Builds a notarized ScreenCap DMG for distribution.
#
# Prerequisites:
#   1. Developer ID Application certificate installed in your keychain.
#      Create one at developer.apple.com > Certificates, Identifiers & Profiles.
#
#   2. Notarization credentials stored in your keychain (one-time setup):
#        xcrun notarytool store-credentials "ScreenCap-notarization" \
#          --apple-id "YOUR_APPLE_ID" \
#          --team-id "YOUR_TEAM_ID" \
#          --password "APP_SPECIFIC_PASSWORD"
#      App-specific passwords: appleid.apple.com > Security > App-Specific Passwords
#
# Output: dist/ScreenCap-<version>.dmg (notarized and stapled)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT="$ROOT/ScreenCap.xcodeproj"
SCHEME="ScreenCap"
CONFIG="Release"
APP_NAME="ScreenCap.app"
ENTITLEMENTS="$ROOT/ScreenCap/ScreenCap.entitlements"
KEYCHAIN_PROFILE="ScreenCap-notarization"
DIST_DIR="$ROOT/dist"

# Require Developer ID Application cert
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')
if [[ -z "$IDENTITY" ]]; then
  echo "ERROR: No 'Developer ID Application' certificate found in keychain."
  echo "       Create one at developer.apple.com and download it to Keychain Access."
  exit 1
fi

# Get version
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
  | awk '/^ *MARKETING_VERSION/{print $3}')
DMG_NAME="ScreenCap-${VERSION}.dmg"

echo "==> Building $VERSION (Release)..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build \
  2>&1 | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" | grep -v "warning:" || true

BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
  | awk '/^ *BUILT_PRODUCTS_DIR/{print $3}')
BUILT_APP="$BUILD_DIR/$APP_NAME"

echo "==> Signing with: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  "$BUILT_APP"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$BUILT_APP" 2>&1 | grep -v "^$" || true
spctl --assess --type exec --verbose "$BUILT_APP" 2>&1 || true

mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

echo "==> Creating DMG..."
STAGING=$(mktemp -d)
cp -a "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "ScreenCap" -srcfolder "$STAGING" \
  -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"

echo "==> Submitting for notarization (this may take a minute)..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "Done! Distribution-ready DMG:"
echo "  $DMG_PATH"
