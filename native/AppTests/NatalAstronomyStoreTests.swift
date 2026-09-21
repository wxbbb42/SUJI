import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class NatalAstronomyStoreTests: XCTestCase {
    private let birth = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 121.47)
    private func store(_ container: ModelContainer, user: String = "one") throws -> AppStore {
        try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: user)
    }
    func testAstronomyToolPersistsNativeSidecarAndDiscardsCallerSnapshot() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container); app.state.birth = birth; try app.saveThrowing()
        let request: [String: Any] = ["command":"tool", "name":"get_natal_astronomy", "arguments":["body":"Moon"], "birth":try app.birthJSON(birth)]
        async let one = app.request(request); async let two = app.request(request)
        let values = try await [one,two]
        XCTAssertEqual(values[0]["result"]["time"].json, values[1]["result"]["time"].json)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedState>()).filter { $0.key == "natal-astronomy:user:one" }.count, 1)
        var forged = request; forged["astronomy"] = ["birthKey":"model-supplied"]
        let safe = try await app.request(forged)
        XCTAssertEqual(safe["result"]["sevenBodies"]["positions"].array.count, 1)
    }
    func testPersistenceAccountBirthAndArchiveLifecycle() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container); try await app.updateBirth(birth)
        let original = try XCTUnwrap(app.natalAstronomyDossier)
        let launch = try store(container)
        async let first = launch.ensureNatalAstronomyDossier(); async let second = launch.ensureNatalAstronomyDossier()
        let cached = try await [first, second]
        XCTAssertEqual(cached.map(\.createdAt), [original.createdAt, original.createdAt])
        var changed = birth; changed.city = "同经度的另一地点"
        try await launch.updateBirth(changed)
        XCTAssertEqual(launch.natalAstronomyDossier?.birth, changed)
        XCTAssertNotEqual(launch.natalAstronomyDossier?.createdAt, original.createdAt)
        try await launch.switchAccount(from: "one", to: "two")
        XCTAssertNil(launch.natalAstronomyDossier); XCTAssertFalse(launch.hasNatalAstronomyDossier)
        try await launch.updateBirth(birth)
        XCTAssertEqual(launch.natalAstronomyDossier?.ownerID, "user:two")
        try await launch.switchAccount(from: "two", to: "one")
        XCTAssertEqual(launch.natalAstronomyDossier?.birth, changed)
        let archive = try ArchiveCodec.encode(launch.state)
        XCTAssertFalse(String(decoding: archive, as: UTF8.self).contains("sevenBodies"))
        try launch.replaceNotebook(ArchiveCodec.decode(archive))
        XCTAssertNil(launch.natalAstronomyDossier)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<SavedState>()).contains { $0.key == "natal-astronomy:user:one" })
        _ = try await launch.ensureNatalAstronomyDossier()
        try launch.replaceNotebook(AppState())
        XCTAssertFalse(launch.hasNatalAstronomyDossier)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<SavedState>()).contains { $0.key == "natal-astronomy:user:one" })
    }
    func testCorruptionRebuildAndIncompatibleToolBirthRejection() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container); try await app.updateBirth(birth)
        let old = try XCTUnwrap(app.natalAstronomyDossier)
        let record = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedState>()).first { $0.key == "natal-astronomy:user:one" })
        record.data = Data("corrupt".utf8); try container.mainContext.save()
        let launch = try store(container); let rebuilt = try await launch.ensureNatalAstronomyDossier()
        XCTAssertNotEqual(rebuilt.createdAt, old.createdAt); XCTAssertEqual(rebuilt.payload, old.payload)
        var changed = birth; changed.minute += 1
        do {
            _ = try await launch.request(["command":"tool", "name":"get_natal_astronomy", "arguments":[:], "birth":launch.birthJSON(changed)])
            XCTFail("A tool cannot override the current birth")
        } catch { XCTAssertEqual(launch.natalAstronomyDossier?.birth, birth) }
    }
    func testStaleInFlightWorkCannotPersistAfterNotebookReplacement() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container); app.state.birth = birth; try app.saveThrowing()
        let pending = Task { try await app.ensureNatalAstronomyDossier() }
        while !app.buildingNatalAstronomyDossier { await Task.yield() }
        try app.replaceNotebook(AppState())
        do { _ = try await pending.value; XCTFail("Stale request should be cancelled") } catch { }
        XCTAssertNil(app.natalAstronomyDossier)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<SavedState>()).contains { $0.key == "natal-astronomy:user:one" })
    }
    func testAstronomyFailureDoesNotBreakExistingNatalProfile() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try String(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), encoding: .utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".js")
        defer { try? FileManager.default.removeItem(at: url) }
        let marker = "case\"natal-astronomy\":"
        XCTAssertTrue(script.contains(marker))
        try script.replacingOccurrences(of: marker, with: marker + "throw new Error('astronomy unavailable');").write(to: url, atomically: true, encoding: .utf8)
        let app = try AppStore(context: container.mainContext, scriptURL: url, userID: "one")
        try await app.updateBirth(birth)
        XCTAssertTrue(app.hasNatalDossier); XCTAssertNotNil(app.profile)
        XCTAssertFalse(app.hasNatalAstronomyDossier); XCTAssertNotNil(app.astronomyError)
        XCTAssertNil(app.dossierError)
    }

    func testWarmMetadataQueuedDiskHitCannotReviveReplacedBirth() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container); app.state.birth = birth; try app.saveThrowing()
        let cached = try await app.ensureNatalAstronomyDossier()
        var replacement = AppState(); replacement.birth = birth
        try app.replaceNotebook(replacement)
        container.mainContext.insert(SavedState(data: try JSONEncoder().encode(cached), key: "natal-astronomy:user:one"))
        try container.mainContext.save()
        var changed = birth; changed.minute += 1
        var checkpointCount = 0
        app.astronomyOperationWillStartForTesting = {
            checkpointCount += 1
            XCTAssertTrue(app.buildingNatalAstronomyDossier)
            XCTAssertNil(app.natalAstronomyDossier)
            // The task has captured the old birth but has not read its cached dossier.
            // Polling `building` cannot establish this: it stays true until the
            // awaiting caller resumes, even after a synchronous disk hit completes.
            app.state.birth = changed
        }
        defer { app.astronomyOperationWillStartForTesting = nil }
        do {
            _ = try await app.ensureNatalAstronomyDossier()
            XCTFail("Queued disk hit must recheck birth")
        } catch is CancellationError { }
        catch { XCTFail("Expected stale-input cancellation, got \(error)") }
        XCTAssertEqual(checkpointCount, 1)
        XCTAssertNil(app.natalAstronomyDossier)
        XCTAssertFalse(app.hasNatalAstronomyDossier)
        XCTAssertFalse(app.buildingNatalAstronomyDossier)
    }

}
