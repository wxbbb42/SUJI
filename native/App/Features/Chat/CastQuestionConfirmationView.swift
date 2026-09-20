import SwiftUI
import SujiCore

@MainActor struct CastQuestionConfirmationView: View {
    let request: CastQuestionConfirmation.Request
    let gate: CastQuestionConfirmation
    let cancel: () -> Void
    @State private var drafts: [CastQuestionDraft]

    init(request: CastQuestionConfirmation.Request, gate: CastQuestionConfirmation, cancel: @escaping () -> Void) {
        self.request = request
        self.gate = gate
        self.cancel = cancel
        _drafts = State(initialValue: request.drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.originalQuestion).textSelection(.enabled)
                } header: { Text("你的原问题") } footer: {
                    Text("请核对以下资料，确认后开始起盘。重试会沿用这次资料和盘面。")
                }
                ForEach($drafts) { $draft in
                    Section(draft.methodName + " · 占问资料") {
                        TextField("具体问题", text: $draft.question, axis: .vertical)
                            .lineLimit(2...6).accessibilityIdentifier("cast.question." + draft.proposedCall.name)
                        Picker("所问对象", selection: $draft.subject) {
                            ForEach(CastQuestionDraft.subjects, id: \.self) { Text(subjectLabel($0)).tag($0) }
                        }.accessibilityIdentifier("cast.subject." + draft.proposedCall.name)
                        TextField("具体事项（待补充）", text: $draft.event, axis: .vertical)
                            .lineLimit(2...5).accessibilityIdentifier("cast.event." + draft.proposedCall.name)
                        Picker("问题类别", selection: $draft.questionType) {
                            ForEach(CastQuestionDraft.questionTypes, id: \.self) { Text(typeLabel($0)).tag($0) }
                        }
                        Picker("时间范围", selection: $draft.timeHorizon) {
                            Text("尚未明确").tag("unspecified")
                            Text("近期的事").tag("near")
                            Text("较长远的事").tag("far")
                        }
                        Toggle("仅核对盘面", isOn: $draft.referenceOnly)
                            .accessibilityIdentifier("cast.reference." + draft.proposedCall.name)
                        if draft.referenceOnly {
                            Text("可以暂不填写事项；本次只查看盘面依据，不判断事情成败或日期。")
                                .font(.footnote).foregroundStyle(SujiTheme.secondary)
                        }
                        if draft.subject == "unknown" || draft.timeHorizon == "unspecified" {
                            Text("未明确的对象或时间范围会保留为待澄清条件，不据此定用或推断具体日期。")
                                .font(.footnote).foregroundStyle(SujiTheme.secondary)
                        }
                        if let message = draft.validationMessage {
                            Text(message).font(.footnote).foregroundStyle(SujiTheme.secondary)
                                .accessibilityIdentifier("cast.validation." + draft.proposedCall.name)
                        }
                    }
                }
                Section {
                    LabeledContent("提问时间") { Text(request.referenceDate, format: .dateTime.year().month().day().hour().minute()) }
                    Text("按原提问时刻起盘；确认资料不会改变起盘时间。资料明确后，取用与应期仍须分别核对。")
                        .font(.footnote).foregroundStyle(SujiTheme.secondary)
                    if let failure = gate.validationFailure { Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                    Button("确认资料并起盘") { gate.confirm(id: request.id, drafts: drafts) }
                        .disabled(drafts.contains { $0.validationMessage != nil })
                        .accessibilityIdentifier("cast.confirm")
                }
            }
            .navigationTitle("确认占问").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("暂不起盘", action: cancel).accessibilityIdentifier("cast.cancel") } }
        }
        .interactiveDismissDisabled()
        .onDisappear { gate.cancel(id: request.id) }
    }

    private func subjectLabel(_ value: String) -> String {
        ["unknown": "尚不清楚", "self": "我自己", "parent": "我的父母", "child": "我的子女", "sibling": "我的兄弟姐妹", "wife": "我的妻子", "husband": "我的丈夫", "other": "其他人"] [value] ?? value
    }
    private func typeLabel(_ value: String) -> String {
        ["general": "暂不归类", "career": "事业", "wealth": "财物", "marriage": "婚恋", "kids": "子女", "parents": "父母", "health": "健康", "event": "具体事件"] [value] ?? value
    }
}
