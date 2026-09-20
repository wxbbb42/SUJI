import XCTest
@testable import SujiCore

final class NatalAstronomyDossierTests: XCTestCase {
    private let birth = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 121.47)
    private func fixture() throws -> [String: Any] {
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("engine-fixtures.json"))) as! [[String: Any]]
        return fixtures.first { ($0["request"] as? [String: Any])?["command"] as? String == "natal-astronomy" }!["result"] as! [String: Any]
    }
    func testAstronomyContractRejectsMissingAndForgedTimeOrCoordinateFields() throws {
        XCTAssertThrowsError(try EngineContract.validate(Data("{}".utf8), command: "natal-astronomy"))
        let original = try fixture()
        XCTAssertNoThrow(try EngineContract.validate(JSONSerialization.data(withJSONObject: original), command: "natal-astronomy"))
        for field in ["julianDayUT", "julianDayTT", "deltaTSeconds"] {
            var altered = original; var time = original["time"] as! [String: Any]
            time[field] = (time[field] as! Double) + 1; altered["time"] = time
            XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: altered), command: "natal-astronomy"), field)
        }
        var altered = original; var seven = original["sevenBodies"] as! [String: Any]
        var positions = seven["positions"] as! [[String: Any]]
        positions[0]["longitudeDegrees"] = 360; seven["positions"] = positions; altered["sevenBodies"] = seven
        XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: altered), command: "natal-astronomy"))
        altered = original; altered["mansions"] = ["ready": true]
        XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: altered), command: "natal-astronomy"))
    }
    func testDossierBindsFullProfileOwnerActualBundleAndPayloadRevisionAcrossPersistence() throws {
        let object = try fixture(), source = object["engineRevision"] as! String, bundle = String(repeating: "b", count: 64)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let saved = try NatalAstronomyDossier(ownerID: "user:a", birth: birth, engineRevision: bundle, enginePayloadRevision: source, payload: data)
        let restored = try JSONDecoder().decode(NatalAstronomyDossier.self, from: JSONEncoder().encode(saved))
        XCTAssertTrue(restored.matches(ownerID: "user:a", birth: birth, engineRevision: bundle, enginePayloadRevision: source))
        XCTAssertFalse(restored.matches(ownerID: "user:b", birth: birth, engineRevision: bundle, enginePayloadRevision: source))
        XCTAssertFalse(restored.matches(ownerID: "user:a", birth: birth, engineRevision: String(repeating: "c", count: 64), enginePayloadRevision: source))
        XCTAssertFalse(restored.matches(ownerID: "user:a", birth: birth, engineRevision: bundle, enginePayloadRevision: String(repeating: "c", count: 64)))
        var changed = birth; changed.city = "北京"
        XCTAssertFalse(restored.matches(ownerID: "user:a", birth: changed, engineRevision: bundle, enginePayloadRevision: source))
        changed = birth; changed.minute += 1
        XCTAssertThrowsError(try NatalAstronomyDossier(ownerID: "user:a", birth: changed, engineRevision: bundle, enginePayloadRevision: source, payload: data))
        XCTAssertThrowsError(try NatalAstronomyDossier(ownerID: "user:a", birth: birth, engineRevision: bundle, enginePayloadRevision: String(repeating: "c", count: 64), payload: data))
        var encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as! [String: Any]
        encoded["payload"] = Data("{}".utf8).base64EncodedString()
        let corrupt = try JSONDecoder().decode(NatalAstronomyDossier.self, from: JSONSerialization.data(withJSONObject: encoded))
        XCTAssertFalse(corrupt.matches(ownerID: "user:a", birth: birth, engineRevision: bundle, enginePayloadRevision: source))
    }
    func testPoliciesCoordinatesIdentityAndMansionMembershipRejectMutations() throws {
        let original = try fixture()
        func rejected(_ change: (inout [String: Any]) -> Void) throws {
            var value = original; change(&value)
            XCTAssertThrowsError(try NatalAstronomyPayload.validated(JSONSerialization.data(withJSONObject: value)))
        }
        try rejected { $0["birthKey"] = "[1995,8,15,19,31,\"女\",121.47,\"Asia/Shanghai\"]" }
        try rejected { var t = $0["time"] as! [String: Any]; t["interpretation"] = "historical-zone"; $0["time"] = t }
        try rejected { var m = $0["sevenBodies"] as! [String: Any]; m["dependencyVersions"] = ["ephemeris":"other"]; $0["sevenBodies"] = m }
        try rejected { var m = $0["mansions"] as! [String: Any]; m["sourceIDs"] = ["made-up"]; $0["mansions"] = m }
        try rejected { var m = $0["mansions"] as! [String: Any]; var p = m["positions"] as! [[String: Any]]; p[1]["boundaryStatus"] = "certain"; m["positions"] = p; $0["mansions"] = m }
        try rejected { var m = $0["mansions"] as! [String: Any]; var p = m["positions"] as! [[String: Any]]; p[1]["entryDegrees"] = 99; m["positions"] = p; $0["mansions"] = m }
        try rejected { var m = $0["mansions"] as! [String: Any]; var b = m["boundaries"] as! [[String: Any]]; b[0]["hip"] = 1; m["boundaries"] = b; $0["mansions"] = m }
    }

}
