import AppKit
import CoreGraphics
import ScreenCaptureKit

final class OnboardingWindowController: NSObject, NSWindowDelegate {

    private enum Step { case accessibility, screenRecording, settings }

    private var window: NSWindow!
    private var pendingSteps: [Step] = []
    private var currentIndex = 0
    private var permissionPollTimer: Timer?
    private var shortcutPanel: ShortcutRecorderPanel?
    private var shortcutValueLabel: NSTextField?
    private var saveFolderValueLabel: NSTextField?

    var onComplete: (() -> Void)?

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        super.init()

        var steps: [Step] = []
        if !HotkeyManager.isAccessibilityGranted() { steps.append(.accessibility) }
        if !CGPreflightScreenCaptureAccess()        { steps.append(.screenRecording) }
        steps.append(.settings)
        pendingSteps = steps
    }

    func show() {
        buildWindow()
        showCurrentStep()
        bringToFront()
    }

    // MARK: - Window

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to ScreenCap"
        w.isReleasedWhenClosed = false
        w.center()
        w.delegate = self
        window = w
    }

    private func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Step rendering

    private func showCurrentStep() {
        guard currentIndex < pendingSteps.count else { return }
        stopPolling()
        switch pendingSteps[currentIndex] {
        case .accessibility:    showPermissionStep(isAccessibility: true)
        case .screenRecording:  showPermissionStep(isAccessibility: false)
        case .settings:         showSettingsStep()
        }
    }

    private func replaceContent(with subviews: [NSView]) {
        window.contentView?.subviews.forEach { $0.removeFromSuperview() }
        subviews.forEach { window.contentView?.addSubview($0) }
    }

    // MARK: - Permission step (Accessibility or Screen Recording)

    private func showPermissionStep(isAccessibility: Bool) {
        let stepLabel = makeLabel(
            "\(currentIndex + 1) of \(pendingSteps.count)",
            fontSize: 11, color: .tertiaryLabelColor
        )
        stepLabel.frame = NSRect(x: 380, y: 292, width: 88, height: 16)
        stepLabel.alignment = .right

        let symbolName = isAccessibility ? "lock.shield" : "rectangle.on.rectangle"
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 40, weight: .regular))
        icon.frame = NSRect(x: 216, y: 236, width: 48, height: 48)

        let title = makeLabel(
            isAccessibility ? "Enable Accessibility Access" : "Enable Screen Recording",
            fontSize: 17, bold: true
        )
        title.frame = NSRect(x: 20, y: 192, width: 440, height: 24)
        title.alignment = .center

        let bodyText = isAccessibility
            ? "ScreenCap needs Accessibility permission to detect your global keyboard shortcut.\n\nClick \"Open System Settings\", then enable ScreenCap under Privacy & Security → Accessibility."
            : "ScreenCap needs Screen Recording permission to capture your screen.\n\nClick \"Open System Settings\", then enable ScreenCap under Privacy & Security → Screen Recording."
        let body = makeLabel(bodyText, fontSize: 13, color: .secondaryLabelColor)
        body.frame = NSRect(x: 20, y: 90, width: 440, height: 96)
        body.alignment = .center

        let laterBtn = NSButton(title: "Later", target: self, action: #selector(laterPressed))
        laterBtn.frame = NSRect(x: 20, y: 20, width: 80, height: 32)
        laterBtn.bezelStyle = .rounded

        let openBtn = NSButton(title: "Open System Settings", target: self,
                               action: isAccessibility ? #selector(openAccessibilitySettings) : #selector(openScreenRecordingSettings))
        openBtn.frame = NSRect(x: 284, y: 20, width: 176, height: 32)
        openBtn.bezelStyle = .rounded
        openBtn.keyEquivalent = "\r"

        replaceContent(with: [stepLabel, icon, title, body, laterBtn, openBtn])
    }

    @objc private func openAccessibilitySettings() {
        HotkeyManager.requestAccessibility()
        startPolling(for: .accessibility)
    }

    @objc private func openScreenRecordingSettings() {
        Task { _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        startPolling(for: .screenRecording)
    }

    @objc private func laterPressed() {
        window.close()
    }

    // MARK: - Settings step

    private func showSettingsStep() {
        let stepLabel = makeLabel(
            "\(currentIndex + 1) of \(pendingSteps.count)",
            fontSize: 11, color: .tertiaryLabelColor
        )
        stepLabel.frame = NSRect(x: 380, y: 292, width: 88, height: 16)
        stepLabel.alignment = .right

        let title = makeLabel("You're all set!", fontSize: 17, bold: true)
        title.frame = NSRect(x: 20, y: 260, width: 440, height: 24)
        title.alignment = .center

        let subtitle = makeLabel("Confirm your settings before you start.", fontSize: 13, color: .secondaryLabelColor)
        subtitle.frame = NSRect(x: 20, y: 232, width: 440, height: 18)
        subtitle.alignment = .center

        // Shortcut row
        let shortcutHeading = makeLabel("Keyboard Shortcut", fontSize: 13)
        shortcutHeading.frame = NSRect(x: 40, y: 178, width: 160, height: 18)

        let shortcutVal = makeLabel(currentShortcutString(), fontSize: 13, bold: true)
        shortcutVal.frame = NSRect(x: 210, y: 178, width: 160, height: 18)
        shortcutValueLabel = shortcutVal

        let changeShortcutBtn = NSButton(title: "Change…", target: self, action: #selector(changeShortcutPressed))
        changeShortcutBtn.frame = NSRect(x: 374, y: 172, width: 86, height: 26)
        changeShortcutBtn.bezelStyle = .rounded

        // Separator line
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.frame = NSRect(x: 40, y: 160, width: 420, height: 1)

        // Save folder row
        let folderHeading = makeLabel("Save Screenshots To", fontSize: 13)
        folderHeading.frame = NSRect(x: 40, y: 130, width: 160, height: 18)

        let folderVal = makeLabel(currentSaveFolderString(), fontSize: 13, bold: true)
        folderVal.frame = NSRect(x: 210, y: 130, width: 160, height: 18)
        folderVal.lineBreakMode = .byTruncatingMiddle
        saveFolderValueLabel = folderVal

        let changeFolderBtn = NSButton(title: "Change…", target: self, action: #selector(changeFolderPressed))
        changeFolderBtn.frame = NSRect(x: 374, y: 124, width: 86, height: 26)
        changeFolderBtn.bezelStyle = .rounded

        let sep2 = NSBox()
        sep2.boxType = .separator
        sep2.frame = NSRect(x: 40, y: 112, width: 420, height: 1)

        let doneBtn = NSButton(title: "Done", target: self, action: #selector(donePressed))
        doneBtn.frame = NSRect(x: 360, y: 20, width: 100, height: 32)
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"

        replaceContent(with: [stepLabel, title, subtitle,
                               shortcutHeading, shortcutVal, changeShortcutBtn, sep1,
                               folderHeading, folderVal, changeFolderBtn, sep2,
                               doneBtn])
    }

    @objc private func changeShortcutPressed() {
        let panel = ShortcutRecorderPanel { [weak self] keyCode, modifiers in
            guard let self else { return }
            Preferences.shared.hotkeyKeyCode = keyCode
            Preferences.shared.hotkeyModifiers = modifiers
            self.shortcutValueLabel?.stringValue = self.currentShortcutString()
        }
        panel.show()
        shortcutPanel = panel
    }

    @objc private func changeFolderPressed() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a folder for saved screenshots."
        panel.directoryURL = Preferences.shared.saveDirectory
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            Preferences.shared.saveDirectory = url
            self.saveFolderValueLabel?.stringValue = self.currentSaveFolderString()
        }
    }

    @objc private func donePressed() {
        Preferences.shared.hasCompletedOnboarding = true
        window.close()
        onComplete?()
    }

    // MARK: - Polling

    private func startPolling(for step: Step) {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = step == .accessibility
                ? HotkeyManager.isAccessibilityGranted()
                : CGPreflightScreenCaptureAccess()
            if granted { self.stopPollingAndAdvance() }
        }
    }

    private func stopPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func stopPollingAndAdvance() {
        stopPolling()
        currentIndex += 1
        showCurrentStep()
        bringToFront()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopPolling()
    }

    // MARK: - Helpers

    private func makeLabel(_ string: String, fontSize: CGFloat, bold: Bool = false, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = bold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
        label.textColor = color
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func currentShortcutString() -> String {
        let mods = HotkeyManager.modifierString(carbonModifiers: Preferences.shared.hotkeyModifiers)
        let key  = HotkeyManager.keyName(forKeyCode: Preferences.shared.hotkeyKeyCode)
        return "\(mods)\(key)"
    }

    private func currentSaveFolderString() -> String {
        let dir = Preferences.shared.saveDirectory
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return dir.path.hasPrefix(home)
            ? "~" + dir.path.dropFirst(home.count)
            : dir.path
    }
}
