import Foundation

/// Plain CSV of recorded readings, for spreadsheets or a bug report. Headers are fixed English
/// identifiers and numbers always use "." so the file reads the same on every locale; a missing
/// reading is an empty cell, never a placeholder value.
enum HistoryCSV {
    struct Row: Equatable {
        var date: Date
        var percentage: Int?
        var hardwarePercentage: Int?
        var batteryWatts: Double?
        var systemWatts: Double?
        var temperatureC: Double?
        var healthPercent: Double?
        var cycleCount: Int?
        var batteryCurrentMA: Double?
        var batteryVoltageV: Double?
        var remainingCapacityMAh: Int?
        var fullCapacityMAh: Int?
    }

    static let header = "timestamp_utc,percentage,hardware_percentage,battery_power_w,system_power_w,temperature_c,"
        + "health_percent,cycle_count,battery_current_ma,battery_voltage_v,remaining_capacity_mah,full_capacity_mah"

    static func make(_ rows: [Row]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        var lines = [header]
        for row in rows.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: row.date),
                int(row.percentage), int(row.hardwarePercentage),
                number(row.batteryWatts, digits: 2), number(row.systemWatts, digits: 2),
                number(row.temperatureC, digits: 1), number(row.healthPercent, digits: 1),
                int(row.cycleCount), number(row.batteryCurrentMA, digits: 0), number(row.batteryVoltageV, digits: 3),
                int(row.remainingCapacityMAh), int(row.fullCapacityMAh),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static let dailyHeader = "day,samples,min_percent,max_percent,average_percent,observed_minutes,"
        + "minutes_at_or_above_90,health_percent,full_capacity_mah,cycle_count,max_temperature_c"

    /// One row per local calendar day from the long-term summaries.
    static func makeDaily(_ days: [DailySummary]) -> String {
        var lines = [dailyHeader]
        for day in days.sorted(by: { $0.day < $1.day }) {
            lines.append([
                day.day, String(day.samples), int(day.minPercent), int(day.maxPercent),
                number(day.averagePercent, digits: 1), number(day.observedMinutes, digits: 1),
                number(day.minutesAtOrAbove90, digits: 1), number(day.healthPercent, digits: 1),
                int(day.fullCapacityMAh), int(day.cycleCount), number(day.maxTemperatureC, digits: 1),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func int(_ value: Int?) -> String { value.map(String.init) ?? "" }

    private static func number(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return "" }
        return String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
