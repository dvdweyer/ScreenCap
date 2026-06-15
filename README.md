# ScreenCap

ScreenCap is a small macOS utility that takes a screenshot of your screen with a single keyboard shortcut. It lives quietly in your menubar — no Dock icon, no window — and saves a clean PNG file the moment you need it.

Built entirely with [Claude Code](https://claude.ai/code), Anthropic's AI coding assistant, as a hands-on demonstration of what's possible when you describe what you want in plain language and let the AI handle the implementation. The source code is intentionally kept simple and readable so you can follow along.

## What it does

- Press a global hotkey (default: **⌘⇧3**) from anywhere in macOS
- A 3-second countdown appears so you have time to set up the screen
- The current display is captured and saved as a PNG
- A notification appears confirming where the file was saved — click it to open in Preview

You can change the hotkey and the save folder any time from the menubar.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (only needed if building from source)
- A free Apple Developer account (only needed if building from source)

## Installation

Download the latest notarized DMG from [Releases](https://github.com/dvdweyer/ScreenCap/releases), open it, and drag ScreenCap to your Applications folder.

### Build from source

If you prefer to compile it yourself:

```bash
git clone https://github.com/dvdweyer/ScreenCap.git
cd ScreenCap
bash scripts/deploy-local.sh
```

This builds the app, signs it, and installs it to `/Applications/ScreenCap.app`. Full walkthrough in [Documentation/building-from-source.md](Documentation/building-from-source.md).

## First-launch setup

The first time ScreenCap runs, it walks you through granting two permissions macOS requires:

1. **Accessibility** — so the hotkey works even when ScreenCap is not the active app
2. **Screen Recording** — so it can capture what is on your display

If you skip the onboarding or need to grant permissions manually, see [Documentation/permissions-setup.md](Documentation/permissions-setup.md).

## Usage

| What you want to do | How |
|---|---|
| Take a screenshot | Press **⌘⇧3** or click the menubar icon → **Take Screenshot** |
| Change the hotkey | Click the menubar icon → tap the **Shortcut:** line → press your new combo |
| Change the save folder | Click the menubar icon → tap the **Save to:** line → choose a folder |
| Quit | Click the menubar icon → **Quit ScreenCap** |

Screenshots are saved in your chosen folder (default: `~/Downloads`) with names like:

```
ScreenCap 2026-06-14 at 09.32.17.png
```

## Built with Claude Code

Every line of Swift in this project was written with Claude Code — Anthropic's AI coding assistant that runs directly in the terminal. The workflow looks like this:

1. Describe what you want in plain English ("add a 3-second countdown before the capture")
2. Claude Code reads the existing code, writes the changes, and explains what it did
3. You review, test, and iterate

ScreenCap is a practical example for anyone learning to build macOS apps with AI assistance. [Documentation/architecture.md](Documentation/architecture.md) walks through how the code is structured and what each file does.

## License

[MIT](LICENSE) — © 2026 Donald van de Weyer
