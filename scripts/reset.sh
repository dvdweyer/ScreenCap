#!/usr/bin/env bash
# Resets ScreenCap to a clean pre-first-launch state:
# kills the app, wipes UserDefaults, and revokes all permission grants.
set -euo pipefail

BUNDLE_ID="org.afaik.ScreenCap"

echo "Stopping ScreenCap (if running)..."
killall ScreenCap 2>/dev/null && sleep 0.5 || true

# Close System Settings before resetting TCC so it reflects the new state
# when the user next opens it (it caches TCC entries while open).
killall "System Settings" 2>/dev/null || true

echo "Deleting UserDefaults..."
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo "Revoking Accessibility permission..."
tccutil reset Accessibility "$BUNDLE_ID"

echo "Revoking Screen Recording permission..."
tccutil reset ScreenCapture "$BUNDLE_ID"

# Notification permissions are not managed via tccutil on macOS 13+.
# To reset manually: System Settings > Notifications > ScreenCap > remove.

echo "Done -- ScreenCap is back to pre-first-launch state."
