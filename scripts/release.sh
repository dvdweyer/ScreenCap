#!/usr/bin/env bash
# Tags the current version, builds a notarized DMG, and publishes a GitHub Release.
#
# Prerequisites: Developer ID Application certificate and notarization credentials
# in keychain (see distribute.sh header). Also requires `gh` authenticated:
#   gh auth login
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT="$ROOT/ScreenCap.xcodeproj"
SCHEME="ScreenCap"
CONFIG="Release"
DIST_DIR="$ROOT/dist"

# -- Preflight checks --

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh not found. Install with: brew install gh"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh is not authenticated. Run: gh auth login"
  exit 1
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  echo "ERROR: No 'Developer ID Application' certificate found in keychain."
  exit 1
fi

# -- Version --

VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIG" -showBuildSettings 2>/dev/null \
  | awk '/^ *MARKETING_VERSION/{print $3}')
TAG="v$VERSION"
DMG_PATH="$DIST_DIR/ScreenCap-${VERSION}.dmg"

echo "==> Releasing $TAG"

# Bail if tag already exists locally or on remote
if git -C "$ROOT" tag --list | grep -qx "$TAG"; then
  echo "ERROR: Tag $TAG already exists locally. Bump MARKETING_VERSION first."
  exit 1
fi
if gh release view "$TAG" &>/dev/null; then
  echo "ERROR: GitHub Release $TAG already exists."
  exit 1
fi

# -- Build notarized DMG --

"$SCRIPT_DIR/distribute.sh"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "ERROR: Expected DMG not found at $DMG_PATH"
  exit 1
fi

# -- Tag and push --

echo "==> Tagging $TAG"
git -C "$ROOT" tag "$TAG"
git -C "$ROOT" push origin "$TAG"

# -- Create GitHub Release --

echo "==> Creating GitHub Release $TAG"
gh release create "$TAG" "$DMG_PATH" \
  --title "ScreenCap $VERSION" \
  --generate-notes \
  --repo dvdweyer/ScreenCap

echo ""
echo "Done! Release published:"
gh release view "$TAG" --repo dvdweyer/ScreenCap --json url -q .url
