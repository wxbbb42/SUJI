import Foundation

public enum ArchiveCodec {
    public static let maximumByteCount = 20_000_000
    private static let currentVersion = 1

    public static func encode(_ state: AppState) throws -> Data {
        do {
            try validate(state)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(state)
            guard data.count <= maximumByteCount else { throw DomainError.invalidArchive }
            return data
        } catch {
            throw DomainError.invalidArchive
        }
    }

    /// External file import only. An archive can be edited outside the app, so its
    /// calculation receipts remain readable history but cannot become tool evidence.
    /// Local SavedState persistence uses JSONDecoder directly and retains contexts.
    public static func decode(_ data: Data) throws -> AppState {
        do {
            guard !data.isEmpty, data.count <= maximumByteCount else { throw DomainError.invalidArchive }
            let object = try JSONSerialization.jsonObject(with: data)
            guard let root = object as? [String: Any] else { throw DomainError.invalidArchive }
            if root["version"] != nil {
                guard let version = integer(root["version"]), (0...currentVersion).contains(version) else {
                    throw DomainError.invalidArchive
                }
            }

            let state: AppState
            if integer(root["version"]) == currentVersion, root["hasOnboarded"] != nil {
                state = try JSONDecoder().decode(AppState.self, from: data)
            } else {
                if root["version"] != nil,
                   root["state"] == nil,
                   root["suiji-user-store"] == nil,
                   root["suiji-chat-store"] == nil,
                   root["userStore"] == nil,
                   root["chatStore"] == nil,
                   root["birthDate"] == nil,
                   root["messages"] == nil { throw DomainError.invalidArchive }
                state = try decodeLegacy(root)
            }
            try validate(state)
            return removingImportedReceiptTrust(from: state)
        } catch {
            throw DomainError.invalidArchive
        }
    }

    private static func removingImportedReceiptTrust(from state: AppState) -> AppState {
        func historicalEntry(_ entry: ConversationEntry) -> ConversationEntry {
            var copy = entry
            copy.toolContext = nil
            copy.analysisMode = nil
            copy.readingDocument = nil
            copy.toolReceipts = entry.toolReceipts?.map { receipt in
                var historicalReceipt = receipt
                historicalReceipt.context = nil
                return historicalReceipt
            }
            return copy
        }
        var imported = state
        imported.conversations = state.conversations.map(historicalEntry)
        imported.reflections = state.reflections?.mapValues { $0.map(historicalEntry) }
        return imported
    }

    private static func validate(_ state: AppState) throws {
        guard state.version == currentVersion,
              ["system", "light", "dark", "celadon"].contains(state.appearance),
              ["温暖", "直言", "诗意"].contains(state.tone),
              !state.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              state.providerURL.count <= 4_096,
              state.model.count <= 512 else { throw DomainError.invalidArchive }
        if let birth = state.birth { try birth.validated() }
        if let previousBirth = state.previousBirth { try previousBirth.validated() }
        guard state.rituals.count <= 100_000,
              state.journal.count <= 100_000,
              state.conversations.count <= 100_000 else { throw DomainError.invalidArchive }

        var ritualDays = Set<String>()
        for ritual in state.rituals {
            guard validDay(ritual.day), ritualDays.insert(ritual.day).inserted,
                  ritual.quote.count <= 20_000, ritual.action.count <= 20_000 else { throw DomainError.invalidArchive }
        }
        var journalIDs = Set<UUID>()
        for entry in state.journal {
            guard validDay(entry.day), journalIDs.insert(entry.id).inserted,
                  entry.note.count <= 1_000_000 else { throw DomainError.invalidArchive }
        }
        var conversationIDs = Set<UUID>()
        for entry in state.conversations {
            try validate(entry, ids: &conversationIDs)
        }
        if let reflections = state.reflections {
            guard reflections.count <= 1_000 else { throw DomainError.invalidArchive }
            for (key, entries) in reflections {
                guard !key.isEmpty, key.count <= 256,
                      key.rangeOfCharacter(from: .controlCharacters) == nil,
                      entries.count <= 1_000 else { throw DomainError.invalidArchive }
                for entry in entries { try validate(entry, ids: &conversationIDs) }
            }
        }
    }

    private static func validate(_ entry: ConversationEntry, ids: inout Set<UUID>) throws {
        guard ["user", "assistant"].contains(entry.role),
              ids.insert(entry.id).inserted,
              entry.text.count <= 2_000_000,
              entry.evidence.count <= 1_000,
              entry.toolData.count <= 1_000,
              entry.evidence.allSatisfy({ $0.count <= 20_000 }),
              entry.toolData.allSatisfy({ $0.count <= 100_000 }) else { throw DomainError.invalidArchive }
        if let context = entry.toolContext, !context.isValid { throw DomainError.invalidArchive }
        if let document = entry.readingDocument {
            guard entry.role == "assistant", document.isValid, entry.text == document.plainText else { throw DomainError.invalidArchive }
        }
        if let mode = entry.analysisMode, !["倾诉", "命理", "起卦"].contains(mode) { throw DomainError.invalidArchive }
        if let receipts = entry.toolReceipts {
            guard receipts.count <= 32 else { throw DomainError.invalidArchive }
            var callIDs = Set<String>()
            for receipt in receipts {
                if let context = receipt.context, !context.isValid { throw DomainError.invalidArchive }
                guard !receipt.callID.isEmpty, receipt.callID.count <= 512,
                      callIDs.insert(receipt.callID).inserted,
                      ToolOrchestrator.allowedToolNames.contains(receipt.name),
                      receipt.output.count <= 1_000_000,
                      receipt.evidence.count <= 1_000,
                      receipt.evidence.allSatisfy({ $0.count <= 20_000 }) else {
                    throw DomainError.invalidArchive
                }
                var nodes = 0
                try validate(receipt.arguments, depth: 0, nodes: &nodes)
            }
        }
    }

