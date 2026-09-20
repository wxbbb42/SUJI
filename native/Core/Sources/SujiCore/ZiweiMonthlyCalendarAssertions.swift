import Foundation

/// A bounded assertion check for a dated two-month comparison. It reads the
/// original calendar; it never recomputes dates or changes transformation layers.
enum ZiweiMonthlyCalendarAssertions {
    private struct Month: Equatable {
        let date: String
        let year: Int
        let month: Int
        let day: Int
        let leap: Bool
        let effective: Int
    }
    private struct Record {
        let id: String
        let month: Month
    }
    private static let sourceID = "ziwei-monthly-selected-v1"
    private static let sourceReferences = [
        "https://unpkg.com/iztro@2.5.8/lib/astro/FunctionalAstrolabe.js": "843f55ba39e20107bb00e83f26116ceb3281d88f092081e1d4bb1a9e0e5ab5fc",
        "https://unpkg.com/lunar-lite@0.2.8/lib/ganzhi.js": "5b7ec19b55f1d703bce40694a7dfb172ddbf3358cef2682f7c048c65b01cba2d"
    ]

    private static func record(_ output: String, call: ChatToolCall, history: [ChatMessage], outputIndex: Int, allowSharedSource: Bool = true) -> Record? {
        guard call.name == "get_ziwei_timing", ReadingVerificationEvidence.pointer("/withMonthly", in: call.arguments) == .bool(true),
              case let .string(date) = ReadingVerificationEvidence.pointer("/date", in: call.arguments), validDate(date),
              let root = try? JSONDecoder().decode(JSONValue.self, from: Data(output.utf8)),
              case let .object(object) = root, object["error"] == nil else { return nil }
        func value(_ path: String) -> JSONValue? { ReadingVerificationEvidence.pointer(path, in: root) }
        func number(_ field: String) -> Int? {
            guard case let .integer(n) = value("/monthly/calendar/" + field) else { return nil }
            return Int(exactly: n)
        }
        guard value("/calculationDate") == .string(date), value("/civilDate") == .string(date),
              value("/referenceMode") == .string("explicit-date-noon"),
              [JSONValue.string(date + "T04:00:00.000Z"), .string(date + "T04:00:00Z")].contains(value("/referenceDate") ?? .null),
              value("/method/algorithm") == .string("suji-ziwei-timing-1"),
              value("/method/civilTimeZone") == .string("UTC+08:00"),
              value("/method/dayBoundary") == .string("zi-hour"),
              value("/method/yearBoundary") == .string("lunar-new-year"),
              value("/monthly/status") == .string("available"),
              value("/monthly/appliesToBirth") == .bool(true),
              value("/monthly/scope") == .string("lunar-month"),
              value("/monthly/sourceId") == .string(sourceID),
              value("/monthly/method/algorithm") == .string("suji-ziwei-monthly-1"),
              value("/monthly/method/monthBoundary") == .string("lunar-month"),
              value("/monthly/method/leapMonth") == .string("split-at-day-15"),
              value("/monthly/method/stemMethod") == .string("lunar-year-five-tiger"),
              value("/monthly/method/palaceMethod") == .string("dou-jun"),
              let year = number("lunarYear"), (1900...2101).contains(year),
              let month = number("month"), (1...12).contains(month),
              let day = number("day"), (1...30).contains(day),
              case let .bool(leap) = value("/monthly/calendar/isLeapMonth"),
              let effective = number("effectiveMonth"), effective == month + (leap && day > 15 ? 1 : 0),
              case let .array(sources) = value("/ruleSources") else { return nil }
        let matching = sources.indices.filter { ReadingVerificationEvidence.pointer("/id", in: sources[$0]) == .string(sourceID) }
        guard matching.count == 1, let index = matching.first else { return nil }
        let source = sources[index]
        guard
              ReadingVerificationEvidence.pointer("/version", in: source) == .string("1"),
              let references = references(at: "/ruleSources/\(index)/references", root: root, history: history, before: outputIndex, allowShared: allowSharedSource) else { return nil }
        for (url, hash) in sourceReferences {
            let selected = references.filter { ReadingVerificationEvidence.pointer("/url", in: $0) == .string(url) }
            guard selected.count == 1,
                  ReadingVerificationEvidence.pointer("/sha256", in: selected[0]) == .string(hash) else { return nil }
        }
        return Record(id: call.id, month: Month(date: date, year: year, month: month, day: day, leap: leap, effective: effective))
    }

