import Foundation
import Observation
import SujiCore

@MainActor @Observable final class ChatSession {
    var working = false
    var partial = ""
    var activity = ""
    var failure: String?
    var evidence: [String] = []
    private var task: Task<Void, Never>?
    private var partialEntryID: UUID?
    private var pendingDocument: ReadingDocument?
    private var hasPreservedCalculation = false

    func stop() {
        guard task != nil else { return }
        failure = hasPreservedCalculation
            ? "回答已停止，已计算的盘面会保留。可以重试继续解读。"
            : "回答已停止，可以重试继续。"
        task?.cancel()
    }

    func send(_ question: String, mode: String, store: AppStore, appendUser: Bool = true) {
        guard !working else { return }

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let revision = store.scopeRevision
        let userID: UUID
        let historyEntries: [ConversationEntry]
        let cachedReceipts: [ToolReceipt]
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
            defer { working = false; activity = ""; task = nil; pendingDocument = nil }
            do {
                let client = try await store.chatClient()
                try Self.checkScope(store, revision: revision, birth: birth)
                let metadata = try await store.request(["command": "metadata"])
                try Self.checkScope(store, revision: revision, birth: birth)
                let context = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"].text, referenceDate: referenceDate, mode: effectiveMode)
                guard context.isValid else { throw EngineError.execution("排盘版本信息无效，请更新应用。") }
                if let previousContext, previousContext != context { throw ToolOrchestratorError.staleContext }
                if cachedReceipts.contains(where: { $0.context != context }) { throw ToolOrchestratorError.staleContext }
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
                var history = [ChatMessage(role: .system, content: instruction)]
                history.append(contentsOf: ReadingPrompt.history(from: historyEntries, currentUserID: userID, context: context))

                if effectiveMode != "倾诉" {
                    try Self.checkScope(store, revision: revision, birth: birth)
                    activity = "正在整理线索"
                    let definitions = try await loadDefinitions(mode: effectiveMode, question: originalQuestion, birth: birth, store: store)
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
                        }
                    )
                    let result = try await orchestrator.run(
                        history: history,
                        definitions: definitions,
                        cachedReceipts: cachedReceipts,
                        context: context
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
                    history[0].content = instruction + "\n" + ReadingPrompt.writer
                    if evidence.isEmpty { history[0].content! += "\n本次没有取得新的计算证据；只能提供一般建议，不能声称已完成命盘解读。" }

                }

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
                            let verified = try await ReadingVerifier.verify(draft: draft, history: history, question: originalQuestion) { messages in
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

    private func loadDefinitions(mode: String, question: String, birth: BirthProfile?, store: AppStore) async throws -> [ChatToolDefinition] {
        let definitions = try await store.request(["command": "tools"])
        return try ReadingIntent.definitions(from: Data(definitions.json.utf8), mode: mode, question: question, hasBirth: birth != nil)
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
            "cast_liuyao": "起一卦，留一点思考",
            "setup_qimen": "整理奇门盘面",
        ][name] ?? "正在核对依据"
    }
}
