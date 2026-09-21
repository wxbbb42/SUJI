import Foundation
import XCTest
@testable import SujiCore

final class ReflectionConversationTests: XCTestCase {
    private var birth: BirthProfile { .init(year: 1990, month: 6, day: 1, hour: 12, minute: 0, gender: "女", city: "上海", longitude: 121.47) }
    private func context() throws -> ToolContext {
        try .init(birth: birth, engineRevision: "bundle-v2", referenceDate: Date(timeIntervalSince1970: 1_789_792_000), mode: "倾诉")
    }
    private func key(birth: BirthProfile? = nil, revision: String = "v2", data: String = #"{"a":1,"b":2}"#) -> String {
        ReflectionConversation.storageKey(base: "calibration:1990", context: data, birth: birth ?? self.birth, engineRevision: revision)
    }

    func testIdentityIncludesFullBirthEngineAndCandidateContext() {
        var changedGender = birth; changedGender.gender = "男"
        var changedLongitude = birth; changedLongitude.longitude = 87.62
        XCTAssertEqual(changedGender.label, birth.label)
        XCTAssertEqual(changedLongitude.label, birth.label)
        XCTAssertNotEqual(key(), key(birth: changedGender))
        XCTAssertNotEqual(key(), key(birth: changedLongitude))
        XCTAssertNotEqual(key(), key(revision: "v3"))
        XCTAssertNotEqual(key(), key(data: #"{"a":1,"b":3}"#))
        XCTAssertEqual(key(), key(data: #"{ "b": 2, "a": 1 }"#))
        XCTAssertFalse(key().contains("1990"))
    }

    func testFailedAndCancelledAttemptsRetryTheSamePendingQuestionWithoutAdvancing() throws {
        let context = try context()
        var conversation = ReflectionConversation()
        let original = try conversation.begin("从一个问题开始", retry: false, context: context)
        // A failed network request or cancelled stream never invokes complete.
        for _ in 0..<3 {
            let retried = try conversation.begin("", retry: true, context: context)
            XCTAssertEqual(retried.id, original.id)
            XCTAssertEqual(retried.text, original.text)
            XCTAssertEqual(conversation.entries.count, 1)
            XCTAssertEqual(conversation.completedReplyCount, 0)
            XCTAssertEqual(conversation.interviewPhase, .question(1))
        }
        XCTAssertThrowsError(try conversation.begin("新问题", retry: false, context: context))
        try conversation.complete("你记得当时的大致生活环境吗？", userID: original.id, context: context)
        XCTAssertEqual(conversation.completedReplyCount, 1)
        XCTAssertEqual(conversation.interviewPhase, .question(2))
        XCTAssertThrowsError(try conversation.complete("重复完成", userID: original.id, context: context))
        XCTAssertThrowsError(try conversation.begin("", retry: true, context: context))
    }

    func testPendingQuestionSurvivesLocalRestartButImportedHistoryIsReadOnly() throws {
        let context = try context()
        var conversation = ReflectionConversation()
        let pending = try conversation.begin("不太确定", retry: false, context: context)
        var state = AppState(); state.reflections = ["key": conversation.entries]
        let raw = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(AppState.self, from: raw)
        var resumed = ReflectionConversation(entries: try XCTUnwrap(restored.reflections?["key"]))
        XCTAssertEqual(try resumed.begin("", retry: true, context: context).id, pending.id)
        XCTAssertEqual(resumed.completedReplyCount, 0)
        let imported = try ArchiveCodec.decode(raw)
        XCTAssertTrue(try XCTUnwrap(imported.reflections?["key"]).allSatisfy { $0.toolContext == nil })
    }

    func testFiveCompletedQuestionsLeadToSummaryAndUnknownAnswersRemainUnknown() throws {
        let context = try context()
        var conversation = ReflectionConversation()
        for number in 1...5 {
            XCTAssertEqual(conversation.interviewPhase, .question(number))
            let user = try conversation.begin(number == 1 ? "开始" : "不记得，跳过", retry: false, context: context)
            try conversation.complete("第\(number)个开放问题？", userID: user.id, context: context)
        }
        XCTAssertEqual(conversation.interviewPhase, .summary)
        XCTAssertTrue(conversation.interviewInstruction.contains("不再提出第六个问题"))
        XCTAssertTrue(conversation.interviewInstruction.contains("不算任何候选的支持或反证"))
        let answer = try conversation.begin("仍然不确定", retry: false, context: context)
        try conversation.complete("资料不足，无法区分这些候选。", userID: answer.id, context: context)
        XCTAssertEqual(conversation.interviewPhase, .summary)
        XCTAssertEqual(conversation.entries.filter { $0.text == "不记得，跳过" }.count, 4)
        let supplemental = try conversation.begin("我找到了一条旧记录", retry: false, context: context)
        XCTAssertEqual(conversation.interviewPhase, .summary)
        XCTAssertEqual(supplemental.text, "我找到了一条旧记录")
    }

    func testEmptyOversizedAndWrongTurnRepliesCannotAdvanceTheInterview() throws {
        let context = try context()
        var conversation = ReflectionConversation()
        XCTAssertThrowsError(try conversation.begin(String(repeating: "👨‍👩‍👧‍👦", count: 2_000), retry: false, context: context))
        let user = try conversation.begin("开始", retry: false, context: context)
        XCTAssertThrowsError(try conversation.complete(" ", userID: user.id, context: context))
        XCTAssertThrowsError(try conversation.complete(String(repeating: "答", count: 20_001), userID: user.id, context: context))
        XCTAssertThrowsError(try conversation.complete("正确内容，错误回合", userID: UUID(), context: context))
        XCTAssertEqual(conversation.completedReplyCount, 0)
        XCTAssertEqual(conversation.pendingEntry?.id, user.id)
    }

    func testChangedIdentityAndImportedSessionsRemainDiscoverableWithoutJoiningCurrentHistory() throws {
        let current = try context()
        var active = ConversationEntry(role: "user", text: "当前资料")
        active.toolContext = current
        var old = ConversationEntry(role: "assistant", text: "旧资料下的回信")
        old.toolContext = current
        let imported = ConversationEntry(role: "assistant", text: "导入记录，没有计算身份")
        let oldKey = key(revision: "older-engine")
        let history = ReflectionConversation.archivedSessions([
            key(): [active, imported], oldKey: [old], "calibration:legacy": [imported], "empty": [],
        ], currentKey: key(), context: current)
        XCTAssertEqual(Set(history.map(\.id)), Set([key(), oldKey, "calibration:legacy"]))
        XCTAssertFalse(history.flatMap(\.entries).contains { $0.id == active.id })
        XCTAssertEqual(history.first { $0.id == oldKey }?.entries.map(\.text), [old.text])
        XCTAssertEqual(history.first { $0.id == key() }?.entries.map(\.text), [imported.text])
    }
}
