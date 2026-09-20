import Foundation
import SwiftData
import SwiftUI
import SujiCore
import CryptoKit

@Model final class SavedState {
    @Attribute(.unique) var key: String
    var data: Data
    init(data: Data, key: String = "local") { self.key = key; self.data = data }
}

struct Document {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(data: Data) throws { value = try JSONSerialization.jsonObject(with: data) }
    subscript(_ key: String) -> Document { Document((value as? [String: Any])?[key] as Any? ?? NSNull()) }
    var text: String { value as? String ?? "" }
    var number: Double { (value as? NSNumber)?.doubleValue ?? 0 }
    var array: [Document] { (value as? [Any] ?? []).map(Document.init) }
    var strings: [String] { value as? [String] ?? [] }
    var dictionary: [String: Any] { value as? [String: Any] ?? [:] }
    var json: String { (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])).map { String(decoding: $0, as: UTF8.self) } ?? "null" }
}

@MainActor @Observable final class AppStore {
    var state: AppState
    var calendarInfo: Document?
    var profile: Document?
    private(set) var natalDossier: NatalDossier?
    var dossierError: String?
    var cloudProfileStatus: String?
    private(set) var preparingAccount = false
    private var preparedScope: String?
    private var syncingProfile = false
    private var natalTask: (id: UUID, scope: UUID, birth: BirthProfile, task: Task<NatalDossier, Error>)?
    var today = Date()
    var computing = false
    var error: String?
    var selectedTab = 0
    private(set) var scopeRevision = UUID()
    private(set) var scopeKey: String
    var widgetStatus: String?
    let engine: MingliBridge
    let engineRevision: String
    private let context: ModelContext
    private var record: SavedState
    private var calculationVersion = 0
    private var refreshVersion = 0
    @ObservationIgnored lazy var accountSession: AccountSession = {
#if DEBUG
        let restore = !ProcessInfo.processInfo.arguments.contains("--ui-testing")
#else
        let restore = true
#endif
        return AccountSession(restoreSession: restore) { [weak self] previous, next in
            guard let self else { throw CancellationError() }
            try await self.switchAccount(from: previous, to: next)
        }
    }()

    var isSignedIn: Bool { scopeKey != "local" && accountSession.user?.id == String(scopeKey.dropFirst(5)) }
    var hasNatalDossier: Bool {
        guard let birth = state.birth else { return false }
        return natalDossier?.matches(ownerID: scopeKey, birth: birth, engineRevision: engineRevision) == true
    }
    var buildingNatalDossier: Bool { natalTask != nil }

