import Foundation

extension ReadingVerificationAssertions {
    private static let calendarFields: [String: (system: String, unit: String)] = [
        "liuyao.calendar.month": ("liuyao", "月"),
        "liuyao.calendar.day": ("liuyao", "日"),
        "liuyao.calendar.hour": ("liuyao", "时"),
        "qimen.monthGanZhi": ("qimen", "月"),
        "qimen.dayGanZhi": ("qimen", "日"),
        "qimen.hourGanZhi": ("qimen", "时"),
    ]

    static func unambiguousCalendarFact(_ fact: ReadingVerificationEvidence.Fact, facts: [ReadingVerificationEvidence.Fact]) -> Bool {
        calendarFields[fact.factKey] == nil || facts.filter { $0.factKey == fact.factKey }.allSatisfy { $0.value == fact.value }
    }

    static func calendarAssertion(_ fact: ReadingVerificationEvidence.Fact, sentence: String, draft: String) -> Bool {
        calendarFields[fact.factKey] == nil || calendarStatements(draft).contains(sentence)
    }

    private static func calendarStatements(_ draft: String) -> [String] {
        // The general reviewer protocol strips punctuation. Keep interrogative
        // punctuation until this specialized assertion check has rejected it.
        let regex = try! NSRegularExpression(pattern: "[^。！？\\n]+[。！？]?")
        return regex.matches(in: draft, range: NSRange(draft.startIndex..., in: draft)).compactMap {
            guard let range = Range($0.range, in: draft) else { return nil }
            let raw = String(draft[range])
            guard !has(raw, "[？?]|吗|是否|是不是") else { return nil }
            return raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "。！")))
        }
    }

    /// Only explicit statements about this cast. No inferred dates, natal
    /// pillars, future trigger branches, or unlabeled cross-system comparisons.
    static func calendarClaims(in sentence: String, key: String) -> [String] {
        guard let field = calendarFields[key], !conditional(sentence), !denied(sentence),
              !has(sentence, "八字|紫微|紫薇|梅花|六壬|太乙|塔罗|占星|星盘|本命|出生|流年|流月|大限|大运|上次|上一|前一|之前|此前|去年|昨天|曾经|过去|明年|明天|未来|不对|不正确|不成立|不属实|错|假定|假设|说|声称|认为|提到|表示|指出|记载|书中|原文|用户问|[？?]|吗|是否|是不是") else { return [] }
        let isLiuyao = field.system == "liuyao"
        guard !has(sentence, isLiuyao ? "奇门|起局" : "六爻|起卦") else { return [] }
        let marker = "(?:^|[，,；;])\\s*(?:本次|这次|本盘)?" + (isLiuyao ? "(?:六爻(?:起卦)?|起卦)" : "(?:奇门(?:起局)?|起局)")
        let join = "(?:的)?\\s*(?:为|是|：|:)?\\s*"
        let stemBranch = "[甲乙丙丁戊己庚辛壬癸][子丑寅卯辰巳午未申酉戌亥]"
        let slot = field.unit == "月" ? "(?:月建|月柱|月干支)" : "(?:\(field.unit)柱|\(field.unit)干支)"
        func captures(_ text: String, pattern: String, group: Int = 1) -> [String] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: group), in: text).map { String(text[$0]) }
            }
        }
        let end = "(?=\\s*(?:$|[，,；;]))"
        var values = captures(sentence, pattern: marker + "(?:的)?" + slot + join + "[「『“\"]?(" + stemBranch + ")[」』”\"]?" + end)
        // The sequence has a controlled grammar, so another clause's pillar or
        // proposed timing cannot inherit the cast-time label.
        let termNote = "(?:[（(]按节气月[）)])?"
        let item = stemBranch + "(?:月" + termNote + "|日|时)"
        let separator = "\\s*[、，,]?\\s*"
        let year = "(?:" + stemBranch + "年" + separator + ")?"
        let sequences = captures(sentence, pattern: marker + "(?:的)?(?:时间|时刻|干支)" + join + "(" + year + item + "(?:" + separator + item + "){0,2})" + end)
        for sequence in sequences {
            values += captures(sequence, pattern: "(" + stemBranch + ")" + field.unit)
        }
        return values
    }

    static func calendarIssues(_ draft: String, facts: [ReadingVerificationEvidence.Fact]) -> [String] {
        let grouped = Dictionary(grouping: facts.filter { calendarFields[$0.factKey] != nil }, by: \.factKey)
        var issues: [String] = []
        for key in grouped.keys.sorted() {
            guard let group = grouped[key], let fact = group.first,
                  case let .string(actual) = fact.value,
                  group.allSatisfy({ $0.value == fact.value }) else { continue }
            // Several casts with different values require explicit receipt
            // identity; generic prose cannot choose one as authoritative.
            for sentence in calendarStatements(draft) {
                let claims = calendarClaims(in: sentence, key: key)
                if claims.contains(where: { $0 != actual }) {
                    issues.append("原句：\(sentence)；本次工具\(fact.toolCallID)的\(key)（\(fact.pointer)）实际值为\(actual)。只按这个原始字段纠正对应的起卦/起局干支，不另算历法，不改变已保存的盘面。")
                }
            }
        }
        return issues
    }
}
