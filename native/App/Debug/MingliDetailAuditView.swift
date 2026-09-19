#if DEBUG
import SwiftUI
import SujiCore

/// Only reachable with both UI-testing launch flags; SujiApp uses an in-memory notebook.
/// This renders production views with synthetic records and never authenticates or calls AI.
struct MingliDetailAuditView: View {
    @Environment(AppStore.self) private var store
    @State private var ready = false
    @State private var failure: String?
    private let baseKey = "ui-audit:reflection"
    private let reflectionContext = #"{"fixture":"current-calibration"}"#
    private let referenceDate = ISO8601DateFormatter().date(from: "2026-09-19T04:00:00Z")!
    private let birth = BirthProfile(year: 1995, month: 1, day: 1, hour: 12, minute: 0, gender: "女", city: "上海", longitude: 121.47)

    var body: some View {
        NavigationStack {
            List {
                if ready {
                    NavigationLink("六爻明细验收") {
                        ReadingEvidenceView(receipts: [receipt("cast_liuyao", field: "liuyao")]).safeAreaInset(edge: .top, spacing: 0) { banner }
                    }
                    NavigationLink("奇门明细验收") {
                        ReadingEvidenceView(receipts: [receipt("setup_qimen", field: "qimen")]).safeAreaInset(edge: .top, spacing: 0) { banner }
                    }
                    NavigationLink("历史整理分组验收") {
                        ReflectionView(title: "整理记录验收", key: baseKey, context: reflectionContext,
                            instruction: "合成界面测试，不发送请求。", opening: "合成测试资料。",
                            privacy: "合成界面记录，不是真实经历或模型回信；本次没有调用 AI。")
                            .safeAreaInset(edge: .top, spacing: 0) { banner }
                    }
                } else if let failure { Text(failure) }
                else { ProgressView("准备合成资料") }
            }
            .navigationTitle("明细界面验收")
            .safeAreaInset(edge: .top, spacing: 0) { banner }
        }
        .task {
            do { try prepare(); ready = true }
            catch { failure = error.localizedDescription }
        }
    }

    private var banner: some View {
        Text("界面验收 · 合成数据 · 未调用 AI")
            .font(.caption.weight(.medium)).dynamicTypeSize(...DynamicTypeSize.xxxLarge).foregroundStyle(SujiTheme.ink)
            .frame(maxWidth: .infinity).padding(10).background(SujiTheme.surface)
            .accessibilityIdentifier("audit.synthetic")
    }

    private func receipt(_ name: String, field: String) -> ToolReceipt {
        let data = try! Document(data: Data(MingliDetailAuditData.json.utf8))
        let context = try! ToolContext(birth: nil, engineRevision: MingliDetailAuditData.engineRevision, referenceDate: referenceDate, mode: "起卦")
        return ToolReceipt(callID: "ui-audit:" + name, name: name, arguments: [:], output: data[field].json,
            evidence: ["合成输入的本地计算，用于核对界面；不是模型回信。"], createdAt: referenceDate, context: context)
    }

    private func prepare() throws {
        guard !ready else { return }
        store.state.birth = birth
        let current = try ToolContext(birth: birth, engineRevision: store.engineRevision, referenceDate: referenceDate, mode: "倾诉")
        var otherBirth = birth; otherBirth.hour = 10
        let earlierBirth = try ToolContext(birth: otherBirth, engineRevision: store.engineRevision, referenceDate: referenceDate, mode: "倾诉")
        let earlierEngine = try ToolContext(birth: birth, engineRevision: "synthetic-older-engine", referenceDate: referenceDate, mode: "倾诉")
        let currentKey = ReflectionSession.effectiveKey(base: baseKey, context: reflectionContext, birth: birth, engineRevision: store.engineRevision)
        func entry(_ role: String, _ text: String, day: Int, context: ToolContext?) -> ConversationEntry {
            var entry = ConversationEntry(role: role, text: "【合成测试记录】" + text)
            entry.date = referenceDate.addingTimeInterval(Double(-day * 86_400))
            entry.toolContext = context
            return entry
        }
        store.state.reflections = [
            currentKey: [entry("user", "当前资料：这一轮还没有回信。", day: 0, context: current)],
            "ui-audit:previous-birth": [
                entry("user", "旧出生资料：当时填写的是上午十点。", day: 1, context: earlierBirth),
                entry("assistant", "旧出生资料的占位段落，非模型回信。", day: 1, context: earlierBirth),
            ],
            "ui-audit:previous-engine": [
                entry("user", "旧计算版本：保留当时的整理记录。", day: 2, context: earlierEngine),
                entry("assistant", "旧计算版本的占位段落，非模型回信。", day: 2, context: earlierEngine),
            ],
            "ui-audit:imported": [
                entry("user", "导入旧记录：原资料与版本无法验证。", day: 3, context: nil),
                entry("assistant", "导入记录的占位段落，非模型回信。", day: 3, context: nil),
            ],
        ]
    }
}
#endif
