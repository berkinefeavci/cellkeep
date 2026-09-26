import Foundation
import ServiceManagement

@main
enum StartupPreferencesTests {
    static func main() {
        precondition(LoginItemState(.notRegistered) == .off)
        precondition(LoginItemState(.enabled) == .on)
        precondition(LoginItemState(.requiresApproval) == .needsApproval)
        precondition(LoginItemState(.notFound) == .unavailable)
        precondition(!LoginItemState.off.requested)
        precondition(LoginItemState.on.requested)
        precondition(LoginItemState.needsApproval.requested)
        precondition(!LoginItemState.unavailable.requested)
        precondition(LoginItemState.needsApproval.explanation.contains("onay"))
        print("StartupPreferences: 9 assertions passed (no registration performed)")
    }
}
