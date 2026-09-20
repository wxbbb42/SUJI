import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class NatalDossierStoreTests: XCTestCase {
    private let birth = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 121.47)
    private func store(_ container: ModelContainer, user: String = "one") throws -> AppStore {
        try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: user)
    }
    func testReusesSavedChartAcrossLaunchesConcurrentRequestsAndNewQuestionTimes() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let first = try store(container)
        try await first.updateBirth(birth)
        let saved = try XCTUnwrap(first.natalDossier)
        let nextLaunch = try store(container)
        async let one = nextLaunch.ensureNatalDossier()
        async let two = nextLaunch.ensureNatalDossier()
        let values = try await [one, two]
        XCTAssertEqual(values.map(\.createdAt), [saved.createdAt, saved.createdAt])
        let request: [String: Any] = ["command": "tool", "name": "get_today_context", "arguments": [:], "birth": try nextLaunch.birthJSON(birth)]
        var before = request; before["now"] = "2024-02-04T04:00:00Z"
        var after = request; after["now"] = "2024-02-04T09:00:00Z"
        let earlier = try await nextLaunch.request(before)
        let later = try await nextLaunch.request(after)
        XCTAssertEqual(earlier["result"]["yearGanZhi"].text, "癸卯")
        XCTAssertEqual(later["result"]["yearGanZhi"].text, "甲辰")
        XCTAssertEqual(nextLaunch.natalDossier?.createdAt, saved.createdAt)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedState>()).filter { $0.key.hasPrefix("natal:") }.count, 1)
    }
    func testChangedBirthAndAccountNeverReusePreviousChart() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let old = try XCTUnwrap(app.natalDossier)
        var changed = birth; changed.hour = 10
        try await app.updateBirth(changed)
        XCTAssertNotEqual(app.natalDossier?.payload, old.payload)
        XCTAssertEqual(app.natalDossier?.birth, changed)
        try await app.switchAccount(from: "one", to: "two")
        XCTAssertNil(app.natalDossier)
        XCTAssertNil(app.state.birth)
        XCTAssertFalse(app.hasNatalDossier)
        try await app.updateBirth(birth)
        XCTAssertEqual(app.natalDossier?.ownerID, "user:two")
        try await app.switchAccount(from: "two", to: "one")
        XCTAssertEqual(app.natalDossier?.birth, changed)
        XCTAssertEqual(app.natalDossier?.ownerID, "user:one")
    }
    func testCorruptRecordRebuildsAndNotebookDeletionRemovesDossier() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let old = try XCTUnwrap(app.natalDossier)
        let record = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedState>()).first { $0.key == "natal:user:one" })
        record.data = Data("corrupt".utf8); try container.mainContext.save()
        let nextLaunch = try store(container)
        let rebuilt = try await nextLaunch.ensureNatalDossier()
        XCTAssertNotEqual(rebuilt.createdAt, old.createdAt)
        XCTAssertEqual(rebuilt.payload, old.payload)
        try nextLaunch.replaceNotebook(AppState())
        XCTAssertNil(nextLaunch.natalDossier)
        XCTAssertNil(nextLaunch.state.birth)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<SavedState>()).contains { $0.key.hasPrefix("natal:") })
    }
    func testNotebookArchiveContainsNoComputedDossier() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let archive = try ArchiveCodec.encode(app.state)
        XCTAssertFalse(String(decoding: archive, as: UTF8.self).contains("mingPan"))
        let imported = try ArchiveCodec.decode(archive)
        try app.replaceNotebook(imported)
        XCTAssertNil(app.natalDossier)
        XCTAssertEqual(app.state.birth, birth)
        let rebuilt = try await app.ensureNatalDossier()
        XCTAssertEqual(rebuilt.ownerID, "user:one")
    }
}
