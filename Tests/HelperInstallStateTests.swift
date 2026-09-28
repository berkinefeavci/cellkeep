import Foundation

@main enum HelperInstallStateTests {
    static func main() {
        // Root-owned, not group/world-writable, socket present: trusted.
        precondition(HelperInstallState.isTrusted(ownerUID: 0, posixPermissions: 0o755, socketExists: true))
        // Not root-owned: never trusted regardless of permissions/socket.
        precondition(!HelperInstallState.isTrusted(ownerUID: 501, posixPermissions: 0o755, socketExists: true))
        // Group/world-writable: never trusted even if root-owned.
        precondition(!HelperInstallState.isTrusted(ownerUID: 0, posixPermissions: 0o777, socketExists: true))
        // No socket yet (daemon not running): not trusted.
        precondition(!HelperInstallState.isTrusted(ownerUID: 0, posixPermissions: 0o755, socketExists: false))
        // Missing attributes entirely (helper not installed): not trusted.
        precondition(!HelperInstallState.isTrusted(ownerUID: nil, posixPermissions: nil, socketExists: false))

        // The embedded daemon plists must stay byte-identical to the packaged ones.
        for (label, helper) in [("io.github.berkinefeavci.cellkeep.powermode", "/Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.powermode"),
                                ("io.github.berkinefeavci.cellkeep.led", "/Library/PrivilegedHelperTools/io.github.berkinefeavci.cellkeep.led")] {
            let packaged = try! String(contentsOfFile: "Packaging/\(label).plist", encoding: .utf8)
            let embedded = HelperInstallState.launchDaemonPlistLines(label: label, helperPath: helper).joined(separator: "\n") + "\n"
            precondition(embedded == packaged, "embedded plist drifted from Packaging/\(label).plist")
            let write = HelperInstallState.writeLaunchDaemonPlistCommand(label: label, helperPath: helper)
            precondition(!write.contains("\n") && write.contains("/usr/sbin/chown root:wheel"))
        }

        // Team IDs: exactly ten uppercase letters/digits; anything else is never interpolated.
        precondition(HelperInstallState.isValidTeamIdentifier("ABCDE12345"))
        precondition(!HelperInstallState.isValidTeamIdentifier("abcde12345"))
        precondition(!HelperInstallState.isValidTeamIdentifier("ABCDE1234"))
        precondition(!HelperInstallState.isValidTeamIdentifier("ABCDE1234'"))
        let pinned = HelperInstallState.signatureCheckCommand(installedPath: "/x/helper", teamIdentifier: "ABCDE12345")
        precondition(pinned.contains("leaf[subject.OU] = \"ABCDE12345\"") && pinned.contains("/bin/rm -f '/x/helper'"))
        let adHoc = HelperInstallState.signatureCheckCommand(installedPath: "/x/helper", teamIdentifier: nil)
        precondition(!adHoc.contains(" -R ") && adHoc.hasPrefix("(/usr/bin/codesign --verify --strict '/x/helper'"))
        let injected = HelperInstallState.signatureCheckCommand(installedPath: "/x/helper", teamIdentifier: "A'; rm -rf /")
        precondition(!injected.contains("rm -rf"))
        precondition(HelperInstallState.shellQuoted("a'b") == "'a'\\''b'")
        print("Helper install state: ownership/permission/socket trust, plist and signature assertions passed.")
    }
}
