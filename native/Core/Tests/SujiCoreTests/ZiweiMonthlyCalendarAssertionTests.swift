import XCTest
@testable import SujiCore

final class ZiweiMonthlyCalendarAssertionTests: XCTestCase {
    private func archivedFailure() throws -> (String, [ChatMessage]) {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../Engine/validation/reasoning/core-d5-results.json")
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let record = try XCTUnwrap((report["cases"] as? [[String: Any]])?.first)
        return (try XCTUnwrap(record["draft"] as? String), try JSONDecoder().decode([ChatMessage].self,
            from: JSONSerialization.data(withJSONObject: try XCTUnwrap(record["writerHistory"]))))
    }

    func testArchivedFalseAcceptanceSeparatesRealCalendarFromCalculationMonth() throws {
        let (draft, history) = try archivedFailure()
        let issues = ReadingVerifier.deterministicIssues(in: draft, history: history)
        XCTAssertEqual(issues.count, 1)
        let issue = try XCTUnwrap(issues.first)
        for evidence in ["2025-08-08", "2025-08-09", "/monthly/calendar/month", "/monthly/calendar/effectiveMonth", "闰6月", "排盘月序"] {
            XCTAssertTrue(issue.contains(evidence), evidence)
        }
        let repaired = draft.replacingOccurrences(of: "农历月序号从6月进到7月", with: "两天农历均为闰六月，所选规则的排盘月序从6变为7")
        XCTAssertTrue(ReadingVerifier.deterministicIssues(in: repaired, history: history).isEmpty)
    }

    private let intro = "比较2025年8月8日与8月9日的紫微流月。"
    private let wrong = "农历月序号从6月进到7月"
    private func issues(_ text: String, _ history: [ChatMessage]) -> [String] {
        ZiweiMonthlyCalendarAssertions.issues(text, history: history)
    }
    private func mutate(_ history: [ChatMessage], index: Int = 1, path: String, value: JSONValue?) throws -> [ChatMessage] {
        var result = history
        let toolIndex = try XCTUnwrap(history.indices.filter { history[$0].role == .tool }.dropFirst(index).first)
        let root = try JSONDecoder().decode(JSONValue.self, from: Data(try XCTUnwrap(history[toolIndex].content).utf8))
        func replace(_ current: JSONValue, _ parts: ArraySlice<String>) -> JSONValue {
            guard let key = parts.first else { return value ?? .null }
            if case var .object(object) = current {
                if parts.count == 1 { object[key] = value }
                else if let child = object[key] { object[key] = replace(child, parts.dropFirst()) }
                return .object(object)
            }
            if case var .array(array) = current, let index = Int(key), array.indices.contains(index) {
                array[index] = replace(array[index], parts.dropFirst()); return .array(array)
            }
            return current
        }
        result[toolIndex].content = ReadingVerificationEvidence.encoded(replace(root, path.split(separator: "/").map(String.init)[...]))
        XCTAssertNotEqual(result[toolIndex].content, history[toolIndex].content, path)
        return result
    }

    func testComparisonSupportsLiteralChineseMonthsAndBothDateStyles() throws {
        let (_, history) = try archivedFailure()
        for header in [intro, "2025-08-08与2025-08-09的紫微流月。", "2025年8月8日与2025年8月9日的紫微流月。"] {
            for claim in [wrong, "农历月份由六月变为七月", "实际农历月从6月进入7月", "两天的农历月序号由六月变成七月"] {
                XCTAssertEqual(issues(header + "\n\n" + claim, history).count, 1, header + claim)
            }
        }
        XCTAssertEqual(issues("2025年8月9日与8月8日的紫微流月。\n\n农历月序号从7月进到6月", history).count, 1)
    }

