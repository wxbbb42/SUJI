import SwiftUI
import SujiCore

struct ChatView: View {
    @Environment(AppStore.self) private var store
    @State private var session = ChatSession()
    @State private var input = ""
    @State private var mode = "倾诉"
    @State private var clearConfirmation = false
    @State private var followingReply = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var focused: Bool
    private let prompts = ["最近总是停不下来", "我想重新找回自己的节奏", "今天，给我一点小建议"]
    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if store.state.conversations.isEmpty {
                            VStack(alignment: .leading, spacing: 24) {
                                Text("听自己说").font(.caption).tracking(3).foregroundStyle(SujiTheme.secondary)
                                HStack(alignment: .center, spacing: 16) {
                                    Text("有些话，\n可以慢慢说。")
                                        .font(SujiTheme.serif(31)).lineSpacing(10)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutPriority(1)
                                    Spacer(minLength: 0)
                                    if !typeSize.isAccessibilitySize {
                                        SujiBotanical().frame(width: 66, height: 106)
                                    }
                                }
                                Text("这里没有标准答案。\n从此刻的心情开始就好。")
                                    .font(.subheadline).foregroundStyle(SujiTheme.secondary).lineSpacing(7)
                                VStack(spacing: 0) {
                                    ForEach(prompts, id: \.self) { prompt in
                                        Button { input = prompt; focused = true } label: {
                                            HStack(spacing: 16) {
                                                Text(prompt).font(.subheadline)
                                                Spacer(minLength: 0)
                                                Image(systemName: "arrow.up.left").font(.caption)
                                            }.padding(.vertical, 20).foregroundStyle(SujiTheme.ink)
                                        }
                                        Divider().overlay(SujiTheme.line)
                                    }
                                }.padding(.top, 8)
                            }.padding(.top, 26)
                        }
                        ForEach(store.state.conversations) { entry in
                            VStack(alignment: .leading, spacing: 16) {
                                HStack { Text(entry.role == "user" ? "你" : "有时").font(.caption).foregroundStyle(SujiTheme.secondary); Spacer(); Text(entry.date, style: .time).font(.caption2).foregroundStyle(SujiTheme.secondary) }
                                Text(.init(entry.text)).font(.body).lineSpacing(8).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                if entry.role == "assistant", !entry.evidence.isEmpty {
                                    DisclosureGroup("参照的线索") { VStack(alignment: .leading, spacing: 12) { ForEach(entry.evidence, id: \.self) { Text($0).font(.footnote).foregroundStyle(SujiTheme.secondary) } }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12) }.font(.footnote)
                                }
                                toolResults(replyTools(for: entry))
                                let receipts = replyReceipts(for: entry)
                                if !receipts.isEmpty {
                                    NavigationLink(destination: ReadingEvidenceView(receipts: receipts)) {
                                        Label("查看完整计算依据", systemImage: "text.book.closed").font(.footnote)
                                    }
                                }
                            }.padding(entry.role == "user" ? 20 : 0).background(entry.role == "user" ? SujiTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 20)).id(entry.id)
                        }
                        if session.working {
                            if session.partial.isEmpty { HStack(spacing: 10) { ProgressView(); Text(session.activity.isEmpty ? "正在倾听" : session.activity).font(.caption).foregroundStyle(SujiTheme.secondary) }.padding(.vertical, 12) }
                            else { Text(.init(session.partial)).font(.body).lineSpacing(8).textSelection(.enabled) }
                        }
                        if let failure = session.failure {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(failure).font(.footnote).foregroundStyle(SujiTheme.secondary)
                                HStack {
                                    Button("重试") { if let last = store.state.conversations.last(where: { $0.role == "user" }) { session.send(last.text, mode: mode, store: store, appendUser: false) } }
                                    NavigationLink("账户与登录") { AccountView(session: store.accountSession) }
                                }.font(.subheadline)
                            }.padding(20).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                        if !session.working {
                            ForEach(unansweredToolEntries) { entry in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("这次提问的线索已保留，重试解读不会重新起卦。").font(.caption).foregroundStyle(SujiTheme.secondary)
                                    toolResults(entry.toolData)
                                }
                            }
                        }
                        Color.clear.frame(height: 8).id("bottom")
                    }.padding(24)
                }.scrollDismissesKeyboard(.interactively)
                    .onScrollPhaseChange { _, phase in if phase == .interacting { followingReply = false } }
                    .onChange(of: store.state.conversations.count) { _, _ in withAnimation { scroll.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: session.partial) { _, _ in if followingReply { scroll.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: session.working) { _, value in if value { followingReply = true } }
            }
            .background(SujiTheme.paper).foregroundStyle(SujiTheme.ink)
            .navigationTitle("问道").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if !store.isSignedIn {
                        HStack {
                            Text("登录后，AI 才能为你写回信。").font(.caption).foregroundStyle(SujiTheme.secondary)
                            Spacer(minLength: 8)
                            NavigationLink("去登录") { AccountView(session: store.accountSession) }.font(.caption.weight(.medium))
                        }
                    } else if mode == "命理" && store.state.birth == nil {
                        HStack {
                            Text("个性化排盘需要出生资料。").font(.caption).foregroundStyle(SujiTheme.secondary)
                            Spacer(minLength: 8)
                            Button("去填写") { store.selectedTab = 3 }.font(.caption.weight(.medium))
                        }
                    }
                    Picker("对话方式", selection: $mode) {
                        ForEach(["倾诉", "命理", "起卦"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented).disabled(session.working)
                    HStack(alignment: .bottom, spacing: 12) {
                        TextField("写下此刻的心事…", text: $input, axis: .vertical).lineLimit(1...5).padding(14).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20)).focused($focused).accessibilityIdentifier("chat.input")
                        Button { if session.working { session.stop() } else { let text = input; input = ""; focused = false; session.send(text, mode: mode, store: store) } } label: {
                            Image(systemName: session.working ? "stop.fill" : "arrow.up").font(.system(size: 20, weight: .semibold)).frame(width: 48, height: 48).background(SujiTheme.ink, in: Circle()).foregroundStyle(SujiTheme.paper)
                        }.disabled(!session.working && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel(session.working ? "停止回答" : "发送")
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12).background(.regularMaterial)
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { NavigationLink("设置", destination: SettingsView()); Button("清空对话", role: .destructive) { clearConfirmation = true }.disabled(session.working) } label: { Image(systemName: "ellipsis") } } }
            .confirmationDialog("清空本机的全部对话？", isPresented: $clearConfirmation, titleVisibility: .visible) { Button("清空对话", role: .destructive) { store.state.conversations = []; store.save() } }
            .onChange(of: store.scopeRevision) { _, _ in session.stop(); input = "" }
            .onChange(of: store.state.birth) { _, _ in if session.working { session.stop() } }
        }
    }

    // Receipts remain on the user turn for retry; presentation follows the reply.
    private func replyTools(for entry: ConversationEntry) -> [String] {
        guard entry.role == "assistant" else { return [] }
        var values = entry.toolData
        if let index = store.state.conversations.firstIndex(where: { $0.id == entry.id }), index > 0,
           store.state.conversations[index - 1].role == "user" {
            values += store.state.conversations[index - 1].toolData
        }
        return values.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    private func replyReceipts(for entry: ConversationEntry) -> [ToolReceipt] {
        guard entry.role == "assistant", let index = store.state.conversations.firstIndex(where: { $0.id == entry.id }), index > 0,
              store.state.conversations[index - 1].role == "user" else { return [] }
        return store.state.conversations[index - 1].toolReceipts ?? []
    }
    private var unansweredToolEntries: [ConversationEntry] {
        let entries = store.state.conversations
        return entries.indices.compactMap { index in
            let entry = entries[index]
            guard entry.role == "user", !entry.toolData.isEmpty,
                  index + 1 == entries.count || entries[index + 1].role != "assistant" else { return nil }
            return entry
        }
    }
    @ViewBuilder private func toolResults(_ values: [String]) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { _, raw in
            if let doc = try? Document(data: Data(raw.utf8)), !doc["benGua"]["name"].text.isEmpty { HexagramResultView(document: doc) }
            else if let doc = try? Document(data: Data(raw.utf8)), !doc["palaces"].array.isEmpty { QimenResultView(document: doc) }
        }
    }
}

