import XCTest
@testable import SujiCore

final class QimenSelectionEvidenceTests:XCTestCase {
    private struct Vector:Decodable {let focus:String;let arguments:JSONValue;let chart:JSONValue}
    private func vectors()throws->[Vector] {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode([Vector].self,from:Data(contentsOf:native.appendingPathComponent("Engine/validation/research-divination/selection-2026-09-21/native-vectors.json")))
    }
    private func receipt(_ v:Vector)throws->(ToolReceipt,ToolContext) {
        let context=try ToolContext(birth:nil,engineRevision:"selection-fixture-v1",referenceDate:ISO8601DateFormatter().date(from:"2004-05-29T04:00:00Z")!,mode:"起卦")
        return (ToolReceipt(callID:"specialized-cast",name:"setup_qimen",arguments:v.arguments,output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(v.chart)),context:context),context)
    }
    func testAllTwelveRolesAreIndependentlyCheckedDisplayedAndArchived()throws {
        for v in try vectors() {
            let evidence=try XCTUnwrap(QimenSelectionEvidence.read(root:v.chart,arguments:v.arguments),v.focus)
            XCTAssertTrue(evidence.text.contains("专门取用"));XCTAssertTrue(evidence.text.contains("事件成败仍未裁决"))
            for p in evidence.evidencePaths {XCTAssertNotNil(ReadingVerificationEvidence.pointer(p,in:v.chart),p)}
            let (saved,context)=try receipt(v)
            let report=try XCTUnwrap(QimenReferenceReading.render(receipts:[saved],context:context),v.focus)
            XCTAssertTrue(report.sections.contains{$0.id=="specialized-selection"},v.focus)
            var entry=ConversationEntry(role:"user",text:"明确取用");entry.toolReceipts=[saved];entry.toolContext=context
            let restored=try JSONDecoder().decode(ConversationEntry.self,from:JSONEncoder().encode(entry))
            let restoredReceipts=try XCTUnwrap(restored.toolReceipts)
            XCTAssertEqual(QimenReferenceReading.render(receipts:restoredReceipts,context:context)?.text,report.text)
            XCTAssertEqual(try CastReceiptStorage.expanded(restoredReceipts[0].output),v.chart)
        }
    }
    func testPeerRolesAndPlateAmbiguityRemainVisible()throws {
        let all=try vectors(),rain=all.first{$0.focus=="weather-rain"}!,stove=all.first{$0.focus=="dwelling-stove"}!
        let r=try XCTUnwrap(QimenSelectionEvidence.read(root:rain.chart,arguments:rain.arguments))
        XCTAssertTrue(r.text.contains("天柱"));XCTAssertTrue(r.text.contains("天蓬"))
        let s=try XCTUnwrap(QimenSelectionEvidence.read(root:stove.chart,arguments:stove.arguments))
        XCTAssertTrue(s.text.contains("地盘"));XCTAssertTrue(s.text.contains("天盘"));XCTAssertTrue(s.text.contains("盘层尚未唯一选定"))
    }
    func testTamperedRuleIdentityPeerOccurrenceAndInputBindingCannotRender()throws {
        let v=try vectors().first!,data=try JSONEncoder().encode(v.chart),original=try JSONSerialization.jsonObject(with:data) as! [String:Any]
        for kind in 0..<10 {
            var root=original,selection=root["specializedSelection"] as! [String:Any],sources=root["ruleSources"] as! [[String:Any]]
            let s=sources.firstIndex{($0["id"] as? String)=="qimen-xdyy-weather-selection-v1"}!
            switch kind {
            case 0:selection["outcomeEstablished"]=true
            case 1:selection["event"]="偷换事项"
            case 2:var refs=selection["references"] as! [[String:Any]];refs.removeLast();selection["references"]=refs
            case 3:var refs=selection["references"] as! [[String:Any]];var os=refs[0]["occurrences"] as! [[String:Any]];os[0]["objectPath"]="/palaces/0/bamen";refs[0]["occurrences"]=os;selection["references"]=refs
            case 4:var refs=sources[s]["references"] as! [[String:Any]];refs[0]["sha256"]=String(repeating:"0",count:64);sources[s]["references"]=refs
            case 5:var refs=sources[s]["references"] as! [[String:Any]];refs[0]["quote"]="另一条规则";sources[s]["references"]=refs
            case 6:sources.remove(at:s)
            case 7:selection["methodVersion"]="future"
            case 8:selection["roleMappingEstablished"]=false;selection["assessmentStatus"]="requires-clarification"
            default:root["questionContext"]=["event":"换了原始事件","subject":"self","timeHorizon":"near"]
            }
            root["specializedSelection"]=selection;root["ruleSources"]=sources
            let changed=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root))
            XCTAssertNil(QimenSelectionEvidence.read(root:changed,arguments:v.arguments),"mutation \(kind)")
        }
        let other=try vectors().first{$0.focus=="weather-snow"}!
        XCTAssertNil(QimenSelectionEvidence.read(root:v.chart,arguments:other.arguments))
    }
    func testLegacyAbsenceIsReadableButOneSidedReportSourceOrRequestIsRejected()throws {
        let v=try vectors().first!;guard case var .object(root)=v.chart,case var .object(args)=v.arguments,case let .array(sources)=root["ruleSources"] else{return XCTFail("fixture")}
        let (stored,context)=try receipt(v);root.removeValue(forKey:"specializedSelection");args.removeValue(forKey:"selectionRequest")
        var legacy=stored;legacy.arguments = .object(args);legacy.output=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        XCTAssertNil(QimenReferenceReading.render(receipts:[legacy],context:context),"Orphan source cannot imply legacy")
        root["ruleSources"] = .array(sources.filter{!QimenSelectionEvidence.sourceIDs.contains((ReadingVerificationEvidence.pointer("/id",in:$0)).flatMap{if case let .string(s)=$0{return s};return nil} ?? "")})
        legacy.output=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        XCTAssertNotNil(QimenReferenceReading.render(receipts:[legacy],context:context))
        legacy.arguments=v.arguments
        XCTAssertNil(QimenReferenceReading.render(receipts:[legacy],context:context),"A requested role requires its matching report")
    }
    func testIndependentBoundaryAndConflictReconstruction()throws {
        struct Boundary:Decodable {let name:String;let arguments:JSONValue;let chart:JSONValue;let established:Bool}
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url=native.appendingPathComponent("Engine/validation/research-divination/selection-2026-09-21/native-boundary-vectors.json")
        let boundaries=try JSONDecoder().decode([Boundary].self,from:Data(contentsOf:url))
        XCTAssertEqual(boundaries.count,14)
        for b in boundaries {
            let report=try XCTUnwrap(QimenSelectionEvidence.read(root:b.chart,arguments:b.arguments),b.name)
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/specializedSelection/roleMappingEstablished",in:b.chart),.bool(b.established),b.name)
            XCTAssertTrue(report.text.contains(b.established ? "已核对" : "尚缺适用条件或存在对象冲突"),b.name)
            if b.name=="own-hour-jia" {XCTAssertEqual(ReadingVerificationEvidence.pointer("/specializedSelection/references/0/carrierStem",in:b.chart),"壬")}
            if b.name=="invalid-hour-pillar" {XCTAssertEqual(ReadingVerificationEvidence.pointer("/specializedSelection/references/0/occurrences",in:b.chart),.array([]))}
            // A coordinated status/flag edit still cannot bypass original-fact reconstruction.
            guard case var .object(root)=b.chart,case var .object(selection)=root["specializedSelection"] else {return XCTFail("fixture")}
            selection["roleMappingEstablished"] = .bool(!b.established)
            selection["assessmentStatus"] = .string(b.established ? "requires-clarification" : "role-references-established")
            root["specializedSelection"] = .object(selection)
            XCTAssertNil(QimenSelectionEvidence.read(root:.object(root),arguments:b.arguments),b.name)
        }
    }
    func testEveryReceiptMustBindTheSameRequestedSelection()throws {
        let all=try vectors(),v=all[0],other=all[1]
        let (saved,context)=try receipt(v)
        var replay=saved;replay.callID="planner-reuse";replay.arguments=other.arguments
        XCTAssertNil(QimenReferenceReading.render(receipts:[saved,replay],context:context))
    }
}
