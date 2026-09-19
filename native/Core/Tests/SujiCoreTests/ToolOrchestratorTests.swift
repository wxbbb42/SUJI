import Foundation
import XCTest
@testable import SujiCore

final class ToolOrchestratorTests: XCTestCase {
    func testPreservesHistoryAndPairsAssistantCallWithMatchingToolResult() async throws {
        let model = ModelStub([
            .toolCalls([ChatToolCall(id: "call-7", name: "get_today_context", arguments: ["scope": "today"])]),
            .text("可以慢一点。"),
        ])
        let executed = CallRecorder()
        let saved = ReceiptRecorder()
        let history = [
            ChatMessage(role: .system, content: "system + birth context"),
            ChatMessage(role: .user, content: "上一问"),
            ChatMessage(role: .assistant, content: "上一答"),
            ChatMessage(role: .user, content: "今天呢"),
        ]
        let orchestrator = ToolOrchestrator(
            complete: { messages, tools in
                await model.complete(messages: messages, tools: tools)
            },
            execute: { call in
                await executed.record(call)
                return ToolExecutionResult(output: #"{"solarTerm":"白露"}"#, evidence: ["节气 · 白露"])
            },
            persistReceipt: { receipt in await saved.record(receipt) }
        )

        let result = try await orchestrator.run(history: history, definitions: [todayDefinition])

        XCTAssertEqual(Array(result.messages.prefix(history.count)), history)
        XCTAssertEqual(result.messages[history.count].toolCalls?.first?.id, "call-7")
        XCTAssertEqual(result.messages[history.count + 1].role, .tool)
        XCTAssertEqual(result.messages[history.count + 1].toolCallID, "call-7")
        XCTAssertEqual(result.messages[history.count + 1].content, #"{"solarTerm":"白露"}"#)
        XCTAssertEqual(result.messages.last?.role, .tool)
        XCTAssertFalse(result.messages.contains { $0.content == "可以慢一点。" }, "An ungrounded planning draft must not become evidence for the final reply")
        XCTAssertEqual(result.evidence, ["节气 · 白露"])
        let executedIDs = await executed.values().map(\.id)
        let savedIDs = await saved.values().map(\.callID)
        XCTAssertEqual(executedIDs, ["call-7"])
        XCTAssertEqual(savedIDs, ["call-7"])

        let modelCalls = await model.recordedMessages()
        XCTAssertEqual(Array(modelCalls[0].prefix(history.count)), history)
        XCTAssertEqual(modelCalls[1][history.count].toolCalls?.first?.id, "call-7")
        XCTAssertEqual(modelCalls[1][history.count + 1].toolCallID, "call-7")
    }

    func testRejectsUnknownToolAndRequiredTypeAndEnumViolationsBeforeExecution() async throws {
        let cases: [(ChatToolCall, ToolOrchestratorError)] = [
            (
                ChatToolCall(id: "unknown", name: "delete_everything", arguments: [:]),
                .unknownTool("delete_everything")
            ),
            (
                ChatToolCall(id: "missing", name: "get_today_context", arguments: [:]),
                .invalidArguments(tool: "get_today_context", reason: "缺少必填参数 arguments.scope")
            ),
            (
                ChatToolCall(id: "type", name: "get_today_context", arguments: ["scope": 7]),
                .invalidArguments(tool: "get_today_context", reason: "arguments.scope 应为 string")
            ),
            (
                ChatToolCall(id: "enum", name: "get_today_context", arguments: ["scope": "tomorrow"]),
                .invalidArguments(tool: "get_today_context", reason: "arguments.scope 不在允许值中")
            ),
        ]

        for (call, expected) in cases {
            let executions = CallRecorder()
            let orchestrator = ToolOrchestrator(
                complete: { _, _ in .toolCalls([call]) },
                execute: { call in
                    await executions.record(call)
                    return ToolExecutionResult(output: "unexpected")
                }
            )
            do {
                _ = try await orchestrator.run(history: [], definitions: [todayDefinition])
                XCTFail("Expected \(expected)")
            } catch {
                XCTAssertEqual(error as? ToolOrchestratorError, expected)
            }
            let recordedExecutions = await executions.values()
            XCTAssertTrue(recordedExecutions.isEmpty)
        }
    }

    func testEnforcesEightCallAndFiveRoundCaps() async throws {
        let nineCalls = (0 ..< 9).map {
            ChatToolCall(id: "call-\($0)", name: "get_today_context", arguments: ["scope": "today"])
        }
        let callCap = ToolOrchestrator(
            complete: { _, _ in .toolCalls(nineCalls) },
            execute: { _ in ToolExecutionResult(output: "unexpected") }
        )
        do {
            _ = try await callCap.run(history: [], definitions: [todayDefinition])
            XCTFail("Nine calls must be rejected")
        } catch {
            XCTAssertEqual(error as? ToolOrchestratorError, .tooManyCalls(limit: 8))
        }

        let rounds = Counter()
        let roundCap = ToolOrchestrator(
            complete: { _, _ in
                let index = await rounds.increment()
                return .toolCalls([
                    ChatToolCall(id: "round-\(index)", name: "get_today_context", arguments: ["scope": "today"]),
                ])
            },
            execute: { _ in ToolExecutionResult(output: "{}") }
        )
        let result = try await roundCap.run(history: [], definitions: [todayDefinition])
        let roundCount = await rounds.value()
        XCTAssertTrue(result.reachedRoundLimit)
        XCTAssertEqual(roundCount, 5)
        XCTAssertEqual(result.receipts.count, 5)
    }

    func testRetryReusesCachedLiuyaoWithoutExecutingOrPersistingAgain() async throws {
        let cached = ToolReceipt(
            callID: "original-cast",
            name: "cast_liuyao",
            arguments: ["question": "要不要换工作"],
            output: #"{"benGua":{"name":"谦"}}"#,
            evidence: ["主卦 · 谦"],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let executions = CallRecorder()
        let saved = ReceiptRecorder()
        let model = ModelStub([
            .toolCalls([
                ChatToolCall(id: "retry-call", name: "cast_liuyao", arguments: ["question": "再次问同一件事"]),
            ]),
            .text("沿用刚才的卦，只补充行动建议。"),
        ])
        let orchestrator = ToolOrchestrator(
            complete: { messages, tools in await model.complete(messages: messages, tools: tools) },
            execute: { call in
                await executions.record(call)
                return ToolExecutionResult(output: "rerolled")
            },
            persistReceipt: { receipt in await saved.record(receipt) }
        )

        let result = try await orchestrator.run(
            history: [ChatMessage(role: .user, content: "要不要换工作")],
            definitions: [liuyaoDefinition],
            cachedReceipts: [cached]
        )

        let retryExecutions = await executions.values()
        let retrySaves = await saved.values()
        XCTAssertTrue(retryExecutions.isEmpty)
        XCTAssertTrue(retrySaves.isEmpty)
        XCTAssertEqual(result.receipts.first?.output, cached.output)
        XCTAssertEqual(result.receipts.first?.arguments, cached.arguments)
        XCTAssertEqual(result.messages[1].toolCalls?.first?.arguments, cached.arguments)
        XCTAssertEqual(result.messages[2].toolCallID, "retry-call")
        XCTAssertEqual(result.messages[2].content, cached.output)
    }

    func testInvalidSiblingCannotPartiallyExecuteCast() async throws {
        let calls = CallRecorder()
        let orchestrator = ToolOrchestrator(
            complete: { _, _ in .toolCalls([
                ChatToolCall(id: "cast", name: "cast_liuyao", arguments: ["question": "这个计划如何准备"]),
                ChatToolCall(id: "bad", name: "get_today_context", arguments: ["scope": "invented"]),
            ]) },
            execute: { call in await calls.record(call); return ToolExecutionResult(output: "{}") }
        )
        do {
            _ = try await orchestrator.run(history: [], definitions: [liuyaoDefinition, todayDefinition])
            XCTFail("Invalid batch should fail before any cast")
        } catch { XCTAssertTrue(error is ToolOrchestratorError) }
        let executed = await calls.values()
        XCTAssertTrue(executed.isEmpty)
    }

    func testRejectsDuplicateCallIDsWithinBatchAndAgainstHistory() async throws {
        let call = ChatToolCall(id: "same", name: "get_today_context", arguments: ["scope": "today"])
        for history in [[], [ChatMessage.assistantToolCalls([call]), .toolResult(ChatToolResult(callID: "same", output: "{}"))]] {
            let recorder = CallRecorder()
            let orchestrator = ToolOrchestrator(
                complete: { _, _ in .toolCalls(history.isEmpty ? [call, call] : [call]) },
                execute: { call in await recorder.record(call); return ToolExecutionResult(output: "{}") }
            )
            do {
                _ = try await orchestrator.run(history: history, definitions: [todayDefinition])
                XCTFail("Duplicate IDs break the provider history contract")
            } catch { XCTAssertEqual(error as? ToolOrchestratorError, .invalidCallID("same")) }
            let recorded = await recorder.values()
            XCTAssertTrue(recorded.isEmpty)
        }
    }

    func testRejectsUnboundedReversedFractionalOrMisappliedYearRanges() async throws {
        let definition = ChatToolDefinition(name: "get_timing", description: "timing", parameters: ["type": "object"])
        let invalid: [JSONValue] = [
            ["scope": "liunian", "yearRange": [1900, 2100]],
            ["scope": "liunian", "yearRange": [2026, 2020]],
            ["scope": "liunian", "yearRange": [2026.5, 2027]],
            ["scope": "liunian", "yearRange": [2026]],
            ["scope": "current_dayun", "yearRange": [2026, 2027]],
            ["scope": "liuyue", "year": 2026.5],
            ["scope": "liuyue", "year": 2200],
        ]
        for arguments in invalid {
            let recorder = CallRecorder()
            let orchestrator = ToolOrchestrator(
                complete: { _, _ in .toolCalls([ChatToolCall(id: "bad-range", name: "get_timing", arguments: arguments)]) },
                execute: { call in await recorder.record(call); return ToolExecutionResult(output: "{}") }
            )
            do { _ = try await orchestrator.run(history: [], definitions: [definition]); XCTFail("Invalid range accepted") }
            catch { XCTAssertTrue(error is ToolOrchestratorError) }
            let recorded = await recorder.values()
            XCTAssertTrue(recorded.isEmpty)
        }
    }

    func testSchemaBoundsAndUnknownPropertiesAreEnforced() async throws {
        let definition = ChatToolDefinition(name: "cast_liuyao", description: "cast", parameters: [
            "type": "object", "additionalProperties": false,
            "properties": ["question": ["type": "string", "minLength": 1, "maxLength": 20]],
            "required": ["question"],
        ])
        for args: JSONValue in [["question": ""], ["question": .string(String(repeating: "字", count: 21))], ["question": "工作", "lineValues": [6, 6, 6, 6, 6, 6]]] {
            let orchestrator = ToolOrchestrator(
                complete: { _, _ in .toolCalls([ChatToolCall(id: "bad", name: "cast_liuyao", arguments: args)]) },
                execute: { _ in XCTFail("Must not execute invalid input"); return ToolExecutionResult(output: "{}") }
            )
            do { _ = try await orchestrator.run(history: [], definitions: [definition]); XCTFail("Invalid arguments accepted") }
            catch { XCTAssertTrue(error is ToolOrchestratorError) }
        }
    }

    func testStructuredToolErrorIsNotPersistedAsSuccessfulEvidence() async throws {
        let model = ModelStub([.toolCalls([ChatToolCall(id: "failed", name: "get_today_context", arguments: ["scope": "today"])]), .text("ready")])
        let saved = ReceiptRecorder()
        let orchestrator = ToolOrchestrator(
            complete: { messages, tools in await model.complete(messages: messages, tools: tools) },
            execute: { _ in ToolExecutionResult(output: #"{"error":"calendar unavailable"}"#, evidence: ["invented evidence"]) },
            persistReceipt: { receipt in await saved.record(receipt) }
        )
        let result = try await orchestrator.run(history: [], definitions: [todayDefinition])
        XCTAssertTrue(result.receipts.isEmpty)
        XCTAssertTrue(result.evidence.isEmpty)
        let persisted = await saved.values()
        XCTAssertTrue(persisted.isEmpty)
        XCTAssertEqual(result.messages.last?.role, .tool)
        XCTAssertTrue(result.messages.last?.content?.contains("calendar unavailable") == true)
    }

    func testQimenRetryPreservesOriginalQuestionAndTimeJustLikeLiuyao() async throws {
        let cached = ToolReceipt(callID: "original", name: "setup_qimen", arguments: ["question": "迁居计划"], output: #"{"setupTime":"2026-09-19T12:00:00Z"}"#, createdAt: Date(timeIntervalSince1970: 100))
        let model = ModelStub([.toolCalls([ChatToolCall(id: "retry", name: "setup_qimen", arguments: ["question": "模型重新改写的问题"])]), .text("ready")])
        let orchestrator = ToolOrchestrator(
            complete: { messages, tools in await model.complete(messages: messages, tools: tools) },
            execute: { _ in XCTFail("Retry cannot create a new timed chart"); return ToolExecutionResult(output: "{}") }
        )
        let definition = ChatToolDefinition(name: "setup_qimen", description: "qimen", parameters: liuyaoDefinition.parameters)
        let result = try await orchestrator.run(history: [], definitions: [definition], cachedReceipts: [cached])
        XCTAssertEqual(result.receipts.first?.arguments, cached.arguments)
        XCTAssertEqual(result.receipts.first?.createdAt, cached.createdAt)
        XCTAssertEqual(result.receipts.first?.output, cached.output)
    }

    func testStructuredAndThrownErrorsCannotBypassModelOutputLimit() async throws {
        struct LongFailure: LocalizedError { var errorDescription: String? { String(repeating: "x", count: 400_000) } }
        for throwsError in [false, true] {
            let model = ModelStub([.toolCalls([ChatToolCall(id: "failed", name: "get_today_context", arguments: ["scope": "today"])]), .text("ready")])
            let saved = ReceiptRecorder()
            let orchestrator = ToolOrchestrator(
                complete: { messages, tools in await model.complete(messages: messages, tools: tools) },
                execute: { _ in
                    if throwsError { throw LongFailure() }
                    return ToolExecutionResult(output: "{\"error\":\"" + String(repeating: "x", count: 400_000) + "\"}")
                },
                persistReceipt: { await saved.record($0) }
            )
            let result = try await orchestrator.run(history: [], definitions: [todayDefinition])
            let calls = await model.recordedMessages()
            let outputs = calls.last!.filter { $0.role == .tool }
            XCTAssertEqual(outputs.count, 1)
            XCTAssertEqual(outputs.first?.toolCallID, "failed")
            XCTAssertLessThan(outputs.first!.content!.utf8.count, 1_000)
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(outputs.first!.content!.utf8)))
            XCTAssertTrue(result.receipts.isEmpty)
            let persisted = await saved.values()
            XCTAssertTrue(persisted.isEmpty)
        }
    }

    func testErrorBytesCountTowardAggregateCapacity() async throws {
        let model = ModelStub([
            .toolCalls([ChatToolCall(id: "failed1", name: "get_today_context", arguments: ["scope": "today"])]),
            .toolCalls([ChatToolCall(id: "failed2", name: "get_today_context", arguments: ["scope": "today"])]),
            .toolCalls([ChatToolCall(id: "success", name: "get_today_context", arguments: ["scope": "today"])]),
            .text("ready"),
        ])
        let orchestrator = ToolOrchestrator(
            complete: { messages, tools in await model.complete(messages: messages, tools: tools) },
            execute: { call in
                ToolExecutionResult(output: call.id == "success" ? String(repeating: "y", count: 31_000) : "{\"error\":\"" + String(repeating: "x", count: 31_000) + "\"}")
            }
        )
        let result = try await orchestrator.run(history: [], definitions: [todayDefinition])
        let calls = await model.recordedMessages()
        for call in calls {
            let outputs = call.filter { $0.role == .tool }.compactMap(\.content)
            XCTAssertLessThanOrEqual(outputs.reduce(0) { $0 + $1.utf8.count }, 60_000)
            XCTAssertTrue(outputs.allSatisfy { $0.utf16.count <= 32_000 })
        }
        XCTAssertEqual(result.receipts.map(\.callID), ["success"])
        XCTAssertTrue(result.messages.last?.content?.contains("盘面已保存") == true)
    }

    func testModelCapacityNeverDiscardsSuccessfulCastOrPermitsRecast() async throws {
        let qimen = ChatToolDefinition(name: "setup_qimen", description: "qimen", parameters: liuyaoDefinition.parameters)
        let model = ModelStub([
            .toolCalls([ChatToolCall(id: "large1", name: "get_today_context", arguments: ["scope":"today"])]),
            .toolCalls([ChatToolCall(id: "large2", name: "get_today_context", arguments: ["scope":"today"])]),
            .toolCalls([ChatToolCall(id: "cast1", name: "setup_qimen", arguments: ["question":"同一个问题"])]),
            .toolCalls([ChatToolCall(id: "cast2", name: "setup_qimen", arguments: ["question":"不能换问题"])]),
            .text("stop")
        ])
        let casts = Counter(); let saved = ReceiptRecorder()
        let orchestrator = ToolOrchestrator(complete: { messages, tools in await model.complete(messages: messages, tools: tools) }, execute: { call in
            if call.name == "setup_qimen" { _ = await casts.increment() }
            return ToolExecutionResult(output: String(repeating: "x", count: call.name == "setup_qimen" ? 5_000 : 28_000))
        }, persistReceipt: { await saved.record($0) })
        let result = try await orchestrator.run(history: [], definitions: [todayDefinition,qimen])
        let castCount = await casts.value()
        let savedNames = await saved.values().map(\.name)
        XCTAssertEqual(castCount, 1)
        XCTAssertEqual(savedNames.filter { $0 == "setup_qimen" }.count, 1)
        XCTAssertEqual(result.receipts.filter { $0.name == "setup_qimen" }.count, 2)
        XCTAssertTrue(result.messages.filter { $0.role == .tool }.suffix(2).allSatisfy { $0.content?.contains("盘面已保存") == true })
    }

    private var todayDefinition: ChatToolDefinition {
        ChatToolDefinition(
            name: "get_today_context",
            description: "today",
            parameters: [
                "type": "object",
                "properties": [
                    "scope": ["type": "string", "enum": ["today", "week"]],
                ],
                "required": ["scope"],
            ]
        )
    }

    private var liuyaoDefinition: ChatToolDefinition {
        ChatToolDefinition(
            name: "cast_liuyao",
            description: "cast",
            parameters: [
                "type": "object",
                "properties": ["question": ["type": "string"]],
                "required": ["question"],
            ]
        )
    }
}

private actor ModelStub {
    private var responses: [ChatCompletionResult]
    private var messages: [[ChatMessage]] = []

    init(_ responses: [ChatCompletionResult]) { self.responses = responses }

    func complete(messages: [ChatMessage], tools: [ChatToolDefinition]) -> ChatCompletionResult {
        self.messages.append(messages)
        return responses.removeFirst()
    }

    func recordedMessages() -> [[ChatMessage]] { messages }
}

private actor CallRecorder {
    private var calls: [ChatToolCall] = []
    func record(_ call: ChatToolCall) { calls.append(call) }
    func values() -> [ChatToolCall] { calls }
}

private actor ReceiptRecorder {
    private var receipts: [ToolReceipt] = []
    func record(_ receipt: ToolReceipt) { receipts.append(receipt) }
    func values() -> [ToolReceipt] { receipts }
}

private actor Counter {
    private var count = 0
    func increment() -> Int { count += 1; return count }
    func value() -> Int { count }
}
