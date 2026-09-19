#if DEBUG
import SwiftUI
import SujiCore

/// Local calculation + local claim rendering. Never authenticates or calls a model.
/// SujiApp admits this view only in an in-memory UI-testing launch.
struct ReadingPresentationAuditView: View {
    @Environment(AppStore.self) private var store
    @State private var ready = false
    @State private var failure: String?
    @State private var session = ChatSession()
    @State private var delayedReply: ConversationEntry?

    var body: some View {
        Group {
            if ready { ChatView(session: session) }
            else if let failure { Text(failure) }
            else { ProgressView("准备合成资料") }
        }
        .task {
            guard !ready else { return }
            do {
                try await prepare(); ready = true
                if let delayedReply {
                    try await Task.sleep(for: .seconds(2))
                    // Reproduce the production observation order without an AI call.
                    session.partial = delayedReply.text
                    store.state.conversations.append(delayedReply)
                    session.partial = ""
                    session.working = false
                }
            }
            catch { failure = error.localizedDescription }
        }
    }

    private func prepare() async throws {
        let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T04:00:00Z")!
        let birth = BirthProfile(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
        store.state.birth = birth
        let metadata = try await store.request(["command": "metadata"])
        let context = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"].text, referenceDate: referenceDate, mode: "命理")
        var question = ConversationEntry(role: "user", text: "为什么扶抑用神和格局用神不同？可以结合我的资料解释吗？")
        question.date = referenceDate; question.toolContext = context; question.analysisMode = "命理"
        if ProcessInfo.processInfo.arguments.contains("--reading-failure-fixture") {
            question.toolReceipts = []
            store.state.conversations = [question]
            session.failure = "这次计算暂时没有完成。出生资料已保留，无需重填；可以重试。"
            return
        }
        let data = try await store.request(["command": "tool", "name": "get_domain", "id": "ui-audit:bazi-framework", "arguments": ["domain": "事业"], "birth": store.birthJSON(birth), "now": ISO8601DateFormatter().string(from: referenceDate)])
        let receipt = ToolReceipt(callID: "ui-audit:bazi-framework", name: "get_domain", arguments: ["domain": "事业"], output: data["result"].json, evidence: data["evidence"].strings, createdAt: referenceDate, context: context)
        guard let catalog = BaziFrameworkReading.catalog(receipts: [receipt], context: context) else { throw EngineError.execution("合成界面资料未能建立解释条目。") }
        let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog)
        question.toolReceipts = [receipt]
        var reply = ConversationEntry(role: "assistant", text: answer.text)
        reply.date = referenceDate; reply.toolContext = context
        reply.readingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: question.id)
        store.state.conversations = [question, reply]
        if ProcessInfo.processInfo.arguments.contains("--reading-delivery-fixture") {
            store.state.conversations = [question]
            delayedReply = reply
            session.working = true
            session.activity = "等待合成界面记录"
        }
        if ProcessInfo.processInfo.arguments.contains("--reading-followup-fixture") {
            var followup = ConversationEntry(role: "user", text: "可以简单说说吗？")
            followup.date = referenceDate.addingTimeInterval(60); followup.toolContext = context
            followup.analysisMode = "命理"; followup.toolReceipts = [receipt]
            let focused = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: .overview)
            var focusedReply = ConversationEntry(role: "assistant", text: focused.text)
            focusedReply.date = followup.date; focusedReply.toolContext = context
            focusedReply.readingDocument = ReadingDocument(catalog: catalog, answer: focused, sourceUserID: followup.id, focus: .overview)
            store.state.conversations += [followup, focusedReply]
        }
    }
}
#endif
