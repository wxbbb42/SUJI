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
        XCTAssertEqual(result.messages.last?.content, "可以慢一点。")
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
        XCTAssertEqual(result.messages[2].toolCallID, "retry-call")
        XCTAssertEqual(result.messages[2].content, cached.output)
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
