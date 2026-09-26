import AppKit
import SwiftUI

final class AppDelegate {
    static var shared: AppDelegate? { nil }
    func showSettings(page: SettingsPage = .dashboard) {}
    func closePanel() {}
}

@main
enum FlowChartPreview {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            fatalError("Provide flow, idle chart and detailed chart PNG paths")
        }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        var snapshot = BatterySnapshot()
        snapshot.sampledAt = Date()
        snapshot.available = true
        snapshot.percentage = 15
        snapshot.externalConnected = true
        snapshot.isCharging = true
        snapshot.batteryPowerAvailable = true
        snapshot.adapterWatts = 57.4
        snapshot.systemWatts = 17.3
        snapshot.processorWatts = 13.5
        snapshot.displayWatts = 2.8
        snapshot.wattage = 38.5

        let now = Date()
        // Twenty-four hours with a deliberate collection gap and raw sensor variation.
        let samples = stride(from: 288, through: 0, by: -1).compactMap { step -> ChartSample? in
            if (94...110).contains(step) { return nil }
            let elapsed = Double(288 - step)
            let trend = elapsed / 288 * 0.55
            let jitter = step % 23 == 0 ? -0.18 : (step % 17 == 0 ? 0.14 : 0)
            return ChartSample(date: now.addingTimeInterval(Double(-step * 300)), value: 99.2 + trend + jitter)
        }
        let data = ChartData(samples: samples, now: now, hours: 24, health: true)

        let devices = [ConnectedDevice(id: "phone", name: "iPhone", vendor: "Apple", kind: .phone),
                       ConnectedDevice(id: "ssd", name: "SanDisk 3.2Gen1", vendor: "SanDisk", kind: .storage, diskIdentifier: "disk4")]
        try render(PowerFlowView(snapshot: snapshot, connectedDevices: devices).chargeCard().padding(12),
                   size: NSSize(width: 400, height: 410), path: CommandLine.arguments[1])
        try render(chart(data: data, progress: 0).padding(12),
                   size: NSSize(width: 400, height: 230), path: CommandLine.arguments[2])
        try render(chart(data: data, progress: 1).padding(12),
                   size: NSSize(width: 400, height: 230), path: CommandLine.arguments[3])
        print("Power flow and chart previews written offscreen; no window shown and no hardware access.")
    }

    private static func chart(data: ChartData, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Maksimum kapasite").font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "heart.fill").foregroundStyle(.orange)
                Text("100 %").font(.system(size: 14, weight: .semibold)).monospacedDigit()
            }
            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 9)
            HistoryPlot(data: data, metric: .health, hours: 24, height: 142, detailProgress: progress)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(GlassSurface())
    }

    private static func render<V: View>(_ root: V, size: NSSize, path: String) throws {
        let view = NSHostingView(rootView: root
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark))
        view.appearance = NSAppearance(named: .darkAqua)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: true)
        window.contentView = view
        window.appearance = NSAppearance(named: .darkAqua)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fatalError("Offscreen preview could not render")
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Offscreen preview could not encode")
        }
        try data.write(to: URL(fileURLWithPath: path))
    }
}
