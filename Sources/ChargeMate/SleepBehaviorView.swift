import SwiftUI

struct SleepBehaviorView: View {
    @AppStorage(SleepBehaviorPreferences.preventIdleSleepUntilTarget) private var preventIdleSleep = false
    @ObservedObject private var controller = SleepInhibitionController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: controller.isActive ? "moon.zzz.fill" : "moon.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(controller.isActive ? Color.green : Color.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Uyku davranışı").font(.system(size: 14, weight: .semibold))
                        Text(controller.status.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(controller.isActive ? Color.green : Color.secondary)
                    }
                    Spacer()
                }
                Divider()
                Toggle("Hedefe kadar otomatik uykuyu ertele", isOn: $preventIdleSleep)
                    .font(.system(size: 12, weight: .medium))
                    .toggleStyle(.switch)
                Text("Adaptör bağlı ve pil kayıtlı hedefin altındayken yalnız boşta sistem uykusunu engeller. Ekran kapanabilir; kapak kapatma ve elle Uyut komutu çalışmaya devam eder.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .chargeCard()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Uyku sırasında şarjı durdur", systemImage: "pause.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("Doğrulama bekliyor")
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(.orange)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
                Text("Bu Mac’te doğrulanmış bir şarj duraklatma/devam primitive’i yok. Güvenli donanım yolu kanıtlanmadan uyku olayında pil ayarı yazılmaz.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .chargeCard()
        }
    }
}
