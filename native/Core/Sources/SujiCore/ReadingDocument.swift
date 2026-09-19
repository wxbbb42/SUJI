import Foundation

/// A persisted local presentation, never a new tool result or a model-authored verdict.
/// External imports drop this metadata and retain the readable historical text.
public struct ReadingDocument: Codable, Sendable {
    public enum Topic: String, Codable, Sendable { case baziFrameworks }
    public enum Focus: String, Codable, CaseIterable, Sendable {
        case comparison, overview, strength, pattern, relations, climate
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
    public let sourceUserID: UUID
    public let context: ToolContext
    public let sections: [Section]
    public var plainText: String { sections.map(\.body).joined(separator: "\n\n") }

    public init(catalog: BaziFrameworkReading.Catalog, answer: BaziFrameworkReading.Answer, sourceUserID: UUID, focus: Focus = .comparison) {
        version = "suji-reading-document-1"
        topic = .baziFrameworks
        self.focus = focus
        self.sourceUserID = sourceUserID
        context = catalog.context
        let byID = Dictionary(uniqueKeysWithValues: catalog.claims.map { ($0.id, $0) })
        sections = answer.selectedClaimIDs.compactMap { id in
            guard let claim = byID[id] else { return nil }
            return Section(id: id, title: Self.titles[id] ?? "解释依据", body: claim.text,
                           qualification: claim.qualification, evidence: claim.evidence)
        }
    }

    public var isValid: Bool {
        version == "suji-reading-document-1" && context.isValid && context.mode == "命理"
            && (1...8).contains(sections.count) && Set(sections.map(\.id)).count == sections.count
            && sections.allSatisfy { section in
                Self.titles[section.id] == section.title && !section.body.isEmpty && section.body.utf8.count <= 6_000
                    && section.evidence.count <= 48 && section.evidence.allSatisfy { field in
                        !field.toolCallID.isEmpty && field.toolCallID.utf8.count <= 200
                            && field.pointer.hasPrefix("/bazi/") && field.pointer.utf8.count <= 512
                            && ReadingVerificationEvidence.encoded(field.value).utf8.count <= 6_000
                    }
            }
    }

