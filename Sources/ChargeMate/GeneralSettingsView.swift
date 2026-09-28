import AppKit
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("backgroundDashboardUpdates") private var backgroundUpdates = false
    @AppStorage("showPanelAtLaunch") private var showPanelAtLaunch = false
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var loginItemState = LoginItemState.off
    @State private var loginItemError: String?
    @EnvironmentObject private var battery: BatteryMonitor
    @State private var showUninstallConfirm = false
    @State private var uninstallResetLimit = UninstallPlan.Options.default.resetNativeChargeLimit
    @State private var uninstallRemoveData = UninstallPlan.Options.default.removeApplicationSupportData
    @State private var uninstalling = false
    @State private var uninstallError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsLayout.cardSpacing) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Oturum ve arka plan", systemImage: "clock.arrow.circlepath").font(.headline)
                TrailingToggle(title: String(localized: "Pencereler kapalıyken uygulama etkinliğini yenile"), isOn: $backgroundUpdates)
                Text("Yalnız ek etkinlik ve Gösterge Tablosu örneklemesini etkiler; şarj denetimini açmaz veya durdurmaz.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                TrailingToggle(title: String(localized: "Menü panelini açılışta göster"), isOn: $showPanelAtLaunch)
            }
            .chargeCard()

            VStack(alignment: .leading, spacing: 14) {
                Label("Uygulama erişimi", systemImage: "macwindow.on.rectangle").font(.headline)
                TrailingToggle(title: String(localized: "Dock simgesini göster"), isOn: $showDockIcon)
                Divider()
                HStack {
                    Text("Oturum açılışında başlat")
                    Spacer()
                    Toggle("Oturum açılışında başlat", isOn: Binding(
                        get: { loginItemState.requested },
                        set: { setLoginItemEnabled($0) }
                    ))
                    .labelsHidden()
                    .disabled(loginItemState == .unavailable)
                }
                Text(loginItemError ?? loginItemState.explanation)
                    .font(.caption)
                    .foregroundStyle(loginItemError == nil ? Color.secondary : Color.orange)
                if loginItemState == .needsApproval {
                    Button("Giriş Öğeleri ayarlarını aç") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonStyle(.link)
                }
            }
            .chargeCard()

            VStack(alignment: .leading, spacing: 14) {
                Label("Kaldır", systemImage: "trash").font(.headline)
                Text("Yardımcı süreçleri ve arka plan servislerini kaldırır; uygulamayı Çöp Sepeti'ne taşımanız gerekir.")
                    .font(.caption).foregroundStyle(.secondary)
                if let uninstallError {
                    Text(uninstallError).font(.caption).foregroundStyle(.orange)
                }
                Button("Cellkeep'i kaldır", role: .destructive) { showUninstallConfirm = true }
                    .disabled(uninstalling)
            }
            .chargeCard()
        }
        .toggleStyle(.switch)
        .onAppear { refreshLoginItemState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLoginItemState()
        }
        .sheet(isPresented: $showUninstallConfirm) {
            UninstallConfirmationView(resetLimit: $uninstallResetLimit, removeData: $uninstallRemoveData,
                                       onCancel: { showUninstallConfirm = false },
                                       onConfirm: { showUninstallConfirm = false; performUninstall() })
        }
    }

    private func refreshLoginItemState() {
        loginItemState = StartupPreferences.loginItemState()
    }

    private func setLoginItemEnabled(_ enabled: Bool) {
        loginItemError = nil
        do { loginItemState = try StartupPreferences.setLoginItemEnabled(enabled) }
        catch {
            refreshLoginItemState()
            loginItemError = String(localized: "Giriş öğesi değiştirilemedi: \(error.localizedDescription)")
        }
    }

    private func performUninstall() {
        uninstalling = true
        uninstallError = nil
        let options = UninstallPlan.Options(resetNativeChargeLimit: uninstallResetLimit,
                                             removeApplicationSupportData: uninstallRemoveData)
        Task {
            let result = await UninstallExecutor.run(options: options, battery: battery)
            await MainActor.run {
                uninstalling = false
                switch result {
                case .success:
                    let alert = NSAlert()
                    alert.messageText = String(localized: "Cellkeep kaldırıldı")
                    alert.informativeText = String(localized: "Yardımcı süreçler ve servisler kaldırıldı. Şimdi uygulamayı Çöp Sepeti'ne sürükleyin.")
                    alert.runModal()
                    NSApplication.shared.terminate(nil)
                case .failure(let error):
                    uninstallError = error.localizedDescription
                }
            }
        }
    }
}

/// Confirmation shown before the "Cellkeep'i kaldır" action executes. Explains what gets
/// removed, one admin prompt, then two independent checkboxes for the destructive extras
/// (native limit reset defaults on, app-data removal defaults off — matching the task's alert).
private struct UninstallConfirmationView: View {
    @Binding var resetLimit: Bool
    @Binding var removeData: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Cellkeep'i kaldır", systemImage: "trash").font(.title3.bold())
            Text("Yönetici izniyle yardımcı süreçler ve arka plan servisleri (yeni ve varsa eski ChargeMate "
                + String(localized: "sürümünden kalanlar) kaldırılır, giriş öğesi kayıttan silinir. Tek bir yönetici onayı istenir. ")
                + String(localized: "İşlem bitince uygulamayı Çöp Sepeti'ne sürüklemeniz istenir. Bu adım geri alınamaz."))
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Native şarj limitini %100'e sıfırla", isOn: $resetLimit)
            Toggle("Uygulama verilerini de sil (geçmiş, program, günlük)", isOn: $removeData)
            HStack {
                Spacer()
                Button("İptal", action: onCancel)
                Button("Kaldır", role: .destructive, action: onConfirm)
            }
        }
        .toggleStyle(.checkbox)
        .padding(24)
        .frame(width: 380)
    }
}
