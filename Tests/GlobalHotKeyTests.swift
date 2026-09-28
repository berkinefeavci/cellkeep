import Carbon.HIToolbox
import Foundation

@main enum GlobalHotKeyTests {
    static func main() {
        // Off by default and when the stored value is unknown.
        let saved = UserDefaults.standard.string(forKey: HotKeyChoice.storageKey)
        defer { UserDefaults.standard.set(saved, forKey: HotKeyChoice.storageKey) }
        UserDefaults.standard.removeObject(forKey: HotKeyChoice.storageKey)
        precondition(HotKeyChoice.current == .off)
        UserDefaults.standard.set("somethingElse", forKey: HotKeyChoice.storageKey)
        precondition(HotKeyChoice.current == .off)
        UserDefaults.standard.set(HotKeyChoice.controlOptionCommandC.rawValue, forKey: HotKeyChoice.storageKey)
        precondition(HotKeyChoice.current == .controlOptionCommandC)

        precondition(HotKeyChoice.off.key == nil && HotKeyChoice.off.symbols == nil)
        let all = UInt32(controlKey | optionKey | cmdKey)
        precondition(HotKeyChoice.controlOptionCommandB.key! == (UInt32(kVK_ANSI_B), all))
        precondition(HotKeyChoice.controlOptionCommandC.key! == (UInt32(kVK_ANSI_C), all))
        precondition(HotKeyChoice.controlOptionCommandB.symbols == "⌃⌥⌘B")
        // Turning it off never registers anything.
        precondition(GlobalHotKey().apply(.off))
        print("Global hot key: default-off, stored choice, key code and modifier assertions passed; nothing registered.")
    }
}
