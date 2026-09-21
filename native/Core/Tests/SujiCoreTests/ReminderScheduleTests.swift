import XCTest
@testable import SujiCore

final class ReminderScheduleTests: XCTestCase {
    private let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    func testNextDailyFireRollsToTomorrowAfterChosenTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T00:31:00Z")) // 08:31

        let fire = try XCTUnwrap(ReminderSchedule.nextDailyFire(after: now, hour: 8, minute: 30, calendar: calendar))

        XCTAssertEqual(DayKey(date: fire, timeZone: shanghai).rawValue, "2026-09-20")
        let components = calendar.dateComponents([.hour, .minute], from: fire)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 30)
    }

    func testNextDailyFireKeepsTodayBeforeChosenTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T00:29:00Z")) // 08:29

        let fire = try XCTUnwrap(ReminderSchedule.nextDailyFire(after: now, hour: 8, minute: 30, calendar: calendar))

        XCTAssertEqual(DayKey(date: fire, timeZone: shanghai).rawValue, "2026-09-19")
    }

    func testAuthorizedPlanBuildsDailyAndSolarRequestsWithinSystemBudget() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T00:00:00Z"))
        let configuration = ReminderConfiguration(
            dailyEnabled: true,
            solarTermEnabled: true,
            hour: 8,
            minute: 30
        )

        let denied = ReminderSchedule.makePlan(configuration: configuration, after: now, calendar: calendar, isAuthorized: false)
        let authorized = ReminderSchedule.makePlan(configuration: configuration, after: now, calendar: calendar, isAuthorized: true)

        XCTAssertTrue(denied.isEmpty)
        XCTAssertEqual(authorized.filter { $0.kind == .daily }.count, 1)
        XCTAssertEqual(authorized.filter { $0.kind == .solarTerm }.count, ReminderSchedule.solarTermRequestCount)
        XCTAssertLessThan(authorized.count, ReminderSchedule.systemPendingRequestLimit)
        XCTAssertEqual(authorized.first?.identifier, ReminderSchedule.dailyIdentifier)
        guard case .daily(let hour, let minute) = authorized.first?.trigger else {
            return XCTFail("Expected repeating daily trigger")
        }
        XCTAssertEqual(hour, 8)
        XCTAssertEqual(minute, 30)
    }

    func testPlanCanScheduleSolarTermsWithoutReplacingDailyRequest() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-19T00:00:00Z"))

        let plan = ReminderSchedule.makePlan(
            configuration: ReminderConfiguration(dailyEnabled: true, solarTermEnabled: true, hour: 7, minute: 45),
            after: now,
            calendar: calendar,
            isAuthorized: true
        )

        XCTAssertTrue(plan.contains { $0.identifier == ReminderSchedule.dailyIdentifier })
        XCTAssertTrue(plan.filter { $0.kind == .solarTerm }.allSatisfy { $0.identifier.hasPrefix(ReminderSchedule.solarTermIdentifierPrefix) })
        XCTAssertTrue(plan.filter { $0.kind == .solarTerm }.allSatisfy { $0.body.hasPrefix("\($0.title)到了。") })
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count)
    }

    func testAstronomyFindsKnown2024EquinoxAndSolsticeInstants() throws {
        let formatter = ISO8601DateFormatter()
        let start = try XCTUnwrap(formatter.date(from: "2024-01-01T00:00:00Z"))
        let occurrences = SolarTermCalculator.nextOccurrences(after: start, count: 24)
        let equinox = try XCTUnwrap(occurrences.first { $0.name == "春分" })
        let solstice = try XCTUnwrap(occurrences.first { $0.name == "冬至" })
        let expectedEquinox = try XCTUnwrap(formatter.date(from: "2024-03-20T03:06:00Z"))
        let expectedSolstice = try XCTUnwrap(formatter.date(from: "2024-12-21T09:20:00Z"))

        XCTAssertEqual(equinox.date.timeIntervalSince(expectedEquinox), 0, accuracy: 30 * 60)
        XCTAssertEqual(solstice.date.timeIntervalSince(expectedSolstice), 0, accuracy: 30 * 60)
    }

    func testSolarTermInstantHasStableAbsoluteTimeAcrossTimeZones() throws {
        let start = try XCTUnwrap(ISO8601DateFormatter().date(from: "2024-03-01T00:00:00Z"))
        let occurrence = try XCTUnwrap(SolarTermCalculator.nextOccurrences(after: start, count: 1).first)
        var shanghaiCalendar = Calendar(identifier: .gregorian)
        shanghaiCalendar.timeZone = shanghai
        var losAngelesCalendar = Calendar(identifier: .gregorian)
        losAngelesCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let shanghaiComponents = shanghaiCalendar.dateComponents([.year, .month, .day, .hour], from: occurrence.date)
        let losAngelesComponents = losAngelesCalendar.dateComponents([.year, .month, .day, .hour], from: occurrence.date)

        XCTAssertNotEqual(shanghaiComponents.day, losAngelesComponents.day)
        XCTAssertNotEqual(shanghaiComponents.hour, losAngelesComponents.hour)
    }
}
