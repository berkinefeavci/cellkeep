import AppKit

/// Per-app language override, the same `AppleLanguages` key macOS writes from
/// System Settings → Language & Region → Applications. Takes effect on relaunch.
enum AppLanguage {
    static let system = ""
    static let choices = ["tr", "en", "de", "fr", "es"]

    static var current: String {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let code = (domain?["AppleLanguages"] as? [String])?.first else { return system }
        return choices.first { code.hasPrefix($0) } ?? system
    }

    /// Native name, so a user who cannot read the current language still finds their own.
    static func name(_ code: String) -> String {
        Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    static func set(_ code: String) {
        if code == system { UserDefaults.standard.removeObject(forKey: "AppleLanguages") }
        else { UserDefaults.standard.set([code], forKey: "AppleLanguages") }
    }

    static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }
}
