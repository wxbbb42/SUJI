import XCTest
@testable import SujiCore

final class ZiweiReadingAssertionTests: XCTestCase {
    private func archivedFailure() throws -> (String,[ChatMessage]) {
        let file = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../Engine/validation/reasoning/core-d3-verified-results.json")
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any])
        let record = try XCTUnwrap((report["cases"] as? [[String:Any]])?.first)
        return (try XCTUnwrap(record["draft"] as? String),try JSONDecoder().decode([ChatMessage].self,from:JSONSerialization.data(withJSONObject:try XCTUnwrap(record["writerHistory"]))))
    }
    func testArchivedAcceptedDraftRequiresSourceStemAndLunarYearRepair() async throws {
        let (draft,messages) = try archivedFailure()
        let issues = ReadingVerifier.deterministicIssues(in:draft,history:messages)
        XCTAssertEqual(issues.count,2)
        XCTAssertTrue(issues.contains { $0.contains("sourceStem") && $0.contains("庚") && $0.contains("丁") && $0.contains("乙") })
        XCTAssertTrue(issues.contains { $0.contains("annual.ganZhi") && $0.contains("2025-01-29") && $0.contains("乙巳") })
        let repaired = "生年太阴化科，大限太阴化禄，流年太阴化忌落子女宫"
        let answer = try await ReadingVerifier.verify(draft:draft,history:messages,question:"核对三层四化") { request in
            if request.last?.content?.hasPrefix(ReadingVerifier.revision) == true {
                XCTAssertTrue(request.last?.content?.contains("sourceStem") == true)
                XCTAssertTrue(request.last?.content?.contains("annual.ganZhi") == true)
                return .text(repaired)
            }
            return .text(#"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#)
        }
        XCTAssertEqual(answer,repaired)
    }
    func testCrossLayerComparisonAndDatedYearDenialKeepTheirContext() throws {
        let (_,messages) = try archivedFailure()
        let clear = "太阴在生年、大限、流年三层都有四化，但来源干和落宫一致"
        XCTAssertEqual(ReadingVerifier.deterministicIssues(in:clear,history:messages).count,1)
        let sameStems = tool("n","get_ziwei_palace",natal.replacingOccurrences(of:"\"sourceStem\":\"癸\"",with:"\"sourceStem\":\"庚\"")) + tool("t","get_ziwei_timing",timing.replacingOccurrences(of:"\"sourceStem\":\"戊\"",with:"\"sourceStem\":\"庚\"").replacingOccurrences(of:"\"sourceStem\":\"乙\"",with:"\"sourceStem\":\"庚\""))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:clear,history:sameStems).isEmpty)
        let conflictingStem = history + tool("other-natal","get_ziwei_palace",natal.replacingOccurrences(of:"\"sourceStem\":\"癸\"",with:"\"sourceStem\":\"庚\""))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:clear,history:conflictingStem).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:clear + "；此说法未成立",history:messages).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"如果这里只是假设；" + clear,history:messages).isEmpty)
        for draft in ["太阴在生年、大限、流年三层都有四化，但落宫一致", "太阴在生年、大限、流年三层都有四化，但来源干不一致", "如果" + clear, "有人说：" + clear, clear + "？", clear + "，未成立", clear.replacingOccurrences(of:"太阴",with:"太阳")] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:draft,history:messages).isEmpty,draft)
        }
        let year = "2025年1月29日运限：虚岁36。流年方面，该日农历仍属乙巳年之前，但系统返回乙巳"
        XCTAssertEqual(ReadingVerifier.deterministicIssues(in:year,history:messages).count,1)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:year + "，并非事实",history:messages).isEmpty)
        for draft in [year.replacingOccurrences(of:"2025年1月29日",with:"2025年1月28日"), year.replacingOccurrences(of:"仍属乙巳年之前",with:"已进入乙巳年"), "有人说：" + year, "如果" + year, year + "？", year.replacingOccurrences(of:"。",with:"。\n\n"), "2024年1月29日与" + year] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:draft,history:messages).isEmpty,draft)
        }
        let conflicts = messages + tool("other-date","get_ziwei_timing",#"{"calculationDate":"2025-01-28","annual":{"ganZhi":"甲辰"},"method":{"yearBoundary":"lunar-new-year"}}"#)
        // The explicit date selects the matching receipt; another date is not
        // a competing value for that same dated statement.
        XCTAssertEqual(ReadingVerifier.deterministicIssues(in:year,history:conflicts).count,1)
        let sameDateConflict = messages + tool("same-date","get_ziwei_timing",#"{"calculationDate":"2025-01-29","annual":{"ganZhi":"甲辰"},"method":{"yearBoundary":"lunar-new-year"}}"#)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:year,history:sameDateConflict).isEmpty)
    }
    private let natal = #"{"palace":"福德宫","mainStars":["太阴"],"minorStars":[],"starDetails":[{"name":"太阴","group":"main","brightness":"陷","sihua":["化科"]}],"natalTransformations":[{"scope":"natal-year-stem","sourceStem":"癸","star":"太阴","transformation":"化科","targetPalace":"福德宫","sourceId":"ziwei-sihua-selected-v1"}],"relatedPalaces":[{"palace":"命宫","relation":"opposite","mainStars":[],"minorStars":["文昌"],"emptyMainPalace":true}],"ruleSources":[{"id":"ziwei-sihua-selected-v1","version":"1"}]}"#
    private let timing = #"{"referenceDate":"2025-01-29T04:00:00Z","annual":{"lunarYear":2025,"ganZhi":"乙巳","transformations":[{"scope":"annual-year-stem","sourceStem":"乙","star":"太阴","transformation":"化忌","targetPalace":"福德宫","sourceId":"ziwei-timing-selected-v1"}]},"decadalTransformations":[{"scope":"decadal-palace-stem","sourceStem":"戊","star":"太阴","transformation":"化权","targetPalace":"福德宫","sourceId":"ziwei-timing-selected-v1"}],"ruleSources":[{"id":"ziwei-timing-selected-v1","version":"1"}]}"#
    private func tool(_ id: String, _ name: String, _ output: String) -> [ChatMessage] {
        [.assistantToolCalls([.init(id:id,name:name,arguments:[:])]),.toolResult(.init(callID:id,output:output))]
    }
    private var history: [ChatMessage] { tool("n","get_ziwei_palace",natal) + tool("t","get_ziwei_timing",timing) }

    func testRealCachedNatalAndTimingResultsPreserveThreeLayersAndEmptyPalaceStars() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let birth: [String:Any] = ["year":1990,"month":8,"day":15,"hour":10,"minute":0,"gender":"女","longitude":120]
        let natalData = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:["command":"natal","birth":birth]),as:UTF8.self))
        let snapshot = try JSONSerialization.jsonObject(with:natalData)
        var messages: [ChatMessage] = []
        for (id,name,args) in [("child","get_ziwei_palace",["palace":"子女宫"]),("health","get_ziwei_palace",["palace":"疾厄宫"]),("timing","get_ziwei_timing",["date":"2025-01-29"])] {
            let request: [String:Any] = ["command":"tool","name":name,"birth":birth,"natal":snapshot,"now":"2025-01-29T04:00:00Z","arguments":args]
            let response = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:request),as:UTF8.self))
            let envelope = try JSONDecoder().decode(JSONValue.self,from:response)
            let output = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
            messages += tool(id,name,ReadingVerificationEvidence.encoded(output))
        }
        // 庚:太阴科，丁:太阴禄，乙:太阴忌; these labels coexist on
        // the same natal star. This is native transport/assertion verification.
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"生年太阴化科，大限太阴化禄，流年太阴化忌落子女宫",history:messages).isEmpty)
        let wrong = ReadingVerifier.deterministicIssues(in:"生年太阴化忌，大限太阴化科，流年太阴化禄",history:messages)
        XCTAssertEqual(wrong.count,3)
        XCTAssertTrue(wrong.contains { $0.contains("annual") && $0.contains("化忌") })
        XCTAssertTrue(wrong.contains { $0.contains("decadal") && $0.contains("化禄") })
        let empty = ReadingVerifier.deterministicIssues(in:"本命疾厄宫为空宫，所以没有任何星曜",history:messages)
        XCTAssertEqual(empty.count,1)
        XCTAssertTrue(empty.first?.contains("文曲") == true)
        XCTAssertTrue(empty.first?.contains("左辅") == true)
    }

    func testSameStarDifferentTransformationLayersCannotOverwriteEachOther() {
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"生年太阴化科，流年太阴化忌，大限太阴化权",history:history).isEmpty)
        for (sentence,key,actual) in [("生年太阴化忌","ziwei.福德宫.transformation1.transformation","化科"),("流年太阴化科","ziwei.timing.annual.transformation1.transformation","化忌"),("大限太阴化忌","ziwei.timing.decadal.transformation1.transformation","化权")] {
            let issues = ReadingVerifier.deterministicIssues(in:sentence,history:history)
            XCTAssertEqual(issues.count,1,sentence)
            XCTAssertTrue(issues.first?.contains(key) == true)
            XCTAssertTrue(issues.first?.contains(actual) == true)
        }
    }
    func testNamedStarBrightnessAndTransformationDestinationRemainSeparate() {
        for (sentence,key,actual) in [("本命福德宫太阴亮度为庙","ziwei.福德宫.star1.brightness","陷"),("流年太阴化忌落夫妻宫","ziwei.timing.annual.transformation1.targetPalace","福德宫")] {
            let issues = ReadingVerifier.deterministicIssues(in:sentence,history:history)
            XCTAssertEqual(issues.count,1,sentence)
            XCTAssertTrue(issues.first?.contains(key) == true)
            XCTAssertTrue(issues.first?.contains(actual) == true)
        }
    }
    func testEmptyMajorStarPalaceStillHasItsOwnMinorStars() {
        let issues = ReadingVerifier.deterministicIssues(in:"本命命宫为空宫，所以没有任何星曜",history:history)
        XCTAssertEqual(issues.count,1)
        XCTAssertTrue(issues.first?.contains("文昌") == true)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"本命命宫没有主星，但有文昌；对宫星曜只能参照",history:history).isEmpty)
    }
    func testOtherObjectsQuestionsHypothesesAndConflictingTemporalReceiptsCannotAuthorizeRepair() {
        for sentence in ["流年太阳化科", "本命官禄宫太阴亮度为庙", "如果流年太阴化科", "有人说流年太阴化科", "流年太阴化科？", "流年太阴不是化科", "本命命宫为空宫，不代表没有任何星曜", "去年流年太阴化科", "他提到，流年太阴化科", "过去，流年太阴化科", "2023年，流年太阴化科", "2026年，流年太阴化科"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
        }
        for sentence in ["流年太阴化科，未成立", "流年太阴化科，尚未确定"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
            let facts = ReadingVerificationEvidence.facts(history)
            if let fact = facts.first(where: { $0.factKey == "ziwei.timing.annual.transformation1.transformation" }) {
                XCTAssertFalse(ZiweiReadingAssertions.binds("化科",to:fact,in:sentence,facts:facts),sentence)
            } else { XCTFail("Missing annual transformation fixture") }
        }
        let conflicting = history + tool("other","get_ziwei_timing",timing.replacingOccurrences(of:"化忌",with:"化禄"))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流年太阴化科",history:conflicting).isEmpty)
    }
    func testReviewerTransformationMismatchRequiresSameStarAndScope() {
        let response = #"{"protocolVersion":"suji-verification-2","accepted":false,"reviewedSentences":[1],"issues":[{"kind":"field_mismatch","candidateQuote":"流年太阴化科","candidateValueQuote":"化科","factKey":"ziwei.timing.annual.transformation1.transformation","toolCallID":"t","pointer":"/annual/transformations/0/transformation","actualValue":"化忌","claimedValue":"化科","predicate":"equals"}]}"#
        guard case .revise = ReadingVerifier.feedback(response,draft:"流年太阴化科",history:history) else { return XCTFail("Scoped mismatch should authorize only its field correction") }
        let repeated = history + tool("duplicate","get_ziwei_timing",timing)
        guard case .revise = ReadingVerifier.feedback(response.replacingOccurrences(of:"\"toolCallID\":\"t\"",with:"\"toolCallID\":\"duplicate\""),draft:"流年太阴化科",history:repeated) else { return XCTFail("Equally supported receipts retain their own citation identity") }
        for sentence in ["生年太阴化科","流年太阳化科"] {
            let wrong = response.replacingOccurrences(of:"流年太阴化科",with:sentence)
            guard case .invalid = ReadingVerifier.feedback(wrong,draft:sentence,history:history) else { return XCTFail(sentence) }
        }
    }
}
