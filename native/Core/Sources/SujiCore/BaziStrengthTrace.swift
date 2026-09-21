import Foundation

/// Audits the recorded engineering calculation, then supplies plain-language
/// presentation. These numbers are not measurements of traditional strength.
public struct BaziStrengthTrace: Sendable {
    public struct Row: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String
    }
    public struct Group: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let rows: [Row]
    }
    public let summary: String
    public let groups: [Group]
    public let footnote: String
    public let supportTotal: Double
    public let drainTotal: Double

    private struct Contribution: Codable, Equatable {
        let pillar: String, source: String, gan: String, zhi: String, element: String
        let weight: Double
        let relation: String
        let isDayMaster: Bool
    }
    private struct Count: Decodable {
        let version: String, basis: String, dayMaster: String, dayElement: String, monthBranch: String
        let contributions: [Contribution]
        let elementTotals: [String: Double], relationTotals: [String: Double]
        let supportTotal: Double, drainTotal: Double, total: Double, dayMasterContribution: Double, supportExcludingDayMaster: Double
        let threshold: String, monthWeightApplied: Bool
        let strongestElements: [String], weakestElements: [String], tieBreakOrder: [String]
    }

    public static func from(evidence: [BaziFrameworkReading.FieldEvidence]) -> Self? {
        let inputPaths = ["/bazi/pillars", "/bazi/strengthReference", "/bazi/structureReference"]
        guard Set(evidence.filter { inputPaths.contains($0.pointer) }.map(\.toolCallID)).count == 1 else { return nil }
        func field(_ path: String) -> JSONValue? {
            let matches = evidence.filter { $0.pointer == path }
            guard let first = matches.first, matches.allSatisfy({ $0.value == first.value && $0.toolCallID == first.toolCallID }) else { return nil }
            return first.value
        }
        guard let pillars = field("/bazi/pillars"), let strength = field("/bazi/strengthReference") else { return nil }
        return make(pillars: pillars, strength: strength, structure: field("/bazi/structureReference"))
    }

    public static func make(pillars: JSONValue, strength: JSONValue, structure: JSONValue? = nil) -> Self? {
        guard let raw = value("/evidence", strength), let count: Count = decode(raw),
              count.version == "weighted-count-v1", count.basis == "engineering-heuristic",
              let dayStem = string("/day/ganZhi/gan", pillars), let day = element(dayStem),
              count.dayMaster == dayStem, count.dayElement == day.rawValue,
              count.monthBranch == string("/month/ganZhi/zhi", pillars),
              count.threshold == "supportTotal >= drainTotal", !count.monthWeightApplied,
              string("/suggestionBasis", strength) == "fuyi-heuristic",
              string("/suggestionStatus", strength) == "not-empirically-validated",
              value("/tiaohouApplied", strength) == .bool(false) else { return nil }

        let columns = ["year", "month", "day", "hour"]
        let labels = ["年", "月", "日", "时"]
        let order = ["金", "木", "水", "火", "土"]
        let relations = ["peer", "resource", "output", "wealth", "officer"]
        var expected: [Contribution] = [], hidden: [Contribution] = []
        var pillarRows: [Row] = []
        for (index, column) in columns.enumerated() {
            guard let stem = string("/\(column)/ganZhi/gan", pillars), let stemElement = element(stem),
                  string("/\(column)/ganZhi/ganWuXing", pillars) == stemElement.rawValue,
                  let branch = string("/\(column)/ganZhi/zhi", pillars), branches.contains(branch),
                  case let .array(items) = value("/\(column)/cangGan", pillars), (1...3).contains(items.count) else { return nil }
            expected.append(.init(pillar: column, source: "stem", gan: stem, zhi: branch, element: stemElement.rawValue, weight: 1, relation: relation(stemElement, to: day), isDayMaster: column == "day"))
            var branchUnits = 0, terms: [String] = []
            for item in items {
                guard let gan = string("/gan", item), let wx = element(gan), string("/wuXing", item) == wx.rawValue,
                      let weight = number("/weight", item), let units = tenths(weight), (1...10).contains(units) else { return nil }
                branchUnits += units
                hidden.append(.init(pillar: column, source: "hidden-stem", gan: gan, zhi: branch, element: wx.rawValue, weight: weight, relation: relation(wx, to: day), isDayMaster: false))
                terms.append("\(gan)\(wx.rawValue) \(format(weight))")
            }
            guard branchUnits == 10 else { return nil }
            pillarRows.append(Row(id: column, title: labels[index] + "柱 " + stem + branch,
                                  detail: "天干\(stem)\(stemElement.rawValue)计 1；\(branch)藏\(terms.joined(separator: "、"))。"))
        }
        expected += hidden
        guard count.contributions == expected, count.tieBreakOrder == order else { return nil }
        var elements = Dictionary(uniqueKeysWithValues: order.map { ($0, 0) })
        var relationUnits = Dictionary(uniqueKeysWithValues: relations.map { ($0, 0) })
        for item in expected {
            guard let units = tenths(item.weight) else { return nil }
            elements[item.element, default: 0] += units
            relationUnits[item.relation, default: 0] += units
        }
        let support = relationUnits["peer"]! + relationUnits["resource"]!
        let drain = relationUnits["output"]! + relationUnits["wealth"]! + relationUnits["officer"]!
        let strong = support >= drain
        guard Set(count.elementTotals.keys) == Set(order), Set(count.relationTotals.keys) == Set(relations),
              elements.allSatisfy({ tenths(count.elementTotals[$0.key]!) == $0.value }),
              relationUnits.allSatisfy({ tenths(count.relationTotals[$0.key]!) == $0.value }),
              tenths(count.supportTotal) == support, tenths(count.drainTotal) == drain,
              tenths(count.total) == 80, support + drain == 80,
              tenths(count.dayMasterContribution) == 10, tenths(count.supportExcludingDayMaster) == support - 10,
              value("/riZhuStrong", strength) == .bool(strong),
              let yong = string("/yongShen", strength).flatMap(BaziFrameworkReading.Element.init(rawValue:)),
              (strong ? yong.controls : yong.generates) == day else { return nil }
        let most = order.filter { elements[$0] == elements.values.max() }
        let least = order.filter { elements[$0] == elements.values.min() }
        guard count.strongestElements == most, count.weakestElements == least,
              string("/strongest", strength) == most.first, string("/weakest", strength) == least.first else { return nil }

        let names = ["peer": "同我（比劫）", "resource": "生我（印）", "output": "我生（泄）", "wealth": "我克（耗）", "officer": "克我（制约）"]
        var groups = [Group(id: "count", title: "工程计数明细", rows: pillarRows),
                      Group(id: "totals", title: "分组与边界", rows: relations.map { key in
                          Row(id: key, title: names[key]!, detail: format(Double(relationUnits[key]!) / 10))
                      } + [Row(id: "day-master", title: "日主本人计入一次", detail: "日干\(dayStem)计 1；其余帮扶合计 \(format(count.supportExcludingDayMaster))。不含日干的数字仅供核对，没有用于本次强弱判定。"),
                           Row(id: "threshold", title: "相等时也列为偏强", detail: "规则为帮扶 ≥ 克泄耗；本次 \(format(count.supportTotal)) \(strong ? "≥" : "<") \(format(count.drainTotal))。"),
                           Row(id: "month", title: "月令未额外加权", detail: "月干和月支按上面相同的计数规则加入；此结果不能解释成“因为得令所以身强”。")])]
        if let structure, value("/evidence", structure) != nil {
            guard let structural = structureGroup(structure, pillars: pillars, day: day) else { return nil }
            groups.append(structural)
        }
        let boundary = support == drain ? "两侧相等，按当前“≥”规则列为偏强。" : "按当前规则列为\(strong ? "偏强" : "偏弱")。"
        return Self(summary: "当前工程启发式的固定权重计数：帮扶 \(format(count.supportTotal))，克泄耗 \(format(count.drainTotal))。" + boundary,
                    groups: groups,
                    footnote: "这些数字是工程权重，不是实测力量。计数包含日干本人一次，未综合月令旺衰、根气、合化与调候，不能替代完整传统强弱辨析。",
                    supportTotal: count.supportTotal, drainTotal: count.drainTotal)
    }

    private static func structureGroup(_ structure: JSONValue, pillars: JSONValue, day: BaziFrameworkReading.Element) -> Group? {
        guard let trace = value("/evidence", structure), string("/version", trace) == "month-root-matrix-v1",
              string("/basis", trace) == "engineering-heuristic", string("/monthMethod", trace) == "month-branch-main-qi",
              string("/monthBranch", trace) == string("/month/ganZhi/zhi", pillars),
              let main = string("/monthMainQi", trace), let wx = element(main),
              main == string("/month/cangGan/0/gan", pillars), string("/monthMainElement", trace) == wx.rawValue,
              string("/monthRelation", trace) == relation(wx, to: day),
              value("/exposedStemsUsedForStrength", trace) == .bool(false),
              case let .array(same) = value("/sameElementRoots", trace),
              case let .array(resource) = value("/resourceSupport", trace) else { return nil }
        let columns = ["year", "month", "day", "hour"], labels = ["年", "月", "日", "时"]
        var expectedSame: [JSONValue] = [], expectedResource: [JSONValue] = []
        for (index, column) in columns.enumerated() {
            guard let branch = string("/\(column)/ganZhi/zhi", pillars), case let .array(hidden) = value("/\(column)/cangGan", pillars) else { return nil }
            for (rank, item) in hidden.enumerated() {
                guard let stem = string("/gan", item), let element = element(stem), rank < 3 else { return nil }
                let kind = relation(element, to: day)
                guard ["peer", "resource"].contains(kind) else { continue }
                let entry: JSONValue = .object(["zhi": .string(branch), "position": .string(labels[index]), "hiddenGan": .string(stem), "tier": .string(["ben", "zhong", "yu"][rank]), "weight": .double([1, 0.5, 0.2][rank]), "kind": .string(kind == "peer" ? "bijie" : "yin")])
                if kind == "peer" { expectedSame.append(entry) } else { expectedResource.append(entry) }
            }
        }
        // Compare encoded numeric semantics (JSON may decode 1 as integer or Double).
        func equalRoots(_ lhs: [JSONValue], _ rhs: [JSONValue]) -> Bool {
            guard lhs.count == rhs.count else { return false }
            return zip(lhs, rhs).allSatisfy { a, b in
                ["zhi", "position", "hiddenGan", "tier", "kind"].allSatisfy { string("/" + $0, a) == string("/" + $0, b) }
                    && number("/weight", a) == number("/weight", b)
            }
        }
        let sameSeat = same.contains { string("/position", $0) == "日" }
        let resourceSeat = resource.contains { string("/position", $0) == "日" }
        let state = relation(wx, to: day)
        let deLing = ["peer", "resource"].contains(state), shiLing = ["wealth", "officer"].contains(state)
        let yueLing = ["peer": "旺", "resource": "相", "output": "休", "wealth": "囚", "officer": "死"][state]!
        let sameUnits = expectedSame.reduce(0) { $0 + Int((number("/weight", $1)! * 10).rounded()) }
        let resourceUnits = expectedResource.reduce(0) { $0 + Int((number("/weight", $1)! * 10).rounded()) }
        let totalUnits = sameUnits + resourceUnits
        let bands: [(String, Double, Double?)] = [("无根", 0, 0.3), ("微根", 0.3, 0.7), ("弱根", 0.7, 1.5), ("中根", 1.5, 2.5), ("强根", 2.5, nil)]
        let actualRootLabel = totalUnits < 3 ? "无根" : totalUnits < 7 ? "微根" : totalUnits < 15 ? "弱根" : totalUnits < 25 ? "中根" : "强根"
        let dayStem = string("/day/ganZhi/gan", pillars)!, dayBranch = string("/day/ganZhi/zhi", pillars)!
        let blade = ["甲": "卯", "丙": "午", "戊": "午", "庚": "酉", "壬": "子"][dayStem] == dayBranch
        guard equalRoots(same, expectedSame), equalRoots(resource, expectedResource),
              value("/hasSameElementRoot", trace) == .bool(!same.isEmpty), value("/hasResourceSupport", trace) == .bool(!resource.isEmpty),
              value("/daySeatSameElementRoot", trace) == .bool(sameSeat), value("/daySeatResourceSupport", trace) == .bool(resourceSeat),
              value("/deLing", structure) == .bool(deLing), value("/shiLing", structure) == .bool(shiLing),
              string("/yueLingState", structure) == yueLing,
              value("/zuoRen", structure) == .bool(blade), value("/zuoGen", structure) == .bool(sameSeat || resourceSeat),
              string("/rootStrength/label", structure) == actualRootLabel,
              number("/rootStrength/bijieRoot", structure).flatMap(tenths) == sameUnits,
              number("/rootStrength/yinRoot", structure).flatMap(tenths) == resourceUnits,
              number("/rootStrength/totalRoot", structure).flatMap(tenths) == totalUnits,
              string("/rootWeightBasis", trace) == "open-source-engineering-weights",
              number("/rootWeights/ben", trace) == 1, number("/rootWeights/zhong", trace) == 0.5, number("/rootWeights/yu", trace) == 0.2,
              case let .array(recordedBands) = value("/rootLabelBands", trace), recordedBands.count == bands.count else { return nil }
        for (recorded, expected) in zip(recordedBands, bands) {
            guard string("/label", recorded) == expected.0, number("/lowerInclusive", recorded) == expected.1 else { return nil }
            if let upper = expected.2 { guard number("/upperExclusive", recorded) == upper else { return nil } }
            else { guard value("/upperExclusive", recorded) == .null else { return nil } }
        }
        let isStrong = totalUnits >= 15, isWeak = totalUnits < 7
        let assessment: (grade: String, rule: String, explanation: String)
        if deLing && actualRootLabel == "强根" && (blade || sameSeat || resourceSeat) {
            assessment = ("taiwang", "de-ling-strong-root-with-seat-support", "月令关系为得令、根印合计落入“强根”档，且日支有坐刃或根印支持")
        } else if deLing && isStrong {
            assessment = ("wang", "de-ling-medium-or-strong-root", "月令关系为得令、根印合计达到“中根”或“强根”档")
        } else if deLing && actualRootLabel == "弱根" {
            assessment = ("zhonghe", "de-ling-weak-root", "月令关系为得令、根印合计落入“弱根”档")
        } else if shiLing && isStrong {
            assessment = ("zhonghe", "shi-ling-medium-or-strong-root", "月令关系为失令、根印合计达到“中根”或“强根”档")
        } else if shiLing && actualRootLabel == "弱根" {
            assessment = ("ruo", "shi-ling-weak-root", "月令关系为失令、根印合计落入“弱根”档")
        } else if deLing && isWeak {
            assessment = ("ruo", "de-ling-minimal-root", "月令关系为得令、根印合计低于0.7")
        } else if shiLing && isWeak {
            assessment = ("tairuo", "shi-ling-minimal-root", "月令关系为失令、根印合计低于0.7")
        } else if isStrong {
            assessment = ("zhonghe", "neutral-month-medium-or-strong-root", "月令关系为休、根印合计达到“中根”或“强根”档")
        } else if isWeak {
            assessment = ("ruo", "neutral-month-minimal-root", "月令关系为休、根印合计低于0.7")
        } else {
            assessment = ("zhonghe", "neutral-month-weak-root", "月令关系为休、根印合计落入“弱根”档，采用当前矩阵的默认中和分支")
        }
        guard string("/strength", structure) == assessment.grade, string("/strengthRule", trace) == assessment.rule else { return nil }
        func roots(_ values: [JSONValue]) -> String {
            if values.isEmpty { return "本次四支未记录这一类藏干。" }
            return values.map { "\(string("/position", $0)!)支\(string("/zhi", $0)!)藏\(string("/hiddenGan", $0)!)" }.joined(separator: "、") + "。"
        }
        let stateNames = ["peer": "同类", "resource": "生我", "output": "我生", "wealth": "我克", "officer": "克我"]
        let grades = ["taiwang": "太旺", "wang": "旺", "zhonghe": "中和", "ruo": "弱", "tairuo": "太弱"]
        guard let grade = string("/strength", structure), let label = grades[grade],
              let rootLabel = string("/rootStrength/label", structure), ["无根", "微根", "弱根", "中根", "强根"].contains(rootLabel) else { return nil }
        return Group(id: "structure", title: "月令与根气：另一个观察角度", rows: [
            Row(id: "month-qi", title: "月支本气", detail: "\(string("/monthBranch", trace)!)中本气为\(main)\(wx.rawValue)，相对日主为\(stateNames[relation(wx, to: day)]!)。这不是前述计数额外采用的月令系数。"),
            Row(id: "same-roots", title: "同五行藏干", detail: roots(same)),
            Row(id: "resource-roots", title: "印的支持，单独列出", detail: roots(resource)),
            Row(id: "root-scale", title: "根印分档使用另一套权重", detail: "本气1、中气0.5、余气0.2；同五行藏干 \(format(Double(sameUnits) / 10)) + 印支持 \(format(Double(resourceUnits) / 10)) = \(format(Double(totalUnits) / 10))，旧档名为“\(rootLabel)”。边界依次为0.3、0.7、1.5、2.5；档名不等于实际有根或无根。"),
            Row(id: "separate-grade", title: "结构规则参考为“\(label)”", detail: "命中条件：\(assessment.explanation)。这套工程矩阵未综合其他透干，与固定计数的输出不能相互证明。")
        ])
    }

    private static func value(_ path: String, _ root: JSONValue) -> JSONValue? { ReadingVerificationEvidence.pointer(path, in: root) }
    private static func string(_ path: String, _ root: JSONValue) -> String? { if case let .string(s) = value(path, root) { return s }; return nil }
    private static func number(_ path: String, _ root: JSONValue) -> Double? {
        switch value(path, root) { case let .integer(n): return Double(n); case let .double(n): return n.isFinite ? n : nil; default: return nil }
    }
    private static func decode<T: Decodable>(_ raw: JSONValue) -> T? { guard let data = try? JSONEncoder().encode(raw) else { return nil }; return try? JSONDecoder().decode(T.self, from: data) }
    private static func tenths(_ n: Double) -> Int? { guard n.isFinite, n >= 0, n <= 100, abs(n * 10 - (n * 10).rounded()) < 0.0000001 else { return nil }; return Int((n * 10).rounded()) }
    private static func format(_ n: Double) -> String { n == n.rounded() ? String(Int(n)) : String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), n) }
    private static func element(_ stem: String) -> BaziFrameworkReading.Element? { ["甲": .wood, "乙": .wood, "丙": .fire, "丁": .fire, "戊": .earth, "己": .earth, "庚": .metal, "辛": .metal, "壬": .water, "癸": .water][stem] }
    private static func relation(_ subject: BaziFrameworkReading.Element, to day: BaziFrameworkReading.Element) -> String {
        if subject == day { return "peer" }; if subject.generates == day { return "resource" }; if day.generates == subject { return "output" }; if day.controls == subject { return "wealth" }; return "officer"
    }
    private static let branches = Set("子丑寅卯辰巳午未申酉戌亥".map(String.init))
}
