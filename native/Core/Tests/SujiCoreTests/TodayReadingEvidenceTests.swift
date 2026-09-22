import XCTest
@testable import SujiCore

final class TodayReadingEvidenceTests: XCTestCase {
    private func history(_ output: String) -> [ChatMessage] {
        [
            .init(role: .system, content: "出生资料已提供"),
            .init(role: .user, content: "今天适合干什么"),
            .assistantToolCalls([.init(id: "today", name: "get_today_context", arguments: [:])]),
            .toolResult(.init(callID: "today", output: output)),
        ]
    }

    private func verdict(draft: String, actual: String, claimed: String, pointer: String = "/todayGanZhi") throws -> String {
        let value: [String: Any] = [
            "protocolVersion": ReadingVerifier.protocolVersion,
            "accepted": false, "reviewedSentences": [1],
            "issues": [[
                "kind": "field_mismatch", "candidateQuote": draft,
                "candidateValueQuote": claimed, "factKey": "calendar.day",
                "toolCallID": "today", "pointer": pointer,
                "actualValue": actual, "claimedValue": claimed, "predicate": "equals",
            ]],
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: value), as: UTF8.self)
    }

    func testBundledTodayToolProvidesTheDayFactAndSupportsARealCorrection() async throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        let request = #"{"command":"tool","name":"get_today_context","id":"today","arguments":{},"now":"2026-09-22T08:58:41Z","birth":{"year":1990,"month":8,"day":15,"hour":10,"minute":0,"gender":"女","longitude":120}}"#
        let data = try await bridge.request(request)
        let envelope = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = try XCTUnwrap(envelope["result"] as? [String: Any])
        let actual = try XCTUnwrap(result["todayGanZhi"] as? String)
        XCTAssertNil(result["dayGanZhi"], "Use the shipping engine's contract, not a hand-written legacy fixture")
        let output = String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        let messages = history(output)
        let day = try XCTUnwrap(ReadingVerificationEvidence.facts(messages).first { $0.factKey == "calendar.day" })
        XCTAssertEqual(day.toolCallID, "today")
        XCTAssertEqual(day.pointer, "/todayGanZhi")
        XCTAssertEqual(day.value, .string(actual))
        XCTAssertTrue(ReadingFallback.reply(history: messages).contains(actual + "日"))

        let wrong = actual == "甲子" ? "乙丑" : "甲子"
        let draft = "今日日柱为" + wrong
        let review = try verdict(draft: draft, actual: actual, claimed: wrong)
        guard case .revise = ReadingVerifier.feedback(review, draft: draft, history: messages) else {
            return XCTFail("A grounded day correction must reach revision instead of invalid_verdict recovery")
        }

        var calls = 0
        let repaired = "今日日柱为" + actual
        let accepted = #"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#
        let answer = try await ReadingVerifier.verify(draft: draft, history: messages, question: "今天适合干什么") { request in
            calls += 1
            if request.last?.content?.hasPrefix(ReadingVerifier.revision) == true {
                XCTAssertEqual(request.filter { $0.role == .tool }, messages.filter { $0.role == .tool })
                XCTAssertTrue(request.last?.content?.contains(actual) == true)
                return .text(repaired)
            }
            return .text(accepted)
        }
        XCTAssertEqual(answer, repaired)
        XCTAssertEqual(calls, 2, "The explicit current-day mismatch is corrected before asking a model to review it")
    }

    func testCurrentFieldTakesPrecedenceWithoutInventingALegacyPointer() throws {
        let messages = history(#"{"todayGanZhi":"己亥","dayGanZhi":"甲子"}"#)
        let days = ReadingVerificationEvidence.facts(messages).filter { $0.factKey == "calendar.day" }
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days.first?.value, .string("己亥"))
        XCTAssertEqual(days.first?.pointer, "/todayGanZhi")
        let draft = "今日日柱为乙丑"
        let forged = try verdict(draft: draft, actual: "甲子", claimed: "乙丑", pointer: "/dayGanZhi")
        guard case .invalid = ReadingVerifier.feedback(forged, draft: draft, history: messages) else {
            return XCTFail("A different stored field must not impersonate the indexed current day")
        }
    }

    func testLegacyReceiptUsesItsOriginalDayPointer() throws {
        let messages = history(#"{"dayGanZhi":"戊戌"}"#)
        let day = try XCTUnwrap(ReadingVerificationEvidence.facts(messages).first { $0.factKey == "calendar.day" })
        XCTAssertEqual(day.pointer, "/dayGanZhi")
        XCTAssertEqual(day.value, .string("戊戌"))
        let draft = "今日日柱为甲子"
        let review = try verdict(draft: draft, actual: "戊戌", claimed: "甲子", pointer: "/dayGanZhi")
        guard case .revise = ReadingVerifier.feedback(review, draft: draft, history: messages) else {
            return XCTFail("Existing stored receipts must remain verifiable")
        }
    }

    func testMissingOrNullCurrentDayCannotBeInferredFromOtherFields() {
        for output in [#"{"yearGanZhi":"丙午","monthGanZhi":"丁酉"}"#,
                       #"{"todayGanZhi":null,"dayGanZhi":"甲子"}"#] {
            XCTAssertFalse(ReadingVerificationEvidence.facts(history(output)).contains { $0.factKey == "calendar.day" })
        }
    }

    func testInvalidReviewerProtocolDoesNotClaimAFactualContradiction() async throws {
        let messages = history(#"{"yearGanZhi":"丙午","monthGanZhi":"丁酉","todayGanZhi":"己亥","solarTerm":"白露"}"#)
        do {
            _ = try await ReadingVerifier.verify(draft: "今日日柱为己亥", history: messages, question: "今天适合干什么") { _ in
                .text("not a verification verdict")
            }
            XCTFail("An invalid reviewer response must never accept the draft")
        } catch let error as ReadingVerifier.Rejected {
            XCTAssertEqual(error.reason, "invalid_verdict")
            XCTAssertTrue(error.localizedDescription.contains("未完成核对"))
            XCTAssertFalse(error.localizedDescription.contains("未能核对一致"))
            let fallback = ReadingFallback.reply(history: messages, rejectionReason: error.reason)
            XCTAssertTrue(fallback.contains("己亥日"))
            XCTAssertTrue(fallback.contains("未完成核对"))
            XCTAssertFalse(fallback.contains("未能与盘面核对一致"))
        }
    }

    func testNaturalTodayDateSequenceIsCheckedWithoutBorrowingNatalOrOtherDates() throws {
        let messages = history(#"{"yearGanZhi":"丙午","monthGanZhi":"丁酉","todayGanZhi":"己亥"}"#)
        for draft in ["今天是丙午年、丁酉月、甲子日", "今日是甲子日", "今日日柱为甲子"] {
            let issues = ReadingVerifier.deterministicIssues(in: draft, history: messages)
            XCTAssertEqual(issues.count, 1, draft)
            XCTAssertTrue(issues.first?.contains("/todayGanZhi") == true)
        }
        for draft in ["今天是丙午年、丁酉月、己亥日", "我的本命日柱为甲子", "明天是甲子日", "今天是甲子日吗？", "如果今天是甲子日", "不能说今天是甲子日"] {
            XCTAssertTrue(ReadingVerifier.deterministicIssues(in: draft, history: messages).isEmpty, draft)
        }
        for draft in ["我的日柱为甲子", "你的日柱为甲子", "本命日柱为甲子", "明天日柱为甲子", "后天日柱为甲子", "日柱为甲子"] {
            let raw = try verdict(draft: draft, actual: "己亥", claimed: "甲子")
            guard case .invalid = ReadingVerifier.feedback(raw, draft: draft, history: messages) else {
                return XCTFail("Today's receipt cannot contradict another subject or date: " + draft)
            }
        }
    }
}
