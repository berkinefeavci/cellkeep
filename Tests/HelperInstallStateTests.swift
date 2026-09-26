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
        print("Helper install state: ownership/permission/socket trust assertions passed.")
    }
}
