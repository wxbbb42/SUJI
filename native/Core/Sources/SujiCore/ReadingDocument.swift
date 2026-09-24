import Foundation

/// A persisted local presentation, never a new tool result or a model-authored verdict.
/// External imports drop this metadata and retain the readable historical text.
public struct ReadingDocument: Codable, Sendable {
    public enum Topic: String, Codable, Sendable { case baziFrameworks }
    public enum Focus: String, Codable, CaseIterable, Sendable {
        case comparison, overview, strength, pattern, relations, climate
    }
    public enum Detail: String, Codable, Sendable { case standard, brief }
    public struct Presentation: Codable, Equatable, Sendable {
        public let focuses: [Focus]
        public let detail: Detail
        public init(focuses: [Focus], detail: Detail = .standard) { self.focuses = focuses; self.detail = detail }
        public var isValid: Bool {
            (1...4).contains(focuses.count) && Set(focuses).count == focuses.count
                && (focuses.count == 1 || !focuses.contains(where: { $0 == .comparison || $0 == .overview }))
        }
    }
    public struct Section: Codable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let body: String
        public let qualification: BaziFrameworkReading.Claim.Qualification
        public let evidence: [BaziFrameworkReading.FieldEvidence]
    }
    public let version: String
    public let topic: Topic
    public let focus: Focus
    public let presentation: Presentation?
    public var resolvedPresentation: Presentation { presentation ?? .init(focuses: [focus]) }
    public let sourceUserID: UUID
    public let context: ToolContext
    public let sections: [Section]
    public var plainText: String { sections.map(\.body).joined(separator: "\n\n") }

    public init(catalog: BaziFrameworkReading.Catalog, answer: BaziFrameworkReading.Answer, sourceUserID: UUID, focus: Focus = .comparison, presentation: Presentation? = nil) {
        version = "suji-reading-document-1"
        topic = .baziFrameworks
        self.focus = presentation?.focuses.first ?? focus
        self.presentation = presentation
        self.sourceUserID = sourceUserID
        context = catalog.context
        let byID = Dictionary(uniqueKeysWithValues: catalog.claims.map { ($0.id, $0) })
        sections = answer.selectedClaimIDs.compactMap { id in
            guard let claim = byID[id] else { return nil }
            return Section(id: id, title: Self.title(for: id) ?? "解释依据", body: claim.text,
                           qualification: claim.qualification, evidence: claim.evidence)
        }
    }

    public var isValid: Bool {
        version == "suji-reading-document-1" && context.isValid && context.mode == "命理"
            && resolvedPresentation.isValid && resolvedPresentation.focuses.first == focus
            && (1...8).contains(sections.count) && Set(sections.map(\.id)).count == sections.count
            && sections.allSatisfy { section in
                Self.title(for: section.id) == section.title && !section.body.isEmpty && section.body.utf8.count <= 6_000
                    && section.evidence.count <= 48 && section.evidence.allSatisfy { field in
                        !field.toolCallID.isEmpty && field.toolCallID.utf8.count <= 200
                            && field.pointer.hasPrefix("/bazi/") && field.pointer.utf8.count <= 512
                            && ReadingVerificationEvidence.encoded(field.value).utf8.count <= 6_000
                    }
            }
    }

    private static func title(for id: String) -> String? {
        titles[id.hasSuffix("-brief") ? String(id.dropLast(6)) : id]
    }
    private static let titles = ["chart": "本次命盘", "strength": "扶抑参考", "pattern": "格局候选", "relations": "五行关系", "tiaohou": "调候文献", "climate-unavailable": "调候依据", "overview": "两种用神怎么看", "comparison": "如何理解差异"]
}

/// Resolve a supported Bazi question from explicit wording or the last locally
/// generated answer's identity. Old assistant prose alone cannot establish a topic.
public enum BaziReadingRequest {
    public static func resolve(question: String, mode: String, entries: [ConversationEntry], currentUserID: UUID, context: ToolContext) -> ReadingDocument.Focus? {
        resolveRequest(question: question, mode: mode, entries: entries, currentUserID: currentUserID, context: context)?.focuses.first
    }