    init(context: ModelContext, scriptURL: URL, userID: String? = nil) throws {
        self.context = context
        let key = userID.map { "user:" + $0 } ?? "local"
        scopeKey = key
        engineRevision = SHA256.hash(data: try Data(contentsOf: scriptURL)).map { String(format: "%02x", $0) }.joined()
        engine = try MingliBridge(scriptURL: scriptURL)
        if let existing = try context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == key })).first {
            state = try JSONDecoder().decode(AppState.self, from: existing.data)
            record = existing
        } else {
            let initial = AppState()
            state = initial
            record = SavedState(data: try JSONEncoder().encode(initial), key: key)
            context.insert(record)
            try context.save()
        }
    }
    var day: DayKey { DayKey(date: today) }
    var ritual: RitualEntry? { state.rituals.first { $0.day == day.rawValue } }
    var content: DailyContent { DailyContent.forDate(today) }
    var aiKeyName: String { scopeKey == "local" ? "ai-key" : "ai-key:" + scopeKey }
    func saveThrowing() throws { record.data = try JSONEncoder().encode(state); try context.save() }
    func save() {
        do { try saveThrowing() }
        catch { self.error = "内容尚未保存：\(error.localizedDescription)" }
    }
    func switchAccount(from previous: String?, to next: String?) async throws {
        guard scopeKey == (previous.map { "user:" + $0 } ?? "local") else { throw EngineError.execution("当前账户已改变，请重新打开账户设置。") }
        let nextKey = next.map { "user:" + $0 } ?? "local"
        guard nextKey != scopeKey else { return }
        try saveThrowing()
        let candidate = try context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == nextKey })).first
        let nextState = try candidate.map { try JSONDecoder().decode(AppState.self, from: $0.data) } ?? AppState()
        let nextRecord = try candidate ?? SavedState(data: JSONEncoder().encode(nextState), key: nextKey)
        if candidate == nil { context.insert(nextRecord); try context.save() }
        scopeRevision = UUID(); calculationVersion += 1
        natalTask?.task.cancel(); natalTask = nil; natalDossier = nil; dossierError = nil
        cloudProfileStatus = nil; preparedScope = nil; preparingAccount = false
        record = nextRecord; scopeKey = nextKey; state = nextState; profile = nil; computing = false
        await refresh()
    }
    func revealToday() { state.reveal(day: day, quote: content.quote, action: content.action); save(); publishWidget() }
    func recordMood(_ mood: Mood, note: String) { state.recordMood(day: day.rawValue, mood: mood, note: note); save() }
    func refresh() async {
        refreshVersion += 1
        let version = refreshVersion
        today = Date()
        do {
            let value = try await request(["command": "calendar", "day": day.rawValue])
            guard version == refreshVersion else { return }
            calendarInfo = value
        }
        catch { guard version == refreshVersion else { return }; calendarInfo = nil; self.error = error.localizedDescription }
        publishWidget()
        await calculateProfile()
    }
    private func publishWidget() {
        do {
            try WidgetSnapshotService.publish(day: day, date: today, lunar: calendarInfo?["lunarDate"].text ?? "", solarTerm: calendarInfo?["solarTerm"].text, quote: ritual?.quote ?? content.quote, action: ritual?.action ?? content.action, isRevealed: ritual != nil)
            widgetStatus = nil
        } catch { widgetStatus = error.localizedDescription }
    }
    func request(_ payload: [String: Any]) async throws -> Document {
        let scope = scopeRevision
        var payload = payload
        let command = payload["command"] as? String ?? ""
        let cast = ["cast_liuyao", "setup_qimen"].contains(payload["name"] as? String ?? "")
        if ["profile", "forecast", "relationship", "tool"].contains(command), !cast,
           let birth = state.birth, let supplied = payload["birth"],
           let data = try? JSONSerialization.data(withJSONObject: supplied),
           (try? JSONDecoder().decode(BirthProfile.self, from: data)) == birth {
            let dossier = try await ensureNatalDossier()
            guard scope == scopeRevision, state.birth == birth else { throw CancellationError() }
            payload["natal"] = try JSONSerialization.jsonObject(with: dossier.payload)
        }
        let result = try await rawRequest(payload)
        guard scope == scopeRevision else { throw CancellationError() }
        return result
    }
    private func rawRequest(_ payload: [String: Any]) async throws -> Document {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try await engine.request(String(decoding: data, as: UTF8.self))
        try EngineContract.validate(result, command: payload["command"] as? String ?? "")
        return try Document(data: result)
    }
    func birthJSON(_ birth: BirthProfile) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth)) }

    func legacyNotebook() throws -> AppState? {
        guard scopeKey != "local", let saved = try context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == "local" })).first else { return nil }
        let notebook = try JSONDecoder().decode(AppState.self, from: saved.data)
        return notebook.birth != nil || !notebook.rituals.isEmpty || !notebook.journal.isEmpty || !notebook.conversations.isEmpty ? notebook : nil
    }

    func replaceNotebook(_ replacement: AppState, uploadBirth: Bool = false) throws {
        let old = state
        state = replacement
        state.profileNeedsUpload = uploadBirth
        let key = "natal:" + scopeKey
        do {
            for saved in try context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == key })) { context.delete(saved) }
            try saveThrowing()
        } catch { context.rollback(); state = old; throw error }
        scopeRevision = UUID(); calculationVersion += 1
        natalTask?.task.cancel(); natalTask = nil; natalDossier = nil
        profile = nil; dossierError = nil; computing = false; preparingAccount = false
        // A deliberate local import/deletion must not immediately be replaced
        // by the empty-account cloud restoration path.
        preparedScope = scopeKey
    }
    func updateBirth(_ birth: BirthProfile) async throws {
        try birth.validated()
        let old = state
        let scope = scopeRevision
        if state.birth != birth { state.previousBirth = state.birth }
        state.birth = birth; state.profileNeedsUpload = true
        do { try saveThrowing() }
        catch { context.rollback(); state = old; throw error }
        profile = nil
        _ = try await ensureNatalDossier()
        guard scope == scopeRevision, state.birth == birth else { throw CancellationError() }
        state.hasOnboarded = true
        try saveThrowing()
        await calculateProfile()
        await syncBirthProfile()
    }

    func ensureNatalDossier() async throws -> NatalDossier {
        guard let birth = state.birth else { throw DomainError.invalidBirth }
        if let natalDossier, natalDossier.matches(ownerID: scopeKey, birth: birth, engineRevision: engineRevision) { return natalDossier }
        let scope = scopeRevision
        if let pending = natalTask, pending.scope == scope, pending.birth == birth { return try await pending.task.value }
        let key = "natal:" + scopeKey
        if let record = try context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == key })).first,
           let cached = try? JSONDecoder().decode(NatalDossier.self, from: record.data),
           cached.matches(ownerID: scopeKey, birth: birth, engineRevision: engineRevision) {
            natalDossier = cached
            return cached
        }
        let id = UUID()
        let operation = Task { @MainActor in
            let document = try await self.rawRequest(["command": "natal", "birth": self.birthJSON(birth)])
            try Task.checkCancellation()
            guard self.scopeRevision == scope, self.state.birth == birth else { throw CancellationError() }
            let dossier = try NatalDossier(ownerID: self.scopeKey, birth: birth, engineRevision: self.engineRevision, payload: Data(document.json.utf8))
            let data = try JSONEncoder().encode(dossier)
            if let existing = try self.context.fetch(FetchDescriptor<SavedState>(predicate: #Predicate { $0.key == key })).first {
                existing.data = data
            } else { self.context.insert(SavedState(data: data, key: key)) }
            do { try self.context.save() } catch { self.context.rollback(); throw error }
            self.natalDossier = dossier
            return dossier
        }
        natalTask = (id, scope, birth, operation)
        defer { if natalTask?.id == id { natalTask = nil } }
        return try await operation.value
    }

    /// Restore only an empty account. Existing local edits always stay local
    /// until explicitly uploaded or replaced via the account settings.
    func prepareAccount() async {
        guard isSignedIn, preparedScope != scopeKey else { return }
        let scope = scopeRevision
        preparedScope = scopeKey; preparingAccount = true
        defer { if scopeRevision == scope { preparingAccount = false } }
        if state.birth == nil, state.profileNeedsUpload != true {
            do {
                if let cloud = try await accountSession.fetchProfile() {
                    guard scopeRevision == scope, state.birth == nil else { return }
                    let old = state
                    state = try accountSession.applying(cloud, to: state)
                    do { try saveThrowing() } catch { context.rollback(); state = old; throw error }
                }
            } catch {
                guard scopeRevision == scope else { return }
                cloudProfileStatus = "云端资料暂未恢复：\(error.localizedDescription)"
                preparedScope = nil
            }
        }
        guard scopeRevision == scope else { return }
        await calculateProfile()
        await syncBirthProfile()
    }

    func syncBirthProfile() async {
        guard isSignedIn, state.profileNeedsUpload == true, !syncingProfile else { return }
        let scope = scopeRevision; let birth = state.birth
        syncingProfile = true
        defer {
            syncingProfile = false
            // An edit/account change while a request was in flight leaves a
            // newer queued profile; send it only after the older write ends.
            if (scopeRevision != scope || state.birth != birth), isSignedIn, state.profileNeedsUpload == true {
                Task { await self.syncBirthProfile() }
            }
        }
        do {
            _ = try await accountSession.pushProfile(from: state)
            guard scopeRevision == scope, state.birth == birth else { return }
            state.profileNeedsUpload = false
            do { try saveThrowing() } catch { state.profileNeedsUpload = true; throw error }
            cloudProfileStatus = nil
        } catch {
            guard scopeRevision == scope else { return }
            cloudProfileStatus = "资料已保存在本机，云端尚未同步。\(error.localizedDescription)"
        }
    }
    func calculateProfile() async {
        calculationVersion += 1
        let version = calculationVersion
        guard let birth = state.birth else { profile = nil; computing = false; return }
        computing = true
        dossierError = nil
        defer { if version == calculationVersion { computing = false } }
        do {
            let result = try await request(["command": "profile", "birth": birthJSON(birth), "now": ISO8601DateFormatter().string(from: today)])
            guard version == calculationVersion else { return }
            profile = result
        } catch { if version == calculationVersion { profile = nil; dossierError = error.localizedDescription } }
    }
}
