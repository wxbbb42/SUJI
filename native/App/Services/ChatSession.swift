import Foundation
import Observation
import SujiCore

@MainActor @Observable final class ChatSession {
    let castConfirmation = CastQuestionConfirmation()
    var working = false
    var partial = ""
    var activity = ""
    var failure: String?
    var evidence: [String] = []
    @ObservationIgnored private let makeClient: (AppStore) async throws -> ChatClient
    private var task: Task<Void, Never>?

    init(makeClient: @escaping (AppStore) async throws -> ChatClient = { try await $0.chatClient() }) {
        self.makeClient = makeClient
    }
    private var partialEntryID: UUID?
    private var pendingDocument: ReadingDocument?
    private var hasPreservedCalculation = false

    func stop() {
        castConfirmation.cancel()
        guard task != nil else { return }
        failure = hasPreservedCalculation
            ? "回答已停止，已计算的盘面会保留。可以重试继续解读。"
            : "回答已停止，可以重试继续。"
        task?.cancel()
    }

    func send(_ question: String, mode: String, store: AppStore, appendUser: Bool = true) {
        guard !working else { return }
        if !appendUser, let last = store.state.conversations.last(where: { $0.role == "user" }), last.castSupplement != nil {
            startSupplement(store: store, retryID: last.id)
            return
        }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let revision = store.scopeRevision
        let userID: UUID
        let historyEntries: [ConversationEntry]
        let cachedReceipts: [ToolReceipt]
        let confirmedQuestions: [ConfirmedCastQuestion]
        let replacementID: UUID?
        let referenceDate: Date
        let previousContext: ToolContext?
        let effectiveMode: String
        let originalQuestion: String

        if appendUser {
            guard !trimmedQuestion.isEmpty else { return }
            guard trimmedQuestion.count <= 8_000, trimmedQuestion.utf8.count <= 24_000 else { failure = "这段心事有些长，请先聚焦一个问题（最多8000字）。"; return }
            var entry = ConversationEntry(role: "user", text: trimmedQuestion)
            entry.toolReceipts = []
            entry.analysisMode = mode
            effectiveMode = mode
            originalQuestion = trimmedQuestion
            referenceDate = entry.date
            previousContext = nil
            store.state.conversations.append(entry)
            store.save()
            userID = entry.id
            historyEntries = Array(store.state.conversations.suffix(20))
            cachedReceipts = []
            confirmedQuestions = []
            replacementID = nil
            partialEntryID = nil
        } else {
            guard let userIndex = store.state.conversations.lastIndex(where: { $0.role == "user" }) else {
                failure = "没有可重试的问题。"
                return
            }
            let entry = store.state.conversations[userIndex]
            guard entry.toolContext != nil || entry.analysisMode != nil else {
                failure = "这条旧记录没有可验证的计算快照。原内容已保留，请发起新提问。"
                return
            }
            effectiveMode = entry.analysisMode ?? mode
            originalQuestion = entry.text
            referenceDate = entry.date
            previousContext = entry.toolContext
            guard !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            userID = entry.id
            historyEntries = Array(store.state.conversations[...userIndex].suffix(20))
            cachedReceipts = entry.toolReceipts ?? []
            confirmedQuestions = entry.confirmedCastQuestions ?? []
            replacementID = partialEntryID ?? store.state.conversations[(userIndex + 1)...]
                .last(where: { $0.role == "assistant" })?.id
        }

        let birth = store.state.birth
        let tone = store.state.tone
        failure = nil
        partial = ""
        evidence = []
        pendingDocument = nil
        hasPreservedCalculation = false
        working = true

        task = Task {
            defer { castConfirmation.cancel(); working = false; activity = ""; task = nil; pendingDocument = nil }
            do {
                let client = try await makeClient(store)
                try Self.checkScope(store, revision: revision, birth: birth)
                let metadata = try await store.request(["command": "metadata"])
                try Self.checkScope(store, revision: revision, birth: birth)
                let context = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"].text, referenceDate: referenceDate, mode: effectiveMode)
                guard context.isValid else { throw EngineError.execution("排盘版本信息无效，请更新应用。") }
                if let previousContext, previousContext != context { throw ToolOrchestratorError.staleContext }
                if cachedReceipts.contains(where: { $0.context != context }) { throw ToolOrchestratorError.staleContext }
                for confirmation in confirmedQuestions { try confirmation.validate(userID: userID, context: context) }
                hasPreservedCalculation = !cachedReceipts.isEmpty
                if let index = store.state.conversations.firstIndex(where: { $0.id == userID }) {
                    store.state.conversations[index].toolContext = context
                    try store.saveThrowing()
                }
                let instruction = ReadingPrompt.instruction(tone: tone, mode: effectiveMode, referenceDate: referenceDate, hasBirth: birth != nil)
                let presentation = BaziReadingRequest.resolveRequest(question: originalQuestion, mode: effectiveMode, entries: historyEntries, currentUserID: userID, context: context)
                let focus = presentation?.focuses.first
                // These caches belong only to this user entry and passed the
                // context checks above. A retry planner may need no new calls.
                var frameworkReceipts = cachedReceipts
                var qimenReferenceRequest = false
                var liuyaoReferenceRequest = false
                var history = [ChatMessage(role: .system, content: instruction)]
                history.append(contentsOf: ReadingPrompt.history(from: historyEntries, currentUserID: userID, context: context))

                if effectiveMode != "倾诉" {
                    try Self.checkScope(store, revision: revision, birth: birth)
                    activity = "正在整理线索"
                    let definitions = try await loadDefinitions(mode: effectiveMode, question: originalQuestion, birth: birth, store: store)
                    qimenReferenceRequest = QimenReferenceReading.isExclusiveRequest(definitions: definitions, question: originalQuestion)
                    liuyaoReferenceRequest = LiuyaoReferenceReading.isExclusiveRequest(definitions: definitions, question: originalQuestion)
                    try Self.checkScope(store, revision: revision, birth: birth)
                    history[0].content = instruction + "\n" + ReadingPrompt.plannerInstruction(question: originalQuestion, mode: effectiveMode, focus: focus)
                    let frameworkCallID = "bazi-" + UUID().uuidString
                    let orchestrator = ToolOrchestrator(
                        complete: { messages, tools in
                            if focus != nil {
                                return BaziFrameworkReading.plan(callID: frameworkCallID, history: messages, cachedReceipts: cachedReceipts, context: context, hasBirth: birth != nil)
                            }
                            return try await client.complete(messages: messages, tools: tools)
                        },
                        execute: { call in
                            try Task.checkCancellation()
                            try Self.checkScope(store, revision: revision, birth: birth)
                            self.activity = Self.toolLabel(call.name)
                            var request: [String: Any] = [
                                "command": "tool",
                                "name": call.name,
                                "id": call.id,
                                "arguments": try JSONSerialization.jsonObject(with: JSONEncoder().encode(call.arguments)),
                                "now": ISO8601DateFormatter().string(from: referenceDate),
                            ]
                            if let birth { request["birth"] = try store.birthJSON(birth) }
                            let document: Document
                            if ["cast_liuyao", "setup_qimen"].contains(call.name) {
                                // Once a cast has started, let the deterministic engine finish so
                                // its receipt can be saved even if the user stops the prose reply.
                                // The next cancellation check ends orchestration after persistence,
                                // and an account switch still rejects the result below.
                                let cast = Task { @MainActor in try await store.request(request) }
                                document = try await cast.value
                            } else {
                                document = try await store.request(request)
                            }
                            try Self.checkScope(store, revision: revision, birth: birth)
                            return ToolExecutionResult(
                                output: document["result"].json,
                                evidence: document["evidence"].strings
                            )
                        },
                        persistReceipt: { receipt in
                            try Self.checkScope(store, revision: revision, birth: birth)
                            try self.persist(receipt: receipt, on: userID, store: store, revision: revision, birth: birth)
                        },
                        prepareCasts: { calls in
                            self.activity = "等待核对占问资料"
                            return try await self.castConfirmation.request(calls: calls, originalQuestion: originalQuestion, userID: userID, context: context) {
                                try Self.checkScope(store, revision: revision, birth: birth)
                            }
                        },
                        persistConfirmations: { confirmations in
                            try Self.checkScope(store, revision: revision, birth: birth)
                            try self.persist(confirmations: confirmations, on: userID, store: store)
                        }
                    )
                    let result = try await orchestrator.run(
                        history: history,
                        definitions: definitions,
                        cachedReceipts: cachedReceipts,
                        context: context,
                        questionID: userID,
                        confirmedQuestions: confirmedQuestions
                    )
                    history = result.messages
                    frameworkReceipts += result.receipts
                    evidence = result.evidence
                    if result.reachedRoundLimit {
                        history.append(ChatMessage(
                            role: .user,
                            content: "已达到工具轮次上限，请说明现有依据的限度，不要继续起盘。"
                        ))
                    }
                    history[0].content = instruction + "\n" + ReadingPrompt.writer + "\n若本次有用户确认的占问资料，按确认后的问题、对象、事项和范围解读；仅核对盘面时不判断成败或日期。"
                    if evidence.isEmpty { history[0].content! += "\n本次没有取得新的计算证据；只能提供一般建议，不能声称已完成命盘解读。" }

                }

                let currentConfirmations = store.state.conversations.first(where: { $0.id == userID })?.confirmedCastQuestions ?? []
                for confirmation in currentConfirmations { try confirmation.validate(userID: userID, context: context) }
                let verificationQuestion = ReadingPrompt.verificationQuestion(original: originalQuestion, confirmations: currentConfirmations)

                if let focus {
                    activity = "正在整理解释依据"
                    if let catalog = BaziFrameworkReading.catalog(receipts: frameworkReceipts, context: context) {
                        let answer = try await BaziFrameworkReading.compose(catalog: catalog, question: originalQuestion, focus: focus, presentation: presentation) { messages in
                            try Self.checkScope(store, revision: revision, birth: birth)
                            let selected = try await client.complete(messages: messages)
                            try Self.checkScope(store, revision: revision, birth: birth)
                            return selected
                        }
                        try Task.checkCancellation()
                        try Self.checkScope(store, revision: revision, birth: birth)
                        partial = answer.text
                        pendingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: userID, focus: focus, presentation: presentation)
                    } else {
                        partial = BaziFrameworkReading.unavailableReply(hasBirth: birth != nil, focus: focus)
                    }
                } else if qimenReferenceRequest {
                    activity = "正在整理奇门依据"
                    try Task.checkCancellation()
                    try Self.checkScope(store, revision: revision, birth: birth)
                    partial = QimenReferenceReading.render(receipts: frameworkReceipts, context: context)?.text
                        ?? QimenReferenceReading.unavailableReply(receipts: frameworkReceipts)
                } else if liuyaoReferenceRequest {
                    activity = "正在整理六爻依据"
                    try Task.checkCancellation()
                    try Self.checkScope(store, revision: revision, birth: birth)
                    partial = LiuyaoReferenceReading.render(receipts: frameworkReceipts, context: context)?.text
                        ?? LiuyaoReferenceReading.unavailableReply(receipts: frameworkReceipts)
                } else {
                    activity = "正在写回信"
                    var draft = ""
                    for try await delta in client.streamText(messages: history) {
                        try Task.checkCancellation()
                        try Self.checkScope(store, revision: revision, birth: birth)
                        if effectiveMode == "倾诉" { partial += delta } else { draft += delta }
                    }
                    try Task.checkCancellation()
                    try Self.checkScope(store, revision: revision, birth: birth)
                    if effectiveMode != "倾诉" {
                        activity = "正在核对盘面依据"
                        do {
                            let verified = try await ReadingVerifier.verify(draft: draft, history: history, question: verificationQuestion) { messages in
                                try Self.checkScope(store, revision: revision, birth: birth)
                                let result = try await client.complete(messages: messages)
                                try Self.checkScope(store, revision: revision, birth: birth)
                                return result
                            }
                            try Task.checkCancellation()
                            try Self.checkScope(store, revision: revision, birth: birth)
                            partial = verified
                        } catch let error as ReadingVerifier.Rejected {
                            try Task.checkCancellation()
                            try Self.checkScope(store, revision: revision, birth: birth)
                            failure = error.localizedDescription
                            partial = ReadingFallback.reply(history: history)
                        }
                    }
                }
                try Task.checkCancellation()
                try Self.checkScope(store, revision: revision, birth: birth)
                guard !partial.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw EngineError.execution("模型没有返回内容，请重试。")
                }
                _ = try persistReply(store, revision: revision, birth: birth, replacing: replacementID)
                partialEntryID = nil
            } catch {
                guard store.scopeRevision == revision else {
                    partial = ""
                    return
                }
                if store.state.birth != birth {
                    partial = ""
                    failure = "出生资料已更改，本次解读已停止。请用新资料重新提问。"
                    return
                }
                if !partial.isEmpty {
                    partialEntryID = try? persistReply(store, revision: revision, birth: birth, replacing: replacementID)
                }
                if !Task.isCancelled && !(error is CancellationError) {
                    failure = error.localizedDescription
                }
            }
        }
    }

    func supplement(entryID: UUID, callID: String, store: AppStore) {
        guard !working else { return }
        startSupplement(store: store, selection: (entryID, callID))
    }

    private func startSupplement(store: AppStore, selection: (UUID, String)? = nil, retryID: UUID? = nil) {
        let revision = store.scopeRevision, birth = store.state.birth
        failure = nil; partial = ""; evidence = []; pendingDocument = nil
        hasPreservedCalculation = false; working = true; activity = "正在核对原盘"
        task = Task {
            defer { castConfirmation.cancel(); working = false; activity = ""; task = nil }
            do {
                let metadata = try await store.request(["command": "metadata"])
                try Task.checkCancellation()
                try Self.checkScope(store, revision: revision, birth: birth)
                let userID: UUID
                if let selection {
                    guard let source = store.state.conversations.first(where: { $0.id == selection.0 }), let previous = source.toolContext else { throw ToolOrchestratorError.staleContext }
                    let context = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"].text, referenceDate: previous.referenceDate, mode: previous.mode)
                    let link = try CastSupplement.select(entryID: selection.0, callID: selection.1, entries: store.state.conversations, context: context)
                    let originalQuestion = store.state.conversations.first(where: { $0.id == link.sourceUserID })?.text ?? source.text
                    var entry = ConversationEntry(role: "user", text: "补充这次占问：" + originalQuestion)
                    entry.toolContext = context; entry.analysisMode = context.mode; entry.castSupplement = link; entry.toolReceipts = []
                    userID = entry.id
                    try link.validate(userID: userID, entries: store.state.conversations + [entry], context: context)
                    store.state.conversations.append(entry)
                    do { try store.saveThrowing() }
                    catch { store.state.conversations.removeAll { $0.id == userID }; throw error }
                } else if let retryID { userID = retryID }
                else { throw CancellationError() }
                guard let entry = store.state.conversations.first(where: { $0.id == userID }), let link = entry.castSupplement, let context = entry.toolContext else { throw CancellationError() }
                let currentContext = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"].text, referenceDate: context.referenceDate, mode: context.mode)
                try link.validate(userID: userID, entries: store.state.conversations, context: currentContext)
                let confirmation: ConfirmedCastQuestion
                if let existing = entry.confirmedCastQuestions, !existing.isEmpty {
                    guard existing.count == 1 else { throw ToolOrchestratorError.staleContext }
                    confirmation = existing[0]
                    try confirmation.validate(userID: userID, context: context)
                } else {
                    guard entry.toolReceipts?.isEmpty ?? true else { throw ToolOrchestratorError.staleContext }
                    activity = "等待核对补充资料"
                    let call = ChatToolCall(id: "supplement-" + UUID().uuidString, name: link.original.name, arguments: link.arguments)
                    let confirmed = try await castConfirmation.request(calls: [call], originalQuestion: entry.text, userID: userID, context: context, reusesOriginal: true, referenceOnly: link.referenceOnly) {
                        try Self.checkScope(store, revision: revision, birth: birth)
                        try link.validate(userID: userID, entries: store.state.conversations, context: context)
                    }
                    try Task.checkCancellation()
                    try Self.checkScope(store, revision: revision, birth: birth)
                    try persist(confirmations: confirmed, on: userID, store: store)
                    confirmation = confirmed[0]
                }
                try Self.checkScope(store, revision: revision, birth: birth)
                guard confirmation.call.name == link.original.name else { throw ToolOrchestratorError.staleContext }
                let receipt: ToolReceipt
                let cached = entry.toolReceipts ?? []
                if !cached.isEmpty {
                    guard cached.count == 1 else { throw ToolOrchestratorError.staleContext }
                    receipt = cached[0]
                } else {
                    try Task.checkCancellation()
                    activity = "正在沿用原盘核对补充"
                    let request: [String: Any] = ["command": "reassess-question", "name": link.original.name, "sourceCallID": link.original.callID,
                        "original": try JSONSerialization.jsonObject(with: CastReceiptStorage.expandedData(link.original.output)),
                        "arguments": try JSONSerialization.jsonObject(with: JSONEncoder().encode(confirmation.call.arguments))]
                    // Finish and persist a started reassessment even if prose is stopped.
                    let calculation = Task { @MainActor in try await store.request(request) }
                    let document = try await calculation.value
                    try Self.checkScope(store, revision: revision, birth: birth)
                    receipt = ToolReceipt(callID: confirmation.call.id, name: link.derivedName, arguments: confirmation.call.arguments,
                        output: try CastReceiptStorage.encode(document["result"].json), evidence: document["evidence"].strings, context: context)
                    _ = try link.render(receipt: receipt, confirmation: confirmation, userID: userID, entries: store.state.conversations, context: context)
                    try persist(receipt: receipt, on: userID, store: store, revision: revision, birth: birth)
                }
                hasPreservedCalculation = true
                let rendered = try link.render(receipt: receipt, confirmation: confirmation, userID: userID, entries: store.state.conversations, context: context)
                try Task.checkCancellation()
                try Self.checkScope(store, revision: revision, birth: birth)
                partial = rendered; evidence = receipt.evidence
                let index = store.state.conversations.firstIndex(where: { $0.id == userID })!
                let replacement = store.state.conversations.dropFirst(index + 1).first(where: { $0.role == "assistant" })?.id
                _ = try persistReply(store, revision: revision, birth: birth, replacing: replacement)
                partialEntryID = nil
            } catch {
                partial = ""
                guard store.scopeRevision == revision else { return }
                if store.state.birth != birth { failure = "出生资料已更改，本次补充已停止。" }
                else if !Task.isCancelled && !(error is CancellationError) { failure = error.localizedDescription }
            }
        }
    }

    private func loadDefinitions(mode: String, question: String, birth: BirthProfile?, store: AppStore) async throws -> [ChatToolDefinition] {
        let definitions = try await store.request(["command": "tools"])
        return try ReadingIntent.definitions(from: Data(definitions.json.utf8), mode: mode, question: question, hasBirth: birth != nil)
    }

    func persist(confirmations: [ConfirmedCastQuestion], on userID: UUID, store: AppStore) throws {
        guard let index = store.state.conversations.firstIndex(where: { $0.id == userID && $0.role == "user" }),
              let context = store.state.conversations[index].toolContext else { throw CancellationError() }
        for confirmation in confirmations { try confirmation.validate(userID: userID, context: context) }
        let previous = store.state.conversations[index].confirmedCastQuestions
        let existing = previous ?? []
        guard Set(existing.map { $0.call.name } + confirmations.map { $0.call.name }).count == existing.count + confirmations.count else {
            throw EngineError.execution("这次占问已有已确认资料，请重试继续")
        }
        store.state.conversations[index].confirmedCastQuestions = existing + confirmations
        do { try store.saveThrowing() }
        catch { store.state.conversations[index].confirmedCastQuestions = previous; throw error }
    }

    private func persist(
        receipt: ToolReceipt,
        on userID: UUID,
        store: AppStore,
        revision: UUID,
        birth: BirthProfile?
    ) throws {
        try Self.checkScope(store, revision: revision, birth: birth)
        guard let index = store.state.conversations.firstIndex(where: { $0.id == userID && $0.role == "user" }) else {
            throw CancellationError()
        }
        var receipts = store.state.conversations[index].toolReceipts ?? []
        guard !receipts.contains(where: { $0.callID == receipt.callID }) else { return }
        receipts.append(receipt)
        store.state.conversations[index].toolReceipts = receipts
        store.state.conversations[index].toolData.append(receipt.output)
        try store.saveThrowing()
        hasPreservedCalculation = true
    }

    @discardableResult
    private func persistReply(_ store: AppStore, revision: UUID, birth: BirthProfile?, replacing id: UUID?) throws -> UUID {
        try Self.checkScope(store, revision: revision, birth: birth)
        let uniqueEvidence = Self.unique(evidence)
        if let id, let index = store.state.conversations.firstIndex(where: { $0.id == id && $0.role == "assistant" }) {
            store.state.conversations[index].text = partial
            store.state.conversations[index].evidence = uniqueEvidence
            store.state.conversations[index].readingDocument = pendingDocument
            store.save()
            partial = ""
            return id
        }
        var entry = ConversationEntry(role: "assistant", text: partial)
        entry.evidence = uniqueEvidence
        entry.readingDocument = pendingDocument
        store.state.conversations.append(entry)
        store.save()
        partial = ""
        return entry.id
    }

    private static func checkScope(_ store: AppStore, revision: UUID, birth: BirthProfile?) throws {
        guard store.scopeRevision == revision, store.state.birth == birth else { throw CancellationError() }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    static func toolLabel(_ name: String) -> String {
        [
            "get_domain": "参照你的命盘",
            "get_bazi_star": "整理四柱关系",
            "list_shensha": "核对传统线索",
            "get_timing": "查看时间节奏",
            "get_today_context": "查看今日历法",
            "get_ziwei_palace": "参照紫微宫位",
            "get_ziwei_timing": "核对紫微大限与流年",
            "cast_liuyao": "起一卦，留一点思考",
            "setup_qimen": "整理奇门盘面",
            "reassess_liuyao": "六爻 · 原盘补充",
            "reassess_qimen": "奇门 · 原盘补充",
        ][name] ?? "正在核对依据"
    }
}
