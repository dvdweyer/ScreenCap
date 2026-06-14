# Architecture

This document explains how ScreenCap is structured internally. It is written for developers and curious learners who want to understand how the pieces fit together — including people who are new to macOS development.

You do not need to understand everything here to use ScreenCap. But if you want to modify it, learn from it, or use it as a starting point for your own app, this is the right place to start.

---

## The big picture

ScreenCap is a **menubar app** — it has no window, no Dock icon, and no visible presence other than a small icon in the menu bar at the top of your screen. In macOS terms, this is called an "LSUIElement" app (more on that below).

When the user presses the hotkey, ScreenCap:
1. Shows a full-screen countdown
2. Waits for the countdown to finish
3. Captures the display
4. Saves the result as a PNG and sends a notification

That is the entire core loop. The code is intentionally small and straightforward — there are no third-party dependencies and no complex frameworks.

---

## Key concepts for beginners

Before diving into the files, a few terms that appear throughout the code:

**AppDelegate** — In a macOS app, `AppDelegate` is the object that macOS calls when the app starts, when it quits, and when important events happen. Think of it as the app's main coordinator or "brain." Every macOS app has one.

**NSEvent monitor** — macOS lets you register a function that gets called whenever a key is pressed anywhere on the system, not just in your app. ScreenCap uses this to watch for the hotkey even when the user is in Safari, Finder, or anywhere else.

**ScreenCaptureKit** — Apple's modern framework for capturing screen content. It replaced older APIs in macOS 13 and later. ScreenCap uses it to take the actual screenshot.

**UserDefaults** — macOS's built-in system for saving small amounts of data between app launches. ScreenCap uses it to remember your hotkey and save folder.

**async/await** — A way of writing code that does something in the background (like capturing the screen) without freezing the user interface while it works.

---

## Source files

| File | What it does |
|---|---|
| `main.swift` | The very first file that runs when the app launches. It creates the `AppDelegate` and starts the app. |
| `AppDelegate.swift` | The central coordinator. It builds the menubar icon and menu, registers the hotkey, and starts the capture process. |
| `HotkeyManager.swift` | Listens for the keyboard shortcut system-wide and calls a function when it detects the right key combination. |
| `ShortcutRecorderPanel.swift` | Shows a small panel that lets the user press a new key combination to change the hotkey. |
| `CountdownOverlay.swift` | Draws the full-screen countdown (3, 2, 1) that appears before each capture. |
| `ScreenCaptureService.swift` | The code that actually takes the screenshot using Apple's ScreenCaptureKit. |
| `OnboardingWindowController.swift` | The first-launch setup wizard that asks the user to grant Accessibility and Screen Recording permissions. |
| `Preferences.swift` | Reads and writes the user's settings (hotkey, save folder) using `UserDefaults`. |

---

## How a screenshot is taken — step by step

This is the sequence of events every time the user triggers a capture:

```
User presses ⌘⇧3
       ↓
HotkeyManager detects the key combination
       ↓
AppDelegate.startCaptureFlow() is called
       ↓
CountdownOverlay appears (3 seconds)
       ↓
[0.15 second pause — lets the overlay fully disappear]
       ↓
ScreenCaptureService.capture() runs in the background
       ↓
PNG file is written to the save folder
       ↓
macOS notification appears: "Screenshot saved"
```

The 0.15-second pause before the capture is there so the countdown window itself does not appear in the screenshot. Without it, the overlay's final frame would still be visible on screen when the capture happens.

---

## The hotkey system

### Why the Accessibility permission is required

ScreenCap uses `NSEvent.addGlobalMonitorForEvents` to watch for keypresses anywhere in the system. This is a powerful capability — it means ScreenCap can "see" every key you press, even in other apps. For this reason, macOS requires the **Accessibility** permission before allowing it.

### How modifier keys are stored

When you press **⌘⇧3**, three things are happening at once: the Command key is held, the Shift key is held, and the 3 key is pressed. ScreenCap stores this as two numbers:
- The **key code** of the main key (3 → key code 20)
- A **modifier bitmask** — a single number that encodes which modifier keys (⌘, ⇧, ⌥, ⌃) are held

This bitmask format comes from an older Apple technology called Carbon. The app still uses it for storage because it is reliable and compact — but it converts to the modern `NSEvent.ModifierFlags` format when comparing keys at runtime.

---

## The capture backends

ScreenCap supports macOS 13 and later, but Apple's screenshot API changed significantly between versions. The code picks the right method automatically:

| macOS version | Method used | Why |
|---|---|---|
| 14.2 and later | `SCScreenshotManager` | Apple added a simple, one-shot screenshot API in macOS 14.2. This is the preferred path. |
| 13.0 – 14.1 | `SCStream` + frame capture | On earlier versions, there is no one-shot API. Instead, the app starts a screen recording stream, captures a single frame, then immediately stops the stream. |

An older API called `CGDisplayCreateImage` used to be the standard way to take screenshots on the Mac. It was removed from the macOS 15 SDK and is not used anywhere in ScreenCap.

---

## The menubar-only setup

macOS normally shows every running app in the Dock. ScreenCap suppresses this using a setting in its `Info.plist` file:

```
LSUIElement = YES
```

This tells macOS to run the app as a "UI element" — something that runs in the background and only interacts with the user through the menu bar. The app does not appear in the Dock, in the App Switcher (⌘Tab), or in the Force Quit window.

---

## How preferences are stored

All user settings are saved in macOS's `UserDefaults` system, which stores small values by key name (similar to a dictionary). ScreenCap's bundle ID is `org.afaik.ScreenCap`, and defaults are stored under that namespace.

| Setting | How it is stored |
|---|---|
| **Save folder** | As "bookmark data" — a special format that keeps track of a folder even if it is renamed or moved |
| **Hotkey key code** | As a number (e.g., `20` for the 3 key) |
| **Hotkey modifiers** | As a Carbon-style bitmask number |

To clear all preferences from the Terminal:

```bash
defaults delete org.afaik.ScreenCap
```

Or use `bash scripts/reset.sh`, which also revokes macOS permissions at the same time.

---

## No sandbox, no SwiftUI, no external dependencies

ScreenCap deliberately avoids several common modern patterns:

- **No App Sandbox** — the sandbox restricts what an app can do, but it also blocks the global key monitor. Since ScreenCap is distributed as open-source source code (not through the App Store), there is no requirement to sandbox it.
- **No SwiftUI** — the UI is built with AppKit (the older, more explicit macOS UI framework). AppKit gives more direct control over window behaviour, which is important for the countdown overlay and the shortcut recorder panel.
- **No external packages** — all code is in the eight Swift files listed above. This makes the project easy to read, build, and understand without needing to download anything extra.