    func testNegationReportHypothesisQuestionsAndCalculationSubjectDoNotAuthorizeRepair() throws {
        let (_, history) = try archivedFailure()
        for claim in ["不是" + wrong, "不能说" + wrong, "如果" + wrong, "假定：" + wrong,
                      "有人说：" + wrong, "原文：" + wrong, "有人声称。\n" + wrong,
                      wrong + "？", wrong + "吗", wrong + "，这个说法不成立", wrong + "，未确定",
                      "“" + wrong + "”", "`" + wrong + "`", "上次" + wrong,
                      "排盘采用的" + wrong, "计算用的" + wrong,
                      "排盘月序从6月进到7月", "农历均为闰六月，排盘月序从6变为7",
                      "农历月序号从5月进到6月", "另一日期：" + wrong] {
            XCTAssertTrue(issues(intro + "\n\n" + claim, history).isEmpty, claim)
        }
    }

    func testDatesMustBeExplicitAndUnambiguousInTheDraft() throws {
        let (_, history) = try archivedFailure()
        for header in ["两天的紫微流月。", "2025年8月8日的紫微流月。", "8月8日与8月9日的紫微流月。",
                       "2024年8月8日与8月9日的紫微流月。", "2025年8月7日与8月9日的紫微流月。",
                       "2025年8月8日与8月9日的八字流月。", "假设" + intro,
                       intro + "2025年8月10日也列入比较。", intro + "\n\n2026-08-08的紫微流月："] {
            XCTAssertTrue(issues(header + "\n\n" + wrong, history).isEmpty, header)
        }
        XCTAssertTrue(issues(intro + "\n\n2025年8月10日：" + wrong, history).isEmpty)
    }

    func testIndependentReviewFramingAndUnboundNumericDateCounterexamples() throws {
        let (_, history) = try archivedFailure()
        for claim in ["他说：" + wrong, "她说：" + wrong, "‘结论：" + wrong + "；待续’",
                      "8月10号：" + wrong, "8/10：" + wrong, "2025/08/10：" + wrong,
                      "农历2025年8月8日与8月9日：" + wrong] {
            XCTAssertTrue(issues(intro + "\n\n" + claim, history).isEmpty, claim)
        }
        XCTAssertTrue(issues("比较农历2025年8月8日与8月9日的紫微流月。\n\n" + wrong, history).isEmpty)
    }

    func testCallMustPrecedeOutputAndSharedSourceMustHaveGloballyUniqueIdentity() throws {
        let (_, history) = try archivedFailure()
        let callIndex = try XCTUnwrap(history.firstIndex { $0.toolCalls != nil })
        let outputIndex = try XCTUnwrap(history.firstIndex { $0.role == .tool })
        var reordered = history; reordered.swapAt(callIndex, outputIndex)
        XCTAssertTrue(issues(intro + "\n\n" + wrong, reordered).isEmpty)
        let donor = history[outputIndex]
        let donorCall = try XCTUnwrap(history[callIndex].toolCalls?.first)
        // A donor remains invalid even when duplication appears after the two
        // target receipts rather than in the earlier transport prefix.
        XCTAssertTrue(issues(intro + "\n\n" + wrong, history + [donor]).isEmpty)
        XCTAssertTrue(issues(intro + "\n\n" + wrong, history + [.assistantToolCalls([donorCall])]).isEmpty)
    }

    func testSameReceiptDateMethodAndSourceAreRequired() throws {
        let (_, history) = try archivedFailure()
        for path in ["monthly/calendar/month", "monthly/calendar/day", "monthly/calendar/isLeapMonth", "monthly/calendar/effectiveMonth",
                     "monthly/calendar/lunarYear", "monthly/method", "monthly/sourceId", "monthly/status", "monthly/appliesToBirth",
                     "ruleSources", "referenceDate", "referenceMode", "civilDate", "calculationDate", "method"] {
            XCTAssertTrue(issues(intro + "\n\n" + wrong, try mutate(history, path: path, value: nil)).isEmpty, path)
        }
        for (path, value) in [("monthly/method/leapMonth", JSONValue.string("whole-month")),
                              ("monthly/method/stemMethod", .string("natal-palace-stem")),
                              ("monthly/sourceId", .string("unknown")), ("monthly/calendar/effectiveMonth", .integer(8)),
                              ("monthly/calendar/day", .integer(31)), ("monthly/calendar/month", .integer(13)),
                              ("referenceMode", .string("question-instant")), ("civilDate", .string("2025-08-08")),
                              ("referenceDate", .string("2025-08-09T15:30:00Z")),
                              ("ruleSources/1/version", .string("2")), ("ruleSources/1/references/0/sha256", .string("bad")),
                              ("ruleSources/1/references", .null), ("ruleSources/1/references", .string("bad"))] {
            XCTAssertTrue(issues(intro + "\n\n" + wrong, try mutate(history, index: path.hasSuffix("sha256") ? 0 : 1, path: path, value: value)).isEmpty, path)
        }
    }

