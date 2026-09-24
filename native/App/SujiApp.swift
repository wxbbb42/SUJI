import SwiftUI
import SwiftData
import SujiCore

@main struct SujiApp: App {
    @UIApplicationDelegateAdaptor(SujiApplicationDelegate.self) private var delegate
    private let container: ModelContainer?
    private let store: AppStore?
    private let launchError: String?
    init() {
        do {
#if DEBUG
            let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
#else
            let testing = false
#endif
            let container = try PersistenceBootstrap.makeContainer(isStoredInMemoryOnly: testing)
            guard let script = Bundle.main.url(forResource: "mingli", withExtension: "js") else { throw EngineError.execution("本地历法资源缺失，请重新安装。") }
            let store = try AppStore(context: container.mainContext, scriptURL: script, userID: testing ? nil : AccountSession.restoredUserID())
            self.container = container; self.store = store; self.launchError = nil
        } catch { container = nil; store = nil; launchError = error.localizedDescription }
    }
    var body: some Scene {
        WindowGroup {
            if let store {
                launchView.environment(store)
                    .tint(SujiTheme.sage)
                    .preferredColorScheme(colorScheme(for: store))
            } else { ContentUnavailableView("暂时无法打开册页", systemImage: "book.closed", description: Text(launchError ?? "请重试")) }
        }
    }
    @ViewBuilder private var launchView: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--cast-confirmation-fixtures") {
            CastPreparationAuditView()
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--reading-presentation-fixtures") {
            ReadingPresentationAuditView()
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--mingli-detail-fixtures") {
            MingliDetailAuditView()
        } else { RootView() }
#else
        RootView()
