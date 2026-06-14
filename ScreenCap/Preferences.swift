import Foundation
import Carbon

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key: String {
        case saveDirectoryBookmark
        case hotkeyKeyCode
        case hotkeyModifiers
        case hasCompletedOnboarding
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding.rawValue) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding.rawValue) }
    }

    var saveDirectory: URL {
        get {
            if let data = defaults.data(forKey: Key.saveDirectoryBookmark.rawValue) {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                    return url
                }
            }
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        }
        set {
            let data = try? newValue.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: Key.saveDirectoryBookmark.rawValue)
        }
    }

    var hotkeyKeyCode: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyKeyCode.rawValue)
            return v == 0 ? 20 : UInt32(v) // 20 = key "3" on US keyboard
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyKeyCode.rawValue) }
    }

    // Carbon modifier flags
    var hotkeyModifiers: UInt32 {
        get {
            let v = defaults.integer(forKey: Key.hotkeyModifiers.rawValue)
            return v == 0 ? UInt32(cmdKey | shiftKey) : UInt32(v)
        }
        set { defaults.set(Int(newValue), forKey: Key.hotkeyModifiers.rawValue) }
    }
}
