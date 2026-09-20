import Foundation

public struct DayKey: Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        rawValue = String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

public enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case bright = "明朗", calm = "平静", unsettled = "起伏", tired = "疲惫", low = "低落"
    public var id: String { rawValue }
    public var symbol: String {
        switch self { case .bright: return "sun.max"; case .calm: return "water.waves"; case .unsettled: return "wind"; case .tired: return "moon"; case .low: return "cloud.rain" }
    }
    public var level: Int {
        switch self { case .bright: return 5; case .calm: return 4; case .unsettled: return 3; case .tired: return 2; case .low: return 1 }
    }
}

public struct RitualEntry: Codable, Identifiable, Sendable {
    public var id: String { day }
    public let day: String
    public let quote: String
    public let action: String
    public let revealedAt: Date
}

public struct JournalEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let day: String
    public var mood: Mood
    public var note: String
    public let createdAt: Date
}

public struct BirthProfile: Codable, Equatable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var gender: String
    public var city: String
    public var longitude: Double
    public var timeZoneID: String
    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, gender: String, city: String, longitude: Double, timeZoneID: String = "Asia/Shanghai") {
        self.year = year; self.month = month; self.day = day; self.hour = hour; self.minute = minute
        self.gender = gender; self.city = city; self.longitude = longitude; self.timeZoneID = timeZoneID
    }
    public var date: Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }
    @discardableResult public func validated() throws -> Self {
        guard (1901...2100).contains(year), (1...12).contains(month), (0...23).contains(hour), (0...59).contains(minute), !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, longitude.isFinite, (-180...180).contains(longitude), ["男", "女"].contains(gender), timeZoneID == "Asia/Shanghai", let date else { throw DomainError.invalidBirth }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let values = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard values.year == year, values.month == month, values.day == day, values.hour == hour, values.minute == minute else { throw DomainError.invalidBirth }
        return self
    }
    public var label: String { String(format: "%d年%d月%d日 %02d:%02d", year, month, day, hour, minute) }
}

public enum DomainError: LocalizedError {
    case invalidBirth, invalidArchive
    public var errorDescription: String? {
        switch self {
        case .invalidBirth: return "请检查出生日期、时间、地点与经度。当前排盘使用北京时间。"
        case .invalidArchive: return "这份备份格式不受支持，原有数据未被更改。"
        }
    }
}

public struct ConversationEntry: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var role: String
    public var text: String
    public var date: Date = Date()
    public var evidence: [String] = []
    public var toolData: [String] = []
    public var toolReceipts: [ToolReceipt]?
    public var toolContext: ToolContext?
    public var confirmedCastQuestions: [ConfirmedCastQuestion]?
    public var analysisMode: String?
    public var readingDocument: ReadingDocument?
    public init(role: String, text: String) { self.role = role; self.text = text }
}

public struct AppState: Codable, Sendable {
    public var version = 1
    public var hasOnboarded = false
    public var birth: BirthProfile?
    public var previousBirth: BirthProfile?
    public var profileNeedsUpload: Bool?
    public var rituals: [RitualEntry] = []
    public var journal: [JournalEntry] = []
    public var conversations: [ConversationEntry] = []
    public var reflections: [String: [ConversationEntry]]?
    public var appearance = "system"
    public var tone = "温暖"
    // Retained only to decode existing version-1 notebooks. Managed AI never
    // reads these fields, including after archive import or cloud restoration.
    public var providerURL = "https://api.openai.com/v1"
    public var model = "gpt-4.1-mini"
    public init() {}
    public mutating func reveal(day: DayKey, quote: String, action: String) {
        guard !rituals.contains(where: { $0.day == day.rawValue }) else { return }
        rituals.append(RitualEntry(day: day.rawValue, quote: quote, action: action, revealedAt: Date()))
    }
    @discardableResult public mutating func recordMood(day: String, mood: Mood, note: String) -> UUID {
        let entry = JournalEntry(id: UUID(), day: day, mood: mood, note: note, createdAt: Date())
        journal.append(entry); return entry.id
    }
    public mutating func editJournal(id: UUID, mood: Mood, note: String) {
        guard let index = journal.firstIndex(where: { $0.id == id }) else { return }
        journal[index].mood = mood; journal[index].note = note
    }
    public mutating func deleteJournal(id: UUID) { journal.removeAll { $0.id == id } }
}

public struct DailyContent: Sendable {
    public let quote: String
    public let action: String
    public static func forDate(_ date: Date, calendar: Calendar = .current) -> Self {
        let pairs = [
            ("日子慢慢过，\n心事轻轻放。", "给自己留十分钟，不安排任何事。"),
            ("不必追赶风，\n你也有自己的季节。", "把最重要的一件事，做得从容一点。"),
            ("万物有时，\n你也一样。", "出门走一段路，看看今天的天空。"),
            ("心有留白，\n自有回响。", "暂时放下屏幕，喝一杯温水。"),
            ("允许今天，\n只是一段途中。", "把一个过高的要求，换成一件小事。"),
            ("在细微处，\n重新喜欢生活。", "记下今天一件让你舒服的小事。"),
            ("向内安顿，\n向外生长。", "给在意的人，留下一句真诚的问候。")
        ]
        let ordinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let pair = pairs[abs(ordinal) % pairs.count]
        return Self(quote: pair.0, action: pair.1)
    }
}
