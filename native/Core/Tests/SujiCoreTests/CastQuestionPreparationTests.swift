import Foundation
import XCTest
@testable import SujiCore

final class CastQuestionPreparationTests: XCTestCase {
    private let userID = UUID(uuidString: "A5A05A39-609D-471B-8491-7D6576B852F5")!
    private var context: ToolContext { get throws {
        try ToolContext(birth: nil, engineRevision: "fixture-f6", referenceDate: Date(timeIntervalSince1970: 1789880000), mode: "起卦")
    } }
    // Actual F4 planner omission. The original request explicitly mentioned the lease.
    private var omitted: ChatToolCall {
        ChatToolCall(id: "call_00_38IbWgAki7a6Um1N8aoe8763", name: "setup_qimen", arguments: [
            "question": "我自己近期能否签下新办公室租约", "questionType": "event", "subject": "self", "timeHorizon": "near"
        ])
    }
    private var definitions: [ChatToolDefinition] { ["setup_qimen", "cast_liuyao"].map {
        ChatToolDefinition(name: $0, description: "fixture", parameters: ["type": "object", "additionalProperties": false,
            "required": ["question"], "properties": [
                "question": ["type": "string", "minLength": 1, "maxLength": 1600],
                "questionType": ["type": "string", "enum": ["event", "general", "career"]],
                "subject": ["type": "string", "enum": ["self", "parent", "unknown"]],
                "event": ["type": "string", "minLength": 1, "maxLength": 200],
                "timeHorizon": ["type": "string", "enum": ["near", "far", "unspecified"]]
            ]])
    } }
    private func confirm(_ call: ChatToolCall) throws -> ConfirmedCastQuestion {
        var draft = try CastQuestionDraft(call: call)
        draft.event = "签下新办公室租约"
        return try ConfirmedCastQuestion(draft: draft, userID: userID, context: context)
    }

    func testArchivedOmittedEventRequiresExplicitCorrectionBeforeConfirming() throws {
        var draft = try CastQuestionDraft(call: omitted)
        XCTAssertEqual(draft.event, "")
        XCTAssertThrowsError(try ConfirmedCastQuestion(draft: draft, userID: userID, context: context))
        draft.event = "  签下新办公室租约  "
        let accepted = try ConfirmedCastQuestion(draft: draft, userID: userID, context: context)
        XCTAssertEqual(accepted.call.arguments, ["question": "我自己近期能否签下新办公室租约", "questionType": "event", "subject": "self", "timeHorizon": "near", "event": "签下新办公室租约"])
        XCTAssertEqual(accepted.proposedCall, omitted)
        XCTAssertEqual(accepted.context.referenceDate, try context.referenceDate)
    }

    func testReferenceOnlyPreservesUnknownsWithoutInferringFromGender() throws {
        let call = ChatToolCall(id: "reference", name: "cast_liuyao", arguments: ["question": "只核对盘面", "gender": "男"])
        var draft = try CastQuestionDraft(call: call)
        draft.referenceOnly = true
        let accepted = try ConfirmedCastQuestion(draft: draft, userID: userID, context: context)
        XCTAssertEqual(accepted.call.arguments, ["question": "只核对盘面", "questionType": "general", "subject": "unknown", "timeHorizon": "unspecified"])
        XCTAssertTrue(accepted.referenceOnly)
    }

    func testRejectsBlankOversizedAndInvalidSelections() throws {
        var valid = try CastQuestionDraft(call: omitted)
        valid.event = "签约"
        for mutation in 0..<6 {
            var draft = valid
            switch mutation {
            case 0: draft.question = " \n "
            case 1: draft.question = String(repeating: "字", count: 1601)
            case 2: draft.event = String(repeating: "字", count: 201)
            case 3: draft.subject = "wife-from-gender"
            case 4: draft.timeHorizon = "tomorrow"
            default: draft.questionType = "made-up"
            }
            XCTAssertThrowsError(try ConfirmedCastQuestion(draft: draft, userID: userID, context: context))
        }
    }

