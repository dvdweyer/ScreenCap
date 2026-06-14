#!/usr/bin/env bash
# Resets ScreenCap to a clean pre-first-launch state:
# kills the app, wipes UserDefaults, and revokes all three permission grants.
set -euo pipefail

BUNDLE_ID="org.afaik.ScreenCap"

echo "Stopping ScreenCap (if running)…"
killall ScreenCap 2>/dev/null && sleep 0.5 || true

echo "Deleting UserDefaults…"
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo "Revoking Accessibility permission…"
tccutil reset Accessibility "$BUNDLE_ID"

echo "Revoking Screen Recording permission…"
tccutil reset ScreenCapture "$BUNDLE_ID"

echo "Revoking Notifications permission…"
tccutil reset UserNotification "$BUNDLE_ID"

echo "Done — ScreenCap is back to pre-first-launch state."
