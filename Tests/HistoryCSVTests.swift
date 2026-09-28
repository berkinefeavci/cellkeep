import Foundation

@main enum HistoryCSVTests {
    static func main() {
        // Empty history: header only.
        precondition(HistoryCSV.make([]) == HistoryCSV.header + "\n")

        let early = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15T08:00:00Z
        let late = early.addingTimeInterval(60)
        let full = HistoryCSV.Row(date: late, percentage: 80, hardwarePercentage: 82, batteryWatts: -7.456,
                                  systemWatts: 12.3, temperatureC: 31.25, healthPercent: 97.46, cycleCount: 120,
                                  batteryCurrentMA: -612.4, batteryVoltageV: 12.3456, remainingCapacityMAh: 4100,
                                  fullCapacityMAh: 5000)
        let sparse = HistoryCSV.Row(date: early, percentage: 79)
        let lines = HistoryCSV.make([full, sparse]).split(separator: "\n", omittingEmptySubsequences: false)

        precondition(lines.count == 4 && lines[3].isEmpty, "header + 2 rows + trailing newline")
        precondition(lines[0] == Substring(HistoryCSV.header))
        let columns = HistoryCSV.header.split(separator: ",").count
        // Sorted by time; missing readings are empty cells, never 0 or a placeholder.
        precondition(lines[1] == "2027-01-15T08:00:00Z,79,,,,,,,,,,")
        precondition(lines[1].split(separator: ",", omittingEmptySubsequences: false).count == columns)
        precondition(lines[2] == "2027-01-15T08:01:00Z,80,82,-7.46,12.30,31.2,97.5,120,-612,12.346,4100,5000")
        // Non-finite values are treated as missing.
        let nan = HistoryCSV.make([HistoryCSV.Row(date: early, batteryWatts: .nan, systemWatts: .infinity)])
        precondition(nan.hasSuffix("2027-01-15T08:00:00Z,,,,,,,,,,,\n"))
        print("History CSV: header, ordering, empty cells, rounding and non-finite assertions passed.")
    }
}
