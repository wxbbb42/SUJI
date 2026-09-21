import XCTest
@testable import SujiCore

final class LiuyaoEfficacyTests: XCTestCase {
    private func fixtures() throws -> [(String, [String:Any])] {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url=native.appendingPathComponent("Engine/validation/research-divination/efficacy-2026-09-21/swift-fixtures.json")
        return try (JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [[String:Any]]).map{($0["name"] as! String,$0["reading"] as! [String:Any])}
    }
    private func render(_ root:[String:Any]) throws -> LiuyaoReferenceReading.Report? {
        let context=try ToolContext(birth:nil,engineRevision:"liuyao-efficacy-fixture-v1",referenceDate:ISO8601DateFormatter().date(from:"2026-09-21T04:00:00Z")!,mode:"起卦")
        let args:JSONValue=["question":"原文规则核对","questionType":"health","subject":"self","event":"原文规则核对","timeHorizon":"near"]
        let output=String(decoding:try JSONSerialization.data(withJSONObject:root,options:.withoutEscapingSlashes),as:UTF8.self)
        return LiuyaoReferenceReading.render(receipts:[.init(callID:"saved-original",name:"cast_liuyao",arguments:args,output:output,context:context)],context:context)
    }
    func testLiteralClassicalAndCounterconditionFixturesRenderWithOriginalEvidence() throws {
        for (name,root) in try fixtures() {
            let report=try XCTUnwrap(render(root),name)
            let evidence=report.sections.filter{$0.id.hasPrefix("efficacy-")}
            XCTAssertFalse(evidence.isEmpty,name)
            let json=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root))
            for section in evidence { for fact in section.evidence {
                XCTAssertEqual(fact.toolCallID,"saved-original")
                XCTAssertEqual(fact.value,ReadingVerificationEvidence.pointer(fact.pointer,in:json),name+fact.pointer)
            } }
        }
    }
    func testForgeriesOfDecisionsIndicesPathsObjectsAndSourcesAreRejected() throws {
        let original=try fixtures().first{$0.0=="endpoint-triads"}!.1
        XCTAssertNotNil(try render(original))
        for mutation in 0..<30 {
            var root=original,layer=root["efficacy"] as! [String:Any]
            var objects=layer["objects"] as! [[Any]],paths=layer["factPaths"] as! [[Any]],rows=layer["evidence"] as! [[Any]],decisions=layer["decisions"] as! [[Any]]
            var sources=root["ruleSources"] as! [[String:Any]]
            let source=sources.firstIndex{($0["id"] as? String)=="liuyao-efficacy-zengshan-v1"}!
            switch mutation {
            case 0: layer["methodVersion"]="forged"
            case 1: layer["sourceId"]="liuyao-triad-selected-v1"
            case 2: layer["outcomeEstablished"]=true
            case 3: layer["limitations"]=[]
            case 4: layer["evidenceLayout"]="unknown"
            case 5: layer["evidenceColumns"]=["factPathIndices","id"]
            case 6: paths[0]=["/lines/0/changed/wuXing",0]
            case 7: paths.append(paths[0])
            case 8: rows[0][1]=[-1]
            case 9: rows[0][1]=[paths.count]
            case 10: rows[0][1]=[0.5]
            case 11: rows[0][0]="forged-rule"
            case 12: rows.append(rows[0])
            case 13: rows[0].append("extra")
            case 14: objects[0][0]="/lines/1/changed"
            case 15: objects.removeLast()
            case 16: let i=objects[0][2] as! Int;decisions[i][0]="supported-unopposed";decisions[i][2]=[]
            case 17: let i=objects[0][4] as! Int;decisions[i][1]=[rows.count]
            case 18: let i=objects[0][3] as! Int;decisions[i][1]=[true]
            case 19: var s=layer["selection"] as! [String:Any];s["selectedCandidateId"]="original-1";layer["selection"]=s
            case 20: let t=layer["triads"] as! [[Any]];let i=t[0][1] as! Int;decisions[i][0]="formed"
            case 21: sources[source]["version"]="2"
            case 22: sources[source]["editionStatus"]="print-collated"
            case 23: var r=sources[source]["references"] as! [[String:Any]];r[0]["url"]="https://example.com";sources[source]["references"]=r
            case 24: var r=sources[source]["references"] as! [[String:Any]];r[6]["sha256"]="forged";sources[source]["references"]=r
            case 25: sources.remove(at:source)
            case 26: layer["selectedEffect"]=["status":"effective-under-selected-rule","conditions":[],"blockers":[]]
            case 27: paths.append([999,999])
            case 28: objects[0][5]=[];objects[0][6]=[]
            default: layer["assessmentStatus"]="established"
            }
            layer["objects"]=objects;layer["decisions"]=decisions;layer["factPaths"]=paths;layer["evidence"]=rows;root["efficacy"]=layer;root["ruleSources"]=sources
            XCTAssertNil(try render(root),"forgery \(mutation)")
        }
    }
    func testTupleColumnsDecisionIndicesAndCanonicalPointerMapping() throws {
        let raw=try fixtures()[3].1
        let json=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:raw))
        let pointers=try LiuyaoEfficacyEvidence.canonicalPointers(root:json)
        let decoded=try LiuyaoEfficacyEvidence.decodedReport(root:json)
        let canonical="/efficacy/objects/0/vitality/status",pointer=try XCTUnwrap(pointers[canonical])
        XCTAssertTrue(pointer.hasPrefix("/efficacy/states/"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer(pointer,in:json),ReadingVerificationEvidence.pointer("/objects/0/vitality/status",in:decoded))
        for mutation in 0..<16 {
            var root=raw,layer=root["efficacy"] as! [String:Any],objects=layer["objects"] as! [[Any]],decisions=layer["decisions"] as! [[Any]]
            switch mutation {
            case 0:layer["indexBase"]=1
            case 1:layer["objectColumns"]=["forged"]
            case 2:layer["calendarStrengthColumns"]=["forged"]
            case 3:layer["referenceColumns"]=["forged"]
            case 4:layer["triadColumns"]=["forged"]
            case 5:layer["decisionColumns"]=["conditions","status","blockers"]
            case 6:objects[0][2]=decisions.count
            case 7:objects[0].append([])
            case 8:decisions.append(decisions[0])
            case 9:decisions[0].append([])
            case 10:layer["states"]=(layer["states"] as! [String])+["unused-state"]
            case 11:layer["ruleIDs"]=(layer["ruleIDs"] as! [String])+["unused-rule"]
            case 12:layer["pathRoots"]=(layer["pathRoots"] as! [String])+["/unused"]
            case 13:layer["pathSuffixes"]=(layer["pathSuffixes"] as! [String])+["/unused"]
            case 14:layer["factPathColumns"]=["suffixIndex","rootIndex"]
            default:decisions[0][0]=(layer["states"] as! [String]).count
            }
            layer["objects"]=objects;layer["decisions"]=decisions;root["efficacy"]=layer
            XCTAssertNil(try render(root),"tuple forgery \(mutation)")
        }
    }
    func testAllSelectedSourceCoordinatesAreAuthenticated() throws {
        let original=try fixtures()[0].1
        for index in 0..<7 {for key in ["url","sha256"] {
            var root=original,sources=root["ruleSources"] as! [[String:Any]]
            let i=sources.firstIndex{($0["id"] as? String)=="liuyao-efficacy-zengshan-v1"}!
            var refs=sources[i]["references"] as! [[String:Any]];refs[index][key]="forged"
            sources[i]["references"]=refs;root["ruleSources"]=sources
            XCTAssertNil(try render(root),"source \(index) \(key)")
        }}
    }
    func testJointCandidateAndEfficacyRewriteCannotReplaceTheQuerent() throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url=native.appendingPathComponent("Engine/validation/research-divination/efficacy-2026-09-21/swift-joint-forgery.json")
        let root=try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:url))
        XCTAssertThrowsError(try LiuyaoEfficacyEvidence.sections(root:root,receiptID:"saved-original",sourcePaths:[]))
    }
    func testMissingEfficacySymmetryAndLegacyReceipt() throws {
        var root=try fixtures()[0].1
        root.removeValue(forKey:"efficacy")
        XCTAssertNil(try render(root))
        root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-efficacy-zengshan-v1"}
        XCTAssertNotNil(try render(root))
    }
}
