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
    func testUnknownCommandFailsRatherThanProducingEmptyChart() async throws {
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        do {
            _ = try await bridge.request("{\"command\":\"not-a-command\"}")
            XCTFail("Unknown command must fail")
        } catch { XCTAssertFalse(error.localizedDescription.isEmpty) }
    }
}
