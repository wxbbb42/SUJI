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
    @FocusState private var focused: Bool
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(title).font(SujiTheme.serif(30)).padding(.top, 12)
                    Text(privacy).font(.footnote).foregroundStyle(SujiTheme.secondary).lineSpacing(6)
                    let messages = store.state.reflections?[key] ?? []
                    if messages.isEmpty {
                        Text(opening).font(.body).lineSpacing(8)
                        Button("开始这段整理") { send(opening) }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    }
                    ForEach(messages) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(entry.role == "user" ? "你" : "有时").font(.caption).foregroundStyle(SujiTheme.secondary)
                            Text(.init(entry.text)).font(.body).lineSpacing(8).textSelection(.enabled)
                        }.padding(entry.role == "user" ? 18 : 0).frame(maxWidth: .infinity, alignment: .leading)
                            .background(entry.role == "user" ? SujiTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if session.working {
                        if session.partial.isEmpty { ProgressView("正在整理") }
                        else { Text(.init(session.partial)).lineSpacing(8).textSelection(.enabled) }
                    }
                    if let failure = session.failure {
                        Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary)
                        HStack {
                            Button("继续整理") { send("请继续上一轮尚未完成的整理。") }
                            NavigationLink("账户与登录") { AccountView(session: store.accountSession) }
                        }.font(.subheadline)
                    }
                    Color.clear.frame(height: 1).id("reflection-bottom")
                }.padding(24)
            }.scrollDismissesKeyboard(.interactively)
                .onChange(of: store.state.reflections?[key]?.count) { _, _ in proxy.scrollTo("reflection-bottom", anchor: .bottom) }
        }
        .background(SujiTheme.paper).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("补充你的经历或想法…", text: $input, axis: .vertical).lineLimit(1...5).focused($focused)
                    .padding(14).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                Button {
                    if session.working { session.stop() }
                    else { let text = input; input = ""; focused = false; send(text) }
                } label: {
                    Image(systemName: session.working ? "stop.fill" : "arrow.up").frame(width: 48, height: 48).background(SujiTheme.ink, in: Circle()).foregroundStyle(SujiTheme.paper)
                }.disabled(!session.working && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(session.working ? "停止整理" : "发送补充")
            }.padding(16).background(.regularMaterial)
        }
        .onDisappear { session.stop() }
        .onChange(of: store.scopeRevision) { _, _ in session.stop() }
    }
    private func send(_ text: String) { session.send(text, key: key, context: context, instruction: instruction, store: store) }
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
