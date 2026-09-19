import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import SujiCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var export = false
    @State private var importing = false
    @State private var archive: StateArchive?
    @State private var pendingImport: AppState?
    @State private var confirmImport = false
    @State private var confirmDelete = false
    @State private var message: String?
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("界面", selection: $store.state.appearance) { Text("跟随系统").tag("system"); Text("暖纸").tag("light"); Text("深墨").tag("dark"); Text("青瓷").tag("celadon") }
                    .accessibilityIdentifier("appearance.picker")
                    .onChange(of: store.state.appearance) { _, _ in store.save() }
                Picker("回信的语气", selection: $store.state.tone) { ForEach(["温暖","直言","诗意"], id: \.self) { Text($0) } }.onChange(of: store.state.tone) { _, _ in store.save() }
            } header: { Text("与你合拍") }
            Section {
                LabeledContent("回信伙伴", value: "DeepSeek Flash")
                Text(store.isSignedIn ? "已登录，可以开始对话与回顾。" : "登录后，就可以使用对话与回顾。")
                    .font(.footnote).foregroundStyle(.secondary)
            } header: { Text("AI 回信") } footer: { Text("回信由有时提供。主动使用时，对话及相关资料会经有时的服务发送给 DeepSeek；你可以随时停止。") }
            Section {
                NavigationLink("账户与云端资料") { AccountView(session: store.accountSession) }
                NavigationLink("晨间与节气提醒") { ReminderSettingsView() }
                if let status = store.widgetStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("相伴的方式") }
            Section {
                Button("导出本机册页", systemImage: "square.and.arrow.up") {
                    do { archive = StateArchive(data: try ArchiveCodec.encode(store.state)); export = true } catch { message = error.localizedDescription }
                }
                Button("导入册页备份", systemImage: "square.and.arrow.down") { importing = true }
                Button("删除当前册页资料", role: .destructive) { confirmDelete = true }
            } header: { Text("你的数据，由你保管") } footer: { Text("备份包含当前册页的出生资料、日签、日记与对话。也可导入旧版 user/chat store 的 JSON 导出。其他账户册页保持独立。请妥善保存。") }
            Section {
                Text("有时").font(.system(.title2, design: .serif))
                Text("万物有时，你也一样。").foregroundStyle(.secondary)
                Text("原生 SwiftUI · 1.0").font(.caption).foregroundStyle(.secondary)
                Text("命理内容是传统文化的观察视角，不构成心理诊断或专业建议。奇门、格局与应期仍包含简化规则。").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $export, document: archive, contentType: .json, defaultFilename: "有时-册页-\(store.day.rawValue)") { if case .failure(let error) = $0 { message = error.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let value = try ArchiveCodec.decode(data)
                    pendingImport = value; confirmImport = true
                } catch { message = error.localizedDescription }
            }
            .confirmationDialog("用这份备份替换本机册页？", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("替换册页", role: .destructive) { if let pendingImport { store.state = pendingImport; store.save(); Task { await store.refresh() } }; pendingImport = nil }
                Button("取消", role: .cancel) { pendingImport = nil }
            }
            .confirmationDialog("删除当前册页资料？此操作无法撤销。", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除当前册页", role: .destructive) {
                    do { try KeychainStore.write(nil, name: store.aiKeyName); store.state = AppState(); store.save(); Task { await store.refresh() } } catch { message = error.localizedDescription }
                }
            }
            .alert("设置", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好", role: .cancel) {} } message: { Text(message ?? "") }
    }
}

struct StateArchive: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { guard let data = configuration.file.regularFileContents else { throw DomainError.invalidArchive }; self.data = data }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