    public static func resolveRequest(question: String, mode: String, entries: [ConversationEntry], currentUserID: UUID, context: ToolContext) -> ReadingDocument.Presentation? {
        guard mode == "命理", context.mode == mode else { return nil }
        let q = question.filter { !$0.isWhitespace }
        func matches(_ pattern: String, in text: String? = nil) -> Bool { (text ?? q).range(of: pattern, options: .regularExpression) != nil }
        guard !matches("紫微|六爻|奇门|起卦|大运|流年|流月|今年|明年|不(看|谈|用|想聊)八字|换个话题|只(问|看).{0,8}(事业|婚姻|健康|工作)") else { return nil }
        guard !matches("格局(放大|太小|大一点)|心情|情绪|失恋|买.{0,8}(基金|股票)|职业选择") else { return nil }
        guard !matches("(不要|不用|不想|别|放下|停止|不谈|不看).{0,6}(命理|命盘|八字|算命|继续算)") else { return nil }

        let old = trustedPrevious(entries: entries, currentUserID: currentUserID, context: context)
        let brief = matches("简单|简短|一句话|两句|白话|概括|讲人话")
        let detail: ReadingDocument.Detail = brief ? .brief : .standard
        let topicPatterns: [(ReadingDocument.Focus, String)] = [
            (.strength, "扶抑|身强|身弱|旺衰|偏强|偏弱|日主.{0,8}月令|月令.{0,8}日主|(日主|八字|命盘|本盘).{0,8}强弱|通根|根气|同类.{0,4}异类|权重|日主.{0,8}(一分|计入|算不算)"),
            (.pattern, "成格|月令取格|格局|偏印格|正印格|透干"),
            (.climate, "调候|寒暖|燥湿|穷通"),
            (.relations, "五行.{0,8}(生克|关系)|[木火土金水].{0,6}(生|克|泄|耗)[木火土金水]|(克|泄|耗)[、，,和与及/]*(克|泄|耗)|^(那)?(克|泄|耗)(是什么意思|怎么理解|呢)")
        ]
        // Refusal applies to a coordinated topic list, including polite/embedded
        // wording. A new positive clause ends that scope even without punctuation.
        // Do not treat the 别 inside 分别/特别/区别 as a refusal.
        let separated = q.replacingOccurrences(of: "(?<!不)(?=只(?:讲|说|谈|看|想看|想聊)|而是|但是|改(?:讲|看))", with: "；", options: .regularExpression)
        let clauses = separated.components(separatedBy: CharacterSet(charactersIn: "，,。；;！？!?"))
        let anyTopic = "(?:" + topicPatterns.map(\.1).joined(separator: "|") + ")"
        let action = "(?:讲|说|谈|看|比较|对比|聊|解释|分析)"
        // Bare 不 needs a refusal action: “为什么不成格” negates a fact,
        // not the request to explain pattern formation.
        let refusal = "(?:(?:不要|不用|无需|不需要|不想|(?<![分特区辨识差个])别)(?:再|先)?" + action + "?|(?:不|暂不|不再|先不)(?:再|先)?" + action + ")(?:这个|这些|我的)?(?=" + anyTopic + ")"
        let positiveClauses = clauses.map { clause -> String in
            if matches(anyTopic + ".*(?:暂时|先)?(?:不看|不用|不需要)(?:再|先)?" + action + "?(?:了)?$", in: clause) { return "" }
            if let range = clause.range(of: refusal, options: .regularExpression) { return String(clause[..<range.lowerBound]) }
            return clause
        }
        var focuses: [ReadingDocument.Focus] = []
        for (focus, pattern) in topicPatterns {
            let positive = positiveClauses.contains { matches(pattern, in: $0) }
            if positive { focuses.append(focus) }
        }
        let personal = matches("我|命盘|八字|本盘|用神|本次|日主")
        if !focuses.isEmpty, personal || old != nil {
            if focuses.contains(.strength), focuses.contains(.pattern), BaziFrameworkReading.applies(question: question, mode: mode), focuses.count == 2 {
                return .init(focuses: [brief ? .overview : .comparison], detail: detail)
            }
            return .init(focuses: focuses, detail: detail)
        }
        guard let old, q.count <= 160 else { return nil }
        let briefRequest = "^(那|所以)?[，,]?(请|麻烦|可以|能不能|能)?(再)?(简单(点|一点)?(说说|说|讲|解释一下)?|简短(点|说|一点)?|用?一句话(说|解释|概括)?|概括(一下)?|讲人话)([，,](我)?(到底|究竟)?(用|选)(哪个|哪种|哪一个)(用神)?)?(吗|么)?[？?。！!]*$"
        let choiceRequest = "^(那|所以)?[，,]?(我)?(到底|究竟)?(用|选)(哪个|哪种|哪一个)(用神)?[？?。！!]*$"
        if matches(briefRequest) {
            let topics = old.resolvedPresentation.focuses
            return .init(focuses: topics.count == 1 && [.comparison, .overview].contains(topics[0]) ? [.overview] : topics, detail: .brief)
        }
        if matches(choiceRequest), [.comparison, .overview].contains(old.focus) { return .init(focuses: [.overview], detail: .brief) }
        if matches("^(那)?(请|能不能|可以|能)?(去掉|省略|不要)(这些|那些|所有)?(限定|限定语|条件|候选|启发式)(语气|这两个字)?(吗)?[？?。！!]*$") { return old.resolvedPresentation }
        if matches("^(那)?(为什么|怎么理解|怎么判断|怎么看|解释一下)?(只是|还是|是)?(候选|格局|限定)(呢|是什么意思)?[？?。！!]*$") { return .init(focuses: [.pattern], detail: detail) }
        if matches("^(那|所以|刚才|你说的)?[，,]?(为什么|怎么理解|再解释(一下)?|继续(说)?|展开(说说)?)[？?。！!]*$") { return .init(focuses: old.resolvedPresentation.focuses) }
        if old.resolvedPresentation.focuses.contains(.strength), matches("^(那)?(你说的)?(参考[，,]?)?(具体)?(怎么|如何)(计算|算出来|累加)|^日主自己") { return .init(focuses: [.strength], detail: detail) }
        return nil
    }

