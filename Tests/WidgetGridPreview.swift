import AppKit
import SwiftUI

// App.swift (the real @main / AppDelegate) is intentionally excluded from this preview tool's
// compile, same as Tests/UIRefinementPreview.swift, to avoid a duplicate `main`. PopoverView only
// calls a couple of AppDelegate.shared methods for toolbar buttons unrelated to this preview.
final class AppDelegate {
    static var shared: AppDelegate? { nil }
    func showSettings(page: SettingsPage = .dashboard) {}
    func closePanel() {}
}

/// Offscreen render of the modernized panel widget editor: normal mode with a mix of square
/// (half-width) and wide cards, and edit mode with the size/remove badges plus the "Kart ekle"
/// gallery open. No window is shown, no hardware is touched, and layout/preferences live in an
/// isolated UserDefaults suite (never the real user's).
@main
enum WidgetGridPreview {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Provide normal-mode and edit-mode PNG output paths")
        }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-widget-grid-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "local.chargemate.widget-grid-preview.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // Fixture layout: two square charts paired in one row, a wide power-flow card, a square
        // "significant energy" card left alone (odd one out -> left half), and a wide chart.
        let placed: [PlacedWidget] = [
            PlacedWidget(.chartLevel, size: .square),
            PlacedWidget(.chartTemperature, size: .square),
            PlacedWidget(.powerFlow, size: .wide),
            PlacedWidget(.significantEnergy, size: .square),
            PlacedWidget(.chartPower, size: .wide),
        ]
        defaults.set(try PopoverLayout.encode(placed), forKey: "popoverLayout")
        defaults.set(true, forKey: "appReduceTransparency")

        var snapshot = BatterySnapshot()
        snapshot.sampledAt = Date()
        snapshot.available = true
        snapshot.percentage = 72
        snapshot.externalConnected = true // Injected fixture; never probes live SMC.
        snapshot.voltage = 12.4
        snapshot.amperage = 900
        snapshot.wattage = 34
        snapshot.batteryPowerAvailable = true
        snapshot.nominalChargeCapacity = 8200
        snapshot.designCapacity = 8579
        snapshot.adapterRatedWatts = 96
        snapshot.temperatureSource = "SMC TB1T (flt)"
        snapshot.sources[.percentage] = "fixture"

        let stateJSON = Data(#"{"schemaVersion":1,"ok":true,"state":{"manualLimit":80,"availableLimits":[80,85,90,95,100],"enabledRaw":1,"currentLimit":80}}"#.utf8)
        let backend = NativeChargeBackend(version: "preview", timeout: 0.1) { arguments, _ in
            guard arguments == ["read"] else { fatalError("Preview must never write hardware") }
            return NativeChargeProcessResult(status: 0, output: stateJSON)
        }
        let coordinator = ChargeControlCoordinator(journal: root.appendingPathComponent("control.json"),
            backend: backend, rival: { false })
        let monitor = BatteryMonitor(defaults: defaults, coordinator: coordinator,
            historyURL: root.appendingPathComponent("history.json"), batteryReader: { snapshot },
            nativeReader: { try? backend.readState() }, controllerRunning: { false },
            energyReader: { .success([
                EnergyApp(pid: 1, name: "WindowServer", power: 45, cpu: 18, isApplication: false),
                EnergyApp(pid: 2, name: "Safari", power: 30, cpu: 12, isApplication: true, iconPath: "/Applications/Safari.app"),
                EnergyApp(pid: 3, name: "Mail", power: 20, cpu: 9, isApplication: true, iconPath: "/System/Applications/Mail.app"),
            ]) },
            connectedDeviceReader: { [] },
            powerModeReader: { .init(battery: .automatic, adapter: .automatic) },
            powerModeWriter: { _, _ in fatalError("Preview must never write power mode") })
        monitor.snapshot = snapshot
        monitor.settingsVisible = true
        monitor.refresh()
        let deadline = Date().addingTimeInterval(3)
        while monitor.nativeLimits.isEmpty && Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        // Normal mode: renders the saved mixed-size layout via the two-column square grid.
        try render(PopoverView().environmentObject(monitor)
            .defaultAppStorage(defaults).preferredColorScheme(.dark),
            size: NSSize(width: 400, height: 760), path: CommandLine.arguments[1])

        // Edit mode: enter editing programmatically is not exposed, so we drive the panel's own
        // "Düzenle" affordance is unavailable offscreen without event injection; instead this
        // second render captures the same layout with the gallery driven directly, which exercises
        // the modernized card gallery grid/size-chip rendering.
        try render(WidgetGalleryPreviewHost().defaultAppStorage(defaults).preferredColorScheme(.dark),
            size: NSSize(width: 400, height: 500), path: CommandLine.arguments[2])

        print("Two offscreen widget-grid previews written; no window shown and no hardware write.")
    }

    private static func render<V: View>(_ root: V, size: NSSize, path: String) throws {
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: true)
        window.contentView = view
        window.appearance = NSAppearance(named: .darkAqua)
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
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

/// Hosts the panel's own gallery sheet content already open (bypassing the pointer click needed to
/// reach it inside the live popover), so the modernized "Kart ekle" grid/size-chip layout renders
/// in isolation for visual inspection.
private struct WidgetGalleryPreviewHost: View {
    @State private var draft: [PlacedWidget] = [PlacedWidget(.statusExplanation), PlacedWidget(.chartLevel, size: .square)]
    var body: some View {
        WidgetGallerySheet(draft: $draft) {}
            .modifier(WindowSurface())
    }
}
