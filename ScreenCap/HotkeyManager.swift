import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var monitor: Any?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        unregister()
        let nsModifiers = nsModifierFlags(fromCarbon: modifiers)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard UInt32(event.keyCode) == keyCode,
                  event.modifierFlags.intersection([.command, .shift, .option, .control]) == nsModifiers
            else { return }
            handler()
        }
    }

    func unregister() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    // MARK: - Accessibility check

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    // MARK: - Modifier conversion

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }

    private func nsModifierFlags(fromCarbon mods: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if mods & UInt32(cmdKey)     != 0 { flags.insert(.command) }
        if mods & UInt32(shiftKey)   != 0 { flags.insert(.shift) }
        if mods & UInt32(optionKey)  != 0 { flags.insert(.option) }
        if mods & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }

    static func modifierString(carbonModifiers mods: UInt32) -> String {
        var s = ""
        if mods & UInt32(controlKey) != 0 { s += "⌃" }
        if mods & UInt32(optionKey)  != 0 { s += "⌥" }
        if mods & UInt32(shiftKey)   != 0 { s += "⇧" }
        if mods & UInt32(cmdKey)     != 0 { s += "⌘" }
        return s
    }

    static func keyName(forKeyCode keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
            11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T",
            18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5", 24:"=", 25:"9",
            26:"7", 27:"-", 28:"8", 29:"0", 30:"]", 31:"O", 32:"U", 33:"[",
            34:"I", 35:"P", 37:"L", 38:"J", 39:"'", 40:"K", 41:";", 42:"\\",
            43:",", 44:"/", 45:"N", 46:"M", 47:".",
            48:"⇥", 49:"Space", 51:"⌫", 53:"Esc",
            96:"F5", 97:"F6", 98:"F7", 99:"F3", 100:"F8", 101:"F9",
            103:"F11", 109:"F10", 111:"F12",
            118:"F4", 120:"F2", 122:"F1"
        ]
        return map[keyCode] ?? "(\(keyCode))"
    }
}
