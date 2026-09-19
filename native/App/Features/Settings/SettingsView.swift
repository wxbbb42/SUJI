import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import SujiCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var key = ""
    @State private var keySaved = false
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
                TextField("服务地址", text: $store.state.providerURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("模型名称", text: $store.state.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField(keySaved ? "已保存，填写可替换" : "API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("保存模型设置") {
                    do {
                        guard let url = URL(string: store.state.providerURL), url.scheme == "https", url.host != nil, !store.state.model.trimmingCharacters(in: .whitespaces).isEmpty else { throw EngineError.execution("请填写 HTTPS 服务地址与模型名称。") }
                        if !key.isEmpty { try KeychainStore.write(key.trimmingCharacters(in: .whitespacesAndNewlines), name: store.aiKeyName); key = ""; keySaved = true }
                        store.save(); message = "模型配置已保存在本机。"
                    } catch { message = error.localizedDescription }
                }
                if keySaved { Button("移除本机 API Key", role: .destructive) { do { try KeychainStore.write(nil, name: store.aiKeyName); keySaved = false } catch { message = error.localizedDescription } } }
            } header: { Text("AI 服务") } footer: { Text("支持 OpenAI、DeepSeek 与兼容服务，包括 Responses API 和 Azure。Key 只保存在本机钥匙串；对话和相关命盘会发送给你选择的服务。") }
            Section {
                NavigationLink("账户与云端资料") { AccountView { previous, next in try await store.switchAccount(from: previous, to: next) } }
                NavigationLink("晨间与节气提醒") { ReminderSettingsView() }
                if let status = store.widgetStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("相伴的方式") }
            Section {
                Button("导出本机册页", systemImage: "square.and.arrow.up") {
                    do { archive = StateArchive(data: try ArchiveCodec.encode(store.state)); export = true } catch { message = error.localizedDescription }
                }
                Button("导入册页备份", systemImage: "square.and.arrow.down") { importing = true }
                Button("删除当前册页资料", role: .destructive) { confirmDelete = true }
            } header: { Text("你的数据，由你保管") } footer: { Text("备份包含当前册页的出生资料、日签、日记与对话，不包含 API Key。也可导入旧版 user/chat store 的 JSON 导出。其他账户册页保持独立。请妥善保存。") }
            Section {
                Text("有时").font(.system(.title2, design: .serif))
                Text("万物有时，你也一样。").foregroundStyle(.secondary)
                Text("原生 SwiftUI · 1.0").font(.caption).foregroundStyle(.secondary)
                Text("命理内容是传统文化的观察视角，不构成心理诊断或专业建议。奇门、格局与应期仍包含简化规则。").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .onAppear { do { keySaved = try KeychainStore.read(store.aiKeyName) != nil } catch { message = error.localizedDescription } }
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
                Button("删除当前册页与 API Key", role: .destructive) {
                    do { try KeychainStore.write(nil, name: store.aiKeyName); store.state = AppState(); store.save(); keySaved = false; Task { await store.refresh() } } catch { message = error.localizedDescription }
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