    private static let titles = ["chart": "本次命盘", "strength": "扶抑参考", "pattern": "格局候选", "relations": "五行关系", "tiaohou": "调候文献", "climate-unavailable": "调候依据", "overview": "两种用神怎么看", "comparison": "如何理解差异"]
}

/// Resolve a supported Bazi question from explicit wording or the last locally
/// generated answer's identity. Old assistant prose alone cannot establish a topic.
public enum BaziReadingRequest {
    public static func resolve(question: String, mode: String, entries: [ConversationEntry], currentUserID: UUID, context: ToolContext) -> ReadingDocument.Focus? {
        guard mode == "命理", context.mode == mode else { return nil }
        let q = question.filter { !$0.isWhitespace }
        func matches(_ pattern: String) -> Bool { q.range(of: pattern, options: .regularExpression) != nil }
        // Explicit topic switches supersede continuity. Do not swallow another system,
        // a new timed reading, or a request to discuss real circumstances instead.
        guard !matches("紫微|六爻|奇门|起卦|大运|流年|流月|今年|明年|不(看|谈|用|想聊)八字|换个话题|只(问|看).{0,8}(事业|婚姻|健康|工作)") else { return nil }
        guard !matches("格局(放大|太小|大一点)|心情|情绪|失恋|买.{0,8}(基金|股票)|职业选择") else { return nil }
        guard !matches("(不要|不用|不想|别|放下|停止|不谈|不看).{0,6}(命理|命盘|八字|算命|继续算)") else { return nil }
        guard !matches("(不要|不用|无需|不需要|暂不|别).{0,4}(比较|对比|格局|扶抑|调候)|(格局|扶抑|调候).{0,4}(不看|不用|暂时不用)") else { return nil }
        if BaziFrameworkReading.applies(question: question, mode: mode) { return .comparison }
        let personal = matches("我|命盘|八字|本盘|用神|本次")
        let elementRelation = matches("五行.{0,8}(生克|关系)|[木火土金水].{0,6}(生|克|泄|耗)[木火土金水]|(克|泄|耗)[、，,和与及/]*(克|泄|耗)|^(那)?(克|泄|耗)(是什么意思|怎么理解|呢)[？?。！!]*$")
        if personal && matches("扶抑|身强|身弱|旺衰|(日主|八字|命盘|本盘).{0,8}(强弱|偏强|偏弱)") { return .strength }
        if personal && matches("成格|月令取格|格局用神|格局候选|(八字|命盘|本盘).{0,8}格局|格局.{0,8}(八字|命盘|本盘)") { return .pattern }
        if personal && matches("调候|寒暖燥湿|穷通宝鉴") { return .climate }
        if personal && elementRelation { return .relations }
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
        // Rebind each persisted section to locally compiled source data. A label or
        // edited/imported sentence cannot promote itself into conversation authority.
        let claims = Dictionary(uniqueKeysWithValues: oldCatalog.claims.map { ($0.id, $0) })
        let selection = ReadingVerificationEvidence.encoded(JSONValue.object([
            "protocolVersion": .string(BaziFrameworkReading.protocolVersion),
            "claimIDs": .array(document.sections.map { .string($0.id) }),
        ]))
        let rebound = BaziFrameworkReading.render(selection: selection, catalog: oldCatalog, focus: document.focus)
        guard rebound.selectionStatus == "validated-selection", rebound.text == document.plainText else { return nil }
        guard document.sections.allSatisfy({ section in
            guard let claim = claims[section.id] else { return false }
            return section.body == claim.text && section.qualification == claim.qualification
                && section.evidence == claim.evidence
        }), q.count <= 160 else { return nil }
        let briefRequest = "^(那|所以)?[，,]?(请|麻烦|可以|能不能|能)?(再)?(简单(点|一点)?(说说|说|讲|解释一下)?|简短(点|说|一点)?|用?一句话(说|解释|概括)?|概括(一下)?|讲人话)([，,](我)?(到底|究竟)?(用|选)(哪个|哪种|哪一个)(用神)?)?(吗|么)?[？?。！!]*$"
        let choiceRequest = "^(那|所以)?[，,]?(我)?(到底|究竟)?(用|选)(哪个|哪种|哪一个)(用神)?[？?。！!]*$"
        if matches(briefRequest) {
            return [.comparison, .overview].contains(document.focus) ? .overview : document.focus
        }
        if matches(choiceRequest), [.comparison, .overview].contains(document.focus) { return .overview }
        if matches("^(那)?(请|能不能|可以|能)?(去掉|省略|不要)(这些|那些|所有)?(限定|限定语|条件|候选|启发式)(语气|这两个字)?(吗)?[？?。！!]*$") { return document.focus }
        if matches("身强|身弱|旺衰|扶抑|日主.{0,4}(强弱|偏强|偏弱)|^(那)?(为什么|怎么判断|怎么看)?(偏强|偏弱|强弱)[？?。！!]*$") { return .strength }
        if matches("成格|偏印格|正印格|月令|透干|格局(用神|候选)|^(那)?(为什么|怎么理解|怎么判断|怎么看|解释一下)?(只是|还是|是)?(候选|格局|限定)(呢|是什么意思)?[？?。！!]*$") { return .pattern }
        if matches("调候|寒暖|燥湿|戊.{0,3}丁|穷通") { return .climate }
        if elementRelation { return .relations }
        if matches("^(那|所以|刚才|你说的)?[，,]?(为什么|怎么理解|再解释(一下)?|继续(说)?|展开(说说)?)[？?。！!]*$") { return document.focus }
        return nil
    }
}
