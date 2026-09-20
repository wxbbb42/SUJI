import XCTest
@testable import SujiCore

final class DivinationCalendarReadingTests: XCTestCase {
    private var history: [ChatMessage] {
        [.assistantToolCalls([.init(id:"liu",name:"cast_liuyao",arguments:[:])]),
         .toolResult(.init(callID:"liu",output:#"{"castGanZhi":{"month":"乙丑","day":"戊戌","hour":"戊午"}}"#)),
         .assistantToolCalls([.init(id:"qi",name:"setup_qimen",arguments:[:])]),
         .toolResult(.init(callID:"qi",output:#"{"monthGanZhi":"乙丑","dayGanZhi":"戊戌","hourGanZhi":"戊午"}"#))]
    }
    func testActualE1PreLiChunMonthMistakeHasAnExactLocalCorrection() {
        let draft = "盘面依据（可复核）：本卦山雷颐、变泽风大过，六爻皆动；起卦时间为丙寅月（按节气月）戊戌日戊午时，旬空在辰、巳。"
        let issues = ReadingVerifier.deterministicIssues(in:draft,history:history)
        XCTAssertEqual(issues.count,1)
        XCTAssertTrue(issues.first?.contains("liuyao.calendar.month") == true)
        XCTAssertTrue(issues.first?.contains("乙丑") == true)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:draft.replacingOccurrences(of:"丙寅",with:"乙丑"),history:history).isEmpty)
    }
    func testArchivedLiveDraftAndCompleteToolHistoryRequireMonthRepairBeforeReview() async throws {
        let archive = URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("../../../Engine/validation/reasoning/core-e1-results.json")
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:archive)) as? [String:Any])
        let record = try XCTUnwrap((report["cases"] as? [[String:Any]])?.first)
        let draft = try XCTUnwrap(record["draft"] as? String)
        let messages = try JSONDecoder().decode([ChatMessage].self,from:JSONSerialization.data(withJSONObject:try XCTUnwrap(record["writerHistory"])))
        let issues = ReadingVerifier.deterministicIssues(in:draft,history:messages)
        XCTAssertEqual(issues.filter { $0.contains("liuyao.calendar.month") }.count,1)
        let answer = try await ReadingVerifier.verify(draft:draft,history:messages,question:"核对起卦月建") { request in
            if request.last?.content?.hasPrefix(ReadingVerifier.revision) == true {
                XCTAssertTrue(request.last?.content?.contains("乙丑") == true)
                return .text("六爻月建为乙丑")
            }
            return .text(#"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#)
        }
        XCTAssertEqual(answer,"六爻月建为乙丑")
    }
    func testCalendarFieldsBindToTheirOwnSystemAndScopeOnly() throws {
        let facts = ReadingVerificationEvidence.facts(history)
        let month = try XCTUnwrap(facts.first { $0.factKey == "liuyao.calendar.month" })
        XCTAssertTrue(ReadingVerificationAssertions.binds("丙寅",to:month,in:"六爻月建为丙寅"))
        XCTAssertTrue(ReadingVerificationAssertions.binds("丙寅",to:month,in:"起卦时间为丙寅月戊戌日戊午时"))
        for sentence in ["奇门月建为丙寅", "八字月柱为丙寅", "六爻日柱为丙寅", "六爻时柱为丙寅", "如果六爻月建为丙寅", "六爻月建不是丙寅", "有人说六爻月建为丙寅", "六爻月建乙丑，奇门月建为丙寅", "上次六爻月建为丙寅", "明年六爻月建为丙寅", "六爻起卦时间为乙丑月，未来丙寅月会变", "六爻起卦时间为乙丑月，八字月柱为丙寅"] {
            XCTAssertFalse(ReadingVerificationAssertions.binds("丙寅",to:month,in:sentence),sentence)
        }
        let hour = try XCTUnwrap(facts.first { $0.factKey == "qimen.hourGanZhi" })
        XCTAssertTrue(ReadingVerificationAssertions.binds("庚申",to:hour,in:"奇门起局时间为乙丑月戊戌日庚申时"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("庚申",to:hour,in:"奇门日干支为庚申"))
    }
    func testNegationsAmbiguousToolValuesAndUnsupportedNarrativesCannotAuthorizeCorrection() {
        for sentence in ["假如起卦时间为丙寅月戊戌日戊午时", "起卦月建不是丙寅", "明年丙寅月我想搬家", "八字月柱为丙寅"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
        }
        let conflicting = history + [.assistantToolCalls([.init(id:"old",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"old",output:#"{"castGanZhi":{"month":"丙寅"}}"#))]
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in:"六爻月建为丁卯",history:conflicting).isEmpty)
    }
    func testAllCalendarSlotsAndSameValueInDifferentSlotsRemainSeparate() {
        for (draft,key,value) in [("六爻日柱为丙寅","liuyao.calendar.day","戊戌"),("六爻时干支为丙寅","liuyao.calendar.hour","戊午"),("奇门月建为丙寅","qimen.monthGanZhi","乙丑"),("奇门日柱为丙寅","qimen.dayGanZhi","戊戌"),("奇门起局时间为乙丑月戊戌日庚申时","qimen.hourGanZhi","戊午")] {
            let issues = ReadingVerifier.deterministicIssues(in:draft,history:history)
            XCTAssertEqual(issues.count,1,draft)
            XCTAssertTrue(issues.first?.contains(key) == true)
            XCTAssertTrue(issues.first?.contains(value) == true)
        }
        let repeated = "起卦时间为乙丑月戊戌日戊戌时"
        let issues = ReadingVerifier.deterministicIssues(in:repeated,history:history)
        XCTAssertEqual(issues.count,1)
        XCTAssertTrue(issues.first?.contains("liuyao.calendar.hour") == true)
    }
    func testIndependentReportedSpeechQuestionsPastCastsAndOtherMethodsAreNotCorrections() throws {
        let month = try XCTUnwrap(ReadingVerificationEvidence.facts(history).first { $0.factKey == "liuyao.calendar.month" })
        for sentence in ["朋友说起卦时间为丙寅月戊戌日戊午时", "起卦月建为丙寅的说法不成立", "起卦月建为丙寅并不属实", "假定六爻月建为丙寅，则另议", "用户问：起卦时间为丙寅月戊戌日戊午时吗？", "六爻月建为丙寅？", "去年六爻月建为丙寅", "昨天起卦时间为丙寅月戊戌日戊午时", "上一卦的起卦时间为丙寅月戊戌日戊午时", "梅花易数起卦时间为丙寅月戊戌日戊午时", "朋友说：起卦时间为丙寅月戊戌日戊午时"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
            XCTAssertFalse(ReadingVerificationAssertions.binds("丙寅",to:month,in:sentence),sentence)
        }
    }
    func testCalendarSequenceMayContainSeparatorsAndYearWithoutLosingFieldScope() {
        for sentence in ["起卦时间为乙丑月、丙寅日、戊午时", "起卦时间为乙丑月，丙寅日，戊午时", "起卦时间为乙巳年乙丑月丙寅日戊午时"] {
            let issues = ReadingVerifier.deterministicIssues(in:sentence,history:history)
            XCTAssertEqual(issues.count,1,sentence)
            XCTAssertTrue(issues.first?.contains("liuyao.calendar.day") == true)
        }
    }
    func testTimingAdviceAndQuotedPriorChartsCannotInheritCalendarLabel() {
        for sentence in ["起卦时间为乙丑月，丙寅日再联系对方", "起卦时间为乙丑月，丙寅日是应期", "起卦时间为乙丑月戊戌日，庚申时再联系对方", "奇门起局时间为乙丑月，丙寅日是应期", "上一局：奇门起局时间为丙寅月戊戌日戊午时", "书中记载：起卦时间为丙寅月戊戌日戊午时", "起卦月建为丙寅，是错的", "起卦月建为丙寅或乙丑"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in:sentence,history:history).isEmpty,sentence)
        }
    }
    func testNarrowFieldMismatchFeedbackAcceptsCorrectPointerButRejectsWrongScope() {
        let draft = "六爻月建为丙寅"
        let response = #"{"protocolVersion":"suji-verification-2","accepted":false,"reviewedSentences":[1],"issues":[{"kind":"field_mismatch","candidateQuote":"六爻月建为丙寅","candidateValueQuote":"丙寅","factKey":"liuyao.calendar.month","toolCallID":"liu","pointer":"/castGanZhi/month","actualValue":"乙丑","claimedValue":"丙寅","predicate":"equals"}]}"#
        guard case .revise = ReadingVerifier.feedback(response,draft:draft,history:history) else { return XCTFail("Real calendar mismatch must be repairable") }
        let wrong = response.replacingOccurrences(of:"calendar.month",with:"calendar.day").replacingOccurrences(of:"/castGanZhi/month",with:"/castGanZhi/day").replacingOccurrences(of:"乙丑",with:"戊戌")
        guard case .invalid = ReadingVerifier.feedback(wrong,draft:draft,history:history) else { return XCTFail("Wrong calendar field must not authorize repair") }
        guard case .invalid = ReadingVerifier.feedback(response,draft:draft + "？",history:history) else { return XCTFail("Sentence splitting must not turn a question into an assertion") }
        let conflicting = history + [.assistantToolCalls([.init(id:"old",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"old",output:#"{"castGanZhi":{"month":"丙寅"}}"#))]
        guard case .invalid = ReadingVerifier.feedback(response,draft:draft,history:conflicting) else { return XCTFail("Reviewer cannot choose among conflicting casts for unscoped prose") }
    }
}