    /// Transport can share a large source bibliography with an earlier receipt.
    /// Follow one concrete, same-index/source/version link; never a chain, a
    /// forward link, or an unrelated receipt merely containing the same text.
    private static func references(at path: String, root: JSONValue, history: [ChatMessage], before: Int, allowShared: Bool) -> [JSONValue]? {
        let links: [JSONValue]
        if case let .array(items) = ReadingVerificationEvidence.pointer("/reusedFacts", in: root) {
            links = items.filter { ReadingVerificationEvidence.pointer("/path", in: $0) == .string(path) }
        } else { links = [] }
        if let inline = ReadingVerificationEvidence.pointer(path, in: root) {
            guard case let .array(items) = inline, links.isEmpty else { return nil }
            return items
        }
        guard allowShared, links.count == 1,
              case let .string(id) = ReadingVerificationEvidence.pointer("/toolCallID", in: links[0]),
              case let .string(pointer) = ReadingVerificationEvidence.pointer("/pointer", in: links[0]),
              pointer == path else { return nil }
        let calls = history.enumerated().flatMap { index, message in
            (message.role == .assistant ? (message.toolCalls ?? []) : []).filter { $0.id == id }.map { (index, $0) }
        }
        let outputs = history.indices.filter { history[$0].role == .tool && history[$0].toolCallID == id }
        guard calls.count == 1, calls[0].1.name == "get_ziwei_timing",
              outputs.count == 1, let outputIndex = outputs.first,
              calls[0].0 < outputIndex, outputIndex < before, let output = history[outputIndex].content,
              let sourceRoot = try? JSONDecoder().decode(JSONValue.self, from: Data(output.utf8)),
              case let .object(sourceObject) = sourceRoot, sourceObject["error"] == nil else { return nil }
        let parent = String(pointer.dropLast("/references".count))
        guard ReadingVerificationEvidence.pointer(parent + "/id", in: sourceRoot) == .string(sourceID),
              ReadingVerificationEvidence.pointer(parent + "/version", in: sourceRoot) == .string("1"),
              case let .array(items) = ReadingVerificationEvidence.pointer(pointer, in: sourceRoot),
              record(output, call: calls[0].1, history: [], outputIndex: 0, allowSharedSource: false) != nil else { return nil }
        return items
    }

    private static func validDate(_ iso: String) -> Bool {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, iso.count == 10, (1901...2100).contains(parts[0]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components) else { return false }
        let actual = calendar.dateComponents([.year, .month, .day], from: date)
        return actual == components
    }

