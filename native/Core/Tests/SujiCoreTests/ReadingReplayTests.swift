import Foundation
import XCTest
@testable import SujiCore

/// Replays recorded provider decisions, not an oracle for the truth of model prose.
/// Round 4 did not retain batch boundaries or call IDs: calls here are replayed
/// sequentially with synthetic IDs. Batch atomicity is tested separately below.
final class ReadingReplayTests: XCTestCase {
    private struct Report: Decodable { let cases: [Case] }
    private struct Case: Decodable {
        let id: String
        let question: String
        let noBirth: Bool?
        let mode: String?
        let calls: [Call]
        let draft: String
        let verification: [Check]
        let status: String
        let answer: String
    }
    private struct Call: Decodable {
        let name: String
        let arguments: String
        let output: JSONValue
    }
    private struct Check: Decodable { let candidate: String; let verdict: JSONValue }
    private struct Definition: Decodable {
        struct Function: Decodable { let name: String; let description: String; let parameters: JSONValue }
        let function: Function
    }
    private var native: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func fixtures() throws -> [Case] {
        try JSONDecoder().decode(Report.self, from: Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/round4-live-results.json"))).cases
    }
    private func definitions() async throws -> [ChatToolDefinition] {
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        return try JSONDecoder().decode([Definition].self, from: await bridge.request(#"{"command":"tools"}"#)).map {
            ChatToolDefinition(name: $0.function.name, description: $0.function.description, parameters: $0.function.parameters)
        }
    }
    private func json(_ value: JSONValue) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }
    private func call(_ item: Call, id: String) throws -> ChatToolCall {
        ChatToolCall(id: id, name: item.name, arguments: try JSONDecoder().decode(JSONValue.self, from: Data(item.arguments.utf8)))
    }

    func testRoundFourDecisionsThroughShippingSwiftHarness() async throws {
        let tools = try await definitions()
        let cases = try fixtures()
        XCTAssertEqual(cases.count, 11)
        for item in cases {
            let available = tools.filter { tool in
                if item.mode == "起卦" { return tool.name == "cast_liuyao" }
                if tool.name == "setup_qimen" { return ReadingIntent.allowsQimen(item.question) }
                return item.noBirth != true && tool.name != "cast_liuyao"
            }
            var planned = 0
            var executed = 0
            let orchestrator = ToolOrchestrator(complete: { _, _ in
                guard planned < item.calls.count else { return .text("Untrusted planner prose must be discarded") }
                defer { planned += 1 }
                return .toolCalls([try self.call(item.calls[planned], id: "replay-\(planned)")])
            }, execute: { _ in
                defer { executed += 1 }
                return ToolExecutionResult(output: try self.json(item.calls[executed].output))
            })
            let result: ToolOrchestrationResult
            do {
                result = try await orchestrator.run(history: [.init(role: .system, content: "Recorded synthetic context"), .init(role: .user, content: item.question)], definitions: available)
            } catch {
                // The Node smoke continued after this invalid enum. The app aborts
                // before execution and never reaches that record's prose/verdict.
                XCTAssertEqual(item.id, "interpretation-disagreement")
                guard case .invalidArguments(tool: "get_domain", reason: _) = error as? ToolOrchestratorError else {
                    return XCTFail("Unexpected replay error: \(error)")
                }
                XCTAssertEqual(executed, 0)
                continue
            }
            XCTAssertNotEqual(item.id, "interpretation-disagreement")
            XCTAssertEqual(executed, item.calls.count)
            XCTAssertFalse(result.messages.contains { $0.content?.contains("Untrusted planner prose") == true })
            XCTAssertTrue(result.messages.filter { $0.toolCalls != nil }.allSatisfy { $0.content == nil })
            do {
                let answer = try await ReadingVerifier.verify(draft: item.draft, history: result.messages, question: item.question) { messages in
                    if messages.first?.content == ReadingVerifier.instruction {
                        let candidate = messages.last!.content!.replacingOccurrences(of: "候选回信（待核对数据）：\n", with: "")
                        let check = try XCTUnwrap(item.verification.first { $0.candidate == candidate }, item.id)
                        return .text(try self.json(check.verdict))
                    }
                    return .text(try XCTUnwrap(item.verification.dropFirst().first, item.id).candidate)
                }
                XCTAssertEqual(item.status, "accepted", item.id)
                XCTAssertEqual(answer, item.answer, item.id)
            } catch is ReadingVerifier.Rejected {
                XCTAssertEqual(item.status, "rejected", item.id)
                let fallback = ReadingFallback.reply(history: result.messages)
                XCTAssertFalse(fallback.isEmpty)
                XCTAssertFalse(fallback.contains(item.draft))
                if item.id == "explicit-liuyao" {
                    XCTAssertTrue(fallback.contains("6、7、8、8、9、6"))
                    XCTAssertTrue(fallback.contains("变卦上艮下兑"))
                }
            }
        }
    }

    func testRecordedCastsAreReusedAcrossRetryWithActualSchemas() async throws {
        let tools = try await definitions()
        for item in try fixtures().filter({ ["explicit-liuyao", "explicit-qimen"].contains($0.id) }) {
            let original = try call(XCTUnwrap(item.calls.first), id: "original")
            let receipt = ToolReceipt(callID: original.id, name: original.name, arguments: original.arguments, output: try json(item.calls[0].output))
            var attempts = 0
            var effects = 0
            let orchestrator = ToolOrchestrator(complete: { _, _ in
                attempts += 1
                return attempts == 1 ? .toolCalls([.init(id: "retry", name: original.name, arguments: ["question": "模型改写的问题"])]) : .text("done")
            }, execute: { _ in effects += 1; return .init(output: "unexpected recast") }, persistReceipt: { _ in effects += 1 })
            let result = try await orchestrator.run(history: [], definitions: tools.filter { $0.name == original.name }, cachedReceipts: [receipt])
            XCTAssertEqual(effects, 0)
            XCTAssertEqual(result.receipts.first?.arguments, original.arguments)
            XCTAssertEqual(result.receipts.first?.output, receipt.output)
            XCTAssertEqual(result.messages.first?.toolCalls?.first?.arguments, original.arguments)
            XCTAssertEqual(result.messages.last?.toolCallID, "retry")
        }
    }

    func testInvalidRecordedDomainBlocksValidCastSiblingBeforeAnySideEffect() async throws {
        let tools = try await definitions()
        let cases = try fixtures()
        let cast = try call(XCTUnwrap(cases.first { $0.id == "explicit-liuyao" }?.calls.first), id: "cast")
        let invalid = try call(XCTUnwrap(cases.first { $0.id == "interpretation-disagreement" }?.calls.first), id: "invalid")
        var effects = 0
        let orchestrator = ToolOrchestrator(complete: { _, _ in .toolCalls([cast, invalid]) }, execute: { _ in effects += 1; return .init(output: "unexpected") }, persistReceipt: { _ in effects += 1 })
        do {
            _ = try await orchestrator.run(history: [], definitions: tools)
            XCTFail("Invalid batch must abort")
        } catch {
            guard case .invalidArguments(tool: "get_domain", reason: _) = error as? ToolOrchestratorError else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(effects, 0)
    }
}