    func testWholeBatchPreparationPrecedesExecutionAndAliasesShareCorrection() async throws {
        var alias = omitted; alias.id = "alias"; alias.arguments = ["question": "model changed question"]
        var second = omitted; second.id = "second"; second.name = "cast_liuyao"
        let recorder = PreparationRecorder()
        let orchestrator = ToolOrchestrator(maxRounds: 1,
            complete: { _, _ in .toolCalls([self.omitted, alias, second]) },
            execute: { call in await recorder.add("execute:" + call.name); return ToolExecutionResult(output: "{}") },
            prepareCasts: { calls in
                await recorder.add("prepare:\(calls.count)")
                return try calls.map(self.confirm)
            },
            persistConfirmations: { values in await recorder.add("save:\(values.count)") }
        )
        let result = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID)
        let events = await recorder.events
        XCTAssertEqual(events, ["prepare:2", "save:2", "execute:setup_qimen", "execute:cast_liuyao"])
        XCTAssertEqual(result.receipts.count, 3)
        XCTAssertEqual(result.receipts[0].arguments, result.receipts[1].arguments)
        XCTAssertEqual(result.messages.first(where: { $0.toolCalls != nil })?.toolCalls?.map(\.id), [omitted.id, "alias", "second"])
        XCTAssertEqual(result.receipts[0].arguments, try confirm(omitted).call.arguments)
    }

    func testInvalidSiblingRejectsBeforeConfirmation() async throws {
        let recorder = PreparationRecorder()
        let orchestrator = ToolOrchestrator(maxRounds: 1,
            complete: { _, _ in .toolCalls([self.omitted, ChatToolCall(id: "bad", name: "setup_qimen", arguments: ["question": 5])]) },
            execute: { _ in await recorder.add("execute"); return ToolExecutionResult(output: "{}") },
            prepareCasts: { _ in await recorder.add("prepare"); return [] }
        )
        do { _ = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID); XCTFail() } catch {}
        let events = await recorder.events
        XCTAssertTrue(events.isEmpty)
    }

    func testCancelledOrInvalidPreparationNeverSavesOrExecutes() async throws {
        for variant in 0..<5 {
            let recorder = PreparationRecorder()
            let orchestrator = ToolOrchestrator(maxRounds: 1,
                complete: { _, _ in .toolCalls([self.omitted]) },
                execute: { _ in await recorder.add("execute"); return ToolExecutionResult(output: "{}") },
                prepareCasts: { calls in
                    if variant == 0 { throw CancellationError() }
                    if variant == 1 { return [] }
                    if variant == 2 { var call = calls[0]; call.id = "wrong-id"; return [try self.confirm(call)] }
                    if variant == 3 {
                        var draft = try CastQuestionDraft(call: calls[0]); draft.event = "签约"
                        return [try ConfirmedCastQuestion(draft: draft, userID: UUID(), context: self.context)]
                    }
                    var draft = try CastQuestionDraft(call: calls[0]); draft.event = "签约"; draft.questionType = "marriage" // excluded by this test schema
                    return [try ConfirmedCastQuestion(draft: draft, userID: self.userID, context: self.context)]
                },
                persistConfirmations: { _ in await recorder.add("save") }
            )
            do { _ = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID); XCTFail("variant \(variant)") } catch {}
            let events = await recorder.events
            XCTAssertTrue(events.isEmpty)
        }
    }

    func testConfirmationPersistenceFailurePreventsCalculation() async throws {
        let recorder = PreparationRecorder()
        let orchestrator = ToolOrchestrator(maxRounds: 1,
            complete: { _, _ in .toolCalls([self.omitted]) },
            execute: { _ in await recorder.add("execute"); return ToolExecutionResult(output: "{}") },
            prepareCasts: { try $0.map(self.confirm) },
            persistConfirmations: { _ in throw CocoaError(.fileWriteUnknown) }
        )
        do { _ = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID); XCTFail() } catch {}
        let events = await recorder.events
        XCTAssertTrue(events.isEmpty)
    }

    func testRetryUsesSavedConfirmationAndCompletedChartNeverRepromptsOrRecasts() async throws {
        let confirmation = try confirm(omitted)
        for hasReceipt in [false, true] {
            var newCall = omitted; newCall.id = "retry"; newCall.arguments = ["question": "model changed intent"]
            let receipts = hasReceipt ? [ToolReceipt(callID: omitted.id, name: omitted.name, arguments: confirmation.call.arguments, output: "{\"original\":true}", context: try context)] : []
            let recorder = PreparationRecorder()
            let orchestrator = ToolOrchestrator(maxRounds: 1,
                complete: { _, _ in .toolCalls([newCall]) },
                execute: { call in
                    await recorder.add("execute")
                    XCTAssertEqual(call.arguments, confirmation.call.arguments)
                    return ToolExecutionResult(output: "{\"original\":true}")
                },
                prepareCasts: { _ in XCTFail("Retry must not reconfirm"); return [] }
            )
            let result = try await orchestrator.run(history: [], definitions: definitions, cachedReceipts: receipts, context: context, questionID: userID, confirmedQuestions: [confirmation])
            XCTAssertEqual(result.receipts.first?.arguments, confirmation.call.arguments)
            let events = await recorder.events
            XCTAssertEqual(events, hasReceipt ? [] : ["execute"])
        }
    }

    func testCorrectedEventReachesActualEnginesWithoutEstablishingFinalSelection() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let rawDefinitions = try await bridge.request("{\"command\":\"tools\"}")
        let definitions = try ReadingIntent.definitions(from: rawDefinitions, mode: "起卦", question: "请用六爻和奇门核对盘面", hasBirth: false)
        for name in ["setup_qimen", "cast_liuyao"] {
            var call = omitted; call.name = name
            let orchestrator = ToolOrchestrator(maxRounds: 1,
                complete: { _, _ in .toolCalls([call]) },
                execute: { call in
                    let request: JSONValue = ["command": "tool", "name": .string(call.name), "id": .string(call.id), "arguments": call.arguments, "now": "2026-09-20T04:00:00Z"]
                    let data = try await bridge.request(String(decoding: JSONEncoder().encode(request), as: UTF8.self))
                    let envelope = try JSONDecoder().decode(JSONValue.self, from: data)
                    let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: envelope))
                    return ToolExecutionResult(output: String(decoding: try JSONEncoder().encode(result), as: UTF8.self))
                },
                prepareCasts: { try $0.map(self.confirm) }
            )
            let result = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID)
            let receipt = try XCTUnwrap(result.receipts.first)
            let output = try JSONDecoder().decode(JSONValue.self, from: Data(receipt.output.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/questionContext/event", in: output), "签下新办公室租约")
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/questionContext/subject", in: output), "self")
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/questionContext/timeHorizon", in: output), "near")
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/yongShen/selectedCandidateId", in: output), .null)
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/yongShen/selectionEstablished", in: output), false)
            if case let .array(missing) = ReadingVerificationEvidence.pointer("/yongShen/missingContext", in: output) {
                XCTAssertFalse(missing.contains("event"))
            } else { XCTFail("Missing source-bound context status") }
        }
    }

    func testConfirmedScopeAndEditedQuestionReachWriterAndPersistedReplay() async throws {
        var draft = try CastQuestionDraft(call: omitted)
        draft.referenceOnly = true
        draft.question = "只核对天禽寄干"
        let confirmed = try ConfirmedCastQuestion(draft: draft, userID: userID, context: context)
        let orchestrator = ToolOrchestrator(maxRounds: 1,
            complete: { _, _ in .toolCalls([self.omitted]) },
            execute: { _ in ToolExecutionResult(output: "{}") },
            prepareCasts: { _ in [confirmed] }
        )
        let result = try await orchestrator.run(history: [], definitions: definitions, context: context, questionID: userID)
        XCTAssertTrue(result.messages.contains { $0.role == .user && ($0.content?.contains("仅核对盘面") ?? false) && ($0.content?.contains("只核对天禽寄干") ?? false) })
        var entry = ConversationEntry(role: "user", text: "原来询问成败")
        entry.id = userID; entry.toolContext = try context; entry.confirmedCastQuestions = [confirmed]
        let history = ReadingPrompt.history(from: [entry], currentUserID: userID, context: try context)
        XCTAssertTrue(history.contains { ($0.content?.contains("仅核对盘面") ?? false) && ($0.content?.contains("只核对天禽寄干") ?? false) })
        let otherContext = try ToolContext(birth: nil, engineRevision: "other", referenceDate: context.referenceDate, mode: "起卦")
        let staleHistory = ReadingPrompt.history(from: [entry], currentUserID: userID, context: otherContext)
        XCTAssertFalse(staleHistory.contains { $0.content?.contains("只核对天禽寄干") ?? false })
    }

    func testMaximumOriginalQuestionCannotEvictConfirmedIntentFromVerifier() throws {
        let original = String(repeating: "字", count: 8000)
        var confirmations: [ConfirmedCastQuestion] = []
        for name in ["setup_qimen", "cast_liuyao"] {
            var call = omitted; call.name = name
            var draft = try CastQuestionDraft(call: call)
            draft.referenceOnly = true
            draft.question = "修订问题" + String(repeating: "𠮷", count: 1596)
            draft.event = String(repeating: "𠮷", count: 200)
            confirmations.append(try ConfirmedCastQuestion(draft: draft, userID: userID, context: context))
        }
        let question = ReadingPrompt.verificationQuestion(original: original, confirmations: confirmations)
        let messages = ReadingVerifier.messages(draft: "核对盘面", history: [], question: question)
        let actual = messages.compactMap(\.content).joined(separator: "\n")
        for confirmation in confirmations { XCTAssertTrue(actual.contains(confirmation.intentMessage.content!)) }
        XCTAssertTrue(actual.contains("仅核对盘面"))
        XCTAssertTrue(actual.contains("修订问题"))
    }

    func testConfirmationArchiveRoundTripRejectsDifferentQuestionOrContext() throws {
        var entry = ConversationEntry(role: "user", text: "original")
        entry.confirmedCastQuestions = [try confirm(omitted)]
        let restored = try JSONDecoder().decode(ConversationEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(restored.confirmedCastQuestions, entry.confirmedCastQuestions)
        let saved = try XCTUnwrap(restored.confirmedCastQuestions?.first)
        XCTAssertThrowsError(try saved.validate(userID: UUID(), context: context))
        let changed = try ToolContext(birth: nil, engineRevision: "changed", referenceDate: context.referenceDate, mode: "起卦")
        XCTAssertThrowsError(try saved.validate(userID: userID, context: changed))
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        old.removeValue(forKey: "confirmedCastQuestions")
        let legacy = try JSONDecoder().decode(ConversationEntry.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(legacy.confirmedCastQuestions)
    }
}

private actor PreparationRecorder {
    var events: [String] = []
    func add(_ event: String) { events.append(event) }
}