#endif
    }
    private func colorScheme(for store: AppStore) -> ColorScheme? {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-dark") { return .dark }
#endif
        return store.state.appearance == "dark" ? .dark : store.state.appearance == "light" ? .light : nil
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var sheet: RootSheet?
    @State private var notificationRoute = NotificationRoute.shared
    @State private var initialized = false
    @State private var themeNavigation = NotebookThemeNavigation()
    @State private var admittedScopeRevision: UUID?
#if DEBUG
    @State private var observedDossierGap = false
#endif
    private var accountContent: some View {
        Group {
            if notebookReady {
                mainTabs.id(store.scopeRevision)
            } else if !initialized {
                ProgressView("正在打开你的册页…")
            } else if !notebookAccountAvailable {
                NavigationStack { AccountView(session: store.accountSession, onboarding: true) }
            } else if store.preparingAccount {
                ProgressView("正在读取你的资料…")
            } else if store.state.birth == nil {
                BirthEditor(existing: nil, required: true) { birth in try await store.updateBirth(birth) }
            } else { DossierSetupView() }
        }
    }
    private var presentedContent: some View {
        accountContent
        .background(SujiTheme.paper)
        .sheet(item: $sheet) { item in sheetContent(item) }
        .environment(\.notebookThemeNavigation, themeNavigation)
        .environment(\.openNotebookTheme, { binding, title, prompt in
            themeNavigation.stage(binding, title: title, prompt: prompt)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            sheet = nil; store.selectedTab = 1
        })
        .environment(\.returnNotebookTheme, {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            sheet = .themeReport
        })
        .alert("请留意", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private var accountLifecycleContent: some View {
        presentedContent
        .onChange(of: store.state.appearance, initial: true) { _, value in SujiTheme.appearance.name = value }
        .task {
            consumePendingNotificationRoute()
            await store.accountSession.initialize()
            await store.prepareAccount()
            initialized = true
            await store.refresh()
            await ReminderService.shared.refreshFromSavedPreferences()
        }
        .task(id: store.scopeKey) { await store.prepareAccount() }
        .onChange(of: store.scopeKey) { _, _ in sheet = nil }
        .onChange(of: store.scopeRevision) { _, _ in
            themeNavigation.resetAccount(); admittedScopeRevision = nil
#if DEBUG
            observedDossierGap = false
#endif
        }
        .onChange(of: store.birthRevision) { _, _ in themeNavigation.invalidateBirth() }
        .onChange(of: store.hasNatalDossier) { _, ready in
#if DEBUG
            // Observe the real invalidation interval; do not manufacture a
            // failed dossier or delay the engine to make this UI test pass.
            if gatedNotebookFixture && admittedScopeRevision == store.scopeRevision && !ready {
                observedDossierGap = true
            }
#endif
        }
        .onChange(of: store.isSignedIn) { _, signedIn in
            sheet = nil
            if signedIn { Task { await store.prepareAccount() } }
        }
    }
    var body: some View {
        accountLifecycleContent
        .onChange(of: phase) { _, value in if value == .active { Task { await store.refresh(); await store.syncBirthProfile(); await ReminderService.shared.refreshFromSavedPreferences() } } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in Task { await store.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await store.refresh() } }
        .onChange(of: notificationRoute.todayRequestGeneration) { _, _ in consumePendingNotificationRoute() }
        .onOpenURL { url in
            guard url.scheme == "suji-native" else { return }
            if url.host == "today" { openToday() }
            else if url.host == "auth", url.path == "/reset" { sheet = .recovery(url) }
        }
    }
    private var notebookFixture: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--notebook-fixtures")
#else
        false
#endif
    }
    /// UI fixtures replace authentication only. Birth entry, the actual local
    /// engine and dossier readiness use exactly the production admission path.
    private var gatedNotebookFixture: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--notebook-gated-fixture")
#else
        false
#endif
    }
    private var notebookAccountAvailable: Bool { store.isSignedIn || gatedNotebookFixture }
    private var notebookReady: Bool {
        guard initialized else { return false }
        if notebookFixture { return true }
        guard notebookAccountAvailable else { return false }
        // An admitted notebook keeps its SwiftUI identity during birth rebuilds.
        // Account/import scope changes still require admission afresh.
        return admittedScopeRevision == store.scopeRevision
            || (!store.preparingAccount && store.state.birth != nil && store.hasNatalDossier)
    }
    private var chatTabRole: TabRole? {
#if compiler(>=6.4)
        // Xcode 27 introduces this API; older CI toolchains still compile the
        // standard native tab bar. Runtime availability alone is insufficient.
        if #available(iOS 27.0, *) { return .prominent }
#endif
        return nil
    }
    @ViewBuilder private var mainTabs: some View {
        @Bindable var store = store
        // The system owns tab presentation, safe areas and keyboard transitions.
        // On iOS 27, the prominent chat tab sits apart from home and calm.
        // Earlier systems keep all three destinations in the native tab bar.
        VStack(spacing: 0) {
            notebookStatus
            TabView(selection: $store.selectedTab) {
                Tab("主页", systemImage: "sun.horizon", value: 0) {
                    TodayView(date: store.today, lunarDate: store.calendarInfo?["lunarDate"].text ?? "", ganZhi: store.calendarInfo?["ganZhi"].text ?? "", solarTerm: store.calendarInfo?["solarTerm"].text ?? "", quote: store.ritual?.quote ?? store.content.quote, action: store.ritual?.action ?? store.content.action, isRevealed: store.ritual != nil, onReveal: { store.revealToday() }, onJournal: { sheet = .journal }, onHistory: { sheet = .history }, onShare: { sheet = .share }, onReflect: { sheet = .reflection })
                }
                Tab("静心", systemImage: "water.waves", value: 2) {
                    NavigationStack {
                        CalmView().navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .topBarTrailing) { NotebookProfileButton() } }
                    }
                }
                Tab("问道", systemImage: "bubble.left.and.text.bubble.right", value: 1, role: chatTabRole) {
                    ChatView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            admittedScopeRevision = store.scopeRevision
            if !(0...2).contains(store.selectedTab) { store.selectedTab = 0 }
        }
        .environment(\.openNotebookProfile, {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            sheet = .profile
        })
        .environment(\.editNotebookBirth, { sheet = .birth })
    }
    @ViewBuilder private var notebookStatus: some View {
            if !store.hasNatalDossier && !notebookFixture {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.buildingNatalDossier ? "正在更新本命档案，草稿仍在。" : "本命档案等待更新，已有对话和草稿仍在。")
                        .font(.footnote).accessibilityIdentifier("notebook.rebuilding")
                    if !store.buildingNatalDossier {
                        Button("检查档案") { sheet = .dossierSetup }.font(.footnote).frame(minHeight: 44)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading).background(SujiTheme.surface)
            }
#if DEBUG
            if gatedNotebookFixture {
                Text(observedDossierGap ? "合成验收 · 已观察到档案重建间隙" : "合成验收 · 仅跳过登录，仍检查档案")
                    .font(.caption).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxWidth: .infinity).padding(6).background(SujiTheme.surface)
                    .accessibilityIdentifier(observedDossierGap ? "notebook.gate.observedGap" : "notebook.gate.active")
            }
