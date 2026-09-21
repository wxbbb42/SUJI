import XCTest
@testable import SujiCore

final class AdjudicationFollowupIntegrationTests: XCTestCase {
    private func bridge() throws -> MingliBridge {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
    }

    private func result(_ bridge: MingliBridge, _ request: JSONValue) async throws -> JSONValue {
        let data = try await bridge.request(ReadingVerificationEvidence.encoded(request))
        let envelope = try JSONDecoder().decode(JSONValue.self, from: data)
        return try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: envelope))
    }

    private struct SavedConfirmation: Encodable {
        let userID: UUID
        let context: ToolContext
        let confirmedAt: Date
        let proposedCall: ChatToolCall
        let call: ChatToolCall
        let referenceOnly: Bool
    }

    private let specializedArguments: JSONValue = [
        "question": "用奇门核对本次降雨的取用", "questionType": "event",
        "subject": "unknown", "event": "本次降雨", "timeHorizon": "near",
        "selectionRequest": ["focus": "weather-rain"]
    ]

    func testPersistedExplicitSpecialSelectionValidatesAndKeepsExactRequest() throws {
        let id = UUID()
        let context = try ToolContext(birth: nil, engineRevision: "selection-confirmation-test",
                                      referenceDate: Date(timeIntervalSince1970: 1_790_000_000), mode: "起卦")
        let call = ChatToolCall(id: "confirmed-selection", name: "setup_qimen", arguments: specializedArguments)
        let wire = SavedConfirmation(userID: id, context: context, confirmedAt: context.referenceDate,
                                     proposedCall: call, call: call, referenceOnly: false)
        let restored = try JSONDecoder().decode(ConfirmedCastQuestion.self, from: JSONEncoder().encode(wire))
        XCTAssertNoThrow(try restored.validate(userID: id, context: context))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/selectionRequest/focus", in: restored.call.arguments), "weather-rain")
    }

    func testModelProposedSpecialSelectionIsNotAlreadyUserConfirmation() throws {
        let call = ChatToolCall(id: "proposal", name: "setup_qimen", arguments: specializedArguments)
        let draft = try CastQuestionDraft(call: call)
        XCTAssertNil(ReadingVerificationEvidence.pointer("/selectionRequest", in: try draft.validatedCall().arguments))
    }

    func testExplicitChoicesRejectUnknownFocusAndCategoryConflictAndReferenceOnlyClearsRequest() throws {
        let call = ChatToolCall(id: "selection-edit", name: "setup_qimen", arguments: specializedArguments)
        var draft = try CastQuestionDraft(call: call)
        draft.specialSelectionEnabled = true
        for choice in CastQuestionDraft.specialSelectionChoices {
            draft.specialSelectionFocus = choice.id
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/selectionRequest/focus", in: try draft.validatedCall().arguments), .string(choice.id))
        }
        draft.specialSelectionFocus = "weather-sun-from-guessed-rule"
        XCTAssertThrowsError(try draft.validatedCall())
        draft.specialSelectionFocus = "weather-rain"
        draft.questionType = "career"
        XCTAssertThrowsError(try draft.validatedCall())
        draft.questionType = "event"
        draft.event = " "
        XCTAssertThrowsError(try draft.validatedCall())
        draft.referenceOnly = true
        XCTAssertNil(ReadingVerificationEvidence.pointer("/selectionRequest", in: try draft.validatedCall().arguments))
        let liuyao = ChatToolCall(id: "wrong-method", name: "cast_liuyao", arguments: specializedArguments)
        var other = try CastQuestionDraft(call: liuyao)
        other.specialSelectionEnabled = true
        other.specialSelectionFocus = "weather-rain"
        XCTAssertNil(ReadingVerificationEvidence.pointer("/selectionRequest", in: try other.validatedCall().arguments))
    }

    func testLiuyaoEventAssessmentRebindsOnOriginalChartAndSurvivesStorageReplayAndArchive() async throws {
        let bridge = try bridge(), now = "2024-02-04T04:00:00Z"
        let args: JSONValue = ["question": "先核对同次占问盘面", "questionType": "general", "subject": "unknown", "event": "同次事项", "timeHorizon": "near"]
        let original = try await result(bridge, ["command": "tool", "name": "cast_liuyao", "arguments": args, "now": .string(now)])
        let originalAssessment = try XCTUnwrap(ReadingVerificationEvidence.pointer("/eventAssessment", in: original))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision", in: original) else { return XCTFail("Missing revision") }
        let context = try ToolContext(birth: nil, engineRevision: revision, referenceDate: ISO8601DateFormatter().date(from: now)!, mode: "起卦")
        var source = ConversationEntry(role: "user", text: "先核对同次占问盘面")
        source.date = context.referenceDate; source.toolContext = context; source.analysisMode = context.mode
        source.toolReceipts = [.init(callID: "followup-original", name: "cast_liuyao", arguments: args,
                                    output: try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(original)), context: context)]
        let link = try CastSupplement.select(entryID: source.id, callID: "followup-original", entries: [source], context: context)
        var user = ConversationEntry(role: "user", text: "补充：这次问我自己的身体情况")
        user.toolContext = context; user.castSupplement = link
        var draft = try CastQuestionDraft(call: .init(id: "followup-derived", name: "cast_liuyao", arguments: link.arguments))
        draft.question = user.text; draft.questionType = "health"; draft.subject = "self"; draft.event = "本人的身体情况"
        let confirmation = try ConfirmedCastQuestion(draft: draft, userID: user.id, context: context)
        let revised = try await result(bridge, ["command": "reassess-question", "name": "cast_liuyao", "sourceCallID": "followup-original",
                                                "original": original, "arguments": confirmation.call.arguments])
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/lines", in: revised), ReadingVerificationEvidence.pointer("/lines", in: original))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/castTime", in: revised), ReadingVerificationEvidence.pointer("/castTime", in: original))
        XCTAssertNotEqual(ReadingVerificationEvidence.pointer("/eventAssessment", in: revised), originalAssessment)
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/eventAssessment/outcomeEstablished", in: revised), false)
        let receipt = ToolReceipt(callID: confirmation.call.id, name: link.derivedName, arguments: confirmation.call.arguments,
                                  output: try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(revised)), context: context)
        user.confirmedCastQuestions = [confirmation]; user.toolReceipts = [receipt]
        let text = try link.render(receipt: receipt, confirmation: confirmation, userID: user.id, entries: [source, user], context: context)
        XCTAssertTrue(text.contains("沿用原盘"))
        guard case var .object(stale) = revised else { return XCTFail("Expected chart object") }
        stale["eventAssessment"] = originalAssessment
        var forged = receipt; forged.output = ReadingVerificationEvidence.encoded(JSONValue.object(stale))
        XCTAssertThrowsError(try link.render(receipt: forged, confirmation: confirmation, userID: user.id, entries: [source, user], context: context))

        var state = AppState(); state.conversations = [source, user, ConversationEntry(role: "assistant", text: text)]
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        let restoredReceipt = try XCTUnwrap(restored.conversations[1].toolReceipts?.first)
        XCTAssertEqual(try CastReceiptStorage.expanded(restoredReceipt.output), revised)
        let replay = ReadingPrompt.history(from: restored.conversations, currentUserID: user.id, context: context)
        let facts = ReadingVerificationEvidence.facts(replay)
        XCTAssertTrue(facts.contains { $0.pointer == "/eventAssessment/outcome" })
        XCTAssertTrue(facts.contains { $0.pointer == "/eventAssessment/outcomeEstablished" && $0.value == false })
        let imported = try ArchiveCodec.decode(ArchiveCodec.encode(state))
        XCTAssertEqual(imported.conversations.last?.text, text)
        XCTAssertNil(imported.conversations[1].toolReceipts?.first?.context)
        XCTAssertEqual(try CastReceiptStorage.expanded(XCTUnwrap(imported.conversations[1].toolReceipts?.first?.output)), revised)
    }
    func testReferenceOnlySupplementAndReplayKeepFactsWithoutEventDirection() async throws {
        let bridge = try bridge(), now = "2024-02-04T04:00:00Z"
        let args: JSONValue = ["question": "先核对同次占问盘面", "questionType": "general", "subject": "unknown", "event": "同次事项", "timeHorizon": "near"]
        let original = try await result(bridge, ["command": "tool", "name": "cast_liuyao", "arguments": args, "now": .string(now)])
        let originalAssessment = try XCTUnwrap(ReadingVerificationEvidence.pointer("/eventAssessment", in: original))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision", in: original) else { return XCTFail("Missing revision") }
        let context = try ToolContext(birth: nil, engineRevision: revision, referenceDate: ISO8601DateFormatter().date(from: now)!, mode: "起卦")
        var source = ConversationEntry(role: "user", text: "先核对同次占问盘面")
        source.date = context.referenceDate; source.toolContext = context; source.analysisMode = context.mode
        source.toolReceipts = [.init(callID: "followup-original", name: "cast_liuyao", arguments: args,
                                    output: try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(original)), context: context)]
        let link = try CastSupplement.select(entryID: source.id, callID: "followup-original", entries: [source], context: context)
        var user = ConversationEntry(role: "user", text: "补充：这次问我自己的身体情况")
        user.toolContext = context; user.castSupplement = link
        var draft = try CastQuestionDraft(call: .init(id: "followup-derived", name: "cast_liuyao", arguments: link.arguments))
        draft.referenceOnly = true; draft.question = user.text; draft.questionType = "health"; draft.subject = "self"; draft.event = "本人的身体情况"
        let confirmation = try ConfirmedCastQuestion(draft: draft, userID: user.id, context: context)
        let revised = try await result(bridge, ["command": "reassess-question", "name": "cast_liuyao", "sourceCallID": "followup-original",
                                                "original": original, "arguments": confirmation.call.arguments])
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/lines", in: revised), ReadingVerificationEvidence.pointer("/lines", in: original))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/castTime", in: revised), ReadingVerificationEvidence.pointer("/castTime", in: original))
        XCTAssertNotEqual(ReadingVerificationEvidence.pointer("/eventAssessment", in: revised), originalAssessment)
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/eventAssessment/outcomeEstablished", in: revised), false)
        let receipt = ToolReceipt(callID: confirmation.call.id, name: link.derivedName, arguments: confirmation.call.arguments,
                                  output: try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(revised)), context: context)
        user.confirmedCastQuestions = [confirmation]; user.toolReceipts = [receipt]
        let text = try link.render(receipt: receipt, confirmation: confirmation, userID: user.id, entries: [source, user], context: context)
        XCTAssertTrue(text.contains("沿用原盘"))
        XCTAssertFalse(text.contains("事件方向（"))
        XCTAssertFalse(text.contains("事件候选"))
        guard case var .object(stale) = revised else { return XCTFail("Expected chart object") }
        stale["eventAssessment"] = originalAssessment
        var forged = receipt; forged.output = ReadingVerificationEvidence.encoded(JSONValue.object(stale))
        XCTAssertThrowsError(try link.render(receipt: forged, confirmation: confirmation, userID: user.id, entries: [source, user], context: context))

        var state = AppState(); state.conversations = [source, user, ConversationEntry(role: "assistant", text: text)]
        let restored = try JSONDecoder().decode(AppState.self, from: JSONEncoder().encode(state))
        let restoredReceipt = try XCTUnwrap(restored.conversations[1].toolReceipts?.first)
        XCTAssertEqual(try CastReceiptStorage.expanded(restoredReceipt.output), revised)
        let replay = ReadingPrompt.history(from: restored.conversations, currentUserID: user.id, context: context)
        let facts = ReadingVerificationEvidence.facts(replay)
        XCTAssertTrue(facts.contains { $0.pointer == "/eventAssessment/outcome" })
        XCTAssertTrue(facts.contains { $0.pointer == "/eventAssessment/outcomeEstablished" && $0.value == false })
        let imported = try ArchiveCodec.decode(ArchiveCodec.encode(state))
        XCTAssertEqual(imported.conversations.last?.text, text)
        XCTAssertNil(imported.conversations[1].toolReceipts?.first?.context)
        XCTAssertEqual(try CastReceiptStorage.expanded(XCTUnwrap(imported.conversations[1].toolReceipts?.first?.output)), revised)
    }
    func testQimenSelectionReconfirmationOriginalPlateStorageReplayAndArchive() async throws {
        let bridge = try bridge(), now = "2024-02-04T04:00:00Z"
        let original = try await result(bridge, ["command":"tool", "name":"setup_qimen", "arguments":specializedArguments, "now":.string(now)])
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:original) else { return XCTFail("Missing revision") }
        let context = try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        var source = ConversationEntry(role:"user",text:"本次降雨")
        source.date=context.referenceDate; source.toolContext=context; source.analysisMode=context.mode
        source.toolReceipts=[.init(callID:"qimen-selection-original",name:"setup_qimen",arguments:specializedArguments,
                                  output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(original)),context:context)]
        XCTAssertNotNil(QimenReferenceReading.render(receipts:source.toolReceipts!,context:context))
        let link = try CastSupplement.select(entryID:source.id,callID:"qimen-selection-original",entries:[source],context:context)
        for focus in ["weather-snow", "dwelling-stove", ""] {
            var user = ConversationEntry(role:"user",text:"补充明确本次取用对象")
            user.toolContext=context; user.castSupplement=link
            var draft = try CastQuestionDraft(call:.init(id:"qimen-selection-derived-"+focus,name:"setup_qimen",arguments:link.arguments))
            XCTAssertFalse(draft.specialSelectionEnabled)
            draft.specialSelectionEnabled = !focus.isEmpty; draft.specialSelectionFocus=focus
            draft.event = focus.isEmpty ? "只核对原盘" : focus == "weather-snow" ? "本次降雪" : "本次核对灶具"
            let confirmation = try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
            let revised = try await result(bridge,["command":"reassess-question","name":"setup_qimen","sourceCallID":"qimen-selection-original",
                                                   "original":original,"arguments":confirmation.call.arguments])
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/palaces",in:revised),ReadingVerificationEvidence.pointer("/palaces",in:original))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/setupTime",in:revised),ReadingVerificationEvidence.pointer("/setupTime",in:original))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/specializedSelection/request/focus",in:revised),focus.isEmpty ? nil : .string(focus))
            let receipt = ToolReceipt(callID:confirmation.call.id,name:link.derivedName,arguments:confirmation.call.arguments,
                                      output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(revised)),context:context)
            user.confirmedCastQuestions=[confirmation]; user.toolReceipts=[receipt]
            let text = try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[source,user],context:context)
            if focus == "weather-snow" { XCTAssertTrue(text.contains("天心")); XCTAssertTrue(text.contains("天柱")) }
            guard case var .object(stale) = revised else { return XCTFail("Expected chart") }
            stale["specializedSelection"]=ReadingVerificationEvidence.pointer("/specializedSelection",in:original)
            var forged=receipt; forged.output=ReadingVerificationEvidence.encoded(JSONValue.object(stale))
            XCTAssertThrowsError(try link.render(receipt:forged,confirmation:confirmation,userID:user.id,entries:[source,user],context:context))
            var state=AppState(); state.conversations=[source,user,.init(role:"assistant",text:text)]
            let restored=try JSONDecoder().decode(AppState.self,from:JSONEncoder().encode(state))
            XCTAssertEqual(try CastReceiptStorage.expanded(XCTUnwrap(restored.conversations[1].toolReceipts?.first?.output)),revised)
            let facts=ReadingVerificationEvidence.facts(ReadingPrompt.history(from:restored.conversations,currentUserID:user.id,context:context))
            if !focus.isEmpty {
                XCTAssertTrue(facts.contains { $0.pointer == "/specializedSelection/outcomeEstablished" && $0.value == false })
                XCTAssertTrue(facts.contains { $0.pointer == "/specializedSelection/request/focus" && $0.value == .string(focus) })
                if focus == "dwelling-stove" { XCTAssertTrue(facts.contains { $0.pointer == "/specializedSelection/references/0/selectedObjectPath" && $0.value == .null }) }
            }
            let imported=try ArchiveCodec.decode(ArchiveCodec.encode(state))
            XCTAssertNil(imported.conversations[1].toolReceipts?.first?.context)
            XCTAssertEqual(imported.conversations.last?.text,text)
            XCTAssertEqual(try CastReceiptStorage.expanded(XCTUnwrap(imported.conversations[1].toolReceipts?.first?.output)),revised)
        }
    }

}
