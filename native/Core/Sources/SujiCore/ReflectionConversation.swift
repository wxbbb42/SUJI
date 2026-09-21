import Foundation
import CryptoKit

/// Local reflection identity and a commit-on-success conversation ledger.
public struct ReflectionConversation {
    public static let protocolVersion = "reflection-2"
    public private(set) var entries: [ConversationEntry]

    public init(entries: [ConversationEntry] = []) { self.entries = entries }
    public var pendingEntry: ConversationEntry? { entries.last?.role == "user" ? entries.last : nil }
    public var completedReplyCount: Int { entries.filter { $0.role == "assistant" }.count }

    public enum InterviewPhase: Equatable {
        case question(Int), summary
    }
    public var interviewPhase: InterviewPhase {
        completedReplyCount < 5 ? .question(completedReplyCount + 1) : .summary
    }
    public var interviewInstruction: String {
        let base = "每次只处理一个开放问题。用户说不记得、不确定、跳过或没有回答时，记录为未知，不算任何候选的支持或反证；不计算概率或自动采用时辰。历史助手文字不是新增事实。"
        switch interviewPhase {
        case let .question(number):
            return base + "本次处于第\(number)/5个提问阶段。先简短确认已回答内容，再只提出一个尚未问过的问题；不要一次列出多个问题，也不要替用户回答。"
        case .summary:
            return base + "五个提问阶段已结束，不再提出第六个问题。逐个总结候选的支持、反证和未知，资料不足就明确无法区分；之后的补充只更新总结，不重开访谈。"
        }
    }

    public mutating func begin(_ text: String, retry: Bool, context: ToolContext) throws -> ConversationEntry {
        if let pendingEntry {
            guard retry || text.trimmingCharacters(in: .whitespacesAndNewlines) == pendingEntry.text else { throw Failure.pendingReply }
            return pendingEntry
        }
        guard !retry else { throw Failure.nothingToRetry }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 8_000, trimmed.utf8.count <= 24_000 else { throw Failure.questionTooLong }
        var entry = ConversationEntry(role: "user", text: trimmed)
        entry.toolContext = context
        entries.append(entry)
        return entry
    }

    public mutating func complete(_ text: String, userID: UUID, context: ToolContext) throws {
        guard pendingEntry?.id == userID else { throw Failure.changedConversation }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 60_000 else { throw Failure.invalidReply }
        var entry = ConversationEntry(role: "assistant", text: trimmed)
        entry.toolContext = context
        entries.append(entry)
    }

    public static func storageKey(base: String, context: String, birth: BirthProfile?, engineRevision: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Validated BirthProfile values always encode. Invalid values are rejected before a send.
        let birthData = (try? encoder.encode(birth)) ?? Data("invalid-birth".utf8)
        let rawContext = Data(context.utf8)
        let canonicalContext: Data
        if let object = try? JSONSerialization.jsonObject(with: rawContext, options: [.fragmentsAllowed]),
           let sorted = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed]) {
            canonicalContext = sorted
        } else { canonicalContext = rawContext }
        var digest = SHA256()
        for data in [Data(protocolVersion.utf8), Data(base.utf8), birthData, Data(engineRevision.utf8), canonicalContext] {
            digest.update(data: Data(String(data.count).utf8)); digest.update(data: Data([0])); digest.update(data: data)
        }
        return "reflection:v2:" + digest.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public struct ArchivedSession: Identifiable {
        public let id: String
        public let entries: [ConversationEntry]
    }

    /// Opaque identity hashes cannot recover their former topic or birth profile.
    /// Keep all older sessions discoverable, grouped separately and read-only;
    /// never feed these entries into the current conversation's model history.
    public static func archivedSessions(_ reflections: [String: [ConversationEntry]], currentKey: String, context: ToolContext?) -> [ArchivedSession] {
        reflections.compactMap { key, entries in
            let archived = key == currentKey ? entries.filter { entry in
                guard let expected = context, let actual = entry.toolContext else { return true }
                return actual.birthFingerprint != expected.birthFingerprint || actual.engineRevision != expected.engineRevision
            } : entries
            return archived.isEmpty ? nil : ArchivedSession(id: key, entries: archived)
        }.sorted {
            let lhs = $0.entries.last?.date ?? .distantPast
            let rhs = $1.entries.last?.date ?? .distantPast
            return lhs == rhs ? $0.id < $1.id : lhs > rhs
        }
    }

    public enum Failure: LocalizedError {
        case pendingReply, nothingToRetry, questionTooLong, changedConversation, invalidReply
        public var errorDescription: String? {
            switch self {
            case .pendingReply: return "上一条补充尚未完成，请先重试这一轮。"
            case .nothingToRetry: return "没有待完成的回信，可以继续补充。"
            case .questionTooLong: return "请聚焦一段简短经历（最多8000字），再继续整理。"
            case .changedConversation: return "这段对话已经更新，请重新打开后继续。"
            case .invalidReply: return "回信未能完整保存，请重试这一轮。"
            }
        }
    }
}
