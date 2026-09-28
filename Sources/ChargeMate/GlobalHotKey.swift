import Carbon.HIToolbox
import Foundation

/// Optional system-wide shortcut that opens/closes the menu-bar panel. Off by default. Uses Carbon
/// `RegisterEventHotKey`, which needs no Accessibility permission and only ever sees this one key
/// combination — never other keystrokes.
enum HotKeyChoice: String, CaseIterable, Identifiable {
    case off
    case controlOptionCommandB
    case controlOptionCommandC

    static let storageKey = "panelHotKey"
    var id: String { rawValue }

    static var current: HotKeyChoice {
        UserDefaults.standard.string(forKey: storageKey).flatMap(HotKeyChoice.init(rawValue:)) ?? .off
    }

    /// Carbon virtual key code and modifier mask, or nil when off.
    var key: (code: UInt32, modifiers: UInt32)? {
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        switch self {
        case .off: return nil
        case .controlOptionCommandB: return (UInt32(kVK_ANSI_B), modifiers)
        case .controlOptionCommandC: return (UInt32(kVK_ANSI_C), modifiers)
        }
    }

    /// Symbols as macOS shows them in menus; not translated.
    var symbols: String? {
        switch self {
        case .off: return nil
        case .controlOptionCommandB: return "⌃⌥⌘B"
        case .controlOptionCommandC: return "⌃⌥⌘C"
        }
    }
}

final class GlobalHotKey {
    static let shared = GlobalHotKey()
    var action: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Registers `choice`, replacing any previous shortcut. Returns false when macOS refused it,
    /// typically because another app already owns the same combination.
    @discardableResult
    func apply(_ choice: HotKeyChoice) -> Bool {
        unregister()
        guard let key = choice.key else { return true }
        installHandlerIfNeeded()
        let identifier = EventHotKeyID(signature: OSType(0x434B_4550), id: 1)   // "CKEP"
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(key.code, key.modifiers, identifier, GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { return false }
        hotKeyRef = reference
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
