import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Synthetic, in-memory profiles; never reaches a live account or the model backend.
@MainActor final class NatalIdentityRevisionTests: XCTestCase {
    private let birth = BirthProfile(year: 1988, month: 4, day: 9, hour: 6, minute: 20, gender: "女", city: "合成身份", longitude: 116.4)
    private func store(_ container: ModelContainer) throws -> AppStore {
        try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: "identity-synthetic-a")
    }
    // Reflection keeps the regression executable against the previous implementation.
    // A missing revision is a failing behavior assertion, not a compile failure.
    private func birthRevision(_ app: AppStore) throws -> UUID {
        try XCTUnwrap(Mirror(reflecting: app).children.first { $0.label == "_birthRevision" || $0.label == "birthRevision" }?.value as? UUID, "Confirmed birth operations require an independent generation token")
    }
    func testEveryConfirmedBirthRotatesIdentityEvenWhenValuesReturnToAWithoutChangingScope() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container), scope = app.scopeRevision
        app.recordMood(.calm, note: "synthetic-notebook-preserved")
        let initial = try birthRevision(app)
        try await app.updateBirth(birth)
        let first = try birthRevision(app)
        try await app.updateBirth(birth)
        let same = try birthRevision(app)
        var other = birth; other.hour = 14
        try await app.updateBirth(other)
        let changed = try birthRevision(app)
        try await app.updateBirth(birth)
        let returned = try birthRevision(app)
        XCTAssertEqual(Set([initial, first, same, changed, returned]).count, 5)
        XCTAssertEqual(app.scopeRevision, scope, "Birth edits must not trigger the scope observer that clears chat input")
        XCTAssertEqual(app.state.journal.first?.note, "synthetic-notebook-preserved")
        XCTAssertEqual(app.natalDossier?.birth, birth)
    }
    func testInvalidBirthDoesNotInvalidateValidNotebookAndAccountOrReplacementDoes() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let before = try birthRevision(app)
        var invalid = birth; invalid.month = 20
        do { try await app.updateBirth(invalid); XCTFail("Invalid birth must fail before changing the notebook") } catch { }
        XCTAssertEqual(try birthRevision(app), before)
        XCTAssertEqual(app.state.birth, birth)
        try await app.switchAccount(from: "identity-synthetic-a", to: "identity-synthetic-b")
        let switched = try birthRevision(app)
        XCTAssertNotEqual(before, switched)
        var replacement = AppState(); replacement.birth = birth
        try app.replaceNotebook(replacement)
        XCTAssertNotEqual(try birthRevision(app), switched)
    }
    func testSameBirthConfirmationCancelsAlreadyStartedProfileRead() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let original = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".js")
        defer { try? FileManager.default.removeItem(at: temporary) }
        // Delay only the first real natal computation, without replacing its result.
        let delay = """
        ;(function(){const run=SujiNative.run;let delayed=false;SujiNative.run=function(q,resolve,reject){
        if(JSON.parse(q).command==='natal'&&!delayed){delayed=true;const until=Date.now()+300;while(Date.now()<until){}}
        return run(q,resolve,reject);};})();
        """
        try (String(contentsOf: original, encoding: .utf8) + delay).write(to: temporary, atomically: true, encoding: .utf8)
        let app = try AppStore(context: container.mainContext, scriptURL: temporary, userID: "identity-synthetic-a")
        app.state.birth = birth; try app.saveThrowing()
        let stale = Task { try await app.request(["command": "profile", "birth": app.birthJSON(birth), "now": "2026-09-23T00:00:00Z"]) }
        while !app.buildingNatalDossier { await Task.yield() }
        try await app.updateBirth(birth)
        do { _ = try await stale.value; XCTFail("A pre-confirmation read must not become evidence for the later generation, even with identical birth values") }
        catch is CancellationError { }
        catch { XCTFail("Expected stale generation cancellation, got \(error)") }
        XCTAssertTrue(app.hasNatalDossier)
        XCTAssertEqual(app.natalDossier?.birth, birth)
    }
    func testCallerNatalSnapshotIsDiscardedForAlternateBirthRequest() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        app.state.birth = birth; try app.saveThrowing()
        var other = birth; other.hour = 14
        let raw = try JSONSerialization.data(withJSONObject: ["command": "natal", "birth": app.birthJSON(other)])
        let authentic = try await app.engine.request(String(decoding: raw, as: UTF8.self))
        var supplied = try XCTUnwrap(JSONSerialization.jsonObject(with: authentic) as? [String: Any])
        var personality = try XCTUnwrap(supplied["personality"] as? [String: Any])
        personality["coreTraits"] = ["caller-supplied-untrusted-reading"]
        supplied["personality"] = personality
        let result = try await app.request(["command": "profile", "birth": app.birthJSON(other), "natal": supplied, "now": "2026-09-23T00:00:00Z"])
        XCTAssertFalse(result["personality"]["coreTraits"].strings.contains("caller-supplied-untrusted-reading"), "Alternate profile calculations must not trust caller-supplied natal snapshots")
        XCTAssertEqual(app.state.birth, birth)
    }
    func testValidDigestWithWrongInnerPayloadRevisionIsRebuiltFromBundledEngine() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let original = try XCTUnwrap(app.natalDossier)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original.payload) as? [String: Any])
        object["engineRevision"] = String(repeating: "f", count: 64)
        let altered = try NatalDossier(ownerID: app.scopeKey, birth: birth, engineRevision: app.engineRevision, payload: JSONSerialization.data(withJSONObject: object))
        let record = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedState>()).first { $0.key == "natal:user:identity-synthetic-a" })
        record.data = try JSONEncoder().encode(altered); try container.mainContext.save()
        let reloaded = try store(container)
        let rebuilt = try await reloaded.ensureNatalDossier()
        let metadata = try await reloaded.request(["command": "metadata"])
        let restoredPayload = try XCTUnwrap(JSONSerialization.jsonObject(with: rebuilt.payload) as? [String: Any])
        XCTAssertEqual(restoredPayload["engineRevision"] as? String, metadata["engineRevision"].text)
        XCTAssertNotEqual(rebuilt.createdAt, altered.createdAt)
        XCTAssertEqual(rebuilt.payload, original.payload)
    }
}
