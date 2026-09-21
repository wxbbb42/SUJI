import XCTest
@testable import SujiCore

final class ZiweiMonthlyEvidenceTests: XCTestCase {
    private let raw = #"{"monthly":{"status":"available","scope":"lunar-month","assessmentStatus":"structural-only","appliesToBirth":true,"sourceId":"ziwei-monthly-selected-v1","calendar":{"lunarYear":2025,"month":1,"day":1,"isLeapMonth":false,"effectiveMonth":1},"birthBasis":{"algorithm":"suji-ziwei-monthly-basis-1","lunarMonth":1,"lunarDay":1,"isLeapMonth":false,"effectiveMonth":1,"hourBranch":"子"},"douJun":{"position":"巳","natalPalace":"田宅宫"},"mingGong":{"position":"巳","natalPalace":"田宅宫"},"ganZhi":"戊寅","stem":"戊","branch":"寅","palaces":[{"palace":"命宫","position":"巳","natalPalace":"田宅宫"},{"palace":"福德宫","position":"未","natalPalace":"仆役宫"}],"transformations":[{"scope":"monthly-month-stem","sourceStem":"戊","star":"太阴","transformation":"化权","targetPalace":"福德宫","targetPosition":"辰","sourceId":"ziwei-monthly-selected-v1"}],"method":{"algorithm":"suji-ziwei-monthly-1","monthBoundary":"lunar-month","leapMonth":"split-at-day-15","stemMethod":"lunar-year-five-tiger","palaceMethod":"dou-jun"}},"ruleSources":[{"id":"ziwei-monthly-selected-v1","version":"1"}]}"#
    private func history(_ output:String,_ id:String="m") -> [ChatMessage] {
        [.assistantToolCalls([.init(id:id,name:"get_ziwei_timing",arguments:["withMonthly":true])]),.toolResult(.init(callID:id,output:output))]
    }
    func testMonthOverlayKeepsNatalTargetAndMonthlyPalaceIdentitySeparate() throws {
        let facts = ReadingVerificationEvidence.facts(history(raw))
        for (key,path,value) in [
            ("calendar.isLeapMonth","/calendar/isLeapMonth",JSONValue.bool(false)),
            ("birthBasis.hourBranch","/birthBasis/hourBranch",.string("子")),
            ("douJun.position","/douJun/position",.string("巳")),
            ("mingGong.natalPalace","/mingGong/natalPalace",.string("田宅宫")),
            ("palace2.natalPalace","/palaces/1/natalPalace",.string("仆役宫")),
            ("transformation1.targetPalace","/transformations/0/targetPalace",.string("福德宫")),
            ("transformation1.scope","/transformations/0/scope",.string("monthly-month-stem")),
        ] {
            let fact = try XCTUnwrap(facts.first { $0.factKey == "ziwei.timing.monthly."+key })
            XCTAssertEqual(fact.pointer,"/monthly"+path)
            XCTAssertEqual(fact.value,value)
        }
    }
    func testMissingAndPrebirthMonthsRetainTheirStatusWithoutInventedPositions() {
        let output = #"{"monthly":{"status":"before-birth","appliesToBirth":false,"transformations":[]}}"#
        let facts = ReadingVerificationEvidence.facts(history(output))
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.timing.monthly.appliesToBirth" }?.value,.bool(false))
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.timing.monthly.transformations" }?.value,.array([]))
        XCTAssertFalse(facts.contains { $0.factKey.hasSuffix("position") })
        let missing = ReadingVerificationEvidence.facts(history(#"{"monthly":{"status":"unavailable","reason":"natal-monthly-basis-missing"}}"#))
        XCTAssertEqual(missing.first { $0.factKey == "ziwei.timing.monthly.reason" }?.value,"natal-monthly-basis-missing")
    }
    func testMonthlyRepairRequiresCompleteSameReceiptSourceAndNoDifferentMonthContext() throws {
        let response = #"{"protocolVersion":"suji-verification-2","accepted":false,"reviewedSentences":[1],"issues":[{"kind":"field_mismatch","candidateQuote":"流月太阴化科","candidateValueQuote":"化科","factKey":"ziwei.timing.monthly.transformation1.transformation","toolCallID":"m","pointer":"/monthly/transformations/0/transformation","actualValue":"化权","claimedValue":"化科","predicate":"equals"}]}"#
        guard case .revise = ReadingVerifier.feedback(response,draft:"流月太阴化科",history:history(raw)) else { return XCTFail("Current month has a supported literal mismatch") }
        let original = try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
        for key in ["sourceId","status","appliesToBirth","method","ruleSources","calendar"] {
            guard case var .object(root) = original,case var .object(monthly) = root["monthly"] else { return XCTFail() }
            if key == "ruleSources" { root.removeValue(forKey:key) }
            else { monthly.removeValue(forKey:key);root["monthly"] = .object(monthly) }
            let messages = history(ReadingVerificationEvidence.encoded(JSONValue.object(root)))
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化科",history:messages).isEmpty,key)
            switch ReadingVerifier.feedback(response,draft:"流月太阴化科",history:messages) { case .invalid: break; default: XCTFail("Missing monthly "+key+" must not authorize correction") }
        }
        for qualifier in ["农历六月，","正月，","闰六月，","2025-06-25，","6月25日，","另一个月，","农历六月。","2024年。","去年。"] {
            let draft = qualifier+"流月太阴化科"
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:draft,history:history(raw)).isEmpty,draft)
            let quotes = ReadingVerificationEvidence.sentences(draft)
            let candidate = quotes.last!
            var verdict = response.replacingOccurrences(of:"\"candidateQuote\":\"流月太阴化科\"",with:"\"candidateQuote\":\""+candidate+"\"")
            if quotes.count == 2 { verdict = verdict.replacingOccurrences(of:"[1]",with:"[1,2]") }
            switch ReadingVerifier.feedback(verdict,draft:draft,history:history(raw)) { case .invalid: break; default: XCTFail("Month-qualified claim is outside automatic repair scope") }
        }
    }

