import Foundation

@main enum MeasurementQualityTests {
    static func main() throws {
        let now = Date()
        var assertions = 0
        func check(_ value: Bool, _ label: String) { precondition(value, label); assertions += 1 }
        func decode(_ dict: [String: Any]) -> BatterySnapshot {
            var snapshot = BatterySnapshot(); snapshot.sampledAt = now
            BatteryMonitor.applyRegistry(dict, to: &snapshot)
            return snapshot
        }
        let empty = decode([:])
        for field in BatteryField.allCases {
            check(empty.reading(field, now: now).metadata.quality == .missing, "missing \(field)")
            check(empty.reading(field, now: now).text() == "—", "missing formatted \(field)")
        }
        let percentageOnly = decode(["CurrentCapacity": 80])
        check(percentageOnly.percentage == 80 && percentageOnly.hardwarePercentage == nil, "hardware must not fall back to macOS")
        let zero = decode(["CurrentCapacity": 0, "CycleCount": 0, "Voltage": 12000, "InstantAmperage": 0,
                           "RemainingCapacity": 0, "FullChargeCapacity": 6000, "Temperature": 0,
                           "PowerTelemetryData": ["SystemLoad": 0]])
        check(zero.percentage == 0 && zero.hardwarePercentage == 0 && zero.remainingCapacity == 0, "real zero capacity")
        check(zero.cycleCount == 0 && zero.wattage == 0 && zero.temperatureC == 0 && zero.systemWatts == 0, "real zero measurements")
        check(zero.reading(.batteryPower, now: now).text() == "0.0 W", "zero has a value and unit")
        let denominator = decode(["RemainingCapacity": 0, "FullChargeCapacity": 0, "DesignCapacity": 0])
        check(denominator.hardwarePercentage == nil && denominator.healthPercent == nil, "zero denominator cannot create percentage")
        check(denominator.reading(.fullCapacity, now: now).metadata.quality == .invalid, "zero denominator marked invalid")
        let signed = decode(["Voltage": 12000, "InstantAmperage": NSNumber(value: UInt64.max - 999),
                             "ExternalConnected": true, "FullChargeCapacity": 6200, "DesignCapacity": 6000,
                             "PowerTelemetryData": ["SystemPowerIn": 25000, "SystemLoad": 24000]])
        check(signed.amperage == -1000 && signed.wattage == -12 && signed.adapterWatts == 25 && signed.systemWatts == 24, "signed current and mW units")
        check(signed.healthPercent == 100, "health capped at 100 like macOS")
        check(signed.reading(.health, now: now).text() == "%100.0", "health display capped")
        check(signed.usableCapacityText == "%103.3", "usable capacity stays unclamped")
        // Live Mac17,8 values: macOS reports 100 %, FullChargeCapacity alone would say 99.1 %.
        let nominal = decode(["BatteryData": ["NominalChargeCapacity": 8744, "FullChargeCapacity": 8500, "DesignCapacity": 8579]])
        check(nominal.healthPercent == 100, "health follows nominal capacity")
        check(nominal.reading(.fullCapacity, now: now).text(digits: 0) == "8500 mAh", "full capacity stays usable charge")
        check(nominal.usableCapacityText == "%99.1", "usable capacity from full charge capacity")
        let worn = decode(["BatteryData": ["NominalChargeCapacity": 7722, "FullChargeCapacity": 7500, "DesignCapacity": 8579]])
        check(abs(worn.healthPercent! - 90.01) < 0.01, "worn health below 100 is not rounded up")
        let invalid = decode(["Temperature": Double.nan, "Voltage": Double.infinity, "InstantAmperage": Double.nan,
                              "CurrentCapacity": 150, "CycleCount": -1, "DesignCapacity": Double.infinity,
                              "RemainingCapacity": Double(Int.max), "FullChargeCapacity": 6000,
                              "PowerTelemetryData": ["SystemLoad": -1]])
        for field in [BatteryField.temperature, .voltage, .current, .percentage, .cycles, .designCapacity, .remainingCapacity, .systemPower] {
            check(invalid.reading(field, now: now).metadata.quality == .invalid && invalid.reading(field, now: now).text() == "—", "invalid \(field)")
        }
        let fallback = decode(["Temperature": Double.nan, "BatteryData": ["Temperature": 3550]])
        check(fallback.temperatureC == 35.5 && fallback.sources[.temperature] == "IOKit BatteryData.Temperature", "invalid top-level temperature falls back with provenance")
        let fresh = signed.reading(.batteryPower, now: now.addingTimeInterval(10))
        let stale = signed.reading(.batteryPower, now: now.addingTimeInterval(10.01))
        check(fresh.metadata.quality == .valid && stale.metadata.quality == .stale && stale.validValue == nil, "freshness exact boundary")
        check(stale.text() == "—" && stale.value == -12, "stale retained but not presented as live")
        check(signed.reading(.batteryPower, now: now.addingTimeInterval(-1)).metadata.quality == .invalid, "future reading not valid")
        check(PowerFlowPresentation(snapshot: signed, now: now.addingTimeInterval(11)).edges.allSatisfy { $0.watts == nil }, "stale has no active flow")
        let missingPoint = BatteryMonitor.historyPoint(empty, now: now)
        let encoded = try JSONEncoder().encode(missingPoint)
        let restored = try JSONDecoder().decode(BatteryHistoryPoint.self, from: encoded)
        check(restored.percentage == nil && restored.healthPercent == nil && restored.cycleCount == nil && restored.wattage == nil, "missing history stays absent")
        check(restored.measurementMetadata?["hardwarePercentage"]?.quality == .missing, "history persists quality")
        let signedPoint = BatteryMonitor.historyPoint(signed, now: now)
        check(signedPoint.measurementMetadata?["batteryPower"]?.source?.contains("Voltage") == true, "history persists provenance")
        let old = BatteryHistoryPoint(date: now, percentage: 80, wattage: 0, temperatureC: nil, systemWatts: 25, healthPercent: 100, cycleCount: 2)
        let oldData = try JSONEncoder().encode(old)
        let legacy = try JSONDecoder().decode(BatteryHistoryPoint.self, from: oldData)
        check(legacy.percentage == 80 && legacy.measurementMetadata == nil, "legacy history retains values without invented provenance")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("chargemate-quality-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("history.json")
        let archive = HistoryArchive(schemaVersion: 2, measurements: [old], limitEvents: [])
        let original = try JSONEncoder().encode(archive)
        try original.write(to: file)
        try HistoryArchive(schemaVersion: 2, measurements: [old, missingPoint], limitEvents: []).write(file)
        let after = try HistoryArchive.read(file, now: now)
        check(after.measurements.count == 1 && after.measurements[0].percentage == 80, "empty duplicate must not overwrite valid measurement")
        check(try Data(contentsOf: file.appendingPathExtension("before-measurement-quality.backup")) == original, "old archive byte-for-byte backup")
        print("Measurement quality: \(assertions) assertions passed; missing/zero/invalid/stale/source/history.")
    }
}
