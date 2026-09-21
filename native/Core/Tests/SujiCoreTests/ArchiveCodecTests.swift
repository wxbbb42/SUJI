import Foundation
import XCTest
@testable import SujiCore

final class ArchiveCodecTests: XCTestCase {
    func testLocalSupplementReceiptsCanBeBackedUpWithoutBecomingCallableTools() throws {
        for name in ["reassess_liuyao","reassess_qimen"] {
            let (base,context) = try stateWithReceipts()
            var state = base
            let output = try CastReceiptStorage.encode(#"{"question":"补充原问题","questionRevision":{"sourceCallID":"original-cast"},"lines":[]}"#)
            state.conversations[0].toolReceipts?.append(.init(callID:"supplement",name:name,arguments:["question":"补充原问题"],output:output,context:context))
            let local = try JSONDecoder().decode(AppState.self,from:ArchiveCodec.encode(state))
            XCTAssertEqual(local.conversations[0].toolReceipts?.last?.context,context)
            let imported = try ArchiveCodec.decode(ArchiveCodec.encode(state))
            XCTAssertEqual(imported.conversations[0].toolReceipts?.last?.name,name)
            XCTAssertEqual(imported.conversations[0].toolReceipts?.last?.output,output)
            XCTAssertNil(imported.conversations[0].toolReceipts?.last?.context)
            XCTAssertNil(imported.conversations[0].toolContext)
            XCTAssertFalse(ToolOrchestrator.allowedToolNames.contains(name))
        }
    }
    func testRoundTripPreservesStateAndSettings() throws {
        var state = AppState()
        state.hasOnboarded = true
        state.birth = BirthProfile(year: 1994, month: 5, day: 6, hour: 7, minute: 8, gender: "女", city: "上海", longitude: 121.47)
        state.appearance = "dark"
        state.tone = "直言"
        state.providerURL = "https://example.com/v1"
        state.model = "example-model"
        state.reveal(day: DayKey(rawValue: "2026-09-19"), quote: "慢下来", action: "喝水")
        _ = state.recordMood(day: "2026-09-19", mood: .calm, note: "散步")
        var conversation = ConversationEntry(role: "user", text: "你好")
        conversation.toolReceipts = [ToolReceipt(callID: "call-1", name: "get_today_context", arguments: [:], output: #"{"solarTerm":"白露"}"#, evidence: ["节气 · 白露"])]
        state.conversations = [conversation]
        state.reflections = ["monthly:2026-09": [ConversationEntry(role: "assistant", text: "九月复盘")]]

        let data = try ArchiveCodec.encode(state)
        let decoded = try ArchiveCodec.decode(data)

        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.birth, state.birth)
        XCTAssertEqual(decoded.appearance, "dark")
        XCTAssertEqual(decoded.tone, "直言")
        XCTAssertEqual(decoded.providerURL, "https://example.com/v1")
        XCTAssertEqual(decoded.model, "example-model")
        XCTAssertEqual(decoded.rituals.count, 1)
        XCTAssertEqual(decoded.journal.count, 1)
        XCTAssertEqual(decoded.conversations.first?.text, "你好")
        XCTAssertEqual(decoded.conversations.first?.toolReceipts?.first?.name, "get_today_context")
        XCTAssertEqual(decoded.reflections?["monthly:2026-09"]?.first?.text, "九月复盘")
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(json.contains("apiKey"))
        XCTAssertFalse(json.contains("access_token"))
        XCTAssertFalse(json.contains("refresh_token"))
    }

    func testRejectsFutureMissingMalformedAndOversizedArchives() throws {
        XCTAssertThrowsError(try ArchiveCodec.decode(Data(#"{"version":2}"#.utf8)))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data(#"{"version":2,"state":{"messages":[]}}"#.utf8)))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data(#"{"hasOnboarded":true}"#.utf8)))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data("not-json".utf8)))
        XCTAssertThrowsError(try ArchiveCodec.decode(Data(repeating: 0x20, count: ArchiveCodec.maximumByteCount + 1)))
    }

    func testExternalImportKeepsReadableReceiptsButRemovesCalculationTrust() throws {
        let (state, context) = try stateWithReceipts()
        var archive = try XCTUnwrap(JSONSerialization.jsonObject(with: ArchiveCodec.encode(state)) as? [String: Any])
        var conversations = try XCTUnwrap(archive["conversations"] as? [[String: Any]])
        var receipts = try XCTUnwrap(conversations[0]["toolReceipts"] as? [[String: Any]])
        // Editing a real exported receipt must not let arbitrary content enter a tool role.
        let editedOutput = #"{"benGua":{"name":"externally-edited"}}"#
        receipts[0]["output"] = editedOutput
        conversations[0]["toolReceipts"] = receipts
        archive["conversations"] = conversations

        let imported = try ArchiveCodec.decode(JSONSerialization.data(withJSONObject: archive))
        let current = try XCTUnwrap(imported.conversations.first)
        let receipt = try XCTUnwrap(current.toolReceipts?.first)
        XCTAssertNil(current.toolContext)
        XCTAssertNil(receipt.context)
        XCTAssertEqual(current.id, state.conversations[0].id)
        XCTAssertNil(current.analysisMode)
        XCTAssertEqual(current.date, state.conversations[0].date)
        XCTAssertEqual(current.toolData, state.conversations[0].toolData)
        XCTAssertEqual(receipt.output, editedOutput)
        XCTAssertEqual(receipt.arguments, state.conversations[0].toolReceipts?[0].arguments)
        XCTAssertEqual(receipt.evidence, state.conversations[0].toolReceipts?[0].evidence)
        XCTAssertEqual(receipt.createdAt, state.conversations[0].toolReceipts?[0].createdAt)
        let reflection = try XCTUnwrap(imported.reflections?["calibration:example"]?.first)
        XCTAssertNil(reflection.toolContext)
        XCTAssertNil(reflection.analysisMode)
        XCTAssertNil(reflection.toolReceipts?.first?.context)
        XCTAssertEqual(reflection.toolReceipts?.first?.output, state.reflections?["calibration:example"]?.first?.toolReceipts?.first?.output)

        let history = ReadingPrompt.history(from: imported.conversations, currentUserID: current.id, context: context)
        XCTAssertEqual(history.map(\.role), [.user])
        XCTAssertFalse(history.contains { $0.role == .tool || $0.toolCalls != nil })
    }

    func testImportedReceiptsBlockRetryBeforeAnyModelCallOrRecast() async throws {
        let (state, context) = try stateWithReceipts()
        let imported = try ArchiveCodec.decode(ArchiveCodec.encode(state))
        let receipts = try XCTUnwrap(imported.conversations.first?.toolReceipts)
        let orchestrator = ToolOrchestrator(
            complete: { _, _ in XCTFail("Imported receipts cannot reach the model"); return .text("") },
            execute: { _ in XCTFail("Imported history must not be recast on retry"); return .init(output: "{}") }
        )
        do {
            _ = try await orchestrator.run(history: [], definitions: [], cachedReceipts: receipts, context: context)
            XCTFail("Expected untrusted imported context to fail")
        } catch {
            XCTAssertEqual(error as? ToolOrchestratorError, .staleContext)
        }
    }

    func testLocalPersistenceKeepsContextsAndReexportCannotRestoreImportedTrust() throws {
        let (state, context) = try stateWithReceipts()
        // AppStore's local SavedState path is deliberately distinct from file import.
        let local = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(local.conversations.first?.toolContext, context)
        XCTAssertEqual(local.conversations.first?.analysisMode, "起卦")
        XCTAssertEqual(local.conversations.first?.toolReceipts?.first?.context, context)
        XCTAssertEqual(local.reflections?["calibration:example"]?.first?.toolContext, context)
        let current = try XCTUnwrap(local.conversations.first)
        XCTAssertTrue(ReadingPrompt.history(from: local.conversations, currentUserID: current.id, context: context).contains { $0.role == .tool })

        let imported = try ArchiveCodec.decode(ArchiveCodec.encode(state))
        let reloaded = try JSONDecoder().decode(AppState.self, from: ArchiveCodec.encode(imported))
        XCTAssertNil(reloaded.conversations.first?.toolContext)
        XCTAssertNil(reloaded.conversations.first?.analysisMode)
        XCTAssertNil(reloaded.conversations.first?.toolReceipts?.first?.context)
    }

    private func stateWithReceipts() throws -> (AppState, ToolContext) {
        var question = ConversationEntry(role: "user", text: "这个计划如何准备")
        question.date = Date(timeIntervalSince1970: 1_789_792_000)
        let context = try ToolContext(birth: nil, engineRevision: String(repeating: "a", count: 64), referenceDate: question.date, mode: "起卦")
        question.toolContext = context
        question.analysisMode = "起卦"
        question.toolData = [#"{"benGua":{"name":"谦"}}"#]
        question.toolReceipts = [.init(callID: "original-cast", name: "cast_liuyao", arguments: ["question": .string(question.text)], output: question.toolData[0], evidence: ["主卦 · 谦"], createdAt: question.date, context: context)]
        var reflection = question
        reflection.id = UUID()
        var state = AppState()
        state.conversations = [question]
        state.reflections = ["calibration:example": [reflection]]
        return (state, context)
    }

    func testRejectsInvalidBirthInsideOtherwiseCurrentArchive() throws {
        var state = AppState()
        state.birth = BirthProfile(year: 2025, month: 2, day: 29, hour: 10, minute: 0, gender: "女", city: "上海", longitude: 121.47)
        let raw = try JSONEncoder().encode(state)
        XCTAssertThrowsError(try ArchiveCodec.decode(raw))
    }

    func testRejectsDuplicateOrUnsafeReflectionRecords() throws {
        var state = AppState()
        let duplicated = ConversationEntry(role: "assistant", text: "复盘")
        state.reflections = ["monthly:2026-09": [duplicated, duplicated]]
        XCTAssertThrowsError(try ArchiveCodec.decode(JSONEncoder().encode(state)))

        state.reflections = ["bad\u{0000}key": [ConversationEntry(role: "assistant", text: "复盘")]]
        XCTAssertThrowsError(try ArchiveCodec.decode(JSONEncoder().encode(state)))
    }

    func testRejectsUnboundedOrUnknownToolReceipts() throws {
        var state = AppState()
        var entry = ConversationEntry(role: "assistant", text: "回答")
        entry.toolReceipts = [ToolReceipt(callID: "call-1", name: "not_a_tool", arguments: [:], output: "{}")]
        state.conversations = [entry]
        XCTAssertThrowsError(try ArchiveCodec.decode(JSONEncoder().encode(state)))

        var deeplyNested: JSONValue = "leaf"
        for _ in 0..<30 { deeplyNested = .array([deeplyNested]) }
        entry.toolReceipts = [ToolReceipt(callID: "call-1", name: "get_today_context", arguments: deeplyNested, output: "{}")]
        state.conversations = [entry]
        XCTAssertThrowsError(try ArchiveCodec.decode(JSONEncoder().encode(state)))
    }

    func testImportsExportedZustandStoresWithoutSecretsOrDerivedCaches() throws {
        let legacy: [String: Any] = [
            "suiji-user-store": try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: [
                "state": [
                    "birthDate": "1993-04-05T06:07:00.000Z",
                    "gender": "男",
                    "birthCity": "上海",
                    "birthLongitude": 121.47,
                    "apiProvider": "custom",
                    "apiKey": "must-not-survive",
                    "apiModel": "legacy-model",
                    "apiBaseUrl": "https://legacy.example/v1",
                    "mingPanCache": "secret-derived-cache",
                    "hasOnboarded": true
                ],
                "version": 0
            ]), encoding: .utf8)),
            "suiji-chat-store": try XCTUnwrap(String(data: JSONSerialization.data(withJSONObject: [
                "state": ["messages": [
                    ["role": "user", "content": "旧问题", "timestamp": 1_700_000_000_000],
                    ["role": "assistant", "content": "旧回答", "timestamp": 1_700_000_001_000]
                ]],
                "version": 0
            ]), encoding: .utf8))
        ]
        let decoded = try ArchiveCodec.decode(JSONSerialization.data(withJSONObject: legacy))

        XCTAssertTrue(decoded.hasOnboarded)
        XCTAssertEqual(decoded.birth?.gender, "男")
        XCTAssertEqual(decoded.birth?.city, "上海")
        XCTAssertEqual(decoded.providerURL, "https://legacy.example/v1")
        XCTAssertEqual(decoded.model, "legacy-model")
        XCTAssertEqual(decoded.conversations.map(\.text), ["旧问题", "旧回答"])
        let reexported = String(decoding: try ArchiveCodec.encode(decoded), as: UTF8.self)
        XCTAssertFalse(reexported.contains("must-not-survive"))
        XCTAssertFalse(reexported.contains("secret-derived-cache"))
    }

    func testImportsStandaloneZustandChatStoreVersionZero() throws {
        let legacy: [String: Any] = [
            "state": ["messages": [["role": "user", "content": "单独导出的对话", "timestamp": 1_700_000_000_000]]],
            "version": 0
        ]
        let state = try ArchiveCodec.decode(JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(state.conversations.map(\.text), ["单独导出的对话"])
        XCTAssertNil(state.birth)
    }
}
