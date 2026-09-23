import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Explicitly synthetic, in-memory records. No signed-in session or model calls.
@MainActor final class NatalReadingStoreTests: XCTestCase {
    private let birth = BirthProfile(year: 1988, month: 4, day: 9, hour: 6, minute: 20, gender: "女", city: "合成甲", longitude: 116.4)
    private func makeStore(_ container: ModelContainer, user: String = "report-synthetic-a") throws -> AppStore {
        try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: user)
    }
    private func reports(_ store: AppStore) async throws -> [NatalReadingReport] {
        let birth = try XCTUnwrap(store.state.birth)
        let natal = try await store.ensureNatalDossier()
        let astronomy = try await store.ensureNatalAstronomyDossier()
        return try NatalReadingCompiler.natal(dossier: natal, ownerID: store.scopeKey, birth: birth, engineRevision: store.engineRevision)
            + NatalReadingCompiler.astronomy(dossier: astronomy, ownerID: store.scopeKey, birth: birth, engineRevision: store.engineRevision, enginePayloadRevision: astronomy.enginePayloadRevision)
    }
    func testReportsRebuildIdenticallyFromSavedAndImportedBirthWithoutModel() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let first = try makeStore(container)
        try await first.updateBirth(birth)
        let before = try await reports(first)
        XCTAssertEqual(before.map(\.system), [.bazi, .ziwei, .mansions, .qizheng])
        let reloaded = try makeStore(container)
        let restored = try await reports(reloaded)
        XCTAssertEqual(before, restored)
        let archive = try ArchiveCodec.encode(reloaded.state)
        XCTAssertFalse(String(decoding: archive, as: UTF8.self).contains("natal-structure-reading"))
        try reloaded.replaceNotebook(ArchiveCodec.decode(archive))
        XCTAssertNil(reloaded.natalDossier)
        let rebuilt = try await reports(reloaded)
        XCTAssertEqual(before, rebuilt)
    }
    func testEditedBirthAndAccountSwitchCannotReuseOldReportIdentity() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try makeStore(container)
        try await store.updateBirth(birth)
        let before = try await reports(store)
        let old = try XCTUnwrap(store.natalDossier)
        var changed = birth; changed.hour = 15
        try await store.updateBirth(changed)
        let edited = try await reports(store)
        XCTAssertTrue(zip(before, edited).allSatisfy { $0.id != $1.id })
        XCTAssertNotEqual(before[0].entries, edited[0].entries)
        XCTAssertThrowsError(try NatalReadingCompiler.natal(dossier: old, ownerID: store.scopeKey, birth: changed, engineRevision: store.engineRevision))
        let revision = store.scopeRevision
        try await store.switchAccount(from: "report-synthetic-a", to: "report-synthetic-b")
        XCTAssertNil(store.state.birth)
        XCTAssertNil(store.natalDossier)
        XCTAssertNotEqual(revision, store.scopeRevision)
        XCTAssertThrowsError(try NatalReadingCompiler.natal(dossier: old, ownerID: store.scopeKey, birth: birth, engineRevision: store.engineRevision))
        try await store.updateBirth(birth)
        let other = try await reports(store)
        XCTAssertTrue(zip(before, other).allSatisfy { $0.snapshotID != $1.snapshotID })
        try await store.switchAccount(from: "report-synthetic-b", to: "report-synthetic-a")
        let returned = try await reports(store)
        XCTAssertEqual(edited, returned)
    }
}
