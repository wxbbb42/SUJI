import Foundation
import XCTest
@testable import SujiCore

final class BaziFrameworkIntegrationTests: XCTestCase {
    func testCurrentEngineAcrossTwelveBirthMonthsCompilesSourceBoundClaims() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let metadata = try JSONDecoder().decode(JSONValue.self, from: await bridge.request(#"{"command":"metadata"}"#))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/engineRevision", in: metadata) else { return XCTFail("Missing engine revision") }
        let now = Date(timeIntervalSince1970: 1_706_976_000)
        for month in 1...12 {
            let birth = BirthProfile(year: 1990, month: month, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
            let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: now, mode: "命理")
            let request: [String: Any] = ["command": "tool", "name": "get_domain", "id": "month-\(month)", "arguments": ["domain": "事业"], "now": ISO8601DateFormatter().string(from: now), "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))]
            let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            try EngineContract.validate(raw, command: "tool")
            let response = try JSONDecoder().decode(JSONValue.self, from: raw)
            let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: response))
            let receipt = ToolReceipt(callID: "month-\(month)", name: "get_domain", arguments: ["domain": "事业"], output: ReadingVerificationEvidence.encoded(result), context: context)
            let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: context), "Month \(month)")
            let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog)
            XCTAssertTrue(answer.text.contains("候选"))
            XCTAssertTrue(answer.text.contains("工程启发式"))
            XCTAssertTrue(answer.text.contains("不能证明两套计算都正确"))
            for claim in catalog.claims {
                XCTAssertFalse(claim.evidence.isEmpty, claim.id)
                for field in claim.evidence {
                    XCTAssertEqual(field.toolCallID, receipt.callID)
                    XCTAssertEqual(ReadingVerificationEvidence.pointer(field.pointer, in: result), field.value)
                }
            }
            // The actual backend accepts a maximum 32,000 UTF-16 code units per message.
            XCTAssertTrue(BaziFrameworkReading.selectionMessages(catalog: catalog, question: "扶抑用神与格局用神为什么不同").allSatisfy { ($0.content?.utf16.count ?? 0) <= 32_000 })
        }
    }
}
