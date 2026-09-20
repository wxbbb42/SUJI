import Foundation

/// Literal assertion checking against returned natal/temporal objects. This
/// does not infer transformations or interpret their real-world effects.
enum ZiweiReadingAssertions {
    typealias Fact = ReadingVerificationEvidence.Fact
    private static let palaces = "命宫|兄弟宫|夫妻宫|子女宫|财帛宫|疾厄宫|迁移宫|仆役宫|官禄宫|田宅宫|福德宫|父母宫"
    private struct Transformation {
        let scope: String
        let star: String
        let value: Fact
        let palace: Fact
        var identity: String { scope + ":" + star }
    }
    private struct Brightness {
        let palace: String
        let star: String
        let value: Fact
        var identity: String { palace + ":" + star }
    }
    private static func string(_ fact: Fact?) -> String? {
        guard case let .string(value) = fact?.value else { return nil }
        return value
    }
    private static func sibling(_ fact: Fact, _ field: String, _ facts: [Fact]) -> Fact? {
        let prefix = fact.factKey.split(separator: ".").dropLast().joined(separator: ".") + "."
        let path = fact.pointer.split(separator: "/").dropLast().joined(separator: "/")
        return facts.first { $0.toolCallID == fact.toolCallID && $0.factKey == prefix + field && $0.pointer == "/" + path + "/" + field }
    }
    private static func transformations(_ facts: [Fact]) -> [Transformation] {
        facts.compactMap { fact in
            guard fact.factKey.hasPrefix("ziwei."), fact.factKey.hasSuffix(".transformation"),
                  let value = string(fact), ["化禄","化权","化科","化忌"].contains(value),
                  let scope = string(sibling(fact,"scope",facts)),
                  ["natal-year-stem","annual-year-stem","decadal-palace-stem"].contains(scope),
                  let star = string(sibling(fact,"star",facts)), !star.isEmpty,
                  let palace = sibling(fact,"targetPalace",facts), let palaceName = string(palace),
                  palaces.components(separatedBy:"|").contains(palaceName),
                  let source = string(sibling(fact,"sourceId",facts)),
                  source == (scope == "natal-year-stem" ? "ziwei-sihua-selected-v1" : "ziwei-timing-selected-v1") else { return nil }
            return Transformation(scope:scope,star:star,value:fact,palace:palace)
        }
    }
    private static func brightness(_ facts: [Fact]) -> [Brightness] {
        facts.compactMap { fact in
            let key = fact.factKey.components(separatedBy:".")
            guard key.count == 4, key[0] == "ziwei", key[2].hasPrefix("star"), key[3] == "brightness",
                  palaces.components(separatedBy:"|").contains(key[1]), string(fact) != nil,
                  let star = string(sibling(fact,"name",facts)), !star.isEmpty else { return nil }
            return Brightness(palace:key[1],star:star,value:fact)
        }
    }
    private static func eligible(_ text: String) -> Bool {
        !ReadingVerificationAssertions.conditional(text) && !ReadingVerificationAssertions.denied(text)
            && !excludedContext(text)
    }
    private static func excludedContext(_ text: String) -> Bool {
        ReadingVerificationAssertions.has(text,"[？?]|吗|是否|是不是|[0-9]{4}年|假定|说|记载|书中|原文|认为|声称|提到|表示|指出|错|不成立|未成立|未确定|不属实|上次|上一|前一|去年|昨天|明年|明天|曾经|过去|之前|此前|未来|旧盘|借入|借星")
    }
    private static func clauses(_ sentence: String) -> [String] {
        guard eligible(sentence) else { return [] }
        return ReadingVerificationAssertions.clauses(sentence).map { $0.trimmingCharacters(in:.whitespacesAndNewlines) }
    }
    private static func captures(_ text: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern:pattern),
              let match = regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)) else { return nil }
        return (1..<match.numberOfRanges).map { Range(match.range(at:$0),in:text).map { String(text[$0]) } ?? "" }
    }
    private static func claim(_ clause: String, _ record: Transformation) -> (value: String, palace: String)? {
        let scope = ["natal-year-stem":"(?:生年|本命)","annual-year-stem":"流年","decadal-palace-stem":"大限"][record.scope]!
        let star = NSRegularExpression.escapedPattern(for:record.star)
        let ownPalace = NSRegularExpression.escapedPattern(for:string(record.palace)!)
        let prefix = "^(?:紫微(?:斗数)?)?" + scope + "(?:的)?(?:" + ownPalace + "(?:的)?)?"
        guard let values = captures(clause,prefix + star + "(?:星)?(化[禄权科忌])(?:落(?:在)?(" + palaces + "))?$"), values.count == 2 else { return nil }
        return (values[0],values[1])
    }
    private static func claim(_ clause: String, _ record: Brightness) -> String? {
        let object = NSRegularExpression.escapedPattern(for:record.palace) + "(?:的)?" + NSRegularExpression.escapedPattern(for:record.star)
        return captures(clause,"^(?:紫微(?:斗数)?)?本命" + object + "(?:星)?(?:亮度|庙旺)(?:为|是)?(庙|旺|得|利|平|不|陷)$")?.first
    }
    private static func unique(_ records: [Transformation]) -> [Transformation] {
        Dictionary(grouping:records,by: \.identity).values.compactMap { group in
            guard let first = group.first, group.allSatisfy({ $0.value.value == first.value.value && $0.palace.value == first.palace.value }) else { return nil }
            return first
        }
    }
    private static func unique(_ records: [Brightness]) -> [Brightness] {
        Dictionary(grouping:records,by: \.identity).values.compactMap { group in
            guard let first = group.first, group.allSatisfy({ $0.value.value == first.value.value }) else { return nil }
            return first
        }
    }
    static func binds(_ quote: String, to fact: Fact, in sentence: String, facts: [Fact]) -> Bool {
        let transformations = transformations(facts), stars = brightness(facts)
        let consistentTransformations = Set(unique(transformations).map(\.identity))
        for record in transformations where consistentTransformations.contains(record.identity) {
            for clause in clauses(sentence) {
                guard let assertion = claim(clause,record) else { continue }
                if fact.toolCallID == record.value.toolCallID && fact.pointer == record.value.pointer && assertion.value == quote { return true }
                if fact.toolCallID == record.palace.toolCallID && fact.pointer == record.palace.pointer && assertion.palace == quote { return true }
            }
        }
        let consistentStars = Set(unique(stars).map(\.identity))
        return stars.contains { record in
            consistentStars.contains(record.identity) && fact.toolCallID == record.value.toolCallID && fact.pointer == record.value.pointer && clauses(sentence).contains { claim($0,record) == quote }
        }
    }
    static func issues(_ draft: String, facts: [Fact]) -> [String] {
        var issues = comparisonIssues(draft,facts:facts) + datedYearIssues(draft,facts:facts)
        func correction(_ fact: Fact, _ clause: String) -> String {
            "原句：\(clause)；本次工具\(fact.toolCallID)字段\(fact.factKey)（\(fact.pointer)）实际值为\(ReadingVerificationEvidence.encoded(fact.value))。只纠正该对象和时间层，不改动其他层，也不据此推断现实吉凶。"
        }
        let transformations = unique(transformations(facts)), stars = unique(brightness(facts))
        for sentence in ReadingVerificationAssertions.declarativeSentences(draft) {
            for clause in clauses(sentence) {
                for record in transformations {
                    guard let assertion = claim(clause,record) else { continue }
                    if assertion.value != string(record.value) { issues.append(correction(record.value,clause)) }
                    if !assertion.palace.isEmpty && assertion.palace != string(record.palace) { issues.append(correction(record.palace,clause)) }
                }
                for record in stars {
                    if let value = claim(clause,record), value != string(record.value) { issues.append(correction(record.value,clause)) }
                }
            }
            guard eligible(sentence), let names = captures(sentence,"^(?:本命)?(" + palaces + ")(?:是|为)?空宫[，,]?(?:所以|因此)?没有任何星曜$"), let name = names.first else { continue }
            let major = facts.filter { $0.factKey == "ziwei." + name + ".mainStars" }
            let minor = facts.filter { $0.factKey == "ziwei." + name + ".minorStars" }
            guard !major.isEmpty, major.allSatisfy({ $0.value == .array([]) }), let actual = minor.first,
                  case let .array(values) = actual.value, !values.isEmpty, minor.allSatisfy({ $0.value == actual.value }) else { continue }
            issues.append(correction(actual,sentence) + "空宫在这里指无主星，不能删除已经返回的辅星。")
        }
        return Array(Set(issues)).sorted()
    }

    /// A comparison needs all three explicitly named layers and their own
    /// source stems. Agreement of transformation labels is not source identity.
    private static func comparisonIssues(_ draft: String, facts: [Fact]) -> [String] {
        let groups = Dictionary(grouping:transformations(facts),by: \.star)
        var result: [String] = []
        let parts = ReadingVerificationAssertions.declarativeSentences(draft).flatMap { raw -> [String] in
            let text = raw.replacingOccurrences(of:"^先说结论[：:]",with:"",options:.regularExpression)
            guard !excludedContext(text), !ReadingVerificationAssertions.conditional(text) else { return [] }
            return text.components(separatedBy:CharacterSet(charactersIn:"；;"))
        }
        for sentence in parts {
            guard eligible(sentence) else { continue }
            for (star,records) in groups {
                let pattern = "^" + NSRegularExpression.escapedPattern(for:star) + "在生年、大限、流年三层都有四化，但来源干(?:和落宫)?一致(?:[、，,].*)?$"
                guard ReadingVerificationAssertions.has(sentence,pattern) else { continue }
                let scoped = Dictionary(grouping:records,by: \.scope)
                let stems = ["natal-year-stem","decadal-palace-stem","annual-year-stem"].compactMap { scope -> Fact? in
                    guard let group = scoped[scope] else { return nil }
                    let sources = group.compactMap { sibling($0.value,"sourceStem",facts) }
                    guard sources.count == group.count, let first = sources.first,
                          let value = string(first), "甲乙丙丁戊己庚辛壬癸".contains(value), value.count == 1,
                          sources.allSatisfy({ $0.value == first.value }) else { return nil }
                    return first
                }
                guard stems.count == 3, Set(stems.compactMap(string)).count > 1 else { continue }
                let evidence = stems.map { "\($0.toolCallID):\($0.factKey)（\($0.pointer)）=\(ReadingVerificationEvidence.encoded($0.value))" }.joined(separator:"；")
                result.append("原句：\(sentence)；\(star)三层四化来源干并不一致：\(evidence)。只纠正来源干比较，保留各层四化和落宫。")
            }
        }
        return result
    }

    /// Known denial of the returned lunar year. Require one explicit date in
    /// the same paragraph and an internally consistent, dated timing receipt.
    /// Do not weaken eligible()'s exclusion of old/other-year transformations.
    private static func datedYearIssues(_ draft: String, facts: [Fact]) -> [String] {
        var result: [String] = []
        let datePattern = "([0-9]{4})年([0-9]{1,2})月([0-9]{1,2})日"
        let regex = try! NSRegularExpression(pattern:datePattern)
        for paragraph in draft.components(separatedBy:"\n") {
            guard !ReadingVerificationAssertions.conditional(paragraph), !ReadingVerificationAssertions.denied(paragraph),
                  !ReadingVerificationAssertions.has(paragraph,"[？?]|吗|是否|是不是|说|记载|书中|原文|认为|声称|提到|表示|指出|假定|不成立|未成立|未确定|不属实|错") else { continue }
            let matches = regex.matches(in:paragraph,range:NSRange(paragraph.startIndex...,in:paragraph))
            guard matches.count == 1, let date = captures(paragraph,datePattern), date.count == 3,
                  let year = Int(date[0]), let month = Int(date[1]), let day = Int(date[2]) else { continue }
            let iso = String(format:"%04d-%02d-%02d",year,month,day)
            let dates = facts.filter { $0.factKey == "ziwei.timing.calculationDate" && $0.value == .string(iso) }
            guard !dates.isEmpty else { continue }
            let records = dates.compactMap { date -> Fact? in
                guard let boundary = facts.first(where: { $0.toolCallID == date.toolCallID && $0.factKey == "ziwei.timing.method.yearBoundary" }), boundary.value == .string("lunar-new-year") else { return nil }
                return facts.first { $0.toolCallID == date.toolCallID && $0.factKey == "ziwei.timing.annual.ganZhi" }
            }
            guard records.count == dates.count, let actual = records.first, let ganZhi = string(actual),
                  records.allSatisfy({ $0.value == actual.value }) else { continue }
            let pattern = "(?:^|[。])\\s*流年方面[，,]该日农历仍属" + NSRegularExpression.escapedPattern(for:ganZhi) + "年之前(?=[，,。]|$)"
            guard ReadingVerificationAssertions.has(paragraph,pattern) else { continue }
            result.append("本段明确日期为\(iso)，工具\(actual.toolCallID)字段\(actual.factKey)（\(actual.pointer)）已经返回\(ganZhi)，换年规则为lunar-new-year。不能同时说该日农历仍属\(ganZhi)年之前；只按同份紫微运限回执纠正，不另算历法。")
        }
        return result
    }
}
