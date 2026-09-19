import Foundation

public struct ReminderConfiguration: Equatable, Sendable {
    public var dailyEnabled: Bool
    public var solarTermEnabled: Bool
    public var hour: Int
    public var minute: Int

    public init(dailyEnabled: Bool, solarTermEnabled: Bool, hour: Int, minute: Int) {
        self.dailyEnabled = dailyEnabled
        self.solarTermEnabled = solarTermEnabled
        self.hour = hour
        self.minute = minute
    }
}

public enum ReminderKind: String, Equatable, Sendable {
    case daily
    case solarTerm
}

public enum ReminderTrigger: Equatable, Sendable {
    case daily(hour: Int, minute: Int)
    case date(Date)
}

public struct ReminderPlanItem: Equatable, Sendable {
    public let identifier: String
    public let kind: ReminderKind
    public let title: String
    public let body: String
    public let trigger: ReminderTrigger

    public init(identifier: String, kind: ReminderKind, title: String, body: String, trigger: ReminderTrigger) {
        self.identifier = identifier
        self.kind = kind
        self.title = title
        self.body = body
        self.trigger = trigger
    }
}

public enum ReminderSchedule {
    /// UserNotifications permits 64 pending requests per app. Keeping the repeating
    /// daily request plus one full solar year comfortably below that ceiling also
    /// leaves room for future one-off reminders.
    public static let systemPendingRequestLimit = 64
    public static let solarTermRequestCount = 24
    public static let dailyIdentifier = "suji.reminder.daily"
    public static let solarTermIdentifierPrefix = "suji.reminder.solar-term."

    public static func nextDailyFire(
        after date: Date,
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    public static func makePlan(
        configuration: ReminderConfiguration,
        after date: Date = Date(),
        calendar: Calendar = .current,
        isAuthorized: Bool
    ) -> [ReminderPlanItem] {
        guard isAuthorized else { return [] }
        var items: [ReminderPlanItem] = []

        if configuration.dailyEnabled,
           (0...23).contains(configuration.hour),
           (0...59).contains(configuration.minute) {
            items.append(ReminderPlanItem(
                identifier: dailyIdentifier,
                kind: .daily,
                title: "今日留白",
                body: "新的一天到了。慢一点，看看今天的一张日签。",
                trigger: .daily(hour: configuration.hour, minute: configuration.minute)
            ))
        }

        if configuration.solarTermEnabled {
            let terms = SolarTermCalculator.nextOccurrences(after: date, count: solarTermRequestCount)
            items.append(contentsOf: terms.map { occurrence in
                ReminderPlanItem(
                    identifier: solarTermIdentifierPrefix + identifierDate(occurrence.date),
                    kind: .solarTerm,
                    title: occurrence.name,
                    body: "\(occurrence.name)到了。留意天光与节律的变化，给今天留一点从容。",
                    trigger: .date(occurrence.date)
                )
            })
        }

        // Daily is deliberately first and cannot be displaced if this budget is
        // tightened later. The current maximum is 25.
        return Array(items.prefix(systemPendingRequestLimit - 1))
    }

    private static func identifierDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: date)
    }
}

public struct SolarTermOccurrence: Equatable, Sendable {
    public let name: String
    public let longitude: Int
    public let date: Date

    public init(name: String, longitude: Int, date: Date) {
        self.name = name
        self.longitude = longitude
        self.date = date
    }
}

public enum SolarTermCalculator {
    private static let namesByLongitudeIndex = [
        "春分", "清明", "谷雨", "立夏", "小满", "芒种",
        "夏至", "小暑", "大暑", "立秋", "处暑", "白露",
        "秋分", "寒露", "霜降", "立冬", "小雪", "大雪",
        "冬至", "小寒", "大寒", "立春", "雨水", "惊蛰"
    ]

    public static func currentTerm(at date: Date) -> String {
        namesByLongitudeIndex[longitudeIndex(at: date)]
    }

    public static func nextOccurrences(after date: Date, count: Int) -> [SolarTermOccurrence] {
        guard count > 0 else { return [] }
        var results: [SolarTermOccurrence] = []
        var lower = date
        var lowerIndex = longitudeIndex(at: lower)
        let scanStep: TimeInterval = 6 * 60 * 60

        while results.count < count {
            var upper = lower.addingTimeInterval(scanStep)
            var upperIndex = longitudeIndex(at: upper)
            while upperIndex == lowerIndex {
                lower = upper
                upper = upper.addingTimeInterval(scanStep)
                upperIndex = longitudeIndex(at: upper)
            }

            // Solar longitude is monotonic over this six-hour bracket. Bisection
            // locates the 15-degree boundary to within one second.
            var left = lower
            var right = upper
            while right.timeIntervalSince(left) > 1 {
                let middle = left.addingTimeInterval(right.timeIntervalSince(left) / 2)
                if longitudeIndex(at: middle) == lowerIndex {
                    left = middle
                } else {
                    right = middle
                }
            }

            let occurrenceIndex = longitudeIndex(at: right)
            results.append(SolarTermOccurrence(
                name: namesByLongitudeIndex[occurrenceIndex],
                longitude: occurrenceIndex * 15,
                date: right
            ))
            lower = right.addingTimeInterval(1)
            lowerIndex = occurrenceIndex
        }
        return results
    }

    private static func longitudeIndex(at date: Date) -> Int {
        Int(floor(solarLongitude(at: date) / 15)) % 24
    }

    /// Approximate apparent geocentric solar longitude. This is a direct Swift
    /// port of `lib/qimen/helpers/solarTerms.ts`, whose low-order equations follow
    /// NOAA's Solar Calculation Details (Julian centuries, geometric mean
    /// longitude/anomaly, equation of center, and apparent-longitude correction).
    /// It is suitable for notification timing, not high-precision ephemerides.
    private static func solarLongitude(at date: Date) -> Double {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545.0) / 36_525
        let l0 = normalize(280.46646 + 36_000.76983 * t + 0.0003032 * t * t)
        let m = normalize(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)
        let omega = 125.04 - 1_934.136 * t
        let radians = m * .pi / 180
        let center = sin(radians) * (1.914602 - 0.004817 * t - 0.000014 * t * t)
            + sin(2 * radians) * (0.019993 - 0.000101 * t)
            + sin(3 * radians) * 0.000289
        let trueLongitude = l0 + center
        return normalize(trueLongitude - 0.00569 - 0.00478 * sin(omega * .pi / 180))
    }

    private static func normalize(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}