struct HexagramResultView: View {
    let document: Document
    var body: some View {
        DisclosureGroup("卦象 · " + document["benGua"]["name"].text) {
            VStack(alignment: .leading, spacing: 15) {
                Text(document["benGua"]["name"].text + " → " + document["bianGua"]["name"].text).font(SujiTheme.serif(22))
                HStack(alignment: .top, spacing: 30) {
                    hexagram(document["benGua"], changes: true)
                    Image(systemName: "arrow.right").foregroundStyle(SujiTheme.secondary).padding(.top, 40).accessibilityHidden(true)
                    hexagram(document["bianGua"], changes: false)
                }
                Text("用神：\(document["yongShen"]["type"].text) · \(document["yongShen"]["state"].text)").font(.subheadline)
                Text(document["yingQi"]["description"].text).font(.subheadline).lineSpacing(6)
                Text("起卦是一种整理问题的文化仪式，不代表事情一定如此发生。").font(.footnote).foregroundStyle(SujiTheme.secondary)
            }.padding(.top, 14)
        }.font(.subheadline)
    }
    private func hexagram(_ gua: Document, changes: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(gua["yao"].strings.enumerated().reversed()), id: \.offset) { index, line in
                let moving = changes && document["changingYao"].array.contains { Int($0.number) == index + 1 }
                HStack(spacing: 12) {
                    Capsule().frame(height: 7)
                    if line == "阴" { Capsule().frame(height: 7) }
                }.foregroundStyle(moving ? SujiTheme.accent : SujiTheme.ink)
                    .accessibilityLabel("第\(index + 1)爻，\(line)爻\(moving ? "，动爻" : "")")
            }
            Text(gua["name"].text).font(.caption).foregroundStyle(SujiTheme.secondary)
        }.frame(maxWidth: .infinity)
    }
}
struct QimenResultView: View {
    let document: Document
    var body: some View {
        DisclosureGroup("奇门盘面 · " + document["jieqi"].text) {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                    ForEach([4,9,2,3,5,7,8,1,6], id: \.self) { id in
                        let palace = document["palaces"].array.first { Int($0["id"].number) == id } ?? Document([:])
                        VStack(alignment: .leading, spacing: 9) {
                            Text(palace["name"].text).font(.caption).foregroundStyle(SujiTheme.secondary)
                            Text(palace["bamen"].text).font(.headline)
                            Text(palace["jiuxing"].text + " " + palace["bashen"].text).font(.caption2)
                            Text(palace["tianPanGan"].text + " / " + palace["diPanGan"].text).font(.caption2).foregroundStyle(SujiTheme.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Text("上南下北 · 左东右西").font(.caption2).foregroundStyle(SujiTheme.secondary)
                Text(document["method"]["caveats"].strings.joined(separator: "；")).font(.footnote).foregroundStyle(SujiTheme.secondary)
            }.padding(.top, 16)
        }.font(.subheadline)
    }
}
