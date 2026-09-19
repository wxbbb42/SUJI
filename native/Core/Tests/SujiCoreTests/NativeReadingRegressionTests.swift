import Foundation
import XCTest
@testable import SujiCore

/// Real synthetic model outputs are immutable regression inputs, not expected
/// answers or evidence that the underlying model is generally reliable.
final class NativeReadingRegressionTests: XCTestCase {
    private func recorded(_ id: String, round: Int = 2) throws -> [String: Any] {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/native-round\(round)-results.json"))) as! [String: Any]
        return try XCTUnwrap((report["cases"] as? [[String: Any]])?.first { $0["id"] as? String == id })
    }

    private func history(_ record: [String: Any]) throws -> [ChatMessage] {
        try JSONDecoder().decode([ChatMessage].self, from: JSONSerialization.data(withJSONObject: record["writerHistory"]!))
    }

    func testRecordedHealthDenialsDoNotBecomePersonalRiskAssertions() throws {
        let record = try recorded("health-with-facts")
        let revisions = (record["exchanges"] as! [[String: Any]]).filter { $0["phase"] as? String == "revision" }.map { ($0["response"] as! [String: Any])["text"] as! String }
        for draft in [record["draft"] as! String] + revisions {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: try history(record)).isEmpty)
            for sentence in ReadingVerificationEvidence.sentences(draft) {
                XCTAssertFalse(ReadingVerificationAssertions.healthInference(sentence), sentence)
            }
        }
        XCTAssertFalse(ReadingVerifier.deterministicIssues(in: "擎羊在这一宫出现，按传统意象常被联想去谈\"磕碰、外伤、刀火、急性的状况\"").isEmpty)
        XCTAssertFalse(ReadingVerifier.deterministicIssues(in: "擎羊提示容易外伤，但不能据此确定病名").isEmpty)
    }

    func testRecordedUTCClockMislabelIsCaughtWithoutModelJudgment() throws {
        let record = try recorded("explicit-qimen")
        let draft = record["draft"] as! String
        let source = try history(record)
        let issues = ReadingVerifier.deterministicIssues(in: draft, history: source)
        XCTAssertEqual(issues.count, 1)
        XCTAssertTrue(issues[0].contains("2024-02-04 12:00"))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft.replacingOccurrences(of: "2024-02-04 04:00（UTC+08:00）", with: "2024-02-04 12:00（UTC+08:00）"), history: source).isEmpty)
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: []).isEmpty, "No invented time without a receipt")
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "奇门起局的真太阳时为2024-02-04 11:31（UTC+08:00）", history: source).isEmpty, "Do not compare apparent-solar clock against civil setup instant")
    }

    func testRecordedCandidateUpgradeHasSupportedCorrection() throws {
        let record = try recorded("interpretation-disagreement")
        let review = (record["exchanges"] as! [[String: Any]]).first { $0["phase"] as? String == "verifier" }!
        let raw = (review["response"] as! [String: Any])["text"] as! String
        guard case .revise = ReadingVerifier.feedback(raw, draft: record["draft"] as! String, history: try history(record)) else {
            return XCTFail("Constituting an established pattern must not bypass a candidate status")
        }
    }

    func testExistingBirthContextCannotBeConfusedWithMissingBirthInstruction() throws {
        let record = try recorded("tool-failure")
        XCTAssertFalse(ReadingVerifier.deterministicIssues(in: record["draft"] as! String, history: try history(record)).isEmpty)
        let now = Date(timeIntervalSince1970: 0)
        let absent = [ChatMessage(role: .system, content: ReadingPrompt.instruction(tone: "温暖", mode: "命理", referenceDate: now, hasBirth: false))]
        XCTAssertFalse(ReadingVerificationAssertions.birthAlreadyProvided(absent))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "请提供出生日期和时间", history: absent).isEmpty)
        let supplied = [ChatMessage(role: .system, content: ReadingPrompt.instruction(tone: "温暖", mode: "命理", referenceDate: now, hasBirth: true))]
        XCTAssertTrue(ReadingVerificationAssertions.birthAlreadyProvided(supplied))
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "无需重新提供出生日期，请稍后重试", history: supplied).isEmpty)
    }

    func testRecordedFalseAcceptanceCannotUpgradeCandidatesOrProveBothMethodsCorrect() throws {
        let record = try recorded("interpretation-disagreement", round: 3)
        let issues = ReadingVerifier.deterministicIssues(in: record["answer"] as! String, history: try history(record))
        XCTAssertTrue(issues.contains { $0.contains("候选") })
        XCTAssertTrue(issues.contains { $0.contains("双方算法都正确") })
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: "格局口径仍是候选，与扶抑目标不同不能证明两者都正确", history: try history(record)).isEmpty)
    }

    func testRecordedBirthRequestWithReversedWordOrderStillRequiresCorrection() throws {
        let record = try recorded("tool-failure", round: 3)
        XCTAssertFalse(ReadingVerifier.deterministicIssues(in: record["draft"] as! String, history: try history(record)).isEmpty)
        XCTAssertFalse(ReadingVerificationAssertions.asksForBirthAgain("出生资料不需要补全，请稍后重试"))
    }
}