    private static func captures(_ text: String, _ pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (1..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }
    /// Year inheritance only serves an explicit pair such as 2025年8月8日与8月9日.
    /// Every other numeric date must belong to that pair before a later summary
    /// can inherit it. A third date, another year or an unbound date disables it.
    private static func dates(_ text: String, year: Int?) -> [String]? {
        let matches = captures(text, "(?:(?<=[^0-9])|^)(?:([0-9]{4})年)?([0-9]{1,2})月([0-9]{1,2})日|([0-9]{4})-([0-9]{2})-([0-9]{2})")
        var inherited = year
        var result: [String] = []
        for groups in matches {
            let isoStyle = !groups[3].isEmpty
            let y = Int(groups[isoStyle ? 3 : 0]) ?? inherited
            guard let y, let m = Int(groups[isoStyle ? 4 : 1]), let d = Int(groups[isoStyle ? 5 : 2]) else { return nil }
            let iso = String(format: "%04d-%02d-%02d", y, m, d)
            guard validDate(iso) else { return nil }
            inherited = y
            result.append(iso)
        }
        return result
    }
    private static func affirmative(_ text: String, checkQuotes: Bool = true) -> Bool {
        !ReadingVerificationAssertions.conditional(text) && !ReadingVerificationAssertions.denied(text)
            && !ReadingVerificationAssertions.has(text, "[？?]|吗|是否|是不是|假定|声称|认为|提到|表示|指出|记载|书中|原文|说|错|不成立|不属实|不对|不正确|未确定|尚未|没有|并未|未曾|旧盘|上次|去年|明年|上个月|下个月|上月|下月|另一|其他日期|指(?:的是)?(?:排盘|计算)")
            && (!checkQuotes || !ReadingVerificationAssertions.has(text, "[「」『』“”‘’\"`]|'"))
    }
    private static func monthNumber(_ text: String) -> Int? {
        if let n = Int(text), (1...12).contains(n) { return n }
        return ["正": 1, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9, "十": 10, "十一": 11, "十二": 12, "冬": 11, "腊": 12][text]
    }

    static func issues(_ draft: String, history: [ChatMessage]) -> [String] {
        let paragraphs = draft.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !ReadingVerificationAssertions.has(draft, "[0-9]{1,2}月[0-9]{1,2}号|[0-9]/[0-9]|(?:农历|阴历|陰曆|農曆)[^。\\n]{0,12}(?:(?:[0-9]{4}年)?[0-9]{1,2}月[0-9]{1,2}日|[0-9]{4}-[0-9]{2}-[0-9]{2})"),
              let first = paragraphs.first, first.contains("紫微流月"), affirmative(first),
              let pair = dates(first, year: nil), pair.count == 2, pair[0] != pair[1],
              let inherited = Int(pair[0].prefix(4)),
              let allDates = dates(draft, year: inherited), Set(allDates) == Set(pair) else { return [] }

        let calls = history.flatMap { $0.role == .assistant ? ($0.toolCalls ?? []) : [] }
        let grouped = Dictionary(grouping: calls, by: \.id)
        var selected: [Record] = []
        for date in pair {
            let relevant = calls.filter { $0.name == "get_ziwei_timing" && ReadingVerificationEvidence.pointer("/date", in: $0.arguments) == .string(date) }
            guard !relevant.isEmpty else { return [] }
            var records: [Record] = []
            for call in relevant {
                let outputs = history.indices.filter { history[$0].role == .tool && history[$0].toolCallID == call.id }
                guard grouped[call.id]?.count == 1, outputs.count == 1,
                      let index = outputs.first, let output = history[index].content,
                      let callIndex = history.firstIndex(where: { $0.role == .assistant && ($0.toolCalls ?? []).contains(where: { $0.id == call.id }) }), callIndex < index,
                      let parsed = record(output, call: call, history: history, outputIndex: index) else { return [] }
                records.append(parsed)
            }
            guard let first = records.first, records.allSatisfy({ $0.month == first.month }) else { return [] }
            selected.append(first)
        }
        let a = selected[0], b = selected[1]
        // The observed defect is an effective-month split inside one real
        // lunar month. Actual month/year/leap transitions are outside this rule.
        guard a.month.year == b.month.year, a.month.month == b.month.month,
              a.month.leap == b.month.leap, a.month.effective != b.month.effective else { return [] }

        let digit = "([0-9一二三四五六七八九十正冬腊]{1,2})"
        let pattern = "(?:^|[：:，,；;])\\s*(?:两天的?|实际的?)?农历(?:月序号|月份?)(?:从|由)" + digit + "月(?:进到|进入|变为|变成|变到|转为|到)" + digit + "月(?=$|[，,；;])"
        var result: [String] = []
        for paragraph in paragraphs {
            // Preserve quoted/reported/hypothetical framing before splitting a
            // paragraph into sentences; a colon or newline cannot erase it.
            guard affirmative(paragraph, checkQuotes: false) else { continue }
            for sentence in ReadingVerificationAssertions.declarativeSentences(paragraph) {
                guard affirmative(sentence), let range = paragraph.range(of: sentence),
                      !ReadingVerificationAssertions.has(String(paragraph[..<range.lowerBound]), "[「」『』“”‘’\"`]|'") else { continue }
                for values in captures(sentence, pattern) {
                    guard let from = monthNumber(values[0]), let to = monthNumber(values[1]),
                          from == a.month.effective, to == b.month.effective else { continue }
                    func evidence(_ record: Record) -> String {
                        let m = record.month
                        return "\(m.date)工具\(record.id)：/monthly/calendar/lunarYear=\(m.year)，/monthly/calendar/month=\(m.month)，/monthly/calendar/day=\(m.day)，/monthly/calendar/isLeapMonth=\(m.leap)，/monthly/calendar/effectiveMonth=\(m.effective)"
                    }
                    result.append("原句：\(sentence)；\(evidence(a))；\(evidence(b))。两天实际农历均为\(a.month.leap ? "闰" : "")\(a.month.month)月；所选ziwei-monthly-selected-v1的十五日分界只使排盘月序从\(from)变为\(to)，不表示真实农历换月。只纠正这两个日期的月份比较，用中文说明实际农历与排盘月序，不展示内部字段；保留原有各日期的斗君、流月命宫、月干四化及其他时间层。")
                }
            }
        }
        return Array(Set(result)).sorted()
    }
}