    func testConflictingAndSparseDuplicateReceiptsCannotAuthorizeCorrection() throws {
        let (_, history) = try archivedFailure()
        let duplicate = history.filter { $0.role == .tool }.last!
        XCTAssertTrue(issues(intro + "\n\n" + wrong, history + [duplicate]).isEmpty)
        let call = history.flatMap { $0.toolCalls ?? [] }.last!
        XCTAssertTrue(issues(intro + "\n\n" + wrong, history + [.assistantToolCalls([call])]).isEmpty)
        let altered = try mutate(history, path: "monthly/calendar/month", value: .integer(7))
        let output = try XCTUnwrap(altered.last { $0.role == .tool }?.content)
        let extra = [ChatMessage.assistantToolCalls([.init(id: "conflict", name: call.name, arguments: call.arguments)]),
                     .toolResult(.init(callID: "conflict", output: output))]
        XCTAssertTrue(issues(intro + "\n\n" + wrong, history + extra).isEmpty)
        let same = [ChatMessage.assistantToolCalls([.init(id: "same", name: call.name, arguments: call.arguments)]),
                    .toolResult(.init(callID: "same", output: try XCTUnwrap(duplicate.content)))]
        XCTAssertEqual(issues(intro + "\n\n" + wrong, history + same).count, 1)
    }

    func testArgumentDateCannotBeReplacedByAReceiptOrDifferentTool() throws {
        let (_, history) = try archivedFailure()
        for arguments: JSONValue in [["date": "2025-08-10", "withMonthly": true], ["date": "2025-08-09"], ["withMonthly": true]] {
            var altered = history
            for index in altered.indices where altered[index].toolCalls != nil {
                altered[index].toolCalls = altered[index].toolCalls?.map { call in
                    call.arguments == ["date": "2025-08-09", "withMonthly": true]
                        ? .init(id: call.id, name: call.name, arguments: arguments) : call
                }
            }
            XCTAssertTrue(issues(intro + "\n\n" + wrong, altered).isEmpty)
        }
    }

    func testRealLunarMonthChangeAndUnsplitDatesAreNotTheObservedDefect() throws {
        let (_, history) = try archivedFailure()
        var nextMonth = try mutate(history, path: "monthly/calendar/month", value: .integer(7))
        nextMonth = try mutate(nextMonth, path: "monthly/calendar/isLeapMonth", value: .bool(false))
        XCTAssertTrue(issues(intro + "\n\n" + wrong, nextMonth).isEmpty)
        var same = try mutate(history, path: "monthly/calendar/day", value: .integer(14))
        same = try mutate(same, path: "monthly/calendar/effectiveMonth", value: .integer(6))
        XCTAssertTrue(issues(intro + "\n\n" + wrong, same).isEmpty)
    }

