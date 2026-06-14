# Building ScreenCap from Source

"Building from source" means taking the raw Swift code in this repository and compiling it into a working Mac app on your own machine. You do not need to be a programmer to do this — but you will need to use the Terminal and install a few tools. This guide walks through every step.

Estimated time: **15–30 minutes** (most of that is downloading Xcode)

---

## What you will need

| Tool | What it is | Cost |
|---|---|---|
| **Xcode** | Apple's development environment. It includes the Swift compiler, which turns code into a working app. | Free (Mac App Store) |
| **Apple Developer account** | A free account that lets you sign apps with your identity, so macOS trusts them across builds. | Free |
| **Terminal** | A built-in macOS app that lets you run text commands. You will use it to download the code and run the build script. | Built into macOS |

---

## Step 1 — Install Xcode

1. Open the **Mac App Store** (Dock or Launchpad)
2. Search for **Xcode**
3. Click **Get**, then **Install** — Xcode is large (~10 GB), so this may take a while on a slow connection
4. Once it finishes, open Xcode from your Applications folder
5. The first time Xcode opens, it installs additional components. Accept any prompts and wait for them to complete.
6. You can close Xcode once the setup is done — you will not need to open it manually for the build steps below.

> **Why Xcode?** ScreenCap is written in Swift, Apple's programming language for macOS and iOS apps. Xcode contains the tools that read Swift code and turn it into an executable app. Even though you will build ScreenCap from the Terminal, Xcode's tools are doing the work behind the scenes.

---

## Step 2 — Set up a free Apple Developer account

Code signing is macOS's way of knowing who built an app. When you build ScreenCap yourself, you sign it with your own developer identity. This lets macOS remember the app's permissions (like Accessibility and Screen Recording) across builds. Without a proper signature, macOS forgets those permissions every time you rebuild.

1. Go to [developer.apple.com](https://developer.apple.com) and sign in with your Apple ID (the same one you use for the App Store)
2. If prompted, agree to the Apple Developer Agreement
3. A free account is all you need — you do not need to pay for the $99/year Apple Developer Program

Next, connect that account to Xcode:

1. Open **Xcode**
2. In the menu bar, choose **Xcode → Settings** (or press **⌘,**)
3. Click the **Accounts** tab
4. Click the **+** button in the bottom-left corner
5. Choose **Apple ID** and click **Continue**
6. Sign in with your Apple ID and password
7. Xcode will show your account and automatically create a **development certificate** — a digital credential tied to your Mac and your Apple ID

> **What is a certificate?** Think of it like a wax seal on a letter. When you sign ScreenCap with your certificate, macOS can verify that this specific app came from you. If the seal changes (because someone rebuilt the app differently), macOS treats it as a different app.

---

## Step 3 — Open Terminal

Terminal is a text-based interface for your Mac. Instead of clicking buttons, you type commands.

1. Open **Finder**
2. In the menu bar, choose **Go → Utilities**
3. Double-click **Terminal**

A window opens with a prompt that ends in `%` or `$`. This is where you type commands. Press **Return** after each command to run it.

---

## Step 4 — Install the command-line tools (if not already installed)

Xcode installs a set of command-line tools that include `git` (used to download the code) and `xcodebuild` (used to compile it). If you installed Xcode in Step 1, these are likely already installed. To confirm, type this in Terminal and press Return:

```bash
xcode-select --version
```

If you see a version number, you are ready. If you see an error, run this to install the tools:

```bash
xcode-select --install
```

A dialog will appear asking to install the tools. Click **Install** and wait for it to finish.

---

## Step 5 — Download the ScreenCap source code

In Terminal, run the following command. It downloads a copy of the ScreenCap code to your Mac:

```bash
git clone https://github.com/dvdweyer/ScreenCap.git
```

> **What is `git clone`?** Git is a tool that tracks changes to code over time. `git clone` makes a full copy of a project (called a "repository") from GitHub onto your Mac. You will get a folder called `ScreenCap` in whichever folder Terminal is currently open in (usually your home folder).

After the download completes, move into the project folder:

```bash
cd ScreenCap
```

> **What is `cd`?** It stands for "change directory" — the Terminal equivalent of double-clicking a folder in Finder.

---

## Step 6 — Build and install ScreenCap

Run the build script:

```bash
bash scripts/deploy-local.sh
```

The script will print its progress as it works. Here is what it does, step by step:

1. **Builds** the Swift code using Xcode's build tools (this is the step that takes the longest — around 30–60 seconds the first time)
2. **Finds** your Apple Development certificate in your Mac's keychain
3. **Signs** the built app with that certificate, so macOS recognises it consistently
4. **Stops** any running copy of ScreenCap
5. **Copies** the signed app to `/Applications/ScreenCap.app`
6. **Launches** the newly installed app

If everything works, you should see a ScreenCap icon appear in your menubar.

### What if the script says "No Developer certificate found"?

This means Xcode has not yet created a certificate for your account. Go back to Step 2 and make sure your Apple ID is added to Xcode → Settings → Accounts. If your account is listed but the certificate is missing, click **Manage Certificates** and then the **+** button to create an "Apple Development" certificate.

The script will still proceed using "ad-hoc signing" as a fallback, but macOS will forget the app's permissions after each rebuild. Using a proper certificate avoids this.

---

## Step 7 — Grant permissions and start using ScreenCap

After the app launches, an onboarding window will guide you through granting the two permissions ScreenCap needs. For detailed instructions, see [permissions-setup.md](permissions-setup.md).

---

## Building inside Xcode (alternative method)

If you prefer a visual environment over Terminal commands:

1. In Finder, navigate to the `ScreenCap` folder you downloaded in Step 5
2. Double-click **ScreenCap.xcodeproj** to open it in Xcode
3. Press **⌘R** to build and run

Xcode compiles the code and launches the app directly. This is convenient for exploring and editing the code. For installing a stable copy to `/Applications` that remembers its permissions, use `deploy-local.sh` instead.

---

## Resetting to a clean state

To wipe all settings and permissions and test the first-launch experience from scratch:

```bash
bash scripts/reset.sh
```

This revokes Accessibility and Screen Recording permissions and clears all saved preferences. The next launch will show the onboarding window again as if ScreenCap has never been run.

---

## Troubleshooting

**The build fails with "No such file or directory"**
Make sure you ran `cd ScreenCap` in Step 5 before running the build script. Terminal needs to be inside the project folder.

**The app launches but the hotkey does not work**
The Accessibility permission is probably missing or was reset by macOS. See [permissions-setup.md](permissions-setup.md).

**The screen stays black or the capture fails**
The Screen Recording permission is probably missing. See [permissions-setup.md](permissions-setup.md).

**Xcode says "Signing certificate not found"**
Go to Xcode → Settings → Accounts, select your Apple ID, and click **Manage Certificates → + → Apple Development**.