#endif
    }
    @ViewBuilder private func sheetContent(_ item: RootSheet) -> some View {
            switch item {
            case .profile: NotebookProfileSheet { sheet = nil }
            case .themeReport: NotebookProfileSheet(startsAtTheme: true) { sheet = nil }
            case .dossierSetup:
                VStack(spacing: 0) {
                    HStack { Spacer(); Button("关闭") { sheet = nil }.frame(minWidth: 44, minHeight: 44) }.padding(.horizontal, 20)
                    DossierSetupView()
                }.background(SujiTheme.paper)
            case .birth: BirthEditor(existing: store.state.birth) { birth in try await store.updateBirth(birth) }
            case .journal: JournalComposer()
            case .history: RitualHistoryView()
            case .share: RitualShareView()
            case .recovery(let url): PasswordRecoveryView(url: url)
            case .reflection:
                NavigationStack {
                    ReflectionView(title: "留给今天的一句话", key: "daily:" + store.day.rawValue,
                        context: Document(["date": store.day.rawValue, "calendar": store.calendarInfo?.value ?? NSNull(), "personalObservation": store.profile?["daily"].value ?? NSNull(), "quote": store.ritual?.quote ?? store.content.quote]).json,
                        instruction: "根据今日的日签与可选的传统观察给出简短、具体、容易实行的自我关照行动。没有个人数据时就以普通日常建议回应；不要声称已经分析命盘。不使用吉凶、幸运数或健康运势指令。先问问用户今天最在意的一件事。",
                        opening: "陪我想一想，今天可以怎样照顾自己。",
                        privacy: "开始后，今日历法、日签与已有的个人观察会经有时的服务发送给 DeepSeek。日签正文始终是本地编辑内容。")
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { sheet = nil } } }
                }
            }
    }
    private func consumePendingNotificationRoute() {
        if notificationRoute.consumeToday() { openToday() }
    }
    private func openToday() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        sheet = nil; store.selectedTab = 0
        Task { await store.refresh() }
    }
}
private enum RootSheet: Identifiable {
    case profile, themeReport, dossierSetup, birth, journal, history, share, reflection, recovery(URL)
    var id: String {
        switch self { case .profile: "profile"; case .themeReport: "themeReport"; case .dossierSetup: "dossierSetup"; case .birth: "birth"; case .journal: "journal"; case .history: "history"; case .share: "share"; case .reflection: "reflection"; case .recovery: "recovery" }
    }
}

struct DossierSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if store.computing || store.buildingNatalDossier { ProgressView("正在建立本命档案…") }
                else {
                    Text("建立你的档案").font(SujiTheme.serif(28))
                    Text(store.dossierError ?? "根据出生资料整理八字与紫微本命盘，完成后即可进入册页。")
                        .foregroundStyle(.secondary)
                    Button("重新建档") { Task { await store.calculateProfile() } }.buttonStyle(.borderedProminent)
                    Button("检查出生资料") { editing = true }
                }
                NavigationLink("账户与登录") { AccountView(session: store.accountSession) }
            }.padding(28)
                .sheet(isPresented: $editing) { BirthEditor(existing: store.state.birth) { birth in try await store.updateBirth(birth) } }
        }
    }
}
