import AppKit
import Carbon.HIToolbox
import CoreGraphics
import ScreenCaptureKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeyManager = HotkeyManager()
    private let prefs = Preferences.shared
    private var countdownOverlay: CountdownOverlay?
    private var shortcutMenuItem: NSMenuItem!
    private var saveToMenuItem: NSMenuItem!
    private var shortcutPanel: ShortcutRecorderPanel?
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        let bothGranted = HotkeyManager.isAccessibilityGranted() && CGPreflightScreenCaptureAccess()
        if prefs.hasCompletedOnboarding || bothGranted {
            if bothGranted && !prefs.hasCompletedOnboarding {
                prefs.hasCompletedOnboarding = true
            }
            finishLaunch()
        } else {
            showOnboarding()
        }
    }

    private func finishLaunch() {
        registerHotkey()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func showOnboarding() {
        let controller = OnboardingWindowController { [weak self] in
            self?.onboardingController = nil
            self?.finishLaunch()
        }
        onboardingController = controller
        controller.show()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "camera", accessibilityDescription: "ScreenCap")
        img?.isTemplate = true
        statusItem.button?.image = img

        let menu = NSMenu()

        let captureItem = NSMenuItem(title: NSLocalizedString("Take Screenshot", comment: "Menu item"), action: #selector(takeScreenshot), keyEquivalent: "")
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        shortcutMenuItem = NSMenuItem(title: shortcutLabel(), action: #selector(changeShortcut), keyEquivalent: "")
        shortcutMenuItem.target = self
        menu.addItem(shortcutMenuItem)

        saveToMenuItem = NSMenuItem(title: saveToLabel(), action: #selector(chooseSaveDirectory), keyEquivalent: "")
        saveToMenuItem.target = self
        menu.addItem(saveToMenuItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("Quit ScreenCap", comment: "Menu item"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func takeScreenshot() {
        startCaptureFlow()
    }

    @objc private func changeShortcut() {
        let panel = ShortcutRecorderPanel { [weak self] keyCode, modifiers in
            guard let self else { return }
            self.prefs.hotkeyKeyCode = keyCode
            self.prefs.hotkeyModifiers = modifiers
            self.shortcutMenuItem.title = self.shortcutLabel()
            self.registerHotkey()
        }
        panel.show()
        shortcutPanel = panel
    }

    @objc private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("Select", comment: "Button label in folder picker")
        panel.message = NSLocalizedString("Choose a folder for saved screenshots.", comment: "Prompt in folder picker")
        panel.directoryURL = prefs.saveDirectory

        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.prefs.saveDirectory = url
            self.saveToMenuItem.title = self.saveToLabel()
        }
    }

    // MARK: - Capture Flow

    private func startCaptureFlow() {
        guard let screen = NSScreen.main else { return }

        let overlay = CountdownOverlay()
        countdownOverlay = overlay

        overlay.show(on: screen) { [weak self] in
            guard let self else { return }
            self.countdownOverlay = nil

            // Small pause so the overlay is fully hidden before capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.performCapture(displayID: screen.displayID)
            }
        }
    }

    private func performCapture(displayID: CGDirectDisplayID) {
        let saveDir = prefs.saveDirectory
        Task {
            do {
                let url = try await ScreenCaptureService.capture(displayID: displayID, to: saveDir)
                await MainActor.run { self.notifySuccess(filename: url.lastPathComponent) }
            } catch {
                await MainActor.run { self.showError(error) }
            }
        }
    }

    // MARK: - Notifications

    private func notifySuccess(filename: String) {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Screenshot Saved", comment: "Notification title")
        content.body = filename
        content.sound = .default

        let req = UNNotificationRequest(identifier: UUID().uuidString,
                                        content: content,
                                        trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Screenshot Failed", comment: "Alert title")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: - Hotkey

    private func registerHotkey() {
        hotkeyManager.register(keyCode: prefs.hotkeyKeyCode,
                               modifiers: prefs.hotkeyModifiers) { [weak self] in
            DispatchQueue.main.async { self?.startCaptureFlow() }
        }
    }

    // MARK: - Label helpers

    private func shortcutLabel() -> String {
        let mods = HotkeyManager.modifierString(carbonModifiers: prefs.hotkeyModifiers)
        let key  = HotkeyManager.keyName(forKeyCode: prefs.hotkeyKeyCode)
        return String(format: NSLocalizedString("Shortcut: %@", comment: "Hotkey label in menu"), "\(mods)\(key)")
    }

    private func saveToLabel() -> String {
        let dir = prefs.saveDirectory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let display = dir.path.hasPrefix(home)
            ? "~" + dir.path.dropFirst(home.count)
            : dir.path
        return String(format: NSLocalizedString("Save to: %@", comment: "Save path label in menu"), display)
    }
}

// MARK: - NSScreen display ID helper

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }
}
