import Foundation

@main
enum SupportCenterTests {
    static func main() throws {
        precondition(Thread.isMainThread)
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            precondition(condition(), label); assertions += 1
        }
        func until(_ condition: () -> Bool) {
            let deadline = Date().addingTimeInterval(4)
            while !condition(), Date() < deadline {
                _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            precondition(condition(), "async support callback timed out")
        }

        let suite = "local.chargemate.support-tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("dark", forKey: "appearance")
        defaults.set(true, forKey: "showDockIcon")
        defaults.set(true, forKey: "onboardingCompleted")
        defaults.set(85.0, forKey: "chargeLimit")
        defaults.set(90, forKey: "committedChargeLimit")
        defaults.set(true, forKey: "sailingEnabled")
        ChargeMatePreferences.resetUI(in: defaults)
        check(defaults.object(forKey: "appearance") == nil && defaults.object(forKey: "showDockIcon") == nil,
              "UI keys removed")
        check(defaults.object(forKey: "onboardingCompleted") == nil, "onboarding resets with UI")
        check(defaults.double(forKey: "chargeLimit") == 85 && defaults.integer(forKey: "committedChargeLimit") == 90,
              "native draft and confirmed target preserved")
        check(defaults.bool(forKey: "sailingEnabled"), "control preference preserved")
        check(MenubarPreferences.load(from: defaults) == MenubarPreferences(), "menubar returns to explicit default")

        let now = Date()
        var snapshot = BatterySnapshot()
        snapshot.sampledAt = now; snapshot.available = true; snapshot.percentage = 81
        snapshot.sources[.percentage] = "IOPS CurrentCapacity"
        snapshot.sources[.temperature] = "/Users/private/sensor"
        let report = ChargeMateDiagnostics.report(snapshot: snapshot, nativeLimit: 85, currentSystemLimit: 100,
            nativeLimits: [80, 85, 90, 95, 100], otherControllerRunning: false, applyingLimit: false,
            recoveryRequired: false, historyCount: 4, historyError: false, energyState: .failed("/Users/private/error"),
            now: now, model: "Mac15,3", osVersion: "macOS test")
        check(report.contains("Mac15,3") && report.contains("kalite=valid"), "report includes support facts")
        check(report.contains("ayıklanmış") && !report.contains("/Users/") && !report.contains("private"),
              "report excludes user paths")
        check(!report.contains(NSUserName()), "report excludes identity")
        check(!report.contains("error") && report.contains("hata-var"), "raw errors are reduced to status")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-support-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let historyURL = root.appendingPathComponent("history.json")
        let point = BatteryHistoryPoint(date: now, percentage: 81, wattage: 0, temperatureC: 31,
                                        systemWatts: 8, healthPercent: 96, cycleCount: 12)
        try HistoryArchive(schemaVersion: 2, measurements: [point], limitEvents: [LimitEvent(date: now, value: 85)]).write(historyURL)
        let unavailableBackend = NativeChargeBackend(version: "fake-unavailable", timeout: 0.1) { _, _ in
            throw NativeChargeBackendError.helperMissing
        }
        let coordinator = ChargeControlCoordinator(journal: root.appendingPathComponent("journal.json"),
            backend: unavailableBackend, rival: { false })
        let monitor = BatteryMonitor(defaults: defaults, coordinator: coordinator, historyURL: historyURL,
            batteryReader: { BatterySnapshot() }, nativeReader: { nil }, controllerRunning: { false },
            energyReader: { .success([]) })
        monitor.start(); monitor.stop()
        check(monitor.history.count == 1 && monitor.limitEvents.count == 1, "fixture history loaded")
        var clearMessage: String?
        monitor.clearHistoryWithBackup { clearMessage = $0 }
        until { clearMessage != nil }
        check(monitor.history.isEmpty && monitor.limitEvents.isEmpty && monitor.historyBackupAvailable,
              "history cleared only after backup")
        let clearedArchive = try HistoryArchive.read(historyURL)
        check(clearedArchive.measurements.isEmpty, "empty archive persisted")
        var restoreMessage: String?
        monitor.restoreHistoryBackup { restoreMessage = $0 }
        until { restoreMessage != nil }
        check(monitor.history.count == 1 && monitor.limitEvents.count == 1 && !monitor.historyBackupAvailable,
              "history restored from backup")
        check(defaults.double(forKey: "chargeLimit") == 85 && defaults.integer(forKey: "committedChargeLimit") == 90,
              "history actions preserve control state")

        print("Support center: \(assertions) assertions passed; isolated defaults/files and fake hardware only.")
    }
}
