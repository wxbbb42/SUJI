import XCTest
@testable import SujiCore

final class NatalDossierTests: XCTestCase {
    private let birth = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 121.47)
    func testDossierRequiresBirthLocationAsWellAsDateAndTime() {
        var incomplete = birth; incomplete.city = "  "
        XCTAssertThrowsError(try incomplete.validated())
    }
    private func payload() async throws -> Data {
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        let b = try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))
        let request = try JSONSerialization.data(withJSONObject: ["command": "natal", "birth": b])
        return try await bridge.request(String(decoding: request, as: UTF8.self))
    }
    func testPersistedDossierReusesOnlySameOwnerBirthAndEngine() async throws {
        let saved = try NatalDossier(ownerID: "user:a", birth: birth, engineRevision: "bundle-one", payload: await payload())
        let restored = try JSONDecoder().decode(NatalDossier.self, from: JSONEncoder().encode(saved))
        XCTAssertTrue(restored.matches(ownerID: "user:a", birth: birth, engineRevision: "bundle-one"))
        XCTAssertEqual(restored.createdAt, saved.createdAt)
        XCTAssertFalse(restored.matches(ownerID: "user:b", birth: birth, engineRevision: "bundle-one"))
        XCTAssertFalse(restored.matches(ownerID: "user:a", birth: birth, engineRevision: "bundle-two"))
        var changed = birth; changed.minute += 1
        XCTAssertFalse(restored.matches(ownerID: "user:a", birth: changed, engineRevision: "bundle-one"))
    }
    func testCorruptedPayloadAndUnsupportedSchemaAreNotReusable() async throws {
        let saved = try NatalDossier(ownerID: "user:a", birth: birth, engineRevision: "one", payload: await payload())
        let encoded = try JSONEncoder().encode(saved)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["payload"] = Data("{}".utf8).base64EncodedString()
        let corrupted = try JSONDecoder().decode(NatalDossier.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(corrupted.matches(ownerID: "user:a", birth: birth, engineRevision: "one"))
        object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = 42
        let future = try JSONDecoder().decode(NatalDossier.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(future.matches(ownerID: "user:a", birth: birth, engineRevision: "one"))
        XCTAssertThrowsError(try NatalDossier(ownerID: "user:a", birth: birth, engineRevision: "one", payload: Data("{}".utf8)))
    }
}
