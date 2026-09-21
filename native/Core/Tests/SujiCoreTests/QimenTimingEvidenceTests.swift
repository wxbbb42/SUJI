import XCTest
@testable import SujiCore

final class QimenTimingEvidenceTests: XCTestCase {
    // Real source-compatible plate, with a literal independently dated first horse window.
    private func fixture() async throws -> [String:Any] {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let data=try await bridge.request(#"{"command":"tool","name":"setup_qimen","arguments":{"question":"工作事项","questionType":"career","subject":"self","event":"工作事项","timingRequest":{"focus":"employment","event":"工作事项"}},"now":"2004-05-29T04:00:00Z"}"#)
        var root=(try JSONSerialization.jsonObject(with:data) as! [String:Any])["result"] as! [String:Any]
        root["timing"]=try JSONSerialization.jsonObject(with:Data(#"""
        {"methodVersion":"qimen-xdyy-timing-v1","sourceIDs":["qimen-xdyy-timing-v1","qimen-hour-void-horse-v1"],"event":"工作事项","focus":"employment","assessmentStatus":"conditional-calendar-candidates","outcomeEstablished":false,
        "selection":{"established":true,"candidateId":"category-door-开门","objectPath":"/palaces/1/bamen","palaceId":2,"symbol":"开门","reason":"explicit-employment-focus"},
        "triggers":[{"ruleId":"horse-value","branches":["申"],"priority":2,"objectPath":"/palaces/1/bamen","factPaths":["/horse/branch","/palaces/1/bamen"],"sourceId":"qimen-xdyy-timing-v1"},{"ruleId":"horse-clash","branches":["寅"],"priority":2,"objectPath":"/palaces/1/bamen","factPaths":["/horse/branch","/palaces/1/bamen"],"sourceId":"qimen-xdyy-timing-v1"}],
        "supported":[{"condition":"hour-horse","factPaths":["/horse","/palaces/1/bamen"]}],"opposing":[],"conflicts":[],"unresolved":["event-outcome-not-adjudicated"],
        "dates":[{"unit":"day","ganZhi":"甲寅","branch":"寅","startsAt":"2004-06-03T15:00:00.000Z","endsAt":"2004-06-04T15:00:00.000Z","eligibleStart":"2004-06-03T15:00:00.000Z","eligibleEnd":"2004-06-04T15:00:00.000Z","triggerIds":["horse-clash"],"firstWindow":true}],
        "searchPolicy":{"timezone":"UTC+08:00","dayBoundary":"23:00","yearBoundary":"exact-lichun","monthBoundary":"exact-jie","clockPolicy":"beijing-standard","solarInversePolicy":"none","includeCurrent":false,"maxCandidates":32,"maxPeriods":512,"requestedEnd":"2004-06-05T00:00:00.000Z","searchedUntil":"2004-06-05T00:00:00.000Z","truncated":false,"searchComplete":true,"reason":"window-complete"}}
        """#.utf8))
        return root
    }
    private func read(_ root:[String:Any]) throws -> QimenTimingEvidence.Report? {
        QimenTimingEvidence.read(root:try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root)))
    }
    func testLiteralHorseCandidateIsBoundToTheOpeningDoorAndRemainsConditional() async throws {
        let root=try await fixture(),report=try XCTUnwrap(try read(root))
        XCTAssertTrue(report.text.contains("开门"));XCTAssertTrue(report.text.contains("条件候选"))
        XCTAssertTrue(report.text.contains("2004-06-03 23:00"));XCTAssertTrue(report.text.contains("事件成败仍未裁决"))
        let json=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root))
        for path in report.evidencePaths { XCTAssertNotNil(ReadingVerificationEvidence.pointer(path,in:json),path) }
    }
    func testCorruptConditionsDatesAndSourcesCannotProduceNativeText() async throws {
        let original=try await fixture()
        for kind in 0..<10 {
            var root=original,t=root["timing"] as! [String:Any]
            switch kind {
            case 0:t["outcomeEstablished"]=true
            case 1:var s=t["selection"] as! [String:Any];s["objectPath"]="/palaces/5/bamen";t["selection"]=s
            case 2:var ts=t["triggers"] as! [[String:Any]];ts[1]["branches"]=["未"];t["triggers"]=ts
            case 3:var ds=t["dates"] as! [[String:Any]];ds[0]["triggerIds"]=["invented"];t["dates"]=ds
            case 4:var ds=t["dates"] as! [[String:Any]];ds[0]["endsAt"]="2004-06-03T15:00:00.000Z";t["dates"]=ds
            case 5:var p=t["searchPolicy"] as! [String:Any];p["truncated"]=true;t["searchPolicy"]=p
            case 6:t["outcomeEstablished"]="false"
            case 7:root["ruleSources"]=[]
            case 8:var ds=t["dates"] as! [[String:Any]];ds[0]["ganZhi"]="乙卯";t["dates"]=ds
            default:var ts=t["triggers"] as! [[String:Any]];ts[0]["factPaths"]=["/palaces/5/bamen"];t["triggers"]=ts
            }
            root["timing"]=t;XCTAssertNil(try read(root),"mutation \(kind)")
        }
    }
    func testRealJavaScriptCoreDispatchSupportsEveryCalendarUnitAndUnresolvedRequest() async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        for unit in ["year","month","day","hour",""] {
            var request:[String:Any]=["focus":"employment","event":"工作事项"]
            if !unit.isEmpty { request["timeUnit"]=unit;request["window"]=["end":"2009-05-31T00:00:00Z","maxCandidates":3] }
            let input:[String:Any]=["command":"tool","name":"setup_qimen","arguments":["question":"工作事项","questionType":"career","subject":"self","event":"工作事项","timingRequest":request],"now":"2004-05-29T04:00:00Z"]
            let data=try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:input),as:UTF8.self))
            let root=(try JSONSerialization.jsonObject(with:data) as! [String:Any])["result"] as! [String:Any]
            let report=try XCTUnwrap(try read(root),unit)
            XCTAssertTrue(report.text.contains("事件成败仍未裁决"))
        }
    }
    func testSourceHashURLAndDirectExampleCannotBeReplaced()async throws {
        let original=try await fixture()
        for kind in 0..<3 {
            var root=original,sources=root["ruleSources"] as! [[String:Any]]
            let i=try XCTUnwrap(sources.firstIndex { $0["id"] as? String == "qimen-xdyy-timing-v1" })
            var refs=sources[i]["references"] as! [[String:Any]]
            if kind==0 { refs[0]["sha256"]=String(repeating:"0",count:64) }
            else if kind==1 { refs[0]["url"]="https://invalid.example/" }
            else { refs[2].removeValue(forKey:"quote") }
            sources[i]["references"]=refs;root["ruleSources"]=sources
            XCTAssertNil(try read(root),"source mutation \(kind)")
        }
    }
}
