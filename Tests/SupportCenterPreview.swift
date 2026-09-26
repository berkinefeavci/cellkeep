import AppKit
import SwiftUI

final class AppDelegate {
    static var shared: AppDelegate? { nil }
    func showSettings(page: SettingsPage = .dashboard) {}
    func closePanel() {}
}

@main
enum SupportCenterPreview {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Provide a PNG output path") }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-support-preview-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = UserDefaults(suiteName: "local.chargemate.support-preview.\(UUID())")!
        defaults.set(true, forKey: "appReduceTransparency")
        let coordinator = ChargeControlCoordinator(journal: root.appendingPathComponent("journal.json"),
            read: { [:] }, write: { _ in fatalError("Preview must not write hardware") }, rival: { false })
        let monitor = BatteryMonitor(defaults: defaults, coordinator: coordinator,
            historyURL: root.appendingPathComponent("history.json"), batteryReader: { BatterySnapshot() },
            nativeReader: { [:] }, controllerRunning: { false }, energyReader: { .success([]) })
        var snapshot = BatterySnapshot()
        snapshot.sampledAt = Date(); snapshot.available = true; snapshot.percentage = 80
        snapshot.externalConnected = true; snapshot.batteryPowerAvailable = true; snapshot.wattage = 0
        snapshot.sources[.percentage] = "IOPS CurrentCapacity"
        monitor.snapshot = snapshot

        let view = NSHostingView(rootView: ScrollView {
            SupportCenterView().environmentObject(monitor).padding(24)
        }.defaultAppStorage(defaults).frame(width: 900).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.dark))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 1120), styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = view
        window.appearance = NSAppearance(named: .darkAqua)
        view.frame = NSRect(x: 0, y: 0, width: 900, height: 1120)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Offscreen support preview written; window was never shown.")
    }
}
