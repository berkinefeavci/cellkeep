import SwiftUI
import AppKit

// Link the real views into an offscreen-only test host, without the production app lifecycle.
final class AppDelegate {
    static var shared: AppDelegate? { nil }
    func showSettings(page: SettingsPage = .dashboard) {}
    func closePanel() {}
}

@main
enum MenubarSettingsPreview {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Provide a PNG output path") }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-preview-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "local.chargemate.preview.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: "appReduceTransparency")
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let coordinator = ChargeControlCoordinator(journal: root.appendingPathComponent("journal.json"),
            read: { [:] }, write: { _ in fatalError("Preview must not write hardware") }, rival: { false })
        let monitor = BatteryMonitor(defaults: defaults, coordinator: coordinator,
            historyURL: root.appendingPathComponent("history.json"), batteryReader: { BatterySnapshot() },
            nativeReader: { [:] }, controllerRunning: { false }, energyReader: { .success([]) })
        var snapshot = BatterySnapshot()
        snapshot.sampledAt = Date(); snapshot.available = true; snapshot.percentage = 90
        snapshot.externalConnected = true; snapshot.batteryPowerAvailable = true; snapshot.wattage = 0
        snapshot.temperatureC = 31.5
        monitor.snapshot = snapshot
        let view = NSHostingView(rootView: MenubarSettingsView().environmentObject(monitor)
            .defaultAppStorage(defaults).environment(\.colorScheme, .dark)
            .padding(24).frame(width: 850).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.dark))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 1200), styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = view
        window.appearance = NSAppearance(named: .darkAqua)
        view.frame = NSRect(x: 0, y: 0, width: 850, height: 1200)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No bitmap") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Offscreen settings preview written; window was never shown.")
    }
}
