# Permissions Setup

macOS takes privacy seriously. Before any app can watch your keyboard or capture your screen, you have to explicitly grant it permission. ScreenCap needs two of these permissions to work.

The first time you launch ScreenCap, an onboarding window walks you through both. If you closed that window, or if a macOS update reset the permissions, this guide shows you how to grant them manually.

## Why two permissions?

| Permission | Why ScreenCap needs it |
|---|---|
| **Accessibility** | ScreenCap listens for your hotkey even when you're using another app. macOS calls this ability "Accessibility" because it's the same channel used by assistive technologies. Without it, the hotkey only works when ScreenCap's own menu is open — which defeats the purpose. |
| **Screen Recording** | To capture what is on your display, ScreenCap uses Apple's ScreenCaptureKit framework. macOS gates this behind the Screen Recording permission to prevent apps from spying on you without your knowledge. |

Both permissions must be granted for ScreenCap to work. The app will tell you which one is missing if a capture fails.

---

## Step 1 — Grant Accessibility permission

1. Click the **Apple menu** (top-left corner of your screen) and choose **System Settings**
2. In the left sidebar, scroll down and click **Privacy & Security**
3. Scroll down the right panel until you see **Accessibility**, then click it
4. You will see a list of apps that have requested this permission. If the list is locked, click the **lock icon** at the bottom-left and enter your Mac password to unlock it.
5. If **ScreenCap** already appears in the list, make sure its toggle is switched **on** (green).
6. If ScreenCap is not in the list, click the **+** button, navigate to your **Applications** folder, select **ScreenCap**, and click **Open**.

> **Tip:** If the hotkey stops working after a macOS update, come back here and try toggling ScreenCap off and back on.

---

## Step 2 — Grant Screen Recording permission

1. In the same **Privacy & Security** pane, scroll to find **Screen Recording** and click it
2. Unlock the list if necessary (lock icon, bottom-left)
3. If **ScreenCap** already appears, confirm its toggle is **on**
4. If ScreenCap is not listed, click **+**, navigate to **Applications**, select **ScreenCap**, and click **Open**
5. macOS may show a prompt asking you to quit and reopen ScreenCap. If so, quit ScreenCap from its menubar icon and relaunch it from `/Applications`

---

## Checking that everything works

1. Press your hotkey (default: **⌘⇧3**) — the countdown overlay should appear
2. Wait for the countdown, or just watch — a screenshot will be saved
3. A notification should appear in the top-right corner of your screen confirming where the file was saved

If you instead see an alert dialog mentioning a missing permission, click the button in the alert — it opens the exact System Settings pane you need.

---

## Resetting permissions (for developers and testers)

If you are developing ScreenCap and want to test the first-launch onboarding flow from scratch, you can wipe all permissions and preferences in one step.

Open **Terminal** (found in `/Applications/Utilities/`) and run:

```bash
cd /path/to/ScreenCap
bash scripts/reset.sh
```

This will:
- Quit ScreenCap if it is running
- Delete all saved preferences (hotkey, save folder)
- Revoke the Accessibility permission
- Revoke the Screen Recording permission

The next time you launch ScreenCap, the onboarding window will appear as if it is the first launch.

> **Note:** Notification permissions cannot be reset this way on macOS 13 or later. To reset them manually: **System Settings → Notifications → ScreenCap** → click the app and choose **Remove**.
