import Foundation

extension ReadingVerificationAssertions {
    /// Compare explicit method labels only. The fixed-weight count, seasonal
    /// matrix and pattern strength are deliberately not interchangeable.
    static func baziReceiptLabelIssues(_ draft: String, history: [ChatMessage]) -> [String] {
        let charts = history.enumerated().compactMap { index, message -> [String: JSONValue]? in
            guard message.role == .tool,
                  case let .object(root) = ToolOutputWire.decode(message, history: Array(history.prefix(index))),
                  root["error"] == nil || root["error"] == .null else { return nil }
            if case let .object(bazi) = root["bazi"] { return bazi }
            return root["correspondencePolicy"] == nil ? nil : root
        }
        let countLabels = charts.compactMap { chart -> Bool? in
            guard case let .object(reference) = chart["strengthReference"],
                  case let .bool(strong) = reference["riZhuStrong"] else { return nil }
            return strong
        }
        let policies = charts.compactMap { chart -> String? in
            guard case let .string(policy) = chart["correspondencePolicy"] else { return nil }
            return policy
        }
        var issues: [String] = []
        for raw in declarativeSentences(draft) {
            let sentence = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "").replacingOccurrences(of: "`", with: "")
            guard !conditional(sentence), !denied(sentence), !has(sentence, "[「『“\"]|上次|此前|你说|说法") else { continue }
            if let strong = countLabels.first, countLabels.allSatisfy({ $0 == strong }) {
                let wrong = strong ? "偏弱" : "偏强"
                if has(sentence, "(?:固定权重(?:计数)?|计数(?:结果)?)(?:是|为|列为|属于|按当前规则列为)?\\s*" + wrong) {
                    issues.append("本次/bazi/strengthReference/riZhuStrong为\(strong)，固定权重计数标签应为\(strong ? "偏强" : "偏弱")；不得把月令五态、最旺五行或格局等级当作这个计数结论。保留工程启发式的限制。")
                }
            }
            // Enforce only this explicitly returned policy, not a universal
            // claim about all traditions or the user's actual family roles.
            if !policies.isEmpty, policies.allSatisfy({ $0.contains("男财女官论配偶") }),
               has(sentence, "男命(?:以|用|按)(?:官杀|正官|七杀)论配偶|女命(?:以|用|按)(?:财星|正财|偏财)论配偶") {
                issues.append("本次correspondencePolicy明确采用男财女官论配偶；原句颠倒了所用对应口径。按回执的relevantShiShen说明，不补猜性别，也不将流派对应当作现实家庭角色。")
            }
        }
        return issues
    }

    /// Verify only explicit natal pillar positions against the returned fields.
    /// This neither computes stems nor infers a pattern from a month branch.
    static func natalPillarIssues(_ draft: String, facts: [ReadingVerificationEvidence.Fact]) -> [String] {
        let labels = ["year": "年", "month": "月", "day": "日", "hour": "时"]
        let grouped = Dictionary(grouping: facts.filter { fact in
            labels.keys.contains { fact.factKey == "bazi.\($0).gan" || fact.factKey == "bazi.\($0).zhi" }
        }, by: \.factKey)
        func values(_ text: String, _ pattern: String, group: Int = 1) -> [String] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: group), in: text).map { String(text[$0]) }
            }
        }
        let stems = "[甲乙丙丁戊己庚辛壬癸]", branches = "[子丑寅卯辰巳午未申酉戌亥]"
        let link = "(?:的)?\\s*(?:为|是|：|:|透出|透)?\\s*"
        var issues: [String] = []
        for raw in declarativeSentences(draft) {
            // Presentation markup cannot hide an otherwise explicit field claim.
            let sentence = raw.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "").replacingOccurrences(of: "`", with: "")
            guard !conditional(sentence), !denied(sentence),
                  !has(sentence, "流年|流月|大运|大限|奇门|六爻|上次|此前|之前|原话|声称|你说|说法|[「『“\\\"]") else { continue }
            for (column, label) in labels.sorted(by: { $0.key < $1.key }) {
                for part in ["gan", "zhi"] {
                    let key = "bazi.\(column).\(part)"
                    guard let group = grouped[key], let fact = group.first,
                          case let .string(actual) = fact.value, group.allSatisfy({ $0.value == fact.value }) else { continue }
                    let symbol = part == "gan" ? stems : branches, suffix = part == "gan" ? "干" : "支"
                    var claims = values(sentence, label + "(?:柱)?(?:的)?(?:天|地)?" + suffix + link + "(" + symbol + ")")
                    claims += values(sentence, label + "柱" + link + "(" + stems + ")(" + branches + ")", group: part == "gan" ? 1 : 2)
                    if part == "gan" {
                        claims += values(sentence, "(" + stems + ")(?:木|火|土|金|水)?(?:正印|偏印|正财|偏财|正官|七杀|食神|伤官|比肩|劫财)?(?:透出|透)(?:于|在)" + label + "(?:柱)?(?:天)?干")
                    }
                    if claims.contains(where: { $0 != actual }) {
                        issues.append("原句：\(raw)；本次回执\(fact.toolCallID)的本命\(label)\(suffix)为\(actual)（\(fact.pointer)）。只纠正明确柱位；月支藏干不等于月干，勿混淆透于年干和透于月干，不重新推算格局。")
                    }
                }
            }
        }
        return issues
    }
}