    private static func trustedPrevious(entries: [ConversationEntry], currentUserID: UUID, context: ToolContext) -> ReadingDocument? {
        guard let currentIndex = entries.firstIndex(where: { $0.id == currentUserID }), currentIndex >= 2,
              entries[currentIndex].role == "user" else { return nil }
        let previous = entries[currentIndex - 1], source = entries[currentIndex - 2]
        guard previous.role == "assistant", source.role == "user", let document = previous.readingDocument,
              document.isValid, document.sourceUserID == source.id, source.toolContext == document.context,
              previous.text == document.plainText,
              document.context.birthFingerprint == context.birthFingerprint,
              document.context.engineRevision == context.engineRevision,
              document.context.mode == context.mode,
              let receipts = source.toolReceipts,
              let oldCatalog = BaziFrameworkReading.catalog(receipts: receipts, context: document.context) else { return nil }
        let claims = Dictionary(uniqueKeysWithValues: oldCatalog.claims.map { ($0.id, $0) })
        let selection = ReadingVerificationEvidence.encoded(JSONValue.object([
            "protocolVersion": .string(BaziFrameworkReading.protocolVersion),
            "claimIDs": .array(document.sections.map { .string($0.id) }),
        ]))
        let rebound = BaziFrameworkReading.render(selection: selection, catalog: oldCatalog, presentation: document.resolvedPresentation)
        guard rebound.selectionStatus == "validated-selection", rebound.text == document.plainText,
              document.sections.allSatisfy({ section in
                  guard let claim = claims[section.id] else { return false }
                  return section.body == claim.text && section.qualification == claim.qualification && section.evidence == claim.evidence
              }) else { return nil }
        return document
    }
}
