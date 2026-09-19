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

    init(onAccountChange: @escaping AccountSession.ScopeTransition) {
        _session = State(initialValue: AccountSession(onScopeTransition: onAccountChange))
    }

    var body: some View {
        Form {
            if !session.isConfigured {
                Section {
                    Label("本地模式", systemImage: "iphone")
                    Text("此安装包没有账户服务配置。你仍可使用全部本地功能，并通过册页备份自行迁移。")
                        .foregroundStyle(.secondary)
                } header: { Text("账户") }
            } else if let user = session.user {
                signedInSection(user)
                syncSection
            } else {
                signInSection
            }

            Section {
                Text("账户只同步出生资料、引导状态和 AI 服务地址与模型。API Key、对话、日签和日记不会上传。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("切换账户前，App 会先切换到独立的本机册页空间，避免不同账户看到彼此的私密记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: { Text("同步边界") }
        }
        .navigationTitle("账户与云端资料")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(session.busy)
        .overlay { if session.busy { ProgressView().controlSize(.large) } }
        .task { await session.initialize() }
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
            Text("会覆盖出生资料、是否完成引导、AI 服务地址和模型。日签、日记、对话和本机 API Key保持不变。")
        }
        .confirmationDialog("把本机个人资料保存到云端？", isPresented: $confirmPush, titleVisibility: .visible) {
            Button("保存到云端") { pushProfile() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会写入出生资料、是否完成引导、AI 服务地址和模型。不会上传 API Key、日签、日记或对话。")
        }
        .confirmationDialog("退出这个账户？", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("退出并切换到本地册页", role: .destructive) { Task { await session.signOut() } }
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
            Button("查看并恢复云端个人资料", systemImage: "arrow.down.circle") { pullProfile() }
            Button("将本机个人资料保存到云端", systemImage: "arrow.up.circle") { confirmPush = true }
        } header: { Text("手动同步") } footer: {
            Text("恢复前会再次列出被覆盖字段并要求确认。云端没有对话、日签、日记和 API Key，登录也不会恢复这些内容。")
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
            store.state = try session.applying(profile, to: store.state)
            store.save()
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
                _ = try await session.pushProfile(from: store.state)
                session.notice = "本机个人资料已保存到云端。"
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
