import XCTest
@testable import SujiCore

final class BaziPatternConditionTests: XCTestCase {
    func testAbsentExposedRescueEvidenceSurvivesDocumentPersistence() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let raw = try await bridge.request(#"{"command":"tool","name":"get_domain","arguments":{"domain":"事业"},"now":"2026-09-20T04:00:00Z","birth":{"year":1990,"month":1,"day":15,"hour":10,"minute":0,"gender":"女","longitude":120}}"#)
        let envelope = try JSONDecoder().decode(JSONValue.self,from:raw)
        let output = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        let path = "/bazi/patternAnalysis/conditionalEvidence/rescueCandidates"
        XCTAssertEqual(ReadingVerificationEvidence.pointer(path,in:output),.array([]))
        let context = try ToolContext(birth:nil,engineRevision:"pattern-absence-test",referenceDate:Date(timeIntervalSince1970:1_789_920_000),mode:"命理")
        let receipt = ToolReceipt(callID:"absence",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(output),context:context)
        let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts:[receipt],context:context))
        let pattern = try XCTUnwrap(catalog.claims.first { $0.id == "pattern" })
        XCTAssertTrue(pattern.text.contains("未列透干救应候选"))
        XCTAssertTrue(pattern.evidence.contains { $0.pointer == path && $0.value == .array([]) && $0.toolCallID == "absence" })
        let answer = BaziFrameworkReading.render(selection:nil,catalog:catalog,focus:.pattern)
        let document = ReadingDocument(catalog:catalog,answer:answer,sourceUserID:UUID(),focus:.pattern)
        let saved = try JSONDecoder().decode(ReadingDocument.self,from:JSONEncoder().encode(document))
        XCTAssertTrue(saved.isValid)
        let section = try XCTUnwrap(saved.sections.first { $0.id == "pattern" })
        XCTAssertTrue(section.evidence.contains { $0.pointer == path && $0.value == .array([]) && $0.toolCallID == "absence" })
    }

    func testFrameworkExplainsConditionalRescueAndRejectsWrongObjectOrSource() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let raw = try await bridge.request(#"{"command":"tool","name":"get_domain","arguments":{"domain":"事业"},"now":"2026-09-20T04:00:00Z","birth":{"year":1993,"month":6,"day":8,"hour":13,"minute":30,"gender":"男","longitude":120}}"#)
        let envelope = try JSONDecoder().decode(JSONValue.self,from:raw)
        let output = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        let context = try ToolContext(birth:nil,engineRevision:"pattern-conditions-test",referenceDate:Date(timeIntervalSince1970:1_789_920_000),mode:"命理")
        func catalog(_ result:JSONValue)->BaziFrameworkReading.Catalog? {
            let receipt = ToolReceipt(callID:"pattern",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(result),context:context)
            return BaziFrameworkReading.catalog(receipts:[receipt],context:context)
        }
        let complete = try XCTUnwrap(catalog(output))
        let pattern = try XCTUnwrap(complete.claims.first { $0.id == "pattern" })
        XCTAssertTrue(pattern.text.contains("月干戊合年干癸"),pattern.text)
        XCTAssertTrue(pattern.text.contains("效力未定"))
        XCTAssertTrue(pattern.evidence.contains { $0.pointer.contains("/conditionalEvidence/rescueCandidates/") })
        for (path,value):(String,JSONValue) in [
            ("/bazi/patternAnalysis/conditionalEvidence/rescueCandidates/0/remedyContext","/stems/3"),
            ("/bazi/patternAnalysis/conditionalEvidence/rescueCandidates/0/effectiveness","established"),
            ("/bazi/patternAnalysis/conditionalEvidence/sources/0/sha256","unverified"),
        ] { XCTAssertNil(catalog(replacing(output,path:path,with:value)),path) }
    }

    private func replacing(_ root:JSONValue,path:String,with replacement:JSONValue)->JSONValue {
        func set(_ value:JSONValue,_ segments:ArraySlice<String>)->JSONValue {
            guard let head = segments.first else { return replacement }
            if case var .object(object) = value,let child = object[head] { object[head] = set(child,segments.dropFirst());return .object(object) }
            if case var .array(items) = value,let i = Int(head),items.indices.contains(i) { items[i] = set(items[i],segments.dropFirst());return .array(items) }
            XCTFail("Missing mutation path");return value
        }
        return set(root,path.split(separator:"/").map(String.init)[...])
    }
    func testConditionalIndexKeepsOriginalPositionsSourcesAndUnresolvedEffectiveness() {
        let raw = #"{"bazi":{"patternAnalysis":{"conditionalEvidence":{"assessmentStatus":"conditions-only","outcomeEstablished":false,"stems":[{"position":0,"gan":"丁","constraints":[{"actorPosition":1,"actorGan":"癸","relation":"克","adjacent":true,"interveningPositions":[]}]},{"position":1,"gan":"癸","sameElementRoots":[{"position":3,"branch":"辰","gan":"癸","tier":"yu","sameStem":true}]}],"rescueCandidates":[{"triggerPosition":0,"remedyPosition":1,"relation":"克","effectiveness":"unresolved"}],"sources":[{"id":"ziping-helper-constraints-v1","document":"docs/source.md","sha256":"hash","quote":"所读摘录"}]}}}}"#
        let messages:[ChatMessage] = [.assistantToolCalls([.init(id:"pattern",name:"get_domain",arguments:["domain":"事业"])]),.toolResult(.init(callID:"pattern",output:raw))]
        let facts = Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map { ($0.factKey,$0) })
        XCTAssertEqual(facts["bazi.pattern.conditions.outcomeEstablished"]?.value,.bool(false))
        XCTAssertEqual(facts["bazi.pattern.conditions.stem2.root1.position"]?.value,.integer(3))
        XCTAssertEqual(facts["bazi.pattern.conditions.stem1.constraint1.actorGan"]?.pointer,"/bazi/patternAnalysis/conditionalEvidence/stems/0/constraints/0/actorGan")
        XCTAssertEqual(facts["bazi.pattern.conditions.rescue1.effectiveness"]?.value,.string("unresolved"))
        XCTAssertEqual(facts["bazi.pattern.conditions.source1.quote"]?.value,.string("所读摘录"))
    }
}
