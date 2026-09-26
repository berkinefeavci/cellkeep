import Foundation

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
}
