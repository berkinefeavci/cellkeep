import Foundation

struct ScheduleCapabilities: Equatable {
    let chargeLimits: [Int]
    let topUpAvailable: Bool
    let powerModes: Set<SystemPowerMode>

    static let unavailable = Self(chargeLimits: [], topUpAvailable: false, powerModes: [])
}

enum ScheduleAction: String, Codable, CaseIterable, Identifiable {
    case topUp, pauseCharging, startCalibration, setChargeLimit, dischargeTo
    case enableLowPower, disableLowPower, enableHighPower
    var id: String { rawValue }
    var title: String {
        switch self {
        case .topUp: return "Tam doldur"
        case .pauseCharging: return "Şarjı duraklat"
        case .startCalibration: return "Kalibrasyon başlat"
        case .setChargeLimit: return "Şarj limitini ayarla"
        case .dischargeTo: return "Hedefe kadar boşalt"
        case .enableLowPower: return "Düşük Güç Modunu aç"
        case .disableLowPower: return "Otomatik güç moduna dön"
        case .enableHighPower: return "Yüksek Güç Modunu aç"
        }
    }
    var needsTarget: Bool { self == .setChargeLimit || self == .dischargeTo }
    func availability(in capabilities: ScheduleCapabilities) -> String? {
        switch self {
        case .topUp:
            return capabilities.topUpAvailable && capabilities.chargeLimits.contains(100)
                ? nil : "Top Up için doğrulanmış %100 şarj limiti desteği gerekiyor."
        case .setChargeLimit:
            return capabilities.chargeLimits.isEmpty ? "Bu Mac’te doğrulanmış şarj limiti desteği yok." : nil
        case .enableLowPower:
            return capabilities.powerModes.contains(.lowPower) ? nil : "Bu Mac Düşük Güç Modunu sunmuyor."
        case .disableLowPower:
            return capabilities.powerModes.contains(.automatic) ? nil : "Otomatik güç modu kullanılamıyor."
        case .enableHighPower:
            return capabilities.powerModes.contains(.turbo) ? nil : "Bu Mac Yüksek Güç Modunu sunmuyor."
        case .pauseCharging, .startCalibration, .dischargeTo:
            return "Bu donanım eyleminin fiziksel etkisi henüz doğrulanmadı."
        }
    }
    var unavailableReason: String { availability(in: .unavailable) ?? "" }
}

enum ScheduleRecurrence: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekdays, weekly, biweekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .once: return "Bir kez"
        case .daily: return "Her gün"
        case .weekdays: return "Hafta içi"
        case .weekly: return "Her hafta"
        case .biweekly: return "İki haftada bir"
        case .monthly: return "Her ay"
        case .yearly: return "Her yıl"
        }
    }
}

struct ScheduleTask: Codable, Identifiable, Equatable {
    var schemaVersion = 1
    var id = UUID()
    var name: String
    var enabled = false
    var action: ScheduleAction
    var target: Int?
    var recurrence: ScheduleRecurrence
    var startLocalComponents: DateComponents
    var timezoneID: String
    var createdAt: Date
    var modifiedAt: Date
    var activationStart: Date?
    var lastEvaluatedAt: Date?
    var catchUpEnabled = false

    static func new(now: Date, calendar: Calendar = .current) -> Self {
        let nextHour = calendar.date(bySetting: .minute, value: 0,
            of: calendar.date(byAdding: .hour, value: 1, to: now)!)!
        return Self(name: "Yeni görev", action: .pauseCharging, target: nil, recurrence: .daily,
                    startLocalComponents: localComponents(nextHour, calendar: calendar),
                    timezoneID: calendar.timeZone.identifier, createdAt: now, modifiedAt: now)
    }

    static func localComponents(_ date: Date, calendar: Calendar) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    func duplicated(now: Date) -> Self {
        var copy = self
        copy.id = UUID()
        let suffix = " kopyası"
        copy.name = String(name.prefix(max(1, 80 - suffix.count))) + suffix
        copy.enabled = false
        copy.createdAt = now
        copy.modifiedAt = now
        copy.activationStart = nil
        copy.lastEvaluatedAt = nil
        return copy
    }

