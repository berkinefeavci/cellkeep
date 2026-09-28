import AppKit
import SwiftUI

struct PowerModeQuickControl: View {
    @EnvironmentObject private var battery: BatteryMonitor
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Güç modu", systemImage: battery.selectedPowerMode == .lowPower ? "leaf.fill" : "speedometer")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("Etkin: \(battery.selectedPowerMode.title)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            profileRow(String(localized: "Pil ile"), symbol: "battery.100percent", source: .battery,
                       selectedMode: battery.batteryPowerMode)
            profileRow(String(localized: "Adaptör ile"), symbol: "powerplug.fill", source: .adapter,
                       selectedMode: battery.adapterPowerMode)
            if let message = battery.powerModeMessage {
                Text(message)
                    .font(.system(size: 9)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // A fixed leading label column, kept identical between both rows so the two three-across
    // chip groups line up into one clean segmented-looking block.
    private var labelColumnWidth: CGFloat { compact ? 76 : 88 }

    private func profileRow(_ title: String, symbol: String, source: SystemPowerSource,
                            selectedMode: SystemPowerMode) -> some View {
        HStack(spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: labelColumnWidth, alignment: .leading)
            modeButton(.automatic, source: source, selectedMode: selectedMode)
            modeButton(.turbo, source: source, selectedMode: selectedMode)
            modeButton(.lowPower, source: source, selectedMode: selectedMode)
        }
    }

    /// Text-only (no icon) so "Otomatik"/"Turbo"/"Tasarruf" never wrap or truncate at the
    /// popover's 400 pt width; the icon + label combination didn't fit three-across next to the
    /// leading row label and previously spilled text outside its chip.
    private func modeButton(_ mode: SystemPowerMode, source: SystemPowerSource,
                            selectedMode: SystemPowerMode) -> some View {
        let selected = selectedMode == mode
        let color: Color = mode == .lowPower ? .yellow : mode == .turbo ? .purple : .accentColor
        return Button { battery.applyPowerMode(mode, source: source) } label: {
            Text(mode.title)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(ChipButtonStyle(selected: selected, tint: color, compact: true))
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30)
        .allowsHitTesting(!battery.applyingPowerMode)
        .accessibilityValue(battery.applyingPowerMode ? String(localized: "İşlem sürüyor") : selected ? String(localized: "Seçili") : "")
        .help("\(source == .battery ? String(localized: "Pil") : String(localized: "Adaptör")) profili: \(mode.title)")
    }
}
