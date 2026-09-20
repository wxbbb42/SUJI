import XCTest
@testable import SujiCore

final class NatalAstronomyEvidenceTests: XCTestCase {
    func testAstronomyToolIsAllowedAndIndexesBodyIdentityAtOriginalPointers() {
        XCTAssertTrue(ToolOrchestrator.allowedToolNames.contains("get_natal_astronomy"))
        let output = #"{"time":{"instantUTC":"1995-08-15T11:30:00.000Z","interpretation":"fixed-utc-plus-8-v1"},"sevenBodies":{"methodVersion":"astronomy-engine-2.1.19-geocentric-v1","positions":[{"body":"Moon","longitudeDegrees":12.5,"rightAscensionDegrees":11.25,"declinationDegrees":-4.5}]},"mansions":null,"unsupported":["four-residuals","life-degree"]}"#
        let messages: [ChatMessage] = [.assistantToolCalls([.init(id:"astro",name:"get_natal_astronomy",arguments:["body":"Moon"])]),.toolResult(.init(callID:"astro",output:output))]
        let facts = ReadingVerificationEvidence.facts(messages)
        let longitude = facts.first { $0.factKey == "astronomy.body.Moon.longitudeDegrees" }
        XCTAssertEqual(longitude?.pointer,"/sevenBodies/positions/0/longitudeDegrees")
        XCTAssertEqual(longitude?.value,.double(12.5))
        XCTAssertEqual(longitude?.toolCallID,"astro")
        XCTAssertEqual(facts.first { $0.factKey == "astronomy.mansions" }?.value,.null)
        XCTAssertTrue(facts.contains { $0.factKey == "astronomy.unsupported" })
        XCTAssertFalse(facts.contains { $0.factKey.contains("Sun") })
    }
}
