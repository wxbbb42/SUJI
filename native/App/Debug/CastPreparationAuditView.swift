#if DEBUG
import SwiftUI
import SujiCore

/// Offline UI fixture: archived planner omission, explicit test interaction,
/// actual bundled engine. It never connects to a provider or a real account.
@MainActor struct CastPreparationAuditView: View {
    @Environment(AppStore.self) private var store
    @State private var session = ChatSession()
    @State private var started = false
    @State private var status = "合成资料 · 未调用 AI · 尚未起盘"
    @State private var statusID = "audit.cast.waiting"
    var body: some View {
        ChatView(session: session)
            .safeAreaInset(edge: .top) {
                Text(status).font(.caption).padding(10).frame(maxWidth: .infinity)
                    .background(SujiTheme.surface).accessibilityIdentifier(statusID)
            }
            .task {
                guard !started else { return }; started = true
                session.working = true
                defer { session.working = false }
                do {
                    let original = "请用奇门问我自己近期能否签下新办公室租约，先只核对盘面依据。"
                    var entry = ConversationEntry(role: "user", text: original)
                    let metadata = try await store.request(["command": "metadata"])
                    let context = try ToolContext(birth: nil, engineRevision: metadata["engineRevision"].text, referenceDate: entry.date, mode: "起卦")
                    entry.toolContext = context; entry.analysisMode = "起卦"; entry.toolReceipts = []
                    store.state.conversations = [entry]; try store.saveThrowing()
                    let sourceID = entry.id
                    let call = ChatToolCall(id: "f4-ui-omission", name: "setup_qimen", arguments: ["question": "我自己近期能否签下新办公室租约", "questionType": "event", "subject": "self", "timeHorizon": "near"])
                    let definitions = try await store.request(["command": "tools"])
                    let tools = try ReadingIntent.definitions(from: Data(definitions.json.utf8), mode: "起卦", question: original, hasBirth: false)
                    let orchestrator = ToolOrchestrator(maxRounds: 1,
                        complete: { _, _ in .toolCalls([call]) },
                        execute: { accepted in
                            let arguments = try JSONSerialization.jsonObject(with: JSONEncoder().encode(accepted.arguments))
                            let result = try await store.request(["command": "tool", "name": accepted.name, "id": accepted.id, "arguments": arguments, "now": ISO8601DateFormatter().string(from: context.referenceDate)])
                            return ToolExecutionResult(output: result["result"].json)
                        },
                        persistReceipt: { receipt in store.state.conversations[0].toolReceipts = [receipt]; try store.saveThrowing() },
                        prepareCasts: { calls in try await session.castConfirmation.request(calls: calls, originalQuestion: original, userID: sourceID, context: context, checkScope: {}) },
                        persistConfirmations: { confirmations in try session.persist(confirmations: confirmations, on: sourceID, store: store) }
                    )
                    let result = try await orchestrator.run(history: [], definitions: tools, context: context, questionID: sourceID)
                    guard let receipt = result.receipts.first,
                          let value = try JSONSerialization.jsonObject(with: Data(receipt.output.utf8)) as? [String: Any] else { throw EngineError.execution("缺少盘面") }
                    let event = (value["questionContext"] as? [String: Any])?["event"] as? String ?? "未填写（仅核对盘面）"
                    status = "合成验收 · 确认已保存 · 引擎事项：" + event
                    statusID = "audit.cast.saved"
                } catch is CancellationError {
                    status = "合成验收 · 已取消 · 尚未起盘"
                    statusID = "audit.cast.cancelled"
                } catch { status = error.localizedDescription; statusID = "audit.cast.failed" }
            }
    }
}
#endif
