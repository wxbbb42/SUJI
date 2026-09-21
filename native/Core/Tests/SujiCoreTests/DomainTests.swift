import XCTest
@testable import SujiCore

final class DomainTests: XCTestCase {
    func testDayKeyChangesAtLocalMidnightRatherThanUTCMidnight() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-18T16:00:00Z"))
        XCTAssertEqual(DayKey(date: date, timeZone: TimeZone(identifier: "Asia/Shanghai")!).rawValue, "2026-09-19")
        XCTAssertEqual(DayKey(date: date, timeZone: TimeZone(identifier: "America/Los_Angeles")!).rawValue, "2026-09-18")
    }

    func testRevealIsIdempotentAndRetainsOriginalContent() {
        var state = AppState()
        let day = DayKey(rawValue: "2026-09-19")
        state.reveal(day: day, quote: "慢下来", action: "喝一杯温水")
        state.reveal(day: day, quote: "被替换", action: "被替换")
        XCTAssertEqual(state.rituals.count, 1)
        XCTAssertEqual(state.rituals[0].quote, "慢下来")
    }

    func testJournalEditAndDeleteSurviveArchiveRoundTrip() throws {
        var state = AppState()
        let id = state.recordMood(day: "2026-09-19", mood: .calm, note: "散步")
        state.editJournal(id: id, mood: .tired, note: "需要休息")
        let data = try JSONEncoder().encode(state)
        var decoded = try JSONDecoder().decode(AppState.self, from: data)
        XCTAssertEqual(decoded.journal.first?.note, "需要休息")
        XCTAssertEqual(decoded.journal.first?.mood, .tired)
        decoded.deleteJournal(id: id)
        XCTAssertTrue(decoded.journal.isEmpty)
    }

    func testBirthInputRejectsInvalidCalendarDateAndLongitude() {
        XCTAssertThrowsError(try BirthProfile(year: 2025, month: 2, day: 29, hour: 10, minute: 0, gender: "女", city: "上海", longitude: 121.47).validated())
        XCTAssertThrowsError(try BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 181).validated())
        XCTAssertNoThrow(try BirthProfile(year: 2000, month: 2, day: 29, hour: 23, minute: 59, gender: "女", city: "上海", longitude: 121.47).validated())
    }
}
