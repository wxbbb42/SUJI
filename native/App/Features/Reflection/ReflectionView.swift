import SwiftUI
import SujiCore

struct ReflectionView: View {
    @Environment(AppStore.self) private var store
    let title: String
    let key: String
    let context: String
    let instruction: String
    let opening: String
    let privacy: String
    @State private var session = ReflectionSession()
    @State private var input = ""
    @State private var sourceIdentity: String?
    @FocusState private var focused: Bool
    private var effectiveKey: String {
        ReflectionSession.effectiveKey(base: key, context: context, birth: store.state.birth, engineRevision: store.engineRevision)
    }
    private var currentContext: ToolContext? {
        try? ToolContext(birth: store.state.birth, engineRevision: store.engineRevision, referenceDate: Date(), mode: "倾诉")
    }
    private func matchesCurrent(_ entry: ConversationEntry) -> Bool {
        guard let expected = currentContext, let actual = entry.toolContext else { return false }
        return actual.birthFingerprint == expected.birthFingerprint && actual.engineRevision == expected.engineRevision
    }
    private var messages: [ConversationEntry] { (store.state.reflections?[effectiveKey] ?? []).filter(matchesCurrent) }
    private var archivedSessions: [ReflectionConversation.ArchivedSession] {
        ReflectionConversation.archivedSessions(store.state.reflections ?? [:], currentKey: effectiveKey, context: currentContext)
    }
    private var pendingReply: Bool { messages.last?.role == "user" }
    private var viewIdentity: String { store.scopeRevision.uuidString + ":" + effectiveKey }
    private var sourceChanged: Bool { sourceIdentity != nil && sourceIdentity != viewIdentity }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(title).font(SujiTheme.serif(30)).padding(.top, 12)
                    Text(privacy).font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                    if sourceChanged {
                        Text("资料或账户已改变。请返回上一页，重新打开这段整理，以免沿用旧的盘面资料。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    }
                    if !store.isSignedIn {
                        Text("登录后即可开始 AI 整理，回信会保存在当前账户的册页。").font(.subheadline).foregroundStyle(SujiTheme.secondary)
                        NavigationLink("账户与登录") { AccountView(session: store.accountSession) }.font(.subheadline)
                    }
                    if messages.isEmpty {
                        Text(opening).font(.body).lineSpacing(8)
                        Button("开始这段整理") { send(opening) }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule).disabled(!store.isSignedIn || sourceChanged)
                    }
                    ForEach(messages) { entry in
                        messageView(entry)
                    }
                    if session.working {
                        if session.partial.isEmpty { ProgressView("正在整理") }
                        else { Text(.init(session.partial)).lineSpacing(8).textSelection(.enabled) }
                    }
                    if let failure = session.failure {
                        Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary)
                    }
                    if pendingReply && !session.working {
                        Text("上一条补充还没有完成回信。重试会接着整理同一条内容。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                        if !session.partial.isEmpty {
                            DisclosureGroup("尚未完成的回信") { Text(.init(session.partial)).font(.body).lineSpacing(8).textSelection(.enabled) }.font(.subheadline)
                        }
                        Button("重试这次整理") { if !sourceChanged { session.retry(key: key, context: context, instruction: instruction, store: store) } }
                            .font(.subheadline).disabled(!store.isSignedIn || sourceChanged)
                    }
                    if !archivedSessions.isEmpty {
                        DisclosureGroup("较早的整理（只读）") {
                            VStack(alignment: .leading, spacing: 22) {
                                Text("这里保留了其他资料、主题或计算版本下的整理。每段记录独立展示，不会用于本次 AI 整理。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                                ForEach(archivedSessions) { archive in
                                    DisclosureGroup {
                                        VStack(alignment: .leading, spacing: 22) {
                                            ForEach(archive.entries) { messageView($0) }
                                        }.padding(.top, 12)
                                    } label: {
                                        if let date = archive.entries.first?.date {
                                            Text(date, format: .dateTime.year().month().day().hour().minute())
                                        }
                                    }
                                }
                            }.padding(.top, 16)
                        }.font(.subheadline)
                    }
                    Color.clear.frame(height: 1).id("reflection-bottom")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in proxy.scrollTo("reflection-bottom", anchor: .bottom) }
        }
        .background(SujiTheme.paper).foregroundStyle(SujiTheme.ink).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("补充你的经历或想法…", text: $input, axis: .vertical).lineLimit(1...5).focused($focused)
                    .padding(14).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                Button {
                    if session.working { session.stop() }
                    else { let text = input; input = ""; focused = false; send(text) }
                } label: {
                    Image(systemName: session.working ? "stop.fill" : "arrow.up").frame(width: 48, height: 48).background(SujiTheme.ink, in: Circle()).foregroundStyle(SujiTheme.paper)
                }.disabled(!session.working && (!store.isSignedIn || sourceChanged || pendingReply || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .accessibilityLabel(session.working ? "停止整理" : "发送补充")
            }.padding(16).background(.regularMaterial)
        }
        .onDisappear { session.stop() }
        .onAppear { if sourceIdentity == nil { sourceIdentity = viewIdentity } }
        .onChange(of: effectiveKey) { _, _ in session.stop(); session = ReflectionSession(); input = "" }
        .onChange(of: store.scopeRevision) { _, _ in session.stop(); session = ReflectionSession(); input = "" }
    }
    private func messageView(_ entry: ConversationEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.role == "user" ? "你" : "有时").font(.caption).foregroundStyle(SujiTheme.secondary)
            Text(.init(entry.text)).font(.body).lineSpacing(8).textSelection(.enabled)
        }.padding(entry.role == "user" ? 18 : 0).frame(maxWidth: .infinity, alignment: .leading)
            .background(entry.role == "user" ? SujiTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 16))
    }
    private func send(_ text: String) {
        guard !sourceChanged else { return }
        session.send(text, key: key, context: context, instruction: instruction, store: store)
    }
}

struct MonthlyReflectionView: View {
    @Environment(AppStore.self) private var store
    @State private var month = ""
    private var months: [String] { Array(Set(store.state.journal.map { String($0.day.prefix(7)) })).sorted(by: >) }
    var body: some View {
        Form {
            Section {
                Picker("回望月份", selection: $month) { ForEach(months, id: \.self) { Text($0).tag($0) } }
                let entries = store.state.journal.filter { $0.day.hasPrefix(month) }
                Text("\(entries.count) 份心情记录").foregroundStyle(.secondary)
                if !month.isEmpty {
                    NavigationLink("整理这个月") {
                        ReflectionView(title: "这个月的回声", key: "journal:" + month,
                            context: entries.map { "\($0.day) · \($0.mood.rawValue)：\($0.note)" }.joined(separator: "\n"),
                            instruction: "只根据实际记录总结可观察的心情与生活主题；明确记录稀疏时的局限，不推断心理疾病。找出一两个支持用户的具体时刻，再给一个下月可以尝试的小行动。可温和追问。",
                            opening: "帮我回望 \(month) 的这些记录，看看哪些时刻值得留住。",
                            privacy: "开始后，这个月的心情和短文会经有时的服务发送给 DeepSeek。回信保存在当前本机册页。")
                    }
                }
            }
            Section { Text("这是一段有依据的回顾，不是对心情的诊断。你可以继续补充，也可以随时停止。").font(.footnote).foregroundStyle(.secondary) }
        }.navigationTitle("月度回望").onAppear { month = months.first ?? "" }
    }
}
