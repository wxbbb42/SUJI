import XCTest
@testable import SujiCore

final class TodayReadingRequestTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_790_067_521)
    private var birth: BirthProfile {
        .init(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "上海", longitude: 120)
    }
    private var context: ToolContext { get throws {
        try ToolContext(birth: birth, engineRevision: "today-request-test", referenceDate: date, mode: "命理")
    } }
    // Current get_today_context field layout. No planner computes these facts.
    private let output = #"{"date":"2026-09-22","todayGanZhi":"己亥","yearGanZhi":"丙午","monthGanZhi":"丁酉","solarTerm":"白露"}"#
    private let call = ChatToolCall(id: "today-attempt", name: "get_today_context", arguments: [:])

    func testExplicitChineseTodayVariants() {
        for question in [
            "今天适合干什么", "今天适合做什么？", "今天适合做点什么呢？", "今天适合干点什么呀",
            "我今天该做什么", "今天我应该干什么", "我今日可以做什么", "今日适合干嘛？",
            "请问，今天适合做什么？", "  今天 适合做什么？\n", "今天有什么建议吗？",
            "今日需要注意什么", "今天应该注意什么呢", "今天有什么需要注意的？",
        ] { XCTAssertTrue(TodayReadingRequest.applies(question: question, mode: "命理"), question) }
    }

    func testExplicitEnglishTodayVariants() {
        for question in [
            "What should I do today?", "What can I do today?", "WHAT SHOULD I DO TODAY?",
            " What  should I do today ?\n", "What should I focus on today?", "What is today good for?",
            "What would be good for me to do today?", "What is good to do today?", "Any advice for today?",
            "Suggestions for today", "How should I spend today?", "Please, what should I do today?",
            "What should I do today, please?",
        ] { XCTAssertTrue(TodayReadingRequest.applies(question: question, mode: "命理"), question) }
    }

    func testEdgeControlsDoNotDefeatExplicitTodayQuestions() {
        for question in [
            "\u{8}What should I do today?", "\u{8}\t What should I do today? \u{0}\r\n",
            "\u{8}今天适合干什么？\u{0}", " \u{0}\t今天适合做什么？\u{8}\n ",
        ] { XCTAssertTrue(TodayReadingRequest.applies(question: question, mode: "命理"), question.debugDescription) }
    }

    func testInternalControlsAndMixedIntentRemainExcluded() {
        for question in [
            "What should I do to\u{8}day?", "今天适合干\u{8}什么？",
            "What should I\tdo today?", "今天\n适合干什么？",
            "\u{8}What should I do today?\u{0} Also tell me about tomorrow.\u{8}",
            "\u{8}今天适合干什么？\n也看看明年的运势\u{0}",
            "\u{8}What should I do today? No chart.\u{0}",
            "\u{8}今天适合干什么，不要排盘\u{0}",
        ] { XCTAssertFalse(TodayReadingRequest.applies(question: question, mode: "命理"), question.debugDescription) }
    }

    func testExcludesOtherModesAndNatalQuestionsWithoutExplicitTodayRequest() {
        for mode in ["倾诉", "向诉", "起卦", "", "unknown"] {
            for question in ["今天适合干什么", "What should I do today?"] {
                XCTAssertFalse(TodayReadingRequest.applies(question: question, mode: mode), mode)
            }
        }
        for question in ["", "我的命盘是什么", "我的日主是什么", "我的事业如何", "帮我看看命盘", "What is my birth chart?", "What should I do?", "今天", "today"] {
            XCTAssertFalse(TodayReadingRequest.applies(question: question, mode: "命理"), question)
        }
    }

    func testExcludesNegationsNoChartAndMethodSpecificRequests() {
        for question in [
            "今天不适合干什么", "不要告诉我今天适合干什么", "不用排盘，今天适合干什么",
            "今天适合干什么？不要看命盘", "今天适合干什么，只给生活建议，不用命理",
            "用奇门看看今天适合干什么", "六爻起卦，今天适合干什么", "今天适合干什么？用奇門",
            "Don't tell me what I should do today", "What should I not do today?",
            "No chart, what should I do today?", "What should I do today without astrology?",
            "Use Qimen: what should I do today?", "What should I do today? Use Liuyao.",
        ] { XCTAssertFalse(TodayReadingRequest.applies(question: question, mode: "命理"), question) }
    }

    func testExcludesOtherDatesMixedSubjectsAndQuotedRequests() {
        for question in [
            "明天适合干什么", "今天和明天适合干什么", "今天适合干什么，明天呢", "今天适合干什么？也看看明年的运势",
            "今天适合干什么，我的婚姻如何", "今天适合做什么投资", "今天适合做什么？我的命盘是什么",
            "今天适合结婚吗", "今天适合干什么工作", "解释一下“今天适合干什么”", "“今天适合干什么”",
            "What should I do tomorrow?", "What should I do today and tomorrow?", "Any advice for next week?",
            "What should I do today about my marriage?", "What should I do today, and what is my birth chart?",
            "What should I do today? Also tell me my career prospects.", "What should I do today at work?",
            "Translate: What should I do today?", "\"What should I do today?\"",
        ] { XCTAssertFalse(TodayReadingRequest.applies(question: question, mode: "命理"), question) }
    }

    private func receipt(context: ToolContext? = nil, output: String? = nil) -> ToolReceipt {
        .init(callID: "saved-today", name: "get_today_context", arguments: [:], output: output ?? self.output, context: context)
    }

    func testFreshPlanRequestsOneParameterlessTodayCall() throws {
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], context: try context, hasBirth: true), .toolCalls([call]))
    }

    func testMatchingCacheSkipsNewCallButUnrelatedOrStaleCacheDoesNot() throws {
        let context = try context
        let saved = receipt(context: context)
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], cachedReceipts: [saved], context: context, hasBirth: true), .text(""))
        var otherBirth = birth
        otherBirth.minute = 1
        let wrongContexts = try [
            ToolContext(birth: otherBirth, engineRevision: context.engineRevision, referenceDate: date, mode: "命理"),
            ToolContext(birth: birth, engineRevision: "other-engine", referenceDate: date, mode: "命理"),
            ToolContext(birth: birth, engineRevision: context.engineRevision, referenceDate: date.addingTimeInterval(1), mode: "命理"),
            ToolContext(birth: birth, engineRevision: context.engineRevision, referenceDate: date, mode: "起卦"),
        ]
        for wrong in wrongContexts {
            XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], cachedReceipts: [receipt(context: wrong)], context: context, hasBirth: true), .toolCalls([call]))
        }
        var unrelated = saved
        unrelated.name = "get_domain"
        var wrongArguments = saved
        wrongArguments.arguments = ["scope": "today"]
        for cached in [receipt(), unrelated, wrongArguments] {
            XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], cachedReceipts: [cached], context: context, hasBirth: true), .toolCalls([call]))
        }
    }

    func testFailedOrPartialCacheAllowsANewAttempt() throws {
        let context = try context
        for output in ["not JSON", "{}", "[]", #"{"error":"failed"}"#,
                       #"{"error":"failed","yearGanZhi":"丙午","monthGanZhi":"丁酉","todayGanZhi":"己亥","solarTerm":"白露"}"#,
                       #"{"yearGanZhi":"丙午","monthGanZhi":"丁酉","solarTerm":"白露"}"#,
                       #"{"yearGanZhi":"丙午","monthGanZhi":"丁酉","todayGanZhi":" ","solarTerm":"白露"}"#] {
            XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], cachedReceipts: [receipt(context: context, output: output)], context: context, hasBirth: true), .toolCalls([call]), output)
        }
    }

    func testNoBirthOrInvalidContextMakesNoCall() throws {
        let noBirth = try ToolContext(birth: nil, engineRevision: "today-request-test", referenceDate: date, mode: "命理")
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], context: noBirth, hasBirth: false), .text(""))
        for mode in ["倾诉", "起卦", "invalid"] {
            let context = try ToolContext(birth: birth, engineRevision: "today-request-test", referenceDate: date, mode: mode)
            XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], context: context, hasBirth: true), .text(""))
        }
        let invalid = try ToolContext(birth: birth, engineRevision: "", referenceDate: date, mode: "命理")
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [], context: invalid, hasBirth: true), .text(""))
    }

    func testAttemptIDStopsAfterSuccessFailureOrPendingCall() throws {
        let context = try context
        let pending = ChatMessage.assistantToolCalls([call])
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: [pending], context: context, hasBirth: true), .text(""))
        for output in [output, #"{"error":"calculation failed"}"#, "malformed"] {
            let result = ChatMessage.toolResult(.init(callID: call.id, output: output))
            for history in [[pending, result], [result]] {
                XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: history, context: context, hasBirth: true), .text(""))
            }
        }
        let old = receipt(context: context)
        let historical = [ChatMessage.assistantToolCalls([old.call]), .toolResult(.init(callID: old.callID, output: old.output))]
        XCTAssertEqual(TodayReadingRequest.plan(callID: call.id, history: historical, context: context, hasBirth: true), .toolCalls([call]), "Historical tool messages alone cannot establish current receipt provenance")
    }

    private func attempt(callID: String = "today-attempt", context: ToolContext, cached: [ToolReceipt] = [], history: [ChatMessage] = [], hasBirth: Bool = true, failure: Bool = false, output: String? = nil) async throws -> (ToolOrchestrationResult, [ToolReceipt], Int) {
        var executed = 0
        var saved: [ToolReceipt] = []
        let orchestrator = ToolOrchestrator(complete: { messages, _ in
            TodayReadingRequest.plan(callID: callID, history: messages, cachedReceipts: cached, context: context, hasBirth: hasBirth)
        }, execute: { call in
            XCTAssertEqual(call, .init(id: callID, name: "get_today_context", arguments: [:]))
            executed += 1
            if failure { throw URLError(.networkConnectionLost) }
            return .init(output: output ?? self.output, evidence: ["Current today facts"])
        }, persistReceipt: { saved.append($0) })
        let definitions = [ChatToolDefinition(name: "get_today_context", description: "今日历法", parameters: ["type": "object", "properties": [:], "additionalProperties": false])]
        let result = try await orchestrator.run(history: history, definitions: definitions, cachedReceipts: cached, context: context)
        return (result, saved, executed)
    }

    func testOrchestratorPersistsOnceAndReusesSameContextOnRetry() async throws {
        let context = try context
        let first = try await attempt(context: context, history: [.init(role: .user, content: "What should I do today?")])
        XCTAssertEqual(first.2, 1)
        XCTAssertEqual(first.1.count, 1)
        XCTAssertEqual(first.1.first?.context, context)
        XCTAssertEqual(first.0.messages.filter { $0.role == .tool }.map(\.content), [output])
        XCTAssertFalse(first.0.reachedRoundLimit)

        var question = ConversationEntry(role: "user", text: "What should I do today?")
        question.toolReceipts = first.1
        let replay = ReadingPrompt.history(from: [question], currentUserID: question.id, context: context)
        let retry = try await attempt(callID: "new-retry-id", context: context, cached: first.1, history: replay)
        XCTAssertEqual(retry.2, 0)
        XCTAssertTrue(retry.1.isEmpty)
        XCTAssertEqual(retry.0.messages.filter { $0.role == .tool }.map(\.content), [output])
        XCTAssertFalse(retry.0.reachedRoundLimit)
    }

    func testCurrentBundledTodayOutputIsReusable() async throws {
        let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        let bridge = try MingliBridge(scriptURL: resources.appendingPathComponent("mingli.js"))
        let request: [String: Any] = [
            "command": "tool", "name": "get_today_context", "arguments": [String: String](),
            "now": ISO8601DateFormatter().string(from: date),
            "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth)),
        ]
        let data = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
        let response = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = try XCTUnwrap(response["result"] as? [String: Any])
        XCTAssertNotNil(result["todayGanZhi"])
        XCTAssertNil(result["dayGanZhi"])
        let provenance = try XCTUnwrap(result["provenance"] as? [String: Any])
        let revision = try XCTUnwrap(provenance["engineRevision"] as? String)
        let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: date, mode: "命理")
        let output = String(decoding: try JSONSerialization.data(withJSONObject: result), as: UTF8.self)
        let first = try await attempt(context: context, output: output)
        XCTAssertEqual(first.2, 1)
        XCTAssertEqual(first.1.count, 1)
        XCTAssertEqual(TodayReadingRequest.plan(callID: "bundled-retry", history: first.0.messages, cachedReceipts: first.1, context: context, hasBirth: true), .text(""))
    }

    func testOrchestratorStopsOnFailureAndDoesNotPersistAReceipt() async throws {
        let context = try context
        for throwsError in [false, true] {
            let failed = try await attempt(context: context, failure: throwsError, output: #"{"error":"synthetic_calculation_failure"}"#)
            XCTAssertEqual(failed.2, 1)
            XCTAssertTrue(failed.1.isEmpty)
            XCTAssertEqual(failed.0.messages.filter { $0.role == .tool }.count, 1)
            XCTAssertFalse(failed.0.reachedRoundLimit)
            XCTAssertEqual(TodayReadingRequest.plan(callID: "explicit-retry", history: failed.0.messages, context: context, hasBirth: true), .toolCalls([.init(id: "explicit-retry", name: "get_today_context", arguments: [:])]))
        }
        let noBirth = try await attempt(context: context, hasBirth: false)
        XCTAssertEqual(noBirth.2, 0)
        XCTAssertTrue(noBirth.1.isEmpty)
        XCTAssertTrue(noBirth.0.messages.isEmpty)
        XCTAssertFalse(noBirth.0.reachedRoundLimit)
    }
}
