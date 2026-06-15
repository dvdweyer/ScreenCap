import AppKit
import Carbon.HIToolbox

final class ShortcutRecorderPanel {
    private var panel: NSPanel?
    private var monitor: Any?
    private let completion: (UInt32, UInt32) -> Void

    init(completion: @escaping (UInt32, UInt32) -> Void) {
        self.completion = completion
    }

    func show() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
                            styleMask: [.titled, .closable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.title = NSLocalizedString("Set Shortcut", comment: "Panel title")
        panel.level = .floating
        panel.isReleasedWhenClosed = false

        let prompt = NSTextField(labelWithString: NSLocalizedString("Press a key combination…", comment: "Prompt in shortcut recorder"))
        prompt.frame = NSRect(x: 20, y: 70, width: 280, height: 24)
        prompt.alignment = .center
        panel.contentView?.addSubview(prompt)

        let hint = NSTextField(labelWithString: NSLocalizedString("Include at least one modifier key (⌘, ⌃, ⌥, ⇧)", comment: "Hint in shortcut recorder"))
        hint.frame = NSRect(x: 20, y: 46, width: 280, height: 18)
        hint.alignment = .center
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        panel.contentView?.addSubview(hint)

        let cancel = NSButton(title: NSLocalizedString("Cancel", comment: "Button to cancel shortcut recording"), target: self, action: #selector(cancelPressed))
        cancel.frame = NSRect(x: 110, y: 12, width: 100, height: 26)
        cancel.bezelStyle = .rounded
        panel.contentView?.addSubview(cancel)

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
            return nil // consume the event
        }
    }

    private func handle(event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard !mods.isEmpty else { return } // require at least one modifier

        let keyCode = UInt32(event.keyCode)
        let carbonMods = HotkeyManager.carbonModifiers(from: mods)

        removeMonitor()
        panel?.close()
        panel = nil
        completion(keyCode, carbonMods)
    }

    @objc private func cancelPressed() {
        removeMonitor()
        panel?.close()
        panel = nil
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
