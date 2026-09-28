import Foundation
import ServiceManagement

enum LoginItemState: Equatable {
    case off
    case on
    case needsApproval
    case unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .notRegistered: self = .off
        case .enabled: self = .on
        case .requiresApproval: self = .needsApproval
        case .notFound: self = .unavailable
        @unknown default: self = .unavailable
        }
    }

    var requested: Bool { self == .on || self == .needsApproval }

    var explanation: String {
        switch self {
        case .off: return String(localized: "Oturum açıldığında otomatik başlamaz.")
        case .on: return String(localized: "macOS bu uygulamayı oturum açılışında başlatmak üzere etkinleştirdi.")
        case .needsApproval: return String(localized: "İstek kaydedildi; Sistem Ayarları’nda onay gerekiyor.")
        case .unavailable: return String(localized: "Giriş öğesi bulunamadı. Uygulamayı Applications içinden açıp tekrar deneyin.")
        }
    }
}

enum StartupPreferences {
    static func loginItemState() -> LoginItemState { LoginItemState(SMAppService.mainApp.status) }

    /// Yalnız kullanıcının doğrudan toggle eyleminden çağrılır. Açılışta kayıt yapmayız.
    static func setLoginItemEnabled(_ enabled: Bool) throws -> LoginItemState {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
        return loginItemState()
    }
}
