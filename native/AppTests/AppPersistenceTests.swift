import XCTest
import SwiftData
import SujiCore
import UIKit
@testable import Suji

@MainActor final class AppPersistenceTests: XCTestCase {
    func testEditorialFontIsBundledAndAvailable() throws {
        let font = try XCTUnwrap(UIFont(name: "NotoSerifSC-Regular", size: 24))
        XCTAssertEqual(font.familyName, "Noto Serif SC")
    }
    func testSavedJournalAndAccountIsolation() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script)
        store.revealToday(); store.revealToday()
        store.recordMood(.calm, note: "local-private-note")
        try store.saveThrowing()
        let restored = try AppStore(context: container.mainContext, scriptURL: script)
        XCTAssertEqual(restored.state.rituals.count, 1)
        XCTAssertEqual(restored.state.journal.first?.note, "local-private-note")
        try await restored.switchAccount(from: nil, to: "test-user")
        XCTAssertTrue(restored.state.journal.isEmpty)
        XCTAssertEqual(restored.aiKeyName, "ai-key:user:test-user")
        restored.recordMood(.bright, note: "account-private-note")
        try await restored.switchAccount(from: "test-user", to: nil)
        XCTAssertEqual(restored.state.journal.map(\.note), ["local-private-note"])
        try await restored.switchAccount(from: nil, to: "test-user")
        XCTAssertEqual(restored.state.journal.map(\.note), ["account-private-note"])
    }
    func testSignedSimulatorKeychain() throws {
        let name = "test-" + UUID().uuidString
        defer { try? KeychainStore.write(nil, name: name) }
        try KeychainStore.write("test-only-not-a-real-credential", name: name)
        XCTAssertEqual(try KeychainStore.read(name), "test-only-not-a-real-credential")
        try KeychainStore.write(nil, name: name)
        XCTAssertNil(try KeychainStore.read(name))
    }
    func testWidgetSnapshotContainsOnlyDailyContent() throws {
        let now = Date()
        try WidgetSnapshotService.publish(day: DayKey(date: now), date: now, lunar: "测试农历", solarTerm: nil, quote: "测试日签", action: "散步", isRevealed: true)
        let group = try XCTUnwrap(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.suji.native"))
        let data = try Data(contentsOf: group.appendingPathComponent("widget-snapshot.json"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["quote"] as? String, "测试日签")
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "day", "date", "generatedAt", "lunar", "quote", "action", "isRevealed"])
    }

    func testNotificationRouteRetainsColdLaunchRequestUntilConsumed() {
        let route = NotificationRoute()

        route.enqueueToday()
        XCTAssertTrue(route.hasPendingTodayRequest)
        XCTAssertTrue(route.consumeToday())
        XCTAssertFalse(route.hasPendingTodayRequest)
        XCTAssertFalse(route.consumeToday())

        route.enqueueToday()
        route.enqueueToday()
        XCTAssertTrue(route.hasPendingTodayRequest)
        XCTAssertTrue(route.consumeToday())
        XCTAssertFalse(route.hasPendingTodayRequest)
    }
}
