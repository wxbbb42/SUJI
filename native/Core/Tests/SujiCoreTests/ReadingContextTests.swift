import XCTest
@testable import SujiCore

final class ReadingContextTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_789_792_000)
    private var birth: BirthProfile { BirthProfile(year: 1990, month: 6, day: 1, hour: 12, minute: 0, gender: "女", city: "上海", longitude: 121.47) }

    func testFingerprintTracksBirthAndRevisionAndReferenceClock() throws {
        let context = try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date, mode: "命理")
        XCTAssertTrue(context.isValid)
        XCTAssertEqual(context, try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date, mode: "命理"))
        var changed = birth; changed.minute = 1
        XCTAssertNotEqual(context.birthFingerprint, try ToolContext(birth: changed, engineRevision: "revision-2", referenceDate: date, mode: "命理").birthFingerprint)
        XCTAssertNotEqual(context, try ToolContext(birth: birth, engineRevision: "revision-3", referenceDate: date, mode: "命理"))
        XCTAssertNotEqual(context, try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date.addingTimeInterval(1), mode: "命理"))
    }

    func testOldAndDifferentBirthReceiptsNeverBecomeCurrentToolEvidence() throws {
        let context = try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date, mode: "命理")
        let stale = try ToolContext(birth: nil, engineRevision: "revision-2", referenceDate: date, mode: "命理")
        var old = ConversationEntry(role: "user", text: "昨天呢")
        old.toolReceipts = [.init(callID: "old", name: "get_today_context", arguments: [:], output: "old-chart", context: context)]
        var current = ConversationEntry(role: "user", text: "今天呢")
        current.toolReceipts = [
            .init(callID: "wrong-birth", name: "get_today_context", arguments: [:], output: "wrong-chart", context: stale),
            .init(callID: "current", name: "get_today_context", arguments: [:], output: "current-chart", context: context),
        ]
        let messages = ReadingPrompt.history(from: [old, current], currentUserID: current.id, context: context)
        XCTAssertEqual(messages.filter { $0.role == .tool }.map(\.content), ["current-chart"])
        XCTAssertEqual(messages.last?.toolCallID, "current")
    }

    func testStaleRetryFailsBeforeModelOrEngineRuns() async throws {
        let context = try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date, mode: "起卦")
        let legacy = ToolReceipt(callID: "legacy", name: "cast_liuyao", arguments: [:], output: "{}")
        let orchestrator = ToolOrchestrator(complete: { _, _ in XCTFail("No model call"); return .text("") }, execute: { _ in XCTFail("No recast"); return .init(output: "{}") })
        do {
            _ = try await orchestrator.run(history: [], definitions: [], cachedReceipts: [legacy], context: context)
            XCTFail("Expected stale context")
        } catch { XCTAssertEqual(error as? ToolOrchestratorError, .staleContext) }
    }

    func testHistoryIsBoundedAndKeepsLatestQuestion() {
        let entries = (0..<20).map { ConversationEntry(role: $0 % 2 == 0 ? "assistant" : "user", text: String(repeating: "观察", count: 4_000)) }
        let messages = ReadingPrompt.history(from: entries, currentUserID: entries.last!.id, context: nil)
        XCTAssertLessThan(messages.count, 20)
        XCTAssertEqual(messages.last?.role, .user)
        XCTAssertLessThanOrEqual(messages.reduce(0) { $0 + ($1.content?.utf8.count ?? 0) }, 40_000)
    }

    func testLongGraphemesAndImportedQuestionsCannotRemoveCurrentUserTurn() {
        for text in [String(repeating:"👨‍👩‍👧‍👦",count:2_000),String(repeating:"字",count:14_000)] {
            let entry = ConversationEntry(role:"user",text:text)
            let history = ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:nil)
            XCTAssertEqual(history.count,1)
            XCTAssertEqual(history.first?.role,.user)
            XCTAssertLessThanOrEqual(history.first!.content!.utf8.count,24_000)
            XCTAssertTrue(history.first!.content!.contains("保留片段"))
        }
    }

    func testReceiptContextRoundTripsButLegacyArchivesStillDecode() throws {
        let context = try ToolContext(birth: birth, engineRevision: "revision-2", referenceDate: date, mode: "命理")
        let receipt = ToolReceipt(callID: "a", name: "get_today_context", arguments: [:], output: "{}", context: context)
        XCTAssertEqual(try JSONDecoder().decode(ToolReceipt.self, from: JSONEncoder().encode(receipt)), receipt)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as! [String: Any]
        legacy.removeValue(forKey: "context")
        XCTAssertNil(try JSONDecoder().decode(ToolReceipt.self, from: JSONSerialization.data(withJSONObject: legacy)).context)
    }

    func testReplayAndReviewKeepCompleteRuleDirectoryBesideItsOwnCall() throws {
        let context = try ToolContext(birth: nil, engineRevision: "source-directory", referenceDate: date, mode: "起卦")
        let source: JSONValue = ["id":"explicit-rule", "quote": .string(String(repeating: "source ", count: 4_200) + "完整原文保留"), "limitations": [], "established": false]
        var entry = ConversationEntry(role: "user", text: "核对依据")
        entry.toolReceipts = [ToolReceipt(callID: "directory-call", name: "cast_liuyao", arguments: [:],
            output: ReadingVerificationEvidence.encoded(JSONValue.object(["ruleSources": .array([source]), "lines": []])), context: context)]
        let history = ReadingPrompt.history(from: [entry], currentUserID: entry.id, context: context)
        let prefix = "完整规则来源目录（同轮工具证据）：\n"
        let directories = history.filter { $0.role == .system && ($0.content?.hasPrefix(prefix) ?? false) }
        XCTAssertEqual(directories.count, 1)
        let directory = try XCTUnwrap(directories.first)
        let metadata = try JSONDecoder().decode(JSONValue.self, from: Data(try XCTUnwrap(directory.content).dropFirst(prefix.count).utf8))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/toolCallID", in: metadata), "directory-call")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/ruleSources", in: metadata), .array([source]))
        XCTAssertLessThan(try XCTUnwrap(history.firstIndex(of: directory)), try XCTUnwrap(history.firstIndex { !($0.toolCalls ?? []).isEmpty }))
        let review = ReadingVerifier.messages(draft: "保留原文条件", history: history, question: entry.text)
        XCTAssertEqual(review.filter { $0.role == .system && ($0.content?.hasPrefix(prefix) ?? false) }, directories)
        XCTAssertFalse(review.contains { $0.role == .user && ($0.content?.contains(prefix) ?? false) })
    }

    func testFixedBeijingClockDoesNotApplyHistoricalDaylightSaving() throws {
        let profile = try birth.validated()
        let iso = ISO8601DateFormatter().string(from: profile.date!)
        XCTAssertEqual(iso, "1990-06-01T04:00:00Z")
    }
}
