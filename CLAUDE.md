# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build (from ScreenCap/ directory containing the .xcodeproj)
xcodebuild -project ScreenCap.xcodeproj -scheme ScreenCap -configuration Debug build

# Run the built app
open "$(find ~/Library/Developer/Xcode/DerivedData/ScreenCap-*/Build/Products/Debug -name ScreenCap.app | head -1)"

# Stop the running app
killall ScreenCap
```

There are no tests. Open `ScreenCap.xcodeproj` in Xcode and press ⌘R to build and run interactively.

## Architecture

Single-target macOS app (`LSUIElement = YES` — menubar only, no Dock icon). No SwiftUI, no SPM, no sandbox.

**Capture flow** (triggered by hotkey or menu):
1. `AppDelegate.startCaptureFlow()` — resolves `NSScreen.main` (the display with key window focus) and shows `CountdownOverlay`
2. After the 3-second countdown completes, a 0.15 s delay lets the overlay dismiss before capture
3. `ScreenCaptureService.capture(displayID:to:)` (async) — uses `SCScreenshotManager` on macOS 14.2+, falls back to `SCStream`+`SingleFrameCapturer` on macOS 13
4. Success delivers a `UNUserNotification`; failure shows `NSAlert`

**Hotkey** — `HotkeyManager` uses `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission). Modifier flags are stored in `Preferences` as Carbon-style bitmasks (`cmdKey`, `shiftKey`, etc. from `Carbon.HIToolbox`) and converted to `NSEvent.ModifierFlags` for matching. Default shortcut is ⌘⇧3 (keyCode 20).

**Shortcut recording** — `ShortcutRecorderPanel` installs a *local* `NSEvent` monitor while its panel is key, captures the next key-down with at least one modifier, then hands `(keyCode: UInt32, carbonModifiers: UInt32)` back to `AppDelegate`, which re-registers the hotkey and persists to `UserDefaults`.

**Preferences** — all stored in `UserDefaults` via `Preferences.shared`. Save directory is stored as bookmark data (survives renames). Hotkey is stored as two integers (keyCode + Carbon modifier bitmask).

## macOS API constraints

- `CGDisplayCreateImage` is **removed** from the macOS 15 SDK — use `ScreenCaptureKit` only.
- Carbon `InstallApplicationEventHandler` / `GetApplicationEventTarget` are **removed** from macOS 15 SDK — hence `NSEvent.addGlobalMonitorForEvents` (and the Accessibility permission requirement).
- `SCScreenshotManager.captureImage` requires macOS 14.2+; the `SCStream`-based path in `ScreenCaptureService` handles macOS 13–14.1.
- SourceKit will show false "cannot find X in scope" errors for cross-file symbols outside an Xcode project context — these are indexing artifacts, not real errors.

## Required permissions (both needed at runtime)

- **Accessibility** — for the global hotkey monitor (`NSEvent.addGlobalMonitorForEvents`)
- **Screen Recording** — for `SCShareableContent` / `ScreenCaptureKit`