    private static func validate(_ value: JSONValue, depth: Int, nodes: inout Int) throws {
        nodes += 1
        guard depth <= 24, nodes <= 10_000 else { throw DomainError.invalidArchive }
        switch value {
        case .null, .bool, .integer:
            return
        case let .double(number):
            guard number.isFinite else { throw DomainError.invalidArchive }
        case let .string(string):
            guard string.count <= 100_000 else { throw DomainError.invalidArchive }
        case let .array(values):
            guard values.count <= 1_000 else { throw DomainError.invalidArchive }
            for child in values { try validate(child, depth: depth + 1, nodes: &nodes) }
        case let .object(object):
            guard object.count <= 1_000,
                  object.keys.allSatisfy({ !$0.isEmpty && $0.count <= 256 && $0.rangeOfCharacter(from: .controlCharacters) == nil }) else {
                throw DomainError.invalidArchive
            }
            for child in object.values { try validate(child, depth: depth + 1, nodes: &nodes) }
        }
    }

    private static func validDay(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }

    private static func decodeLegacy(_ root: [String: Any]) throws -> AppState {
        let user = try legacyState(in: root, keys: ["suiji-user-store", "userStore"], identifyingKey: "birthDate")
        let chat = try legacyState(in: root, keys: ["suiji-chat-store", "chatStore"], identifyingKey: "messages")
        guard user != nil || chat != nil else { throw DomainError.invalidArchive }
        var state = AppState()
        state.hasOnboarded = user?["hasOnboarded"] as? Bool ?? false
        if let value = user?["apiBaseUrl"] as? String, !value.isEmpty { state.providerURL = value }
        if let value = user?["apiModel"] as? String, !value.isEmpty { state.model = value }
        state.birth = try user.map(legacyBirth) ?? nil
        state.conversations = try legacyConversations(chat?["messages"])
        return state
    }

    private static func legacyState(in root: [String: Any], keys: [String], identifyingKey: String) throws -> [String: Any]? {
        for key in keys where root[key] != nil {
            let value = try decodedJSONObject(root[key]!)
            guard let container = value as? [String: Any] else { throw DomainError.invalidArchive }
            if let state = container["state"] as? [String: Any] { return state }
            if let stateValue = container["state"] {
                guard let state = try decodedJSONObject(stateValue) as? [String: Any] else { throw DomainError.invalidArchive }
                return state
            }
            return container
        }
        if root[identifyingKey] != nil { return root }
        if let state = root["state"] as? [String: Any], state[identifyingKey] != nil { return state }
        return nil
    }

    private static func decodedJSONObject(_ value: Any) throws -> Any {
        guard let string = value as? String else { return value }
        guard let data = string.data(using: .utf8) else { throw DomainError.invalidArchive }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func legacyBirth(_ user: [String: Any]) throws -> BirthProfile? {
        let fields = ["birthDate", "gender", "birthCity", "birthLongitude"]
        let hasAny = fields.contains { user[$0] != nil && !(user[$0] is NSNull) }
        guard hasAny else { return nil }
        guard let dateString = user["birthDate"] as? String,
              let date = ISO8601DateFormatter.withFractionalSeconds.date(from: dateString)
                ?? ISO8601DateFormatter().date(from: dateString),
              let gender = user["gender"] as? String,
              let city = user["birthCity"] as? String,
              let longitude = number(user["birthLongitude"]) else { throw DomainError.invalidArchive }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let values = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = values.year, let month = values.month, let day = values.day,
              let hour = values.hour, let minute = values.minute else { throw DomainError.invalidArchive }
        return try BirthProfile(year: year, month: month, day: day, hour: hour, minute: minute, gender: gender, city: city, longitude: longitude).validated()
    }

    private static func legacyConversations(_ value: Any?) throws -> [ConversationEntry] {
        guard let value, !(value is NSNull) else { return [] }
        guard let messages = value as? [[String: Any]] else { throw DomainError.invalidArchive }
        return try messages.map { message in
            guard let role = message["role"] as? String, ["user", "assistant"].contains(role),
                  let content = message["content"] as? String else { throw DomainError.invalidArchive }
            var entry = ConversationEntry(role: role, text: content)
            if let milliseconds = number(message["timestamp"]) {
                entry.date = Date(timeIntervalSince1970: milliseconds / 1_000)
            }
            if let orchestration = message["orchestration"] as? [String: Any] {
                entry.evidence = orchestration["evidence"] as? [String] ?? []
                if let calls = orchestration["toolCalls"] as? [[String: Any]] {
                    entry.toolData = calls.compactMap { call in
                        let name = call["name"] as? String
                        let summary = call["resultSummary"] as? String ?? call["argSummary"] as? String
                        return [name, summary].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
                    }
                }
            }
            return entry
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.intValue
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.doubleValue
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
