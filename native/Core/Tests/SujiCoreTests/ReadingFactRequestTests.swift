import XCTest
@testable import SujiCore

final class ReadingFactRequestTests: XCTestCase {
    private func context(_ birth: BirthProfile? = nil, mode: String = "命理") throws -> ToolContext {
        try .init(birth: birth, engineRevision: "synthetic", referenceDate: Date(timeIntervalSince1970: 1790000000), mode: mode)
    }
    func testExplicitPersonalTopicsCannotFinishPlanningWithoutAnyAttempt() throws {
        let context = try context()
        for (question, tool) in [("我的财运怎么样", "get_domain"), ("帮我解释一下我的八字四柱，日主是什么意思？", "get_domain"), ("用紫微看我的命宫", "get_ziwei_palace"), ("我几岁能有孩子", "get_bazi_star"), ("我现在走什么大运", "get_timing")] {
            let calls = ReadingFactRequest.missingCalls(question: question, context: context, hasBirth: true, history: [], entries: [], currentUserID: UUID())
            XCTAssertEqual(calls.first?.name, tool, question)
            XCTAssertFalse(calls.contains { ["cast_liuyao", "setup_qimen"].contains($0.name) })
        }
    }
    func testClarificationRefusalsAndAlreadyAttemptedToolsDoNotForceFacts() throws {
        let context = try context()
        for question in ["帮我看看呗", "最近不太顺，咋回事啊", "什么是八字", "不用命理，我只想谈工作", "不要计算财运", "请用奇门看事业", "我朋友的八字怎么样", "不要看事业，只看感情"] {
            XCTAssertTrue(ReadingFactRequest.missingCalls(question: question, context: context, hasBirth: true, history: [], entries: [], currentUserID: UUID()).isEmpty, question)
        }
        let attempted: [ChatMessage] = [.toolResult(.init(callID: "failure", output: #"{"error":"actual failure"}"#))]
        XCTAssertTrue(ReadingFactRequest.missingCalls(question: "我的财运", context: context, hasBirth: true, history: attempted, entries: [], currentUserID: UUID()).isEmpty)
        XCTAssertTrue(ReadingFactRequest.missingCalls(question: "我的财运", context: context, hasBirth: false, history: [], entries: [], currentUserID: UUID()).isEmpty)
        XCTAssertTrue(ReadingFactRequest.missingCalls(question: "我的财运", context: try self.context(mode: "倾诉"), hasBirth: true, history: [], entries: [], currentUserID: UUID()).isEmpty)
    }
    func testVagueQuestionsHaveASpecificClarificationInsteadOfAFakeToolFailure() {
        for question in ["帮我看看呗", "最近不太顺，咋回事啊", "帮我算算", "最近不顺怎么办？"] {
            let reply = ReadingFactRequest.clarification(question: question, mode: "命理")
            XCTAssertNotNil(reply, question)
            XCTAssertFalse(reply?.contains("取数") == true)
            XCTAssertFalse(reply?.contains("出生") == true)
        }
        for question in ["我的财运怎么样", "帮我看看呗，今天面试", "我几岁有孩子", "那日主和月令之间是什么关系", "那目前能看出什么，哪些还不能确定？"] {
            XCTAssertNil(ReadingFactRequest.clarification(question: question, mode: "命理"), question)
        }
        XCTAssertNil(ReadingFactRequest.clarification(question: "帮我看看呗", mode: "起卦"))
    }

    func testBriefFollowupReacquiresOnlySameProfileNatalFactsAndNeverReplaysProse() throws {
        let context = try context()
        var previous = ConversationEntry(role: "user", text: "我几岁有孩子")
        previous.toolContext = context
        previous.toolReceipts = [.init(callID: "old", name: "get_bazi_star", arguments: ["person": "子女"], output: #"{"person":"子女","relevantShiShen":["食神","伤官"]}"#, context: context)]
        let answer = ConversationEntry(role: "assistant", text: "Untrusted prose must not establish facts")
        let next = ConversationEntry(role: "user", text: "那目前能看出什么，哪些还不能确定？")
        let entries = [previous, answer, next]
        let calls = ReadingFactRequest.missingCalls(question: next.text, context: context, hasBirth: true, history: [], entries: entries, currentUserID: next.id)
        XCTAssertEqual(calls.map(\.name), ["get_bazi_star"])
        XCTAssertEqual(calls.first?.arguments, ["person": "子女"])
        XCTAssertNotEqual(calls.first?.id, "old")
        let changed = try self.context(.init(year: 1991, month: 2, day: 3, hour: 12, minute: 0, gender: "男", city: "合成", longitude: 120))
        XCTAssertTrue(ReadingFactRequest.missingCalls(question: next.text, context: changed, hasBirth: true, history: [], entries: entries, currentUserID: next.id).isEmpty)
        XCTAssertTrue(ReadingFactRequest.missingCalls(question: "换个话题", context: context, hasBirth: true, history: [], entries: entries, currentUserID: next.id).isEmpty)
    }
}
