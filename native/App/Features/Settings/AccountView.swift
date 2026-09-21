import SwiftUI
import SujiCore

struct AccountView: View {
    @Environment(AppStore.self) private var store
    @State private var session: AccountSession
    @State private var email = ""
    @State private var password = ""
    @State private var mode: EmailMode = .signIn
    @State private var pendingProfile: SupabaseProfile?
    @State private var confirmPush = false
    @State private var confirmSignOut = false
    @State private var legacyNotebook: AppState?
    @State private var confirmLegacyImport = false
    private let onboarding: Bool

    init(session: AccountSession, onboarding: Bool = false) {
        _session = State(initialValue: session)
        self.onboarding = onboarding
    }

    var body: some View {
        Form {
            if onboarding {
                Section {
                    Text("万物有时，你也一样。").font(SujiTheme.serif(26))
                    Text("先登录或创建账户，再填写出生资料。我们会为你建立专属的八字与紫微档案，今后的提问沿用这份本命盘。")
                        .foregroundStyle(.secondary)
                }
            }
            if !session.isConfigured {
                Section {
                    Label("账户服务暂不可用", systemImage: "person.crop.circle.badge.exclamationmark")
                    Text("此安装包缺少账户服务配置，请更新应用后登录。已有的本机资料会保留。")
                        .foregroundStyle(.secondary)
                } header: { Text("账户") }
            } else if let user = session.user {
                signedInSection(user)
                syncSection
            } else {
                signInSection
            }

            Section {
                Text("出生资料会随账户同步，本命盘在这台设备建档后反复使用。日签、日记与对话保存在本机；主动使用 AI 时，相关内容会经有时的服务发送给 DeepSeek。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("切换账户前，App 会先切换到独立的本机册页空间，避免不同账户看到彼此的私密记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: { Text("同步边界") }
        }
        .navigationTitle(onboarding ? "欢迎来到有时" : "账户与云端资料")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(session.busy)
        .overlay { if session.busy { ProgressView().controlSize(.large) } }
        .task { await session.initialize(); legacyNotebook = try? store.legacyNotebook() }
        .confirmationDialog("将旧本机册页导入当前账户？", isPresented: $confirmLegacyImport, titleVisibility: .visible) {
            Button("导入并替换当前册页", role: .destructive) {
                guard let legacyNotebook else { return }
                do { try store.replaceNotebook(legacyNotebook); Task { await store.refresh() } }
                catch { session.error = error.localizedDescription }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("旧版未登录时保存的出生资料、日签、日记和对话会复制到当前账户，替换当前册页。旧本机原件仍保留；如当前账户已有记录，请先导出备份。") }
        .confirmationDialog("切换本机册页空间？", isPresented: Binding(get: { session.hasPendingAccountChange }, set: { _ in }), titleVisibility: .visible) {
            Button("切换并登录") { Task { await session.confirmPendingAccountChange() } }
            Button("取消", role: .cancel) { Task { await session.cancelPendingAccountChange() } }
        } message: {
            Text("将切换到 \(session.pendingUser?.email ?? "新账户") 的独立本机册页。当前册页会先保存，不会上传给新账户。")
        }
        .confirmationDialog("用云端资料覆盖这些设置？", isPresented: Binding(get: { pendingProfile != nil }, set: { if !$0 { pendingProfile = nil } }), titleVisibility: .visible) {
            Button("覆盖个人资料", role: .destructive) { applyPendingProfile() }
            Button("取消", role: .cancel) { pendingProfile = nil }
        } message: {
            Text("会覆盖出生资料和是否完成引导。日签、日记与对话保持不变。")
        }
        .confirmationDialog("把本机个人资料保存到云端？", isPresented: $confirmPush, titleVisibility: .visible) {
            Button("保存到云端") { pushProfile() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会写入出生资料和是否完成引导，不会同步日签、日记或对话。")
        }
        .confirmationDialog("退出这个账户？", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { Task { await session.signOut() } }
            Button("取消", role: .cancel) {}
        }
        .alert("账户", isPresented: Binding(get: { session.error != nil || session.notice != nil }, set: { if !$0 { session.error = nil; session.notice = nil } })) {
            Button("好", role: .cancel) { session.error = nil; session.notice = nil }
        } message: { Text(session.error ?? session.notice ?? "") }
    }

    private var signInSection: some View {
        Section {
            Button { Task { await session.signInWithGoogle() } } label: {
                Label("通过 Google 继续", systemImage: "globe")
            }
            Picker("邮箱操作", selection: $mode) {
                ForEach(EmailMode.allCases) { value in Text(value.title).tag(value) }
            }
            .pickerStyle(.segmented)
            TextField("邮箱地址", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if mode != .reset {
                SecureField("密码（至少 6 位）", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
            }
            Button(mode.actionTitle) {
                Task {
                    switch mode {
                    case .signIn: await session.signIn(email: email, password: password)
                    case .signUp: await session.signUp(email: email, password: password)
                    case .reset: await session.sendPasswordReset(email: email)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        } header: { Text("登录或注册") } footer: {
            Text("Google 登录会打开系统安全登录窗口。密码重置邮件会带你回到 App 设置新密码，不会显示旧密码。")
        }
    }

    private func signedInSection(_ user: SupabaseUser) -> some View {
        Section {
            LabeledContent("邮箱", value: user.email ?? "未设置")
            LabeledContent("账户标识", value: String(user.id.prefix(8)) + "…")
            Button("退出登录", role: .destructive) { confirmSignOut = true }
        } header: { Text("已登录") }
    }

    private var syncSection: some View {
        Section {
            if let status = store.cloudProfileStatus { Text(status).font(.footnote).foregroundStyle(.secondary) }
            if store.state.profileNeedsUpload == true { Button("重试同步出生资料") { Task { await store.syncBirthProfile() } } }
            Button("查看并恢复云端个人资料", systemImage: "arrow.down.circle") { pullProfile() }
            Button("将本机个人资料保存到云端", systemImage: "arrow.up.circle") { confirmPush = true }
            if legacyNotebook != nil { Button("导入旧版未登录册页") { confirmLegacyImport = true } }
        } header: { Text("手动同步") } footer: {
            Text("恢复前会再次列出被覆盖字段并要求确认。云端没有对话、日签和日记，登录也不会恢复这些内容。")
        }
    }

    private func pullProfile() {
        Task {
            do {
                if let profile = try await session.fetchProfile() { pendingProfile = profile }
                else { session.notice = "这个账户还没有云端个人资料。你可以先将本机资料保存到云端。" }
            } catch { session.error = error.localizedDescription }
        }
    }

    private func applyPendingProfile() {
        guard let profile = pendingProfile else { return }
        do {
            try store.replaceNotebook(session.applying(profile, to: store.state))
            pendingProfile = nil
            session.notice = "云端个人资料已恢复。"
            Task { await store.refresh() }
        } catch {
            pendingProfile = nil
            session.error = error.localizedDescription
        }
    }

    private func pushProfile() {
        Task {
            do {
                store.state.profileNeedsUpload = true
                try store.saveThrowing()
                let scope = store.scopeRevision
                await store.syncBirthProfile()
                guard scope == store.scopeRevision else { return }
                if store.state.profileNeedsUpload != true { session.notice = "本机个人资料已保存到云端。" }
            } catch { session.error = error.localizedDescription }
        }
    }
}

struct PasswordRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: PasswordRecoverySession
    @State private var password = ""
    @State private var confirmation = ""

    init(url: URL) {
        _session = State(initialValue: PasswordRecoverySession(url: url))
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.completed {
                    ContentUnavailableView {
                        Label("密码已更新", systemImage: "checkmark.circle")
                    } description: {
                        Text("请使用新密码重新登录。")
                    } actions: {
                        Button("完成") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Form {
                        Section {
                            if let user = session.user {
                                LabeledContent("账户", value: user.email ?? String(user.id.prefix(8)) + "…")
                            } else if session.busy {
                                HStack { ProgressView(); Text("正在验证重置链接…") }
                            } else {
                                Text("无法使用这条重置链接。请关闭后重新发送密码重置邮件。")
                                    .foregroundStyle(.secondary)
                            }
                        } header: { Text("安全验证") }

                        if session.ready {
                            Section {
                                SecureField("新密码（至少 6 位）", text: $password)
                                    .textContentType(.newPassword)
                                SecureField("再次输入新密码", text: $confirmation)
                                    .textContentType(.newPassword)
                                Button("更新密码") {
                                    Task { await session.updatePassword(password, confirmation: confirmation) }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(password.isEmpty || confirmation.isEmpty || session.busy)
                            } header: { Text("设置新密码") } footer: {
                                Text("重置凭证只在此页面的内存中使用，不会保存为登录状态。")
                            }
                        }
                    }
                    .disabled(session.busy)
                }
            }
            .navigationTitle("重置密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .task { await session.prepare() }
        .onChange(of: session.completed) { _, completed in
            if completed { password = ""; confirmation = "" }
        }
        .onDisappear { session.clear(); password = ""; confirmation = "" }
        .alert("重置密码", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("好", role: .cancel) { session.error = nil }
        } message: { Text(session.error ?? "") }
    }
}

private enum EmailMode: String, CaseIterable, Identifiable {
    case signIn, signUp, reset
    var id: String { rawValue }
    var title: String {
        switch self { case .signIn: "登录"; case .signUp: "注册"; case .reset: "重置" }
    }
    var actionTitle: String {
        switch self { case .signIn: "邮箱登录"; case .signUp: "创建账户"; case .reset: "发送重置邮件" }
    }
}