    func testVerifierRepairsBeforeProviderReviewAndRejectsUnchangedFalseAcceptance() async throws {
        let (draft, history) = try archivedFailure()
        let repaired = intro + "\n\n两天实际农历均为闰六月；所选规则的排盘月序从6变为7。"
        var phases: [String] = []
        let answer = try await ReadingVerifier.verify(draft: draft, history: history, question: "核对两个日期") { request in
            if request.last?.content?.hasPrefix(ReadingVerifier.revision) == true {
                phases.append("revision")
                XCTAssertTrue(request.last?.content?.contains("/monthly/calendar/effectiveMonth") == true)
                return .text(repaired)
            }
            phases.append("review")
            return .text(#"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1,2],"issues":[]}"#)
        }
        XCTAssertEqual(answer, repaired)
        XCTAssertEqual(phases, ["revision", "review"])
        var requests = 0
        do {
            _ = try await ReadingVerifier.verify(draft: draft, history: history, question: "核对两个日期") { _ in
                requests += 1; return .text(draft)
            }
            XCTFail("Unchanged false draft must not reach an accepting reviewer")
        } catch let error as ReadingVerifier.Rejected { XCTAssertEqual(error.reason, "supported_rejection") }
        XCTAssertEqual(requests, 1)
    }

    func testActualCachedNatalMonthlyTransportAndRetryKeepOriginalCalendars() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../..")
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let birth: [String: Any] = ["year": 1990, "month": 8, "day": 15, "hour": 10, "minute": 0, "gender": "女", "longitude": 120]
        let natalData = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: ["command": "natal", "birth": birth]), as: UTF8.self))
        let natal = try JSONSerialization.jsonObject(with: natalData)
        let definitions = try ReadingIntent.definitions(from: await bridge.request(#"{"command":"tools"}"#), mode: "命理", question: "紫微流月", hasBirth: true)
        let calls = ["2025-08-08", "2025-08-09"].enumerated().map {
            ChatToolCall(id: "month-\($0.offset)", name: "get_ziwei_timing", arguments: ["date": .string($0.element), "withMonthly": true])
        }
        let context = try ToolContext(birth: nil, engineRevision: "f5-fixture", referenceDate: Date(timeIntervalSince1970: 1_738_123_200), mode: "命理")
        var executions = 0
        var persisted: [ToolReceipt] = []
        let orchestrator = ToolOrchestrator(complete: { messages, _ in
            messages.contains { $0.role == .tool } ? .text("ready") : .toolCalls(calls)
        }, execute: { call in
            executions += 1
            let arguments = try JSONSerialization.jsonObject(with: JSONEncoder().encode(call.arguments))
            let request: [String: Any] = ["command": "tool", "name": call.name, "birth": birth, "natal": natal, "now": "2025-01-29T04:00:00Z", "arguments": arguments]
            let response = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            let envelope = try JSONDecoder().decode(JSONValue.self, from: response)
            return .init(output: ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: envelope))))
        }, persistReceipt: { persisted.append($0) })
        let live = try await orchestrator.run(history: [], definitions: definitions, context: context)
        XCTAssertEqual(executions, 2)
        XCTAssertEqual(persisted.count, 2)
        let expected = issues(intro + "\n\n" + wrong, live.messages)
        XCTAssertEqual(expected.count, 1)
        XCTAssertTrue(live.messages.last { $0.role == .tool }?.content?.contains("reusedFacts") == true)
        var entry = ConversationEntry(role: "user", text: intro)
        entry.toolContext = context; entry.toolReceipts = persisted
        let replay = ReadingPrompt.history(from: [entry], currentUserID: entry.id, context: context)
        XCTAssertEqual(issues(intro + "\n\n" + wrong, replay), expected)
        let retry = try await orchestrator.run(history: replay, definitions: definitions, cachedReceipts: persisted, context: context)
        XCTAssertEqual(executions, 2, "Retry must reuse both original calculation receipts")
        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(issues(intro + "\n\n" + wrong, retry.messages), expected)
        for (index, receipt) in persisted.enumerated() {
            let root = try JSONDecoder().decode(JSONValue.self, from: Data(receipt.output.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/monthly/calendar/month", in: root), .integer(6))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/monthly/calendar/isLeapMonth", in: root), .bool(true))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/monthly/calendar/effectiveMonth", in: root), .integer(Int64(6 + index)))
        }
    }
}
