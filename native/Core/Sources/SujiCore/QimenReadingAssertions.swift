import Foundation

/// Narrow current-chart stem/plate assertions. Reads receipts only; this is not
/// a chart calculator or a general language truth checker.
enum QimenReadingAssertions {
    typealias Fact = ReadingVerificationEvidence.Fact
    private static let fields = [
        "diPanGan":"地盘干|地盘", "tianPanGan":"天盘干|天盘",
        "hostedDiPanGan":"地盘寄干", "hostedTianPanGan":"天禽寄干|天盘寄干",
    ]
    private static func identity(_ fact: Fact) -> (id: Int, field: String)? {
        let key = fact.factKey.components(separatedBy:".")
        guard key.count == 3, key[0] == "qimen", key[1].hasPrefix("palace"),
              let id = Int(key[1].dropFirst(6)), (1...9).contains(id), fields[key[2]] != nil else { return nil }
        return (id,key[2])
    }
    static func handles(_ fact: Fact) -> Bool { identity(fact) != nil }
    private static func string(_ fact: Fact?) -> String? {
        guard case let .string(value) = fact?.value else { return nil }
        return value
    }
    private static func stem(_ fact: Fact) -> String? {
        guard let value = string(fact), value.count == 1, "甲乙丙丁戊己庚辛壬癸".contains(value) else { return nil }
        return value
    }
    private static func eligible(_ sentence: String) -> Bool {
        !ReadingVerificationAssertions.conditional(sentence) && !ReadingVerificationAssertions.denied(sentence)
            && !ReadingVerificationAssertions.has(sentence,"[？?]|吗|是否|是不是|六爻|八字|紫微|紫薇|本命|流年|大运|[0-9]{4}年|假定|说|记载|书中|原文|认为|声称|提到|表示|指出|错|不成立|不属实|未确定|上次|上一|前一|之前|此前|过去|曾经|旧盘|昨天|明天|去年|明年|未来")
    }
    private static func palacePattern(_ id: Int) -> String {
        let names = ["","坎","坤","震","巽","中","乾","兑","艮","离"]
        let digits = ["","一","二","三","四","五","六","七","八","九"]
        return "(?:" + names[id] + "(?:" + digits[id] + "|" + String(id) + ")?|" + digits[id] + "|" + String(id) + ")宫"
    }
    private static func patterns(palace: String, label: String) -> [String] {
        let value = "[「『“\"]?([甲乙丙丁戊己庚辛壬癸])[」』”\"]?"
        let prefix = "^(?:本次|这次|本盘)?(?:奇门(?:盘)?(?:的)?)?"
        return [
            prefix + palace + "(?:的)?" + label + "(?:为|是|仍为|仍是)?\\s*" + value + "$",
            prefix + label + value + "(?:也)?(?:在|落在|落于)" + palace + "$",
        ]
    }
    private static func clauses(_ sentence: String) -> [String] {
        guard eligible(sentence) else { return [] }
        let text = sentence.replacingOccurrences(of:"**",with:"")
        let clauses = text.components(separatedBy:CharacterSet(charactersIn:"，,；;：:")).map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
        let allPalaces = "(?:" + (1...9).map(palacePattern).joined(separator:"|") + ")"
        let allLabels = "(?:" + fields.values.sorted().joined(separator:"|") + ")"
        let assertions = patterns(palace:allPalaces,label:allLabels)
        // Accept only a complete, bounded assertion sequence. Arbitrary prefix
        // or suffix clauses can change its meaning and cannot be discarded.
        let locationIntro = "^[甲乙丙丁戊己庚辛壬癸]落在" + allPalaces + "(?:（(?:东|西|南|北|东南|东北|西南|西北)）)?$"
        for (index,clause) in clauses.enumerated() {
            if assertions.contains(where: { ReadingVerificationAssertions.has(clause,$0) }) { continue }
            if index == 0, (text.hasPrefix(clause + "：") || text.hasPrefix(clause + ":")),
               ReadingVerificationAssertions.has(clause,locationIntro) { continue }
            return []
        }
        return clauses
    }
    private static func claims(_ sentence: String, fact: Fact) -> [String] {
        guard let (id,field) = identity(fact) else { return [] }
        let patterns = patterns(palace:palacePattern(id),label:"(?:" + fields[field]! + ")")
        return clauses(sentence).flatMap { clause in
            patterns.compactMap { pattern -> String? in
                let regex = try! NSRegularExpression(pattern:pattern)
                guard let match = regex.firstMatch(in:clause,range:NSRange(clause.startIndex...,in:clause)),
                      let range = Range(match.range(at:1),in:clause) else { return nil }
                return String(clause[range])
            }
        }
    }
    /// All available Qimen receipts must agree about the named slot and its
    /// hosting alternatives. A sparse/conflicting receipt cannot choose a chart.
    private static func supportedValues(_ fact: Fact, facts: [Fact]) -> Set<String>? {
        guard let (id,field) = identity(fact), let primary = stem(fact) else { return nil }
        let receipts = Dictionary(grouping:facts.filter { $0.factKey.hasPrefix("qimen.") },by: \.toolCallID)
        guard !receipts.isEmpty else { return nil }
        var sets: [Set<String>] = []
        for receipt in receipts.values {
            let matching = receipt.filter { $0.factKey == fact.factKey }
            guard matching.count == 1, stem(matching[0]) == primary else { return nil }
            var values: Set<String> = [primary]
            if field == "diPanGan" || field == "tianPanGan" {
                // Middle sky is a static storage record, not an effective sky.
                if id == 5 && field == "tianPanGan" { return nil }
                let hostKey = "qimen.palace\(id)." + (field == "diPanGan" ? "hostedDiPanGan" : "hostedTianPanGan")
                if let hosted = receipt.first(where: { $0.factKey == hostKey }) {
                    guard let value = stem(hosted) else { return nil }
                    values.insert(value)
                } else if id == 2 && field == "diPanGan" {
                    // Old fixed-Kun receipts encoded earth hosting implicitly.
                    guard string(receipt.first(where: { $0.factKey == "qimen.method.centerPolicy" }))?.hasPrefix("fixed-kun-2") == true,
                          let center = receipt.first(where: { $0.factKey == "qimen.palace5.diPanGan" }), let value = stem(center) else { return nil }
                    values.insert(value)
                } else if field == "tianPanGan", receipt.contains(where: { $0.factKey == "qimen.palace\(id).hostsTianQin" && $0.value == .bool(true) }) {
                    return nil
                }
            }
            sets.append(values)
        }
        guard let first = sets.first, sets.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
    static func binds(_ quote: String, to fact: Fact, in sentence: String, facts: [Fact]) -> Bool {
        guard let values = supportedValues(fact,facts:facts), !values.contains(quote) else { return false }
        return claims(sentence,fact:fact).contains(quote)
    }
    static func issues(_ draft: String, facts: [Fact]) -> [String] {
        var issues: [String] = [], seen = Set<String>()
        for fact in facts where handles(fact) && seen.insert(fact.factKey).inserted {
            guard let values = supportedValues(fact,facts:facts) else { continue }
            for sentence in ReadingVerificationAssertions.declarativeSentences(draft) {
                if claims(sentence,fact:fact).contains(where: { !values.contains($0) }) {
                    issues.append("原句：\(sentence)；本次工具\(fact.toolCallID)字段\(fact.factKey)（\(fact.pointer)）实际值为\(ReadingVerificationEvidence.encoded(fact.value))。请按原始盘面分别核对普通地盘、地盘寄干、普通天盘、天禽寄干与所在宫；不能用另一层同名天干替代，不重新起盘。")
                }
            }
        }
        return issues
    }
}
