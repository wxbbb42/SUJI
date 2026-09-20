import Foundation

/// Conservative support for a reviewer's allegation, not a natural-language
/// truth checker. Ambiguous wording requests another review; it cannot authorize
/// a rewrite. In particular, values from adjacent fields are not interchangeable.
enum ReadingVerificationAssertions {
    static func has(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    static func clauses(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "，,；;。！？\n"))
    }

    static func conditional(_ text: String) -> Bool {
        has(text, "假如|假设|如果|若|例如|举例|反例|有人说|你提到|你说|原话|所谓|这句话|这个说法|错误的说法")
    }

    static func denied(_ text: String) -> Bool {
        has(text, "不代表|不意味|不说明|不能|不可|无法|并非|不是|不应|未必|不等于|不能证明|不用于|没有依据|无依据")
    }

    static func sameKind(_ lhs: JSONValue, _ rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.string, .string), (.integer, .integer), (.double, .double), (.bool, .bool): return true
        case let (.array(a), .array(b)):
            // No array/object coercion; an empty array has no element type to infer.
            return a.isEmpty || b.isEmpty || a.allSatisfy { sameKind($0, b[0]) } && b.allSatisfy { sameKind(a[0], $0) }
        default: return false
        }
    }

    static func binds(_ quote: String, to fact: ReadingVerificationEvidence.Fact, in original: String) -> Bool {
        // Quoting a value is different from quoting someone else's assertion.
        var sentence = original
        for (open, close) in [("「", "」"), ("『", "』"), ("“", "”"), ("‘", "’"), ("\"", "\""), ("'", "'")] {
            sentence = sentence.replacingOccurrences(of: open + quote + close, with: quote)
        }
        // Do not discard a negation before the group marker while slicing it.
        // Mixed assertions/denials are ambiguous and are never repair evidence.
        guard !conditional(sentence), !denied(sentence) else { return false }
        let value = NSRegularExpression.escapedPattern(for: quote)
        let link = "(?:的)?\\s*(?:仍为|仍是|为|是|落在|落|在|为：|是：|：|:)?\\s*[「『“\"]?"
        let key = fact.factKey.components(separatedBy: ".")
        func bound(_ clause: String, _ anchor: String) -> Bool {
            !denied(clause) && has(clause, "(?:" + anchor + ")" + link + value)
        }
        let parts = clauses(sentence)
        if key.first == "ziwei", key.count == 3, key[1].hasSuffix("宫") {
            // Require the actual named natal palace, never a generic "主星" or
            // a transit/borrowed/opposite relation that changes the subject.
            guard !has(sentence, "流年|流月|大限|小限|借星|借入") else { return false }
            let field = ["ganZhi": "干支|宫干支", "position": "地支|地支位", "mainStars": "主星", "minorStars": "辅星", "sihua": "生年四化"][key[2]]
            guard let field else { return false }
            return parts.contains { bound($0, NSRegularExpression.escapedPattern(for: key[1]) + "(?:的)?(?:" + field + ")") }
        }
        if key.first == "liuyao", key.count == 3, ["original", "changed"].contains(key[1]) {
            let field = ["upper": "上卦|上", "lower": "下卦|下", "name": "卦名"][key[2]]
            guard let field else { return false }
            let matcher = try! NSRegularExpression(pattern: "(本卦|变卦|之卦)(?:(?!本卦|变卦|之卦).)*")
            for match in matcher.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) {
                guard let range = Range(match.range, in: sentence), let groupRange = Range(match.range(at: 1), in: sentence) else { continue }
                let group = String(sentence[groupRange])
                guard (group == "本卦") == (key[1] == "original") else { continue }
                for part in clauses(String(sentence[range])) {
                    if key[2] == "name", bound(part, group) { return true }
                    if bound(part, field) { return true }
                }
            }
            return false
        }
        if key.first == "bazi", key.count == 3, let column = ["year": "年", "month": "月", "day": "日", "hour": "时"][key[1]] {
            let field = ["gan": "干", "zhi": "支", "tenGod": "干十神|柱十神"][key[2]]
            guard let field else { return false }
            return parts.contains { bound($0, column + "(?:" + field + ")") }
        }
        if key.first == "qimen", key.count == 3, key[1].hasPrefix("palace"), let id = Int(key[1].dropFirst(6)), (1...9).contains(id) {
            let names = ["", "坎", "坤", "震", "巽", "中", "乾", "兑", "艮", "离"]
            let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
            let palace = "(?:" + names[id] + "(?:" + digits[id] + "|" + String(id) + ")?|" + digits[id] + "|" + String(id) + ")宫"
            let fields = ["bashen": "八神", "bamen": "八门|门", "jiuxing": "九星|星", "tianPanGan": "天盘干|天盘", "diPanGan": "地盘干|地盘", "hostedTianPanGan": "寄干"]
            guard let field = fields[key[2]] else { return false }
            return parts.contains { bound($0, palace + "(?:的)?(?:" + field + ")") }
        }
        let anchors = [
            "calendar.year": "年柱|年干支|流年", "calendar.month": "月柱|月干支", "calendar.day": "日柱|日干支", "calendar.term": "节气",
            "liuyao.lineValues": "爻值|六爻数值", "liuyao.changingYao": "动爻", "liuyao.xunKong": "旬空",
            "qimen.zhiShiPalaceId": "值使", "qimen.zhiFuPalaceId": "值符",
            "qimen.zhiFuStar": "值符星|值符", "qimen.zhiShiMen": "值使门|值使", "qimen.juNumber": "局数", "qimen.yuan": "三元|元", "qimen.jieqi": "节气",
        ]
        guard let anchor = anchors[fact.factKey] else { return false }
        return parts.contains { bound($0, anchor) }
    }

    static func healthInference(_ sentence: String) -> Bool {
        guard !has(sentence, "假如|假设|如果|若|例如|举例|反例|有人说|你提到|这句话|这个说法|错误的说法"),
              has(sentence, "擎羊|陀罗|火星|铃星|疾厄宫|五行|水旺|火弱|命盘|星曜") else { return false }
        // A later clause can explicitly deny the preceding proposed mapping.
        // A generic disclaimer about diagnosis does not negate an actual claim.
        if has(sentence, "(超出|没有.{0,12}依据|不支持|不能.{0,8}(对应|映射|推断|判断)|不符合).{0,30}(个人|映射|健康|证据|边界)|没有可用的解释依据|超出了本次计算|不能.{0,8}(判断|推断|对应|映射|下结论)|判断.{0,6}不能.{0,6}下") { return false }
        return clauses(sentence).contains {
            !denied($0) && has($0, "外伤|受伤|磕碰|刀火|急性|器官|体质|疾病|失眠|肝脏|肾脏") && has($0, "提示|意味着|意味|象征|对应|容易|倾向于|会|预示|常被联想|偏向")
        }
    }

    static func supports(rule: String, sentence: String, facts: [ReadingVerificationEvidence.Fact]) -> Bool {
        if rule == "health.no-personal-risk-from-chart" { return healthInference(sentence) }
        guard !conditional(sentence) else { return false }
        let affirmative = clauses(sentence).filter { !denied($0) }
        switch rule {
        case "health.no-personal-risk-from-chart": return healthInference(sentence)
        case "action.no-chart-selected-year":
            return has(sentence, "命盘|盘面|流年|大运|星曜|十神") && affirmative.contains {
                has($0, "(19|20|21)[0-9]{2}|这一年|这几年") && has($0, "更适合|适合|建议|值得关注|准备|发力") && has($0, "升职|投资|搬家|迁居|结婚|买房|发力")
            }
        case "method.no-unproven-validity":
            guard has(sentence, "框架|方法|算法|流派|格局|扶抑|两把尺子"), !has(sentence, "不能说|不应说|不能证明|不等于|不能认为|未验证|有待验证") else { return false }
            if has(sentence, "这不是谁算错了") { return true }
            return affirmative.contains { !has($0, "可能|条件|才能") && has($0, "都正确|都没有错|都没算错|双方正确|各自正确|两者都对|各自成立") }
        case "interpretation.candidate-not-established":
            let candidate = facts.contains { fact in
                ["bazi.pattern.status", "bazi.strength.status"].contains(fact.factKey) && has(ReadingVerificationEvidence.encoded(fact.value), "candidate|heuristic")
            }
            return candidate && !has(sentence, "候选|启发|待定|未定|未成立") && affirmative.contains { has($0, "格局|合化|用神|成格|构成.{0,8}格") && has($0, "已经确定|已经成立|确定成立|必然|确定为|已成格|已经成格|构成.{0,8}格") }
        case "interpretation.personalized-rule-required":
            // Current tool schemas provide chart facts/conditional candidates,
            // not sourced rules establishing the user's real-world personality.
            return affirmative.contains {
                has($0, "你|本人|命主") && has($0, "星|宫|五行|食神|伤官|七杀|正官|正印|偏印") && has($0, "说明|代表|意味着|显示|使你|所以") && has($0, "性格|擅长|适合从事|天生|善于|倾向|能力|职业")
            }
        default: return false
        }
    }

    static func birthAlreadyProvided(_ history: [ChatMessage]) -> Bool {
        has(history.first(where: { $0.role == .system })?.content ?? "", "(^|；)出生资料已提供([。\\n]|$)")
    }

    static func asksForBirthAgain(_ sentence: String) -> Bool {
        !has(sentence, "不必|不用|无需|不需要|已经|已提供") && has(sentence, "(提供|填写|补充).{0,30}出生(日期|时间|资料|信息)|出生资料.{0,10}(补全|补充|填|提供|给我)")
    }

    static func clockIssues(_ draft: String, history: [ChatMessage]) -> [String] {
        let dates = ReadingVerificationEvidence.facts(history).filter { ["qimen.setupTime", "liuyao.castTime"].contains($0.factKey) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let iso = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let matcher = try! NSRegularExpression(pattern: #"([12][0-9]{3}-[0-9]{2}-[0-9]{2})[ T]([0-2][0-9]:[0-5][0-9])(?::[0-5][0-9])?\s*[（(]?UTC\+0?8(?::?00)?[）)]?"#)
        for sentence in ReadingVerificationEvidence.sentences(draft) where !conditional(sentence) && !denied(sentence) {
            // A sentence comparing civil and apparent-solar clocks needs both
            // labels bound separately; never compare its solar value to setupTime.
            guard has(sentence, "起局|起卦|起盘"), !has(sentence, "真太阳时") else { continue }
            for fact in dates {
                guard (fact.factKey.hasPrefix("qimen") ? has(sentence, "奇门|起局") : has(sentence, "六爻|起卦")),
                      case let .string(raw) = fact.value, let date = fractional.date(from: raw) ?? iso.date(from: raw) else { continue }
                let expected = formatter.string(from: date)
                for match in matcher.matches(in: sentence, range: NSRange(sentence.startIndex..., in: sentence)) {
                    guard let day = Range(match.range(at: 1), in: sentence), let time = Range(match.range(at: 2), in: sentence) else { continue }
                    if String(sentence[day]) + " " + String(sentence[time]) != expected {
                        return ["原句起盘时刻的UTC+08:00标签与本次工具不一致。本次\(fact.factKey)为\(raw)，换算UTC+08:00是\(expected)。不要把Z后缀的UTC钟点直接标为北京时间。"]
                    }
                }
            }
        }
        return []
    }
}
