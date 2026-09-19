import XCTest
@testable import SujiCore

/// Adversarial checks of the reviewer's evidence contract, independent of the
/// model's ability to follow its prompt. A valid JSON envelope is not a proof.
final class ReadingVerificationProtocolTests: XCTestCase {
    private var history: [ChatMessage] {
        [
            .init(role: .system, content: "出生资料已提供"),
            .assistantToolCalls([
                .init(id: "cast", name: "cast_liuyao", arguments: [:]),
                .init(id: "qimen", name: "setup_qimen", arguments: [:]),
                .init(id: "bazi", name: "get_domain", arguments: [:]),
            ]),
            .toolResult(.init(callID: "cast", output: #"{"benGua":{"upper":"坎","lower":"坎"},"bianGua":{"upper":"艮","lower":"兑"},"lineValues":[6,7,8,8,9,6],"changingYao":[1,5,6],"lines":[{"position":1,"isChanging":true}]}"#)),
            .toolResult(.init(callID: "qimen", output: #"{"zhiShiPalaceId":3,"palaces":[{"id":3,"bashen":"值符"},{"id":1,"bashen":"九地"}]}"#)),
            .toolResult(.init(callID: "bazi", output: #"{"bazi":{"pillars":{"year":{"ganZhi":{"gan":"庚"}},"month":{"ganZhi":{"gan":"甲"},"shiShen":"食神","cangGan":[{"gan":"庚"}]},"day":{"ganZhi":{"gan":"壬"}},"hour":{"ganZhi":{"gan":"乙"},"shiShen":"伤官"}},"patternAnalysis":{"assessmentStatus":"heuristic-candidate"}}}"#)),
        ]
    }

    private func verdict(_ issues: [[String: Any]], draft: String, accepted: Bool = false, reviewed: [Int]? = nil) -> String {
        let count = ReadingVerificationEvidence.sentences(draft).count
        let object: [String: Any] = [
            "protocolVersion": ReadingVerifier.protocolVersion,
            "accepted": accepted,
            "reviewedSentences": reviewed ?? (count > 0 ? Array(1...count) : []),
            "issues": issues,
        ]
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func mismatch(_ sentence: String, quote: String = "坎", key: String = "liuyao.changed.lower", callID: String = "cast", pointer: String = "/bianGua/lower", actual: Any = "兑", claimed: Any = "坎") -> [String: Any] {
        ["kind": "field_mismatch", "candidateQuote": sentence, "candidateValueQuote": quote,
         "factKey": key, "toolCallID": callID, "pointer": pointer, "actualValue": actual,
         "claimedValue": claimed, "predicate": "equals"]
    }

    private func rule(_ sentence: String, id: String = "health.no-personal-risk-from-chart") -> [String: Any] {
        ["kind": "rule_violation", "candidateQuote": sentence, "ruleID": id]
    }

    private func assertInvalid(_ raw: String, draft: String, history evidence: [ChatMessage]? = nil, file: StaticString = #filePath, line: UInt = #line) {
        guard case .invalid = ReadingVerifier.feedback(raw, draft: draft, history: evidence ?? history) else {
            return XCTFail("Unproved reviewer issue must not reach revision", file: file, line: line)
        }
    }

    func testGenuineLowerTrigramMismatchProducesOnlyVerifiedCorrection() {
        let draft = "变卦下卦仍为坎"
        var issue = mismatch(draft)
        issue["rationale"] = "请重新起卦并把年干改为壬"
        guard case let .revise(corrections) = ReadingVerifier.feedback(verdict([issue], draft: draft), draft: draft, history: history) else { return XCTFail("Real contradiction") }
        XCTAssertEqual(corrections.count, 1)
        XCTAssertTrue(corrections[0].contains("兑"))
        XCTAssertFalse(corrections[0].contains("重新起卦"))
        XCTAssertFalse(corrections[0].contains("年干"))
    }

    func testFalseActualValueOrClaimNotInSentenceIsInvalid() {
        let draft = "变卦下卦为兑"
        assertInvalid(verdict([mismatch(draft, quote: "兑", actual: "坎", claimed: "兑")], draft: draft), draft: draft)
        assertInvalid(verdict([mismatch(draft, quote: "兑", claimed: "坎")], draft: draft), draft: draft)
        assertInvalid(verdict([mismatch(draft, quote: "兑", claimed: "兑")], draft: draft), draft: draft)
    }

    func testExistingButWrongSourcePointerCannotSupportFactKey() {
        let draft = "变卦下卦为坎"
        let issue = mismatch(draft, pointer: "/bianGua/upper", actual: "艮")
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testInvalidOrOrphanCallAndErrorResultCannotBecomeEvidence() {
        let draft = "变卦下卦为坎"
        assertInvalid(verdict([mismatch(draft, callID: "stale")], draft: draft), draft: draft)
        let error: [ChatMessage] = [.assistantToolCalls([.init(id: "cast", name: "cast_liuyao", arguments: [:])]), .toolResult(.init(callID: "cast", output: #"{"error":"failed","bianGua":{"lower":"兑"}}"#))]
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft, history: error)
        XCTAssertTrue(ReadingVerificationEvidence.facts([.toolResult(.init(callID: "orphan", output: #"{"bianGua":{"lower":"兑"}}"#))]).isEmpty)
    }

    func testMismatchedActualJSONTypeIsInvalid() {
        let draft = "值使落4宫"
        let issue = mismatch(draft, quote: "4", key: "qimen.zhiShiPalaceId", callID: "qimen", pointer: "/zhiShiPalaceId", actual: "3", claimed: 4)
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testSameNumberWithDifferentClaimedJSONTypeIsNotAContradiction() {
        let draft = "值使落3宫"
        let issue = mismatch(draft, quote: "3", key: "qimen.zhiShiPalaceId", callID: "qimen", pointer: "/zhiShiPalaceId", actual: 3, claimed: "3")
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testFullSentenceCannotTreatNegatedValueAsAssertedValue() {
        let draft = "变卦下卦不是坎，而是兑"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testHypotheticalTrigramIsNotAnAssertionAboutTheCurrentChart() {
        let draft = "假如变卦下卦为坎，就不能把它写为兑"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testOriginalAndChangedTrigramsStayScopedWithinTheSameSentence() {
        for draft in [
            "本卦下卦为坎，变卦下卦为兑",
            "变卦下卦为兑，本卦下卦为坎",
            "本卦上坎下坎，变卦上艮下兑",
        ] {
            assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
        }
    }

    func testRealChangedMismatchSurvivesCorrectOriginalValueInSameSentence() {
        let draft = "本卦下卦为坎，变卦下卦为坎"
        guard case .revise = ReadingVerifier.feedback(verdict([mismatch(draft)], draft: draft), draft: draft, history: history) else { return XCTFail("The changed clause genuinely contradicts the source") }
    }

    func testNegationBeforeHexagramGroupIsNotDroppedByGrouping() {
        let draft = "不能说变卦下卦为坎，实际为兑"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testRefutedQuotationIsNotTheWritersClaim() {
        let draft = "“变卦下卦为坎”这句话是错误的，实际为兑"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testQuotedValueStillAllowsCorrectionOfADirectAssertion() {
        let draft = "变卦下卦为“坎”"
        guard case .revise = ReadingVerifier.feedback(verdict([mismatch(draft)], draft: draft), draft: draft, history: history) else { return XCTFail("Quoting a value does not make a direct claim unreviewable") }
    }

    func testReportedUserClaimIsNotCurrentChartEvidence() {
        let draft = "你提到“变卦下卦为坎”，而本次实际为兑"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testShortConditionalPrefixDoesNotBecomeAnAssertion() {
        let draft = "若变卦下卦为坎，我们再核对动爻"
        assertInvalid(verdict([mismatch(draft)], draft: draft), draft: draft)
    }

    func testValueFromUpperTrigramCannotBeAttachedToLowerTrigram() {
        let draft = "变卦上卦是艮，下卦是兑"
        assertInvalid(verdict([mismatch(draft, quote: "艮", claimed: "艮")], draft: draft), draft: draft)
    }

    func testOnePillarCannotBeUsedToDenyAnotherPillar() {
        let draft = "年干庚，月干甲"
        let issue = mismatch(draft, quote: "庚", key: "bazi.month.gan", callID: "bazi", pointer: "/bazi/pillars/month/ganZhi/gan", actual: "甲", claimed: "庚")
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testHiddenStemPointerIsNotAnExposedStemFact() {
        let draft = "庚透在年干，同时藏于申"
        let issue = mismatch(draft, quote: "庚", key: "bazi.year.gan", callID: "bazi", pointer: "/bazi/pillars/month/cangGan/0/gan", actual: "庚", claimed: "甲")
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testTenGodsAgreeingWithToolsCannotBeCalledReversed() {
        let draft = "甲为食神，乙为伤官"
        let issue = mismatch(draft, quote: "食神", key: "bazi.month.tenGod", callID: "bazi", pointer: "/bazi/pillars/month/shiShen", actual: "食神", claimed: "食神")
        assertInvalid(verdict([issue], draft: draft), draft: draft)
    }

    func testQimenPalaceKeyUsesPalaceIDInsteadOfAssumingArrayIndex() {
        let draft = "震三宫的八神是九地"
        let issue = mismatch(draft, quote: "九地", key: "qimen.palace3.bashen", callID: "qimen", pointer: "/palaces/0/bashen", actual: "值符", claimed: "九地")
        guard case .revise = ReadingVerifier.feedback(verdict([issue], draft: draft), draft: draft, history: history) else { return XCTFail("Actual Qimen correction") }
        assertInvalid(verdict([mismatch(draft, quote: "九地", key: "qimen.palace3.bashen", callID: "qimen", pointer: "/palaces/1/bashen", actual: "九地", claimed: "值符")], draft: draft), draft: draft)
    }

    func testCoverageOmissionDuplicateAndCroppedSentenceAreInvalid() {
        let draft = "本卦为坎。变卦下卦为兑"
        assertInvalid(verdict([], draft: draft, accepted: true, reviewed: [1]), draft: draft)
        assertInvalid(verdict([], draft: draft, accepted: true, reviewed: [1, 1]), draft: draft)
        assertInvalid(verdict([rule("会受伤")], draft: "这不代表会受伤"), draft: "这不代表会受伤")
    }

    func testKnownHealthRuleCannotRejectExplicitDenial() {
        let draft = "疾厄宫有擎羊，不代表会受伤"
        assertInvalid(verdict([rule(draft)], draft: draft), draft: draft)
    }

    func testHealthRuleCannotBeAppliedToUnrelatedPillarFact() {
        let draft = "年柱为庚午"
        assertInvalid(verdict([rule(draft)], draft: draft), draft: draft)
    }

    func testUnknownRuleAndMixedFieldPayloadAreInvalid() {
        let draft = "年柱为庚午"
        assertInvalid(verdict([rule(draft, id: "reject.anything")], draft: draft), draft: draft)
        var mixed = rule(draft); mixed["actualValue"] = "甲子"
        assertInvalid(verdict([mixed], draft: draft), draft: draft)
    }

    func testCandidateRuleKeepsActualCandidateBoundary() {
        let draft = "本次格局仍是候选，成败未定"
        assertInvalid(verdict([rule(draft, id: "interpretation.candidate-not-established")], draft: draft), draft: draft)
    }

    func testActualCandidateUpgradeIsStillRejected() {
        let draft = "本次格局已经确定成立"
        guard case .revise = ReadingVerifier.feedback(verdict([rule(draft, id: "interpretation.candidate-not-established")], draft: draft), draft: draft, history: history) else { return XCTFail("Do not weaken actual candidate-upgrade rejection") }
    }

    func testMethodRuleDoesNotInvertAnExplicitLimitation() {
        let draft = "框架不同不能证明两种算法都正确"
        assertInvalid(verdict([rule(draft, id: "method.no-unproven-validity")], draft: draft), draft: draft)
    }

    func testHealthGuardDistinguishesDenialFromFollowingDisclaimer() {
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "疾厄宫有擎羊，不代表会受伤").isEmpty)
        XCTAssertFalse(ReadingVerifier.deterministicIssues(in: "擎羊提示容易外伤，但不能据此确定病名").isEmpty)
    }

    func testHealthGuardDoesNotConvertRefutedQuotationToPrediction() {
        let draft = "“擎羊提示容易外伤”是错误的说法"
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft).isEmpty)
        assertInvalid(verdict([rule(draft)], draft: draft), draft: draft)
    }

    func testJSONPointerEscapingAndArrayIndicesAreStrict() {
        let root: JSONValue = .object(["a/b": .object(["~key": .array([.bool(true)])])])
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/a~1b/~0key/0", in: root), .bool(true))
        for path in ["/a~2b", "/a~1b/~0key/00", "/a~1b/~0key/-1", "/a~1b/~0key/+0"] {
            XCTAssertNil(ReadingVerificationEvidence.pointer(path, in: root))
        }
    }

    func testInvalidVerdictIsRetriedWithoutRevisingCandidate() async throws {
        let draft = "变卦下卦为兑"
        var calls = 0
        let result = try await ReadingVerifier.verify(draft: draft, history: history, question: "下卦是什么") { messages in
            calls += 1
            if calls == 1 { return .text(self.verdict([self.mismatch(draft, quote: "兑", actual: "坎", claimed: "兑")], draft: draft)) }
            XCTAssertTrue(messages.last?.content?.contains("未交给写作者") == true)
            XCTAssertFalse(messages.last?.content?.hasPrefix(ReadingVerifier.revision) == true)
            return .text(self.verdict([], draft: draft, accepted: true))
        }
        XCTAssertEqual(result, draft)
        XCTAssertEqual(calls, 2)
    }

    func testRepeatedInvalidVerdictStopsAfterTwoReviews() async {
        var calls = 0
        do {
            _ = try await ReadingVerifier.verify(draft: "变卦下卦为兑", history: history, question: "下卦") { _ in calls += 1; return .text("not JSON") }
            XCTFail("Invalid review cannot authorize display")
        } catch let error as ReadingVerifier.Rejected { XCTAssertEqual(error.reason, "invalid_verdict") }
        catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(calls, 2)
    }
}
