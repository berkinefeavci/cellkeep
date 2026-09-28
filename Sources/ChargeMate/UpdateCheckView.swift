import AppKit
import SwiftUI

/// About-page controls for the opt-in release check. Off by default; see `UpdateCheck`.
struct UpdateCheckSection: View {
    @AppStorage(UpdateCheck.Keys.automatic) private var automatic = false
    @State private var checking = false
    @State private var status: String?
    @State private var available: UpdateCheck.Release? = UpdateCheck.rememberedUpdate()

    var body: some View {
        VStack(spacing: 8) {
            Toggle("Haftada bir yeni sürüm denetle", isOn: $automatic)
            Text("Açıksa Cellkeep yalnızca GitHub'daki son sürüm numarasını sorar. Veri göndermez, hiçbir şey indirmez veya kurmaz.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Button(checking ? "Denetleniyor…" : String(localized: "Şimdi denetle")) { Task { await checkNow() } }
                    .disabled(checking)
                if let available {
                    Button("Sürüm \(available.version) sayfasını aç") { NSWorkspace.shared.open(available.pageURL) }
                }
            }.chargeMateButtonStyle()
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: 520)
    }

    @MainActor private func checkNow() async {
        checking = true
        defer { checking = false }
        switch await UpdateCheck.check() {
        case .upToDate(let current):
            available = nil
            status = String(localized: "Cellkeep \(current) güncel.")
        case .available(let release):
            available = release
            status = String(localized: "Yeni sürüm var: \(release.version)")
        case .failed(let message):
            status = message
        }
    }
}
