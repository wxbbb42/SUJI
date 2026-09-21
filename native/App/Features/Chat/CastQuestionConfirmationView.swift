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
                    Text(request.reusesOriginal ? "请补充同一件事的资料。确认后沿用原盘，另存一份核对结果。若改问另一件事，请返回发起新提问。" : "请核对以下资料，确认后开始起盘。重试会沿用这次资料和盘面。")
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
                        if draft.proposedCall.name == "setup_qimen" && !draft.referenceOnly {
                            Toggle("查看条件应期", isOn:$draft.timingEnabled)
                                .accessibilityIdentifier("cast.timing.enabled")
                            if draft.timingEnabled {
                                Picker("应期对象", selection:$draft.timingFocus) {
                                    Text("请选择").tag("")
                                    Text("工作或单位").tag("employment")
                                    Text("经营利润").tag("profit")
                                    Text("婚恋关系整体").tag("relationship")
                                    Text("我自己").tag("self")
                                }.accessibilityIdentifier("cast.timing.focus")
                                Picker("时间单位", selection:$draft.timingUnit) {
                                    Text("请选择").tag("")
                                    Text("年").tag("year");Text("月").tag("month")
                                    Text("日").tag("day");Text("时辰").tag("hour")
                                }.accessibilityIdentifier("cast.timing.unit")
                                TextField("截止日期（YYYY-MM-DD）",text:$draft.timingEndDate)
                                    .keyboardType(.numbersAndPunctuation).accessibilityIdentifier("cast.timing.end")
                                Toggle("包含起盘所在的当前时段",isOn:$draft.timingIncludeCurrent)
                                    .accessibilityIdentifier("cast.timing.current")
                                Text("按北京时间查至所填日期结束。近期、远期不能代替时间单位；候选时间不代表事情一定成功，未满足条件时可能没有日期。")
                                    .font(.footnote).foregroundStyle(SujiTheme.secondary)
                            }
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
                    Text(request.reusesOriginal ? "沿用这个时刻已经保存的盘面；本次补充不改变原爻、九宫与干支。" : "按原提问时刻起盘；确认资料不会改变起盘时间。资料明确后，取用与应期仍须分别核对。")
                        .font(.footnote).foregroundStyle(SujiTheme.secondary)
                    if let failure = gate.validationFailure { Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary) }
                    Button(request.reusesOriginal ? "确认补充并沿用原盘" : "确认资料并起盘") { gate.confirm(id: request.id, drafts: drafts) }
                        .disabled(drafts.contains { $0.validationMessage != nil })
                        .accessibilityIdentifier("cast.confirm")
                }
            }
            .navigationTitle(request.reusesOriginal ? "补充这次占问" : "确认占问").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(request.reusesOriginal ? "取消补充" : "暂不起盘", action: cancel).accessibilityIdentifier("cast.cancel") } }
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
