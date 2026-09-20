import XCTest
@testable import SujiCore

final class ZiweiEvidenceTests: XCTestCase {
    private let raw = #"{"palace":"命宫","position":"戌","ganZhi":"丙戌","mainStars":[],"isShenGong":false,"emptyMainPalace":true,"relatedPalaces":[{"relation":"opposite","palace":"迁移宫","position":"辰","mainStars":["天机","天梁"],"starDetails":[{"name":"天机","group":"main","brightness":"利","sihua":["化禄"]}],"natalTransformations":[{"scope":"natal-year-stem","sourceStem":"乙","star":"天机","transformation":"化禄","targetPalace":"迁移宫","targetPosition":"辰","sourceId":"ziwei-sihua-selected-v1"}]}],"emptyPalaceReference":{"status":"opposite-reference","sourcePalace":"迁移宫","sourcePosition":"辰","mainStars":["天机","天梁"]},"natalYear":{"lunarYear":1995,"ganZhi":"乙亥","stem":"乙"},"method":{"calculationDate":"1995-08-15","dayBoundary":"zi-hour"},"ruleSources":[{"id":"ziwei-sihua-selected-v1","version":"1","limitations":["壬年异文"]}]}"#
    private func history(_ output: String, name: String = "get_ziwei_palace") -> [ChatMessage] {
        [.assistantToolCalls([.init(id:"z", name:name, arguments:[:])]), .toolResult(.init(callID:"z", output:output))]
    }
    func testPalaceIdentityScopesStarsAndTransformations() {
        let facts = Dictionary(uniqueKeysWithValues: ReadingVerificationEvidence.facts(history(raw)).map { ($0.factKey,$0) })
        XCTAssertEqual(facts["ziwei.命宫.mainStars"]?.value, .array([]))
        XCTAssertEqual(facts["ziwei.命宫.isShenGong"]?.value, .bool(false))
        XCTAssertEqual(facts["ziwei.迁移宫.mainStars"]?.pointer, "/relatedPalaces/0/mainStars")
        XCTAssertEqual(facts["ziwei.迁移宫.star1.brightness"]?.value, .string("利"))
        XCTAssertEqual(facts["ziwei.迁移宫.transformation1.scope"]?.value, .string("natal-year-stem"))
        XCTAssertEqual(facts["ziwei.迁移宫.transformation1.targetPosition"]?.pointer, "/relatedPalaces/0/natalTransformations/0/targetPosition")
        XCTAssertEqual(facts["ziwei.emptyPalaceReference.sourcePalace"]?.value, .string("迁移宫"))
        XCTAssertEqual(facts["ziwei.natalYear.stem"]?.value, .string("乙"))
        XCTAssertEqual(facts["ziwei.method.calculationDate"]?.value, .string("1995-08-15"))
        XCTAssertEqual(facts["ziwei.ruleSource1.version"]?.value, .string("1"))
    }
    func testAggregatedDomainKeepsNestedPointers() {
        let facts = ReadingVerificationEvidence.facts(history("{\"ziwei\":" + raw + "}", name:"get_domain"))
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.迁移宫.star1.name" }?.pointer, "/ziwei/relatedPalaces/0/starDetails/0/name")
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.ruleSource1.version" }?.pointer, "/ziwei/ruleSources/0/version")
    }
    func testOnlyNamedPalaceAssertionsBindToTheirOwnPalace() throws {
        let facts = ReadingVerificationEvidence.facts(history(raw))
        let ming = try XCTUnwrap(facts.first { $0.factKey == "ziwei.命宫.mainStars" })
        let opposite = try XCTUnwrap(facts.first { $0.factKey == "ziwei.迁移宫.mainStars" })
        XCTAssertTrue(ReadingVerificationAssertions.binds("天机", to:ming, in:"本命命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:opposite, in:"本命命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"命宫的对宫迁移宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"流年命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"如果命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"命宫主星不是天机"))
    }
    func testMalformedObjectValuesAreNotAdmittedAsStarFacts() {
        let facts = ReadingVerificationEvidence.facts(history(#"{"palace":"命宫","mainStars":[{"name":"假星"}],"starDetails":[{"name":{"prediction":"必定成功"}}],"relatedPalaces":[{"palace":"伪宫","mainStars":["假星"]}]}"#))
        XCTAssertFalse(facts.contains { $0.factKey.hasSuffix("mainStars") || $0.factKey.hasSuffix("star1.name") })
    }
}
