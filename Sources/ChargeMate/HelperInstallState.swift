import Foundation
import Security

/// Pure ownership/permission/socket trust check shared by every privileged root helper
/// (LED control, power-mode control). Kept separate from `FileManager` so the rule itself —
/// root-owned, not group/world-writable, and its control socket present — is unit-testable
/// without touching real system paths.
enum HelperInstallState {
    static func isTrusted(ownerUID: Int?, posixPermissions: Int?, socketExists: Bool) -> Bool {
        guard let ownerUID, ownerUID == 0,
              let posixPermissions, posixPermissions & 0o022 == 0 else { return false }
        return socketExists
    }

    /// Root shell step run after a helper binary is copied to its root-owned path and before it is
    /// ever executed. The app bundle is user-writable, so its bundled helper could have been swapped;
    /// checking the root-owned copy leaves no window to swap it again. A Developer ID build pins the
    /// helper to the app's own Team ID. An ad-hoc (local/dev) build has no identity to pin, so it
    /// can only require an intact signature — that does not stop a re-signed replacement.
    static func signatureCheckCommand(installedPath: String, teamIdentifier: String?) -> String {
        let path = shellQuoted(installedPath)
        var verify = "/usr/bin/codesign --verify --strict"
        if let teamIdentifier, isValidTeamIdentifier(teamIdentifier) {
            verify += " -R " + shellQuoted("=anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\"")
        }
        return "(\(verify) \(path) || { /bin/rm -f \(path); false; })"
    }

    static func isValidTeamIdentifier(_ value: String) -> Bool {
        value.count == 10 && value.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("0"..."9").contains($0) }
    }

    /// Same content as `Packaging/<label>.plist`. The daemon plist is written from here instead of
    /// being copied out of the user-writable app bundle, where a swapped plist could point launchd
    /// at any program and run it as root.
    static func launchDaemonPlistLines(label: String, helperPath: String) -> [String] {
        [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
            "<plist version=\"1.0\"><dict>",
            "<key>Label</key><string>\(label)</string>",
            "<key>ProgramArguments</key><array><string>\(helperPath)</string><string>--daemon</string></array>",
            "<key>RunAtLoad</key><true/>",
            "<key>KeepAlive</key><true/>",
            "<key>ThrottleInterval</key><integer>10</integer>",
            "<key>ProcessType</key><string>Background</string>",
            "</dict></plist>",
        ]
    }

    /// Root shell step that (re)writes `/Library/LaunchDaemons/<label>.plist`. Each line is its own
    /// single-quoted argument, so the command carries no literal newlines through AppleScript.
    static func writeLaunchDaemonPlistCommand(label: String, helperPath: String) -> String {
        let destination = shellQuoted("/Library/LaunchDaemons/\(label).plist")
        let lines = launchDaemonPlistLines(label: label, helperPath: helperPath).map(shellQuoted).joined(separator: " ")
        return "/bin/rm -f \(destination) && (umask 022; /usr/bin/printf '%s\\n' \(lines) > \(destination)) && " +
            "/usr/sbin/chown root:wheel \(destination) && /bin/chmod 644 \(destination)"
    }

    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Team ID of the running app's signature, or nil for ad-hoc/unsigned builds.
    static func currentTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any] else { return nil }
        return values[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
