import XCTest
@testable import SujiCore

final class BaziAdjudicationTraceTests: XCTestCase {
    private func result(earth:Bool = false) async throws -> JSONValue {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let birth=earth ? #"{"year":1980,"month":1,"day":26,"hour":7,"minute":30,"gender":"男","longitude":120}"# : #"{"year":1993,"month":6,"day":8,"hour":13,"minute":30,"gender":"男","longitude":120}"#
        let raw=try await bridge.request("{\"command\":\"tool\",\"name\":\"get_domain\",\"arguments\":{\"domain\":\"事业\"},\"now\":\"2026-09-21T04:00:00Z\",\"birth\":\(birth)}")
        return try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:JSONDecoder().decode(JSONValue.self,from:raw)))
    }
    private func replace(_ root:JSONValue,_ path:String,_ replacement:JSONValue)->JSONValue {
        func set(_ value:JSONValue,_ keys:ArraySlice<String>)->JSONValue {
            guard let key=keys.first else{return replacement}
            if case var .object(obj)=value,let child=obj[key]{obj[key]=set(child,keys.dropFirst());return .object(obj)}
            if case var .array(a)=value,let i=Int(key),a.indices.contains(i){a[i]=set(a[i],keys.dropFirst());return .array(a)}
            XCTFail("Missing mutation path \(path)");return value
        }
        return set(root,path.split(separator:"/").map(String.init)[...])
    }
    func testActualEarthFormationExplainsSelectedSubsetWithCivilCommander() async throws {
        let root=try await result(earth:true)
        let trace=try XCTUnwrap(BaziAdjudicationTrace.make(root:root))
        XCTAssertTrue(trace.text.contains("稼穑格规则子集成立"),trace.text)
        XCTAssertTrue(trace.text.contains("己土司令"),trace.text)
        XCTAssertTrue(trace.text.contains("不代表全局成败"),trace.text)
        for path in trace.paths{XCTAssertNotNil(ReadingVerificationEvidence.pointer(path,in:root),path)}
    }
    func testActualRootedCombinationNamesTheRetainedRole() async throws {
        let root=try await result()
        let trace=try XCTUnwrap(BaziAdjudicationTrace.make(root:root))
        XCTAssertTrue(trace.text.contains("月干戊合年干癸"),trace.text)
        XCTAssertTrue(trace.text.contains("有根，不能据五合认定已合去"),trace.text)
        XCTAssertTrue(trace.brief.contains("有根"))
    }
    func testRejectsMismatchedBirthMonthCommanderAndSources() async throws {
        let root=try await result(earth:true),p="/bazi/patternAnalysis/specialPatternEvidence"
        for (path,value):(String,JSONValue) in [
            (p+"/sources/0/sha256","wrong"), (p+"/dayElement","木"), (p+"/formation/0/positions/0",3),
            (p+"/season/birthMonthContext/civilBirthTime","1980-01-26T00:00:00.000Z"),
            (p+"/season/birthMonthContext/daysAfterJie",1), (p+"/season/commander/gan","戊"),
            (p+"/outcomeEstablished",true),
        ]{XCTAssertNil(BaziAdjudicationTrace.make(root:replace(root,path,value)),path)}
    }
    func testRejectsRootRemovalAndWrongCombinationObject() async throws {
        let root=try await result(),p="/bazi/patternAnalysis/rescueEvidence"
        for (path,value):(String,JSONValue) in [
            (p+"/sources/2/sha256","wrong"),(p+"/combinations/0/targetGan","甲"),
            (p+"/combinations/0/removalEstablished",true),(p+"/combinations/0/status","role-disabled-in-selected-profile"),
            (p+"/globalResolution","established"),(p+"/combinations/0/sourceIds/0","wrong"),
        ]{XCTAssertNil(BaziAdjudicationTrace.make(root:replace(root,path,value)),path)}
    }
    func testFrameworkFullAndBriefClaimsKeepBoundLocalFindings() async throws {
        let root=try await result()
        let context=try ToolContext(birth:nil,engineRevision:"adjudication-test",referenceDate:Date(timeIntervalSince1970:1_790_000_000),mode:"命理")
        let receipt=ToolReceipt(callID:"adjudicated",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(root),context:context)
        let catalog=try XCTUnwrap(BaziFrameworkReading.catalog(receipts:[receipt],context:context))
        for id in ["pattern","pattern-brief"]{
            let claim=try XCTUnwrap(catalog.claims.first{$0.id==id})
            XCTAssertTrue(claim.text.contains("有根"),claim.text)
            XCTAssertTrue(claim.evidence.contains{$0.pointer.contains("/rescueEvidence/combinations/")&&$0.toolCallID=="adjudicated"})
            for field in claim.evidence{XCTAssertEqual(ReadingVerificationEvidence.pointer(field.pointer,in:root),field.value)}
        }
    }
}