    func testMonthSourceStemAndMethodCannotConflictWithTheEnclosingLayer() {
        for (before,after) in [("\"sourceStem\":\"戊\"","\"sourceStem\":\"丙\""),("lunar-year-five-tiger","natal-palace-stem"),("split-at-day-15","whole-month"),("dou-jun","other"),("lunar-month\",\"leapMonth","solar-term\",\"leapMonth")] {
            let altered = raw.replacingOccurrences(of:before,with:after)
            XCTAssertNotEqual(altered,raw)
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化科",history:history(altered)).isEmpty,after)
        }
    }

    func testDifferentMonthsDoNotBorrowAnOldTransformationAbsentFromTheNewMonth() throws {
        guard case var .object(root) = try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),case var .object(monthly) = root["monthly"] else { return XCTFail() }
        monthly["calendar"] = ["lunarYear":2025,"month":5,"day":1,"isLeapMonth":false,"effectiveMonth":5]
        monthly["ganZhi"] = "壬午";monthly["stem"] = "壬";monthly["branch"] = "午"
        monthly["transformations"] = [["scope":"monthly-month-stem","sourceStem":"壬","star":"天梁","transformation":"化禄","targetPalace":"迁移宫","targetPosition":"申","sourceId":"ziwei-monthly-selected-v1"]]
        root["monthly"] = .object(monthly)
        let messages = history(raw)+history(ReadingVerificationEvidence.encoded(JSONValue.object(root)),"later")
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化科",history:messages).isEmpty)
        let facts = ReadingVerificationEvidence.facts(messages)
        let old = try XCTUnwrap(facts.first { $0.factKey == "ziwei.timing.monthly.transformation1.transformation" && $0.toolCallID == "m" })
        XCTAssertFalse(ZiweiReadingAssertions.binds("化科",to:old,in:"流月太阴化科",facts:facts))
    }

    func testLiteralMonthTransformationMismatchCannotUseAnotherScopeOrFlowPalace() {
        let messages = history(raw)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化权落本命福德宫",history:messages).isEmpty)
        for (sentence,key) in [("流月太阴化科","transformation"),("流月太阴化权落本命仆役宫","targetPalace")] {
            let issues = ReadingVerifier.deterministicIssues(in:sentence,history:messages)
            XCTAssertEqual(issues.count,1,sentence)
            XCTAssertTrue(issues.first?.contains("ziwei.timing.monthly.transformation1."+key) == true)
        }
        for sentence in ["流年太阴化科","生年太阴化科","大限太阴化科","本命宫干太阴化科","流月太阴化权落流月福德宫","上月流月太阴化科","下个月流月太阴化科","流月太阴化科？","如果流月太阴化科","有人说流月太阴化科","流月太阴不是化科"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:messages).isEmpty,sentence)
        }
        let conflicts = messages+history(raw.replacingOccurrences(of:"化权",with:"化忌"),"other")
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化科",history:conflicts).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"流月太阴化科",history:history(raw.replacingOccurrences(of:"ziwei-monthly-selected-v1",with:"unknown"))).isEmpty)
    }
}
