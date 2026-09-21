import XCTest
@testable import SujiCore

final class LiuyaoEventAssessmentTests: XCTestCase {
    private func fixtures() throws -> [(String,[String:Any])] {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data=try Data(contentsOf:native.appendingPathComponent("Engine/validation/research-divination/event-2026-09-21/swift-fixtures.json"))
        return try (JSONSerialization.jsonObject(with:data) as! [[String:Any]]).map{($0["name"] as! String,$0["reading"] as! [String:Any])}
    }
    private func render(_ root:[String:Any],packed:Bool=false) throws -> LiuyaoReferenceReading.Report? {
        let context=try ToolContext(birth:nil,engineRevision:"liuyao-event-fixture-v1",referenceDate:ISO8601DateFormatter().date(from:"2026-09-21T04:00:00Z")!,mode:"起卦")
        let raw=String(decoding:try JSONSerialization.data(withJSONObject:root,options:.withoutEscapingSlashes),as:UTF8.self)
        let output=packed ? try CastReceiptStorage.encode(raw) : raw
        let receipt=ToolReceipt(callID:"event-original",name:"cast_liuyao",arguments:[:],output:output,context:context)
        if packed {
            var entry=ConversationEntry(role:"user",text:"原文规则核对");entry.toolReceipts=[receipt];entry.toolContext=context
            let restored=try JSONDecoder().decode(ConversationEntry.self,from:JSONEncoder().encode(entry))
            let receipts=try XCTUnwrap(restored.toolReceipts)
            return LiuyaoReferenceReading.render(receipts:receipts,context:context)
        }
        return LiuyaoReferenceReading.render(receipts:[receipt],context:context)
    }
    func testSourceDirectionsRenderAndReplayWithEveryEvidencePointerIntact() throws {
        for (name,root) in try fixtures() {
            let direct=try XCTUnwrap(render(root),name),saved=try XCTUnwrap(render(root,packed:true),name)
            XCTAssertEqual(direct.text,saved.text,name)
            let sections=saved.sections.filter{$0.id.hasPrefix("event-")}
            XCTAssertFalse(sections.isEmpty,name)
            XCTAssertTrue(sections[0].text.contains("条文"),name)
            let json=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root))
            for section in sections {for fact in section.evidence {
                XCTAssertEqual(fact.toolCallID,"event-original")
                XCTAssertEqual(fact.value,ReadingVerificationEvidence.pointer(fact.pointer,in:json),name+fact.pointer)
            }}
        }
    }
    func testTamperedDirectionChainEvidenceSelectionAndSourceRejected() throws {
        let original=try fixtures().first{$0.0=="chain"}!.1
        for mutation in 0..<13 {
            var root=original,layer=root["eventAssessment"] as! [String:Any],candidates=layer["candidates"] as! [[String:Any]]
            var sources=root["ruleSources"] as! [[String:Any]]
            let source=sources.firstIndex{($0["id"] as? String)=="liuyao-event-zengshan-v1"}!
            switch mutation {
            case 0:layer["outcome"]="adverse-under-selected-rule"
            case 1:layer["outcomeEstablished"]=true
            case 2:layer["ruleOutcomeEstablished"]=false
            case 3:layer["eventObjectPaths"]=["/lines/1"]
            case 4:candidates[0]["transmissions"]=[]
            case 5:candidates[0]["conditions"]=[]
            case 6:layer["selectionStatus"]="candidate-invariant-direction"
            case 7:layer["methodVersion"]="forged"
            case 8:layer["limitations"]=[]
            case 9:sources[source]["scope"]="guaranteed prediction"
            case 10:var refs=sources[source]["references"] as! [[String:Any]];refs[0]["quote"]="伪造";sources[source]["references"]=refs
            case 11:var refs=sources[source]["references"] as! [[String:Any]];refs[0]["sha256"]="forged";sources[source]["references"]=refs
            default:candidates[0]["blockers"]=[["ruleId":"forged","factPaths":["/does-not-exist"]]]
            }
            layer["candidates"]=candidates;root["eventAssessment"]=layer;root["ruleSources"]=sources
            XCTAssertNil(try render(root),"forgery \(mutation)")
        }
    }
    func testSymmetricAbsencePreservesOldReceiptsAndCannotHideNewVerdicts() throws {
        var root=try fixtures()[0].1
        root.removeValue(forKey:"eventAssessment")
        XCTAssertNil(try render(root))
        root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-event-zengshan-v1"}
        XCTAssertNotNil(try render(root))
        root=try fixtures()[0].1
        root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-event-zengshan-v1"}
        XCTAssertNil(try render(root))
    }
    func testInvalidOrUnusedEvidenceDictionaryEntriesCannotHideConditions() throws {
        let original=try fixtures().first{$0.0=="chain"}!.1
        for mutation in 0..<11 {
            var root=original,layer=root["eventAssessment"] as! [String:Any],rows=layer["evidence"] as! [[Any]]
            switch mutation {
            case 0:layer["indexBase"]=1
            case 1:layer["evidenceLayout"]="unknown"
            case 2:layer["evidenceColumns"]=["paths","rule"]
            case 3:rows[0][0] = -1
            case 4:rows[0][1] = [0.5]
            case 5:rows[0][1] = [99999]
            case 6:rows[0].append(0)
            case 7:rows.append(rows[0])
            case 8:layer["ruleIDs"]=(layer["ruleIDs"] as! [String])+["unused"]
            case 9:layer["factPaths"]=(layer["factPaths"] as! [String])+["/castTime"]
            default:var candidates=layer["candidates"] as! [[String:Any]];candidates[0]["conditions"]=[true];layer["candidates"]=candidates
            }
            layer["evidence"]=rows;root["eventAssessment"]=layer
            XCTAssertNil(try render(root),"dictionary forgery \(mutation)")
        }
    }

}
