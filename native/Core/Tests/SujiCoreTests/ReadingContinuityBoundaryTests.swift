import Foundation
import XCTest
@testable import SujiCore

/// Independent boundary review: context continuity must not silently replace a
/// new real-world question, or change the subject of a requested simplification.
final class ReadingContinuityBoundaryTests: XCTestCase {
    private func conversation(focus: ReadingDocument.Focus = .comparison) throws -> (ToolContext, [ConversationEntry]) {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/native-round6-results.json"))
        let report = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let record = (report["cases"] as! [[String: Any]])[0]
        let context = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: record["context"]!))
        let receipts = try JSONDecoder().decode([ToolReceipt].self, from: JSONSerialization.data(withJSONObject: record["receipts"]!))
        let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: receipts, context: context))
        var source = ConversationEntry(role: "user", text: "结合命盘比较扶抑用神和格局用神的差异")
        source.toolContext = context
        source.toolReceipts = receipts
        source.analysisMode = "命理"
        let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: focus)
        var reply = ConversationEntry(role: "assistant", text: answer.text)
        reply.readingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: source.id, focus: focus)
        return (context, [source, reply])
    }

    private func resolve(_ question: String, focus: ReadingDocument.Focus = .comparison) throws -> ReadingDocument.Focus? {
        let (context, old) = try conversation(focus: focus)
        let next = ConversationEntry(role: "user", text: question)
        return BaziReadingRequest.resolve(question: question, mode: "命理", entries: old + [next], currentUserID: next.id, context: context)
    }

    func testEverydayRelationshipsAndChoicesDoNotBecomeBaziClaims() throws {
        for question in ["我和父母的关系怎么改善？", "我有两个工作机会，该选哪个？", "简单说，我该怎样安排休息？", "那几个候选人，我该怎么比较？", "我们团队的强弱项怎么评估？"] {
            XCTAssertNil(try resolve(question), question)
        }
    }

    func testExplicitWithdrawalFromDivinationDoesNotInheritTheLastChart() throws {
        for question in ["不要谈命理，简单说我该怎么休息", "不想继续算了，我和朋友的关系很糟", "先放下命盘，我该选哪个工作？"] {
            XCTAssertNil(try resolve(question), question)
        }
    }

    func testSimplifyingASingleTopicPreservesThatTopic() throws {
        // The current overview claim compares strength and pattern; it contains
        // neither the requested climate excerpt nor the directed element edges.
        for focus in [ReadingDocument.Focus.climate, .relations, .strength, .pattern] {
            XCTAssertEqual(try resolve("简单说", focus: focus), focus, focus.rawValue)
            XCTAssertEqual(try resolve("一句话概括", focus: focus), focus, focus.rawValue)
        }
        XCTAssertEqual(try resolve("简单说", focus: .comparison), .overview)
    }

    func testContinuationTopicCannotPromoteOldReceiptsIntoNewEvidence() throws {
        let (oldContext, old) = try conversation()
        var next = ConversationEntry(role: "user", text: "简单说")
        next.date = oldContext.referenceDate.addingTimeInterval(120)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldContext)) as! [String: Any]
        object["referenceDate"] = next.date.timeIntervalSinceReferenceDate
        let context = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: object))
        let history = ReadingPrompt.history(from: old + [next], currentUserID: next.id, context: context)
        XCTAssertEqual(history.filter { $0.role == .user }.count, 2)
        XCTAssertEqual(history.filter { $0.role == .assistant }.count, 1)
        XCTAssertFalse(history.contains { $0.role == .tool || !($0.toolCalls ?? []).isEmpty })
    }

    func testFocusedFailureDoesNotPretendTheUserRequestedAFrameworkComparison() {
        for focus in [ReadingDocument.Focus.climate, .relations, .strength, .pattern] {
            let retained = BaziFrameworkReading.unavailableReply(hasBirth: true, focus: focus)
            XCTAssertFalse(retained.contains("命盘比较"), focus.rawValue)
            XCTAssertFalse(retained.contains("扶抑用神关注"), focus.rawValue)
            XCTAssertTrue(retained.contains("尚未取得"), focus.rawValue)
            XCTAssertTrue(retained.contains("出生资料已保留"), focus.rawValue)
            let missing = BaziFrameworkReading.unavailableReply(hasBirth: false, focus: focus)
            XCTAssertFalse(missing.contains("出生资料已保留"), focus.rawValue)
            XCTAssertTrue(missing.contains("补充出生资料"), focus.rawValue)
        }
    }

    private func attempt(callID: String, context: ToolContext, history: [ChatMessage], cached: [ToolReceipt] = [], hasBirth: Bool = true, output: String, fails: Bool = false) async throws -> (ToolOrchestrationResult, [ToolReceipt], Int) {
        var saved: [ToolReceipt] = []
        var executed = 0
        let orchestrator = ToolOrchestrator(complete: { messages, _ in
            BaziFrameworkReading.plan(callID: callID, history: messages, cachedReceipts: cached, context: context, hasBirth: hasBirth)
        }, execute: { _ in
            executed += 1
            if fails { throw URLError(.networkConnectionLost) }
            return ToolExecutionResult(output: output, evidence: ["Synthetic current calculation"])
        }, persistReceipt: { saved.append($0) })
        let result = try await orchestrator.run(history: history, definitions: [
            ChatToolDefinition(name: "get_domain", description: "八字资料", parameters: ["type": "object"])
        ], cachedReceipts: cached, context: context)
        return (result, saved, executed)
    }

    func testLocalPlanExecutesOnceAndReusesOnlyCompleteMatchingCache() async throws {
        let (context, entries) = try conversation()
        let original = try XCTUnwrap(entries[0].toolReceipts?.first)
        let history = [ChatMessage(role: .user, content: "我的调候用神呢？")]
        let first = try await attempt(callID: "independent-first", context: context, history: history, output: original.output)
        XCTAssertEqual(first.2, 1)
        XCTAssertEqual(first.1.count, 1)
        XCTAssertFalse(first.0.reachedRoundLimit)
        XCTAssertNotNil(BaziFrameworkReading.catalog(receipts: first.1, context: context))
        let replay = try await attempt(callID: "independent-retry", context: context, history: history, cached: first.1, output: original.output)
        XCTAssertEqual(replay.2, 0)
        XCTAssertTrue(replay.1.isEmpty)
    }

    func testNoBirthOrFailedAttemptDoesNotCreateReusableReceipts() async throws {
        let (context, entries) = try conversation()
        let original = try XCTUnwrap(entries[0].toolReceipts?.first)
        let history = [ChatMessage(role: .user, content: "解释调候")]
        let noBirth = try await attempt(callID: "no-birth", context: context, history: history, hasBirth: false, output: original.output)
        XCTAssertEqual(noBirth.2, 0)
        XCTAssertTrue(noBirth.1.isEmpty)
        let failed = try await attempt(callID: "failed-attempt", context: context, history: history, output: original.output, fails: true)
        XCTAssertEqual(failed.2, 1)
        XCTAssertTrue(failed.1.isEmpty)
        XCTAssertFalse(failed.0.reachedRoundLimit)
        let retried = try await attempt(callID: "fresh-after-failure", context: context, history: history, cached: failed.1, output: original.output)
        XCTAssertEqual(retried.2, 1)
        XCTAssertNotNil(BaziFrameworkReading.catalog(receipts: retried.1, context: context))
    }

    func testFreshRetryCanFetchAfterPartialReceiptButCannotHideTheConflict() async throws {
        let (context, entries) = try conversation()
        let original = try XCTUnwrap(entries[0].toolReceipts?.first)
        let partial = try await attempt(callID: "partial-attempt", context: context, history: [.init(role: .user, content: "简单说")], output: #"{"bazi":{}}"#)
        XCTAssertEqual(partial.1.count, 1, "A non-error tool result can persist while lacking claim fields")
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: partial.1, context: context))
        var user = entries[0]
        user.toolReceipts = partial.1
        let replayHistory = ReadingPrompt.history(from: [user], currentUserID: user.id, context: context)
        let retried = try await attempt(callID: "fresh-after-partial", context: context, history: replayHistory, cached: partial.1, output: original.output)
        XCTAssertEqual(retried.2, 1, "A retry needs an attempt ID distinct from persisted calls")
        XCTAssertEqual(retried.1.count, 1)
        XCTAssertNotNil(BaziFrameworkReading.catalog(receipts: retried.1, context: context))
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: partial.1 + retried.1, context: context), "Fetching again does not silently choose between inconsistent receipt fields")
    }
}
