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
    var body: some View {
        Group {
            if !initialized {
                ProgressView("正在打开你的册页…")
            } else if notebookFixture {
                mainTabs
            } else if !store.isSignedIn {
                NavigationStack { AccountView(session: store.accountSession, onboarding: true) }
            } else if store.preparingAccount {
                ProgressView("正在读取你的资料…")
            } else if store.state.birth == nil {
                BirthEditor(existing: nil, required: true) { birth in try await store.updateBirth(birth) }
            } else if !store.hasNatalDossier {
                DossierSetupView()
            } else {
                mainTabs
            }
        }
        .background(SujiTheme.paper)
        .sheet(item: $sheet) { item in sheetContent(item) }
        .alert("请留意", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("知道了", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
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
        .onChange(of: store.isSignedIn) { _, signedIn in
            sheet = nil
            if signedIn { Task { await store.prepareAccount() } }
        }
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
    @ViewBuilder private var mainTabs: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            TodayView(date: store.today, lunarDate: store.calendarInfo?["lunarDate"].text ?? "", ganZhi: store.calendarInfo?["ganZhi"].text ?? "", solarTerm: store.calendarInfo?["solarTerm"].text ?? "", quote: store.ritual?.quote ?? store.content.quote, action: store.ritual?.action ?? store.content.action, isRevealed: store.ritual != nil, onReveal: { store.revealToday() }, onJournal: { sheet = .journal }, onHistory: { sheet = .history }, onShare: { sheet = .share }, onReflect: { sheet = .reflection })
                .tabItem { Label("今日", systemImage: "sun.horizon") }.tag(0)
            ChatView().tabItem { Label("问道", systemImage: "bubble.left.and.text.bubble.right") }.tag(1)
            CalmView().tabItem { Label("静心", systemImage: "water.waves") }.tag(2)
            ProfileView().tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(3)
        }
    }
    @ViewBuilder private func sheetContent(_ item: RootSheet) -> some View {
            switch item {
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
    private func openToday() { sheet = nil; store.selectedTab = 0; Task { await store.refresh() } }
}
private enum RootSheet: Identifiable {
    case journal, history, share, reflection, recovery(URL)
    var id: String {
        switch self { case .journal: "journal"; case .history: "history"; case .share: "share"; case .reflection: "reflection"; case .recovery: "recovery" }
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