    func validationError(capabilities: ScheduleCapabilities) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(trimmed.count) else { return "Görev adı 1–80 karakter olmalı." }
        guard TimeZone(identifier: timezoneID) != nil else { return "Geçerli bir saat dilimi seçin." }
        guard startLocalComponents.year != nil, startLocalComponents.month != nil,
              startLocalComponents.day != nil, startLocalComponents.hour != nil,
              startLocalComponents.minute != nil else { return "Başlangıç tarihi eksik." }
        if action.needsTarget {
            guard let target, (20...100).contains(target) else { return "Hedef %20–100 arasında olmalı." }
            if action == .setChargeLimit, !capabilities.chargeLimits.contains(target) {
                return "Bu Mac’in sunduğu limitlerden birini seçin."
            }
        } else if target != nil { return "Bu eylem hedef yüzdesi kullanmaz." }
        if enabled { return action.availability(in: capabilities) }
        return nil
    }

    func validationError(supportedLimits: [Int] = []) -> String? {
        validationError(capabilities: .init(chargeLimits: supportedLimits,
                                            topUpAvailable: supportedLimits.contains(100),
                                            powerModes: []))
    }

    func next(after instant: Date) -> Date? {
        guard let zone = TimeZone(identifier: timezoneID) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let start = calendar.date(from: startLocalComponents) else { return nil }
        if recurrence == .once { return start > instant ? start : nil }
        let startDay = calendar.startOfDay(for: start)
        let afterDay = calendar.startOfDay(for: instant)
        let firstOffset = max(0, calendar.dateComponents([.day], from: startDay, to: afterDay).day ?? 0)
        let hour = startLocalComponents.hour ?? 0
        let minute = startLocalComponents.minute ?? 0
        for offset in firstOffset...(firstOffset + 3662) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay), matches(day, startDay: startDay, calendar: calendar) else { continue }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day)!
            var match = DateComponents(); match.hour = hour; match.minute = minute
            guard let candidate = calendar.nextDate(after: day.addingTimeInterval(-1), matching: match,
                matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward), candidate < dayEnd else { continue }
            if candidate >= start && candidate > instant { return candidate }
        }
        return nil
    }

    /// Returns only the latest occurrence in a closed evaluation window. This
    /// prevents a wake after several days from building an action backlog.
    func latestOccurrence(after lowerBound: Date, through upperBound: Date) -> Date? {
        guard upperBound > lowerBound else { return nil }
        var cursor = lowerBound
        var latest: Date?
        // Ten years of daily occurrences is a defensive bound for damaged data.
        for _ in 0..<3_662 {
            guard let candidate = next(after: cursor), candidate <= upperBound else { break }
            latest = candidate
            cursor = candidate
        }
        return latest
    }

    private func matches(_ day: Date, startDay: Date, calendar: Calendar) -> Bool {
        let days = calendar.dateComponents([.day], from: startDay, to: day).day ?? 0
        switch recurrence {
        case .once: return days == 0
        case .daily: return true
        case .weekdays: return (2...6).contains(calendar.component(.weekday, from: day))
        case .weekly: return days >= 0 && days % 7 == 0
        case .biweekly: return days >= 0 && days % 14 == 0
        case .monthly:
            return calendar.component(.day, from: day) == startLocalComponents.day
        case .yearly:
            return calendar.component(.month, from: day) == startLocalComponents.month &&
                   calendar.component(.day, from: day) == startLocalComponents.day
        }
    }
}

struct ScheduleLoadResult {
    let tasks: [ScheduleTask]
    let warning: String?
}

struct ScheduleStore {
    let url: URL

    func load() -> ScheduleLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return ScheduleLoadResult(tasks: [], warning: nil) }
        do {
            let data = try Data(contentsOf: url)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["schemaVersion"] as? Int == 1,
                  let rawTasks = object["tasks"] as? [Any] else { throw CocoaError(.fileReadCorruptFile) }
            var tasks: [ScheduleTask] = []
            var invalid = 0
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            for raw in rawTasks {
                do {
                    let item = try JSONSerialization.data(withJSONObject: raw)
                    let task = try decoder.decode(ScheduleTask.self, from: item)
                    guard task.schemaVersion == 1 else { invalid += 1; continue }
                    tasks.append(task)
                } catch { invalid += 1 }
            }
            if invalid > 0 { try? backup(data) }
            return ScheduleLoadResult(tasks: tasks, warning: invalid > 0 ? "\(invalid) bozuk görev atlandı; özgün dosya yedeklendi." : nil)
        } catch {
            if let data = try? Data(contentsOf: url) { try? backup(data) }
            return ScheduleLoadResult(tasks: [], warning: "Program dosyası okunamadı; özgün dosya yedeklendi.")
        }
    }

    func save(_ tasks: [ScheduleTask]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let raw = try tasks.map { task -> Any in
            try JSONSerialization.jsonObject(with: encoder.encode(task))
        }
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "tasks": raw], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func backup(_ data: Data) throws {
        let backup = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).backup")
        try data.write(to: backup, options: .atomic)
    }
}

enum ScheduleTemplate: String, CaseIterable, Identifiable {
    case monthlyCalibration, biweeklyCalibration, mondayTopUp, weekendFull
    var id: String { rawValue }
    var title: String {
        switch self {
        case .monthlyCalibration: return "Aylık kalibrasyon"
        case .biweeklyCalibration: return "İki haftalık kalibrasyon"
        case .mondayTopUp: return "Pazartesi tam dolum"
        case .weekendFull: return "Hafta sonu tam dolum"
        }
    }
    func task(now: Date, calendar source: Calendar = .current) -> ScheduleTask {
        let calendar = source
        let action: ScheduleAction
        let recurrence: ScheduleRecurrence
        let targetWeekday: Int?
        let hour: Int
        switch self {
        case .monthlyCalibration: action = .startCalibration; recurrence = .monthly; targetWeekday = nil; hour = 9
        case .biweeklyCalibration: action = .startCalibration; recurrence = .biweekly; targetWeekday = 7; hour = 9
        case .mondayTopUp: action = .topUp; recurrence = .weekly; targetWeekday = 2; hour = 7
        case .weekendFull: action = .topUp; recurrence = .weekly; targetWeekday = 6; hour = 18
        }
        var start: Date
        if self == .monthlyCalibration {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
            var c = calendar.dateComponents([.year, .month], from: nextMonth); c.day = 1; c.hour = hour; c.minute = 0
            start = calendar.date(from: c)!
        } else {
            var match = DateComponents(); match.weekday = targetWeekday; match.hour = hour; match.minute = 0
            start = calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime, repeatedTimePolicy: .first)!
        }
        return ScheduleTask(name: title, action: action, target: nil, recurrence: recurrence,
            startLocalComponents: ScheduleTask.localComponents(start, calendar: calendar),
            timezoneID: calendar.timeZone.identifier, createdAt: now, modifiedAt: now)
    }
}
