import SwiftUI
import Charts
import SujiCore

struct JournalComposer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var entry: JournalEntry?
    @State private var mood: Mood = .calm
    @State private var note = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("此刻，心里是什么天气？").font(SujiTheme.serif(27)).padding(.top, 24)
                    ViewThatFits {
                        HStack(spacing: 10) { moodButtons }
                        VStack(alignment: .leading) { moodButtons }
                    }
                    TextField("写一句话，留给未来的自己。", text: $note, axis: .vertical).lineLimit(6...12).padding(20).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("journal.note")
                    Text("不必整理得很漂亮，如实记下就好。").font(.footnote).foregroundStyle(SujiTheme.secondary)
                }.padding(24)
            }.background(SujiTheme.paper).navigationTitle(entry == nil ? "一日一记" : "编辑心情").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("保存") {
                        if let entry { store.state.editJournal(id: entry.id, mood: mood, note: note); store.save() }
                        else { store.recordMood(mood, note: note) }
                        dismiss()
                    }.accessibilityIdentifier("journal.save") }
                }
        }.onAppear { if let entry { mood = entry.mood; note = entry.note } }
    }
    private var moodButtons: some View {
        ForEach(Mood.allCases) { item in
            Button { mood = item } label: {
                VStack(spacing: 12) { Image(systemName: item.symbol).font(.title2.weight(.light)); Text(item.rawValue).font(.caption) }
                    .frame(maxWidth: .infinity).padding(.vertical, 18).padding(.horizontal, 10)
                    .background(mood == item ? SujiTheme.sage.opacity(0.17) : Color.clear, in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(mood == item ? SujiTheme.ink : SujiTheme.secondary)
            }.buttonStyle(.plain).accessibilityAddTraits(mood == item ? [.isSelected] : [])
        }
    }
}

struct JournalListView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: JournalEntry?
    @State private var composing = false
    var body: some View {
        List {
            if store.state.journal.isEmpty { ContentUnavailableView("把日子轻轻收好", systemImage: "book.pages", description: Text("记录第一份心情，慢慢认识自己的节奏。")) }
            else {
                Section { NavigationLink("月度回望", destination: MonthlyReflectionView()) }
                Section("最近的心情") {
                    Chart(Array(store.state.journal.suffix(30))) { entry in
                        PointMark(x: .value("时间", entry.createdAt), y: .value("心情", entry.mood.level)).foregroundStyle(SujiTheme.sage)
                    }.chartYScale(domain: 0...6).chartYAxis(.hidden).frame(height: 110).accessibilityLabel("最近三十条心情记录")
                }
                Section {
                    ForEach(store.state.journal.sorted { $0.createdAt > $1.createdAt }) { entry in
                        Button { editing = entry } label: {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: entry.mood.symbol).foregroundStyle(SujiTheme.sage).font(.title2).frame(width: 28)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack { Text(entry.mood.rawValue).foregroundStyle(SujiTheme.ink); Spacer(); Text(entry.day).font(.caption).foregroundStyle(SujiTheme.secondary) }
                                    if !entry.note.isEmpty { Text(entry.note).font(.body).foregroundStyle(SujiTheme.secondary) }
                                }
                            }.padding(.vertical, 10)
                        }.swipeActions { Button("删除", role: .destructive) { store.state.deleteJournal(id: entry.id); store.save() } }
                    }
                }
            }
        }.scrollContentBackground(.hidden).background(SujiTheme.paper).navigationTitle("心情册页")
            .toolbar { Button { composing = true } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("记录心情") }
            .sheet(isPresented: $composing) { JournalComposer() }
            .sheet(item: $editing) { JournalComposer(entry: $0) }
    }
}

struct RitualHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if store.state.rituals.isEmpty { ContentUnavailableView("日子，慢慢积攒", systemImage: "calendar", description: Text("撕开今日的日签，它会留在这里。")) }
                ForEach(store.state.rituals.sorted { $0.day > $1.day }.prefix(7)) { entry in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(entry.day).font(.caption).foregroundStyle(SujiTheme.secondary)
                        Text(entry.quote).font(SujiTheme.serif(25)).lineSpacing(7)
                        Text(entry.action).font(.subheadline).foregroundStyle(SujiTheme.secondary)
                    }.padding(.vertical, 20).listRowBackground(Color.clear)
                }
            }.scrollContentBackground(.hidden).background(SujiTheme.paper).navigationTitle("七日回望")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct RitualShareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 28) {
                if let rendered {
                    Image(uiImage: rendered).resizable().scaledToFit().padding(26)
                        .accessibilityLabel("有时日签：" + (store.ritual?.quote ?? store.content.quote))
                    ShareLink(item: Image(uiImage: rendered), preview: SharePreview("有时 · 今日一签", image: Image(uiImage: rendered))) {
                        Label("分享这一刻", systemImage: "square.and.arrow.up").font(.headline).padding(.horizontal, 32).padding(.vertical, 17)
                    }.buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                } else { ProgressView("正在准备日签").padding(60) }
                Spacer(minLength: 10)
            }
            }.background(SujiTheme.paper).navigationTitle("寄一张日签").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
                .task {
                    let renderer = ImageRenderer(content: shareCard.frame(width: 350).environment(\.colorScheme, .light))
                    renderer.scale = 3; rendered = renderer.uiImage
                }
        }
    }
    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 36) {
            HStack { Text("有时").font(SujiTheme.serif(22)); Spacer(); Text(store.day.rawValue).font(.caption).monospacedDigit() }
            Text(store.ritual?.quote ?? store.content.quote).font(SujiTheme.serif(34)).lineSpacing(16).padding(.vertical, 28)
            Rectangle().fill(SujiTheme.line).frame(height: 1)
            Text(store.ritual?.action ?? store.content.action).font(.subheadline).lineSpacing(6)
            Text("万物有时，你也一样。").font(.caption).foregroundStyle(SujiTheme.secondary)
        }.padding(30).foregroundStyle(SujiTheme.ink).frame(maxWidth: .infinity, alignment: .leading).background(SujiTheme.surface, in: RoundedRectangle(cornerRadius: 6))
    }
}
