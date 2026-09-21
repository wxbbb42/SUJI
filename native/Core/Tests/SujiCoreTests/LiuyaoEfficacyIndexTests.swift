import XCTest
@testable import SujiCore

final class LiuyaoEfficacyIndexTests: XCTestCase {
    func testEveryTupleAndDictionaryIsIndexedAtItsOriginalPointerBeforeAndAfterPacking() throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = native.appendingPathComponent("Engine/validation/research-divination/efficacy-2026-09-21/swift-fixtures.json")
        let fixtures = try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:url))
        guard case let .array(cases) = fixtures else { return XCTFail("fixtures") }
        for fixture in cases {
            let root = try XCTUnwrap(ReadingVerificationEvidence.pointer("/reading",in:fixture))
            let raw = ReadingVerificationEvidence.encoded(root)
            let packed = LiuyaoConditionTransport.encodeLayouts(LiuyaoConditionTransport.encode(raw))
            func indexed(_ output:String) -> [String:JSONValue] {
                let history:[ChatMessage] = [.assistantToolCalls([.init(id:"original",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"original",output:output))]
                let facts = ReadingVerificationEvidence.facts(history).filter { $0.factKey.hasPrefix("liuyao.efficacy.") }
                for fact in facts {
                    XCTAssertEqual(fact.toolCallID,"original")
                    XCTAssertEqual(fact.value,ReadingVerificationEvidence.pointer(fact.pointer,in:root))
                }
                return Dictionary(uniqueKeysWithValues:facts.map { ($0.pointer,$0.value) })
            }
            let facts = indexed(raw)
            XCTAssertEqual(facts,indexed(packed))
            guard case let .object(report) = ReadingVerificationEvidence.pointer("/efficacy",in:root) else { return XCTFail("report") }
            // An indexed parent tuple covers all its cells, including empty
            // arrays; this checks coverage independently of the field list.
            func covered(_ value:JSONValue,_ path:String) {
                if let actual = facts[path] { XCTAssertEqual(actual,value);return }
                switch value {
                case let .object(fields):
                    XCTAssertFalse(fields.isEmpty,path)
                    for (key,value) in fields { covered(value,path+"/"+key) }
                case let .array(rows):
                    XCTAssertFalse(rows.isEmpty,path)
                    for (i,value) in rows.enumerated() { covered(value,path+"/\(i)") }
                default: XCTFail("Unindexed efficacy fact: "+path)
                }
            }
            covered(.object(report),"/efficacy")
        }
    }
}
