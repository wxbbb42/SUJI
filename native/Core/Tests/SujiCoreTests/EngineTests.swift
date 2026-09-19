import XCTest
@testable import SujiCore

final class EngineTests: XCTestCase {
    private var resources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
    }
    func testJavaScriptCoreMatchesNodeForCalendarProfileQimenAndCalibration() async throws {
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("engine-fixtures.json"))) as! [[String: Any]]
        for fixture in fixtures {
            let request = try JSONSerialization.data(withJSONObject: fixture["request"]!)
            let result = try await bridge.request(String(decoding: request, as: UTF8.self))
            try EngineContract.validate(result, command: (fixture["request"] as! [String: Any])["command"] as! String)
            let actual = try JSONSerialization.jsonObject(with: result) as! NSObject
            XCTAssertTrue(actual.isEqual(fixture["result"]!), "Runtime parity failed: \(differences(actual, fixture["result"]!, path: "result").prefix(8))")
        }
    }
    private func differences(_ a: Any, _ b: Any, path: String) -> [String] {
        if let a = a as? [String: Any], let b = b as? [String: Any] {
            return Set(a.keys).union(b.keys).sorted().flatMap { differences(a[$0] ?? NSNull(), b[$0] ?? NSNull(), path: path + "." + $0) }
        }
        if let a = a as? [Any], let b = b as? [Any], a.count == b.count {
            return a.indices.flatMap { differences(a[$0], b[$0], path: path + "[\($0)]") }
        }
        return (a as? NSObject)?.isEqual(b) == true ? [] : ["\(path): native=\(a) node=\(b)"]
    }
    func testMalformedChartsFailContractInsteadOfBecomingBlankDocuments() throws {
        let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: resources.appendingPathComponent("engine-fixtures.json"))) as! [[String: Any]]
        let profile = fixtures.first { ($0["request"] as? [String: Any])?["command"] as? String == "profile" }!["result"] as! [String: Any]
        var missingPillars = profile
        var mingPan = profile["mingPan"] as! [String: Any]
        mingPan.removeValue(forKey: "siZhu"); missingPillars["mingPan"] = mingPan
        XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: missingPillars), command: "profile"))
        var missingPalaces = profile
        var ziwei = profile["ziweiPan"] as! [String: Any]
        ziwei["palaces"] = []; missingPalaces["ziweiPan"] = ziwei
        XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: missingPalaces), command: "profile"))
        var wrongYunStatus = profile["forecast"] as! [String: Any]
        wrongYunStatus["daYunStatus"] = "before-start"
        XCTAssertThrowsError(try EngineContract.validate(JSONSerialization.data(withJSONObject: ["forecast": wrongYunStatus]), command: "forecast"))
    }
    func testUnknownCommandFailsRatherThanProducingEmptyChart() async throws {
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        do {
            _ = try await bridge.request("{\"command\":\"not-a-command\"}")
            XCTFail("Unknown command must fail")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }

    func testOnlyTheSixtySexagenaryPairsAreAccepted() throws {
        let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
        let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
        let legal = Set((0..<60).map { stems[$0 % 10] + branches[$0 % 12] })
        for stem in stems {
            for branch in branches {
                let data = try JSONSerialization.data(withJSONObject: [
                    "firstDayPillar": ["gan": stem, "zhi": branch],
                    "secondDayPillar": ["gan": "甲", "zhi": "子"],
                ])
                if legal.contains(stem + branch) {
                    XCTAssertNoThrow(try EngineContract.validate(data, command: "relationship"), stem + branch)
                } else {
                    XCTAssertThrowsError(try EngineContract.validate(data, command: "relationship"), stem + branch)
                }
            }
        }
    }

    func testActiveForecastRequiresValidPeriodContainingReferenceInstant() throws {
        let period: [String: Any] = ["ganZhi": ["gan": "庚", "zhi": "辰"], "startDate": "2023-01-01T00:00:00Z", "endDate": "2033-01-01T00:00:00Z", "period": "32–41"]
        func validate(_ candidate: [String: Any], at reference: String) throws {
            let data = try JSONSerialization.data(withJSONObject: ["forecast": ["year": 2024, "daYun": candidate, "daYunStatus": "active", "referenceDate": reference]])
            try EngineContract.validate(data, command: "forecast")
        }
        XCTAssertNoThrow(try validate(period, at: "2023-01-01T00:00:00Z"))
        XCTAssertNoThrow(try validate(period, at: "2032-12-31T23:59:59Z"))
        XCTAssertThrowsError(try validate(period, at: "2022-12-31T23:59:59Z"))
        XCTAssertThrowsError(try validate(period, at: "2033-01-01T00:00:00Z"))
        var invalid = period
        invalid["ganZhi"] = ["gan": "甲", "zhi": "丑"]
        XCTAssertThrowsError(try validate(invalid, at: "2024-02-04T04:00:00Z"))
        invalid = period; invalid["startDate"] = "broken"
        XCTAssertThrowsError(try validate(invalid, at: "2024-02-04T04:00:00Z"))
        invalid = period; invalid["endDate"] = "2020-01-01T00:00:00Z"
        XCTAssertThrowsError(try validate(invalid, at: "2024-02-04T04:00:00Z"))
    }
}
