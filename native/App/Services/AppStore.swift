import Foundation
import SwiftData
import SwiftUI
import SujiCore

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
    var today = Date()
    var computing = false
    var error: String?
    var selectedTab = 0
    private(set) var scopeRevision = UUID()
    private(set) var scopeKey: String
    var widgetStatus: String?
    let engine: MingliBridge
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

    init(context: ModelContext, scriptURL: URL, userID: String? = nil) throws {
        self.context = context
        let key = userID.map { "user:" + $0 } ?? "local"
        scopeKey = key
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
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try Document(data: await engine.request(String(decoding: data, as: UTF8.self)))
    }
    func birthJSON(_ birth: BirthProfile) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth)) }
    func updateBirth(_ birth: BirthProfile) async throws {
        try birth.validated()
        let old = state.birth; let oldPrevious = state.previousBirth
        state.previousBirth = old; state.birth = birth
        do { try saveThrowing() }
        catch { state.birth = old; state.previousBirth = oldPrevious; throw error }
        await calculateProfile()
    }
    func calculateProfile() async {
        calculationVersion += 1
        let version = calculationVersion
        guard let birth = state.birth else { profile = nil; computing = false; return }
        computing = true
        defer { if version == calculationVersion { computing = false } }
        do {
            let result = try await request(["command": "profile", "birth": birthJSON(birth), "now": ISO8601DateFormatter().string(from: today)])
            guard version == calculationVersion else { return }
            profile = result
        } catch { if version == calculationVersion { profile = nil; self.error = error.localizedDescription } }
    }
}
