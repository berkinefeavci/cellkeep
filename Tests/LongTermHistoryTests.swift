import Foundation

@main enum LongTermHistoryTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day0 = Date(timeIntervalSince1970: 1_800_000_000)   // 2027-01-15T08:00:00Z
        typealias S = LongTermHistory.Sample
        func at(_ minutes: Double, _ percent: Int?, health: Double? = nil, capacity: Int? = nil,
                cycles: Int? = nil, temp: Double? = nil) -> S {
            S(date: day0.addingTimeInterval(minutes * 60), percentage: percent, healthPercent: health,
              fullCapacityMAh: capacity, cycleCount: cycles, temperatureC: temp)
        }

        precondition(LongTermHistory.dayKey(day0, calendar: calendar) == "2027-01-15")
        precondition(LongTermHistory.summarize([], calendar: calendar).isEmpty)

        // One day: readings every minute, an 8-minute gap that is not counted as observed time.
        let samples = [at(0, 88, health: 97, capacity: 5000, cycles: 120, temp: 30),
                       at(1, 90, health: 96, capacity: 4990, cycles: 121, temp: 35.5),
                       at(2, 92, health: 98, capacity: 5010, cycles: 121),
                       at(10, 80, temp: .nan)]
        let one = LongTermHistory.summarize(samples.shuffled(), calendar: calendar)
        precondition(one.count == 1)
        let d = one[0]
        precondition(d.day == "2027-01-15" && d.samples == 4)
        precondition(d.minPercent == 80 && d.maxPercent == 92 && d.averagePercent == 87.5)
        precondition(d.observedMinutes == 2, "the 8-minute gap is not observed time")
        precondition(d.minutesAtOrAbove90 == 1, "only the 90% reading's following minute counts; 92% is followed by a gap")
        precondition(d.healthPercent == 97 && d.fullCapacityMAh == 5000 && d.cycleCount == 121)
        precondition(d.maxTemperatureC == 35.5, "NaN temperature ignored")

        // Missing values stay missing, never zero.
        let sparse = LongTermHistory.summarize([at(0, nil)], calendar: calendar)[0]
        precondition(sparse.minPercent == nil && sparse.averagePercent == nil && sparse.healthPercent == nil
                     && sparse.cycleCount == nil && sparse.maxTemperatureC == nil && sparse.observedMinutes == 0)

        // A gap across midnight is not attributed to either day.
        let lateNight = Date(timeIntervalSince1970: 1_800_057_540)   // 2027-01-15T23:59:00Z
        let split = LongTermHistory.summarize([S(date: lateNight, percentage: 95),
                                               S(date: lateNight.addingTimeInterval(120), percentage: 95)], calendar: calendar)
        precondition(split.map(\.day) == ["2027-01-15", "2027-01-16"] && split.allSatisfy { $0.observedMinutes == 0 })

        // Merge: a fuller stored day is never replaced by a shorter recomputation; newer data wins otherwise.
        func summary(_ day: String, samples: Int, health: Double? = nil, cycles: Int? = nil,
                     avg: Double? = nil, observed: Double = 0, high: Double = 0, temp: Double? = nil) -> DailySummary {
            DailySummary(day: day, samples: samples, minPercent: nil, maxPercent: nil, averagePercent: avg,
                         observedMinutes: observed, minutesAtOrAbove90: high, healthPercent: health,
                         fullCapacityMAh: nil, cycleCount: cycles, maxTemperatureC: temp)
        }
        let merged = LongTermHistory.merge(stored: [summary("2027-01-14", samples: 2000), summary("2027-01-15", samples: 10)],
                                           fresh: [summary("2027-01-14", samples: 300), summary("2027-01-15", samples: 50),
                                                   summary("2027-01-16", samples: 5)],
                                           newestDay: "2027-01-15")
        precondition(merged.map(\.day) == ["2027-01-14", "2027-01-15"], "future day dropped")
        precondition(merged[0].samples == 2000 && merged[1].samples == 50)
        // Retention: only the newest `keepDays` days are kept.
        let many = (0..<(LongTermHistory.keepDays + 5)).map { index -> DailySummary in
            let date = calendar.date(byAdding: .day, value: index, to: day0)!
            return summary(LongTermHistory.dayKey(date, calendar: calendar), samples: 1)
        }
        let kept = LongTermHistory.merge(stored: many, fresh: [], newestDay: many.last!.day)
        precondition(kept.count == LongTermHistory.keepDays && kept.last!.day == many.last!.day)

        // Stats over a window.
        let week = [summary("2027-01-09", samples: 100, health: 99, cycles: 100, avg: 50, observed: 60, high: 0, temp: 30),
                    summary("2027-01-12", samples: 300, health: 98.5, cycles: 103, avg: 90, observed: 120, high: 60, temp: 38),
                    summary("2027-01-15", samples: 100, health: 98, cycles: 105, avg: 70, observed: 60, high: 30)]
        let stats = LongTermHistory.stats(week, lastDays: 7, endingOn: "2027-01-15", calendar: calendar)!
        precondition(stats.days == 3)
        precondition(stats.averagePercent == 78, "sample-weighted: (50*100 + 90*300 + 70*100) / 500")
        precondition(stats.shareAtOrAbove90 == 0.375, "90 of 240 observed minutes")
        precondition(stats.cyclesAdded == 5 && stats.healthChange == -1 && stats.peakTemperatureC == 38)
        // The window excludes older days; no data → nil.
        precondition(LongTermHistory.stats(week, lastDays: 3, endingOn: "2027-01-15", calendar: calendar)!.days == 1)
        precondition(LongTermHistory.stats(week, lastDays: 7, endingOn: "2026-12-01", calendar: calendar) == nil)
        let single = LongTermHistory.stats([week[0]], lastDays: 7, endingOn: "2027-01-10", calendar: calendar)!
        precondition(single.cyclesAdded == nil && single.healthChange == nil, "one day cannot show a change")

        // Storage: round trip, missing file, corrupt file kept aside.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lth-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("daily-summary.json")
        precondition(LongTermHistory.read(url).isEmpty)
        try! LongTermHistory.write(week, to: url)
        precondition(LongTermHistory.read(url) == week)
        try! Data("{not json".utf8).write(to: url)
        precondition(LongTermHistory.read(url, now: Date(timeIntervalSince1970: 42)).isEmpty)
        precondition(FileManager.default.fileExists(atPath: url.path + ".corrupt-42"), "corrupt file preserved")
        print("Long-term history: daily summary, gaps, merge, retention, stats and storage assertions passed.")
    }
}
