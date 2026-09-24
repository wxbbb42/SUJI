import Foundation

private extension JSONValue {
    subscript(_ key: String) -> JSONValue { if case let .object(v) = self { return v[key] ?? .null }; return .null }
    var text: String? { if case let .string(v) = self { return v }; return nil }
    var int: Int? { if case let .integer(v) = self { return Int(exactly: v) }; return nil }
    var bool: Bool? { if case let .bool(v) = self { return v }; return nil }
    var array: [JSONValue]? { if case let .array(v) = self { return v }; return nil }
}

/// Local report projection, not a tool execution or an AI receipt. Each module
/// keeps pointers into the original, owner-checked natal dossier. A rejected
/// advanced projection does not erase the independently validated basic facts.
enum BaziReadableModules {
    typealias Entry = NatalReadingReport.Entry
    typealias Source = NatalReadingReport.Source
    private static let foundation = Source(id: "bazi-module-foundations-v1", title: "《子平真诠评注》五行、用神与配合",
        locator: "01-foundations.md；00-abstract-chapters.md·论用神、论相神紧要",
        note: "据已存电子转录与所选规则解释结构；原文和评注交错，未与印本校勘。不从单一符号推断人格。", url: nil)
    private static let localConditions = Source(id: "bazi-module-local-conditions-v1", title: "《子平真诠评注》相神与合而不合",
        locator: "00-abstract-chapters.md·十五、论相神紧要；01-foundations.md·论十干合而不合；SUJI rescueDependencies.ts",
        note: "正文只采用通过来源、柱位、根气及依赖链复核的局部作用。局部路径不等于全局成败；具体条文与版本可在计算字段核对。", url: nil)
    private static let counting = Source(id: "bazi-module-counting-v1", title: "有时的五行计数参考",
        locator: "BaziEngine.computeWuXingStrength；BaziStrengthTrace.make；weighted-count-v1",
        note: "天干与藏干固定权重计数，含日干一次，未综合月令、根气和调候，不是完整传统旺衰判断。", url: nil)
    private static let labels = ["年", "月", "日", "时"]
    private static let keys = ["year", "month", "day", "hour"]

    static func make(_ chart: NatalReadingInput, _ evidence: NatalReadingEvidence) throws -> [Entry] {
        let b = chart.mingPan, day = b.riZhu, month = b.siZhu.month
        let monthQi = month.cangGan[0] // The shared fact validator checked this table.
        let monthRelation = NatalReadingCatalog.relationDefinitions[monthQi.shiShen]!
        var dayMonth = Entry(id: "module.day-month", title: "日主与月令 · 从哪里读你这张盘",
            summary: "\(day.gan)\(day.wuXing)日主，生于\(month.ganZhi.zhi)月。月支本气是\(monthQi.gan)\(monthQi.wuXing)，相对日主为\(monthQi.shiShen)。",
            explanation: "日主是这张盘的参照点，月令则告诉我们从哪个季节背景读它。你的月支\(month.ganZhi.zhi)以\(monthQi.gan)为本气；\(monthQi.shiShen)在这里指\(monthRelation)。因此，读这张盘时需要同时看日主与月令的关系，再核对其他位置怎样支持或制约它。仅换出生月份，这个阅读起点就可能改变。",
            boundary: "这里采用月支本气，尚未按月内司令细分；它不是完整强弱或性格结论。", reflection: nil,
            evidence: try evidence.at("/mingPan/riZhu", "/mingPan/siZhu/month", "/calendarPolicy/monthBoundary"), sources: [foundation, NatalReadingCatalog.baziRule])

        let dayElement = BaziFrameworkReading.Element(rawValue: day.wuXing)!
        let relations = BaziFrameworkReading.relations(to: dayElement)
        func locations(_ element: String) -> [String] {
            b.siZhu.all.enumerated().flatMap { i, p -> [String] in
                var result = i != 2 && p.ganZhi.ganWuXing == element ? ["\(labels[i])干\(p.ganZhi.gan)"] : []
                result += p.cangGan.filter { $0.wuXing == element }.map { "\(labels[i])支藏\($0.gan)" }
                return result
            }
        }
        let support = relations[0].subject.rawValue, output = relations[2].object.rawValue
        let supporting = locations(support), produced = locations(output)
        let elementSummary: String
        if !supporting.isEmpty && !produced.isEmpty {
            elementSummary = "以日主为中心，可以连起\(support)生\(day.wuXing)、\(day.wuXing)生\(output)两段关系。两端在你的盘里都有对应位置。"
        } else {
            let absent = [(support, supporting), (output, produced)].filter { $0.1.isEmpty }.map(\.0)
            elementSummary = "围绕日主的\(support) → \(day.wuXing) → \(output)关系中，\(absent.joined(separator: "、"))在其余天干与四支藏干里未见。读图时不能把这一段当作已有配合。"
        }
        var elements = Entry(id: "module.elements", title: "五行关系 · 围绕日主看联系",
            summary: elementSummary,
            explanation: "\(support)这一端：\(supporting.isEmpty ? "当前范围未见" : supporting.joined(separator: "、"))。\(output)这一端：\(produced.isEmpty ? "当前范围未见" : produced.joined(separator: "、"))。箭头表示传统相生方向，有位置不等于力量足够或作用已经发生。你可以据此核对一条说法是否真的连接了盘中的对象；不应只数哪一种最多。",
            boundary: "这是一张关系图，不是能量测量。未见某五行，不表示缺少某种能力，也不直接推出需要补它。", reflection: nil,
            evidence: try evidence.at("/mingPan/riZhu", "/mingPan/siZhu"), sources: [foundation, NatalReadingCatalog.baziRule])

        let exposed = b.siZhu.all.enumerated().filter { $0.offset != 2 }.map { "\(labels[$0.offset])干\($0.element.ganZhi.gan)·\($0.element.shiShen)" }
        let exposedNames = Set(b.siZhu.all.enumerated().filter { $0.offset != 2 }.map { $0.element.shiShen })
        let hiddenNames = Set(b.siZhu.all.flatMap(\.cangGan).map(\.shiShen))
        let order = ["比肩", "劫财", "食神", "伤官", "偏财", "正财", "七杀", "正官", "偏印", "正印"]
        let shared = order.filter { exposedNames.contains($0) && hiddenNames.contains($0) }
        let hiddenOnly = order.filter { hiddenNames.contains($0) && !exposedNames.contains($0) }
        let layerMeaning = shared.isEmpty ? "天干与支藏没有同名十神重现，需分别读各自的位置。"
            : "\(shared.joined(separator: "、"))同时见于天干和支藏，可以顺着这两层核对它们的配合。"
        var gods = Entry(id: "module.relations", title: "十神分布 · 哪些关系摆在一起",
            summary: exposed.joined(separator: "；") + "。" + layerMeaning,
            explanation: "天干是盘面直接列出的一层，藏干是地支内部所含的另一层。\(hiddenOnly.isEmpty ? "本盘支藏没有额外独有的十神类别。" : "本盘\(hiddenOnly.joined(separator: "、"))只在支藏出现；要求双方透干的规则，不能直接套在这些关系上。")同一名称重复时还要分清具体是哪一干、在哪一柱。格局章节会进一步说明现有规则能否确认其中的作用，而不是把出现次数换成人格分数。",
            boundary: "透与藏是盘面的层次，不对应外向与内向；官、财、印等名称也不是职业、收入或能力的测量。", reflection: nil,
            evidence: try evidence.at("/mingPan/riZhu", "/mingPan/siZhu"), sources: [foundation, NatalReadingCatalog.baziRule])

        let root = try JSONDecoder().decode(JSONValue.self, from: JSONSerialization.data(withJSONObject: evidence.root, options: [.sortedKeys]))
        let original = root["mingPan"]
        // Value-only aliases permit reuse of independent native validators. No
        // call ID/context/receipt is fabricated, and no projection leaves device.
        let projected: JSONValue = .object(["bazi": .object([
            "birthDateTime": original["birthDateTime"], "pillars": original["siZhu"],
            "dayMaster": original["riZhu"], "patternAnalysis": original["geJuV2"]
        ])])
        let pattern = try patternEntry(original, projected: projected, evidence: evidence)
        let methods = try methodsEntry(original, patternUsable: pattern.usable, evidence: evidence)
        dayMonth.diagram = ["日主 \(day.gan)\(day.wuXing) ← 参照 → 月支 \(month.ganZhi.zhi)", "月支本气 \(monthQi.gan)\(monthQi.wuXing) · \(monthQi.shiShen)"]
        elements.diagram = ["\(support) 生 → \(day.wuXing)（日主）生 → \(output)"]
        gods.diagram = ["天干 · " + exposed.joined(separator: " / "), "仅见支藏 · " + (hiddenOnly.isEmpty ? "无额外类别" : hiddenOnly.joined(separator: "、"))]
        return [dayMonth, elements, gods, pattern.entry, methods]
    }

    private static func patternEntry(_ original: JSONValue, projected: JSONValue, evidence: NatalReadingEvidence) throws -> (entry: Entry, usable: Bool) {
        let g = original["geJuV2"]
        let factPaths = ["/mingPan/siZhu", "/mingPan/riZhu"]
        func unavailable() throws -> (Entry, Bool) {
            (Entry(id: "module.pattern", title: "格局配合 · 这一项暂不能确认",
                summary: "日主、月令和十神仍可阅读；格局的条件或规则版本尚未通过本页核对。",
                explanation: "本页不会把缺失或不一致的格局数据补成结论。当前基础事实仍保留；格局解释需要取用、来源与条件链同时一致。",
                boundary: "这是格局模块的读取限制，不代表你的命盘没有格局。", reflection: nil,
                evidence: try evidence.at(factPaths), sources: [localConditions]), false)
        }
        guard g["assessmentStatus"].text == "heuristic-candidate", g["category"].text == "zhengge",
              let name = g["name"].text, let selectionReason = selectionReason(original),
              let selected = g["yongShenGan"].text, let selectedIndex = NatalReadingInput.stems.firstIndex(of: selected),
              g["yongShen"].text == NatalReadingInput.elements[selectedIndex / 2],
              let day = original["riZhu"]["gan"].text,
              g["yongShenShiShen"].text == (try? NatalReadingInput.relation(day: day, target: selected)),
              BaziPatternConditionTrace.make(root: projected) != nil,
              let adjudicated = BaziAdjudicationTrace.make(root: projected),
              g["rescueEvidence"]["globalResolution"].text == "unresolved",
              g["rescueEvidence"]["outcomeEstablished"] == .bool(false) else { return try unavailable() }

        let resolution = g["rescueEvidence"]["dependencyResolution"]
        let actions = resolution["actions"].array ?? []
        // Select only explicitly scoped control paths; unknown/unscoped actions
        // never become a favorable headline. Multiple outcomes remain separate.
        let scoped = actions.filter { $0["relation"].text == "克" && $0["ruleId"].text != "unscoped-action" }
        let statuses = Set(scoped.compactMap { $0["status"].text })
        let headline: String
        if statuses.count > 1 { headline = "局部配合有不同结果，需要分开读" }
        else if statuses == ["available"] { headline = "有一条局部配合可用" }
        else if statuses == ["blocked"] { headline = "这条配合受到牵制" }
        else if statuses == ["unresolved"] { headline = "仍有条件未定" }
        else { headline = "已有候选，配合还需继续核对" }
        let stems = keys.map { original["siZhu"][$0]["ganZhi"]["gan"].text! }
        let localDescriptions = scoped.map { action -> String in
            guard let a = action["actorPosition"].int, let t = action["targetPosition"].int,
                  (0..<4).contains(a), (0..<4).contains(t), let targetGan = action["targetGan"].text else { return "" }
            let actor = "\(labels[a])干\(stems[a])"
            let target = action["targetLayer"].text == "month-main-qi" ? "月令本气\(targetGan)" : "\(labels[t])干\(targetGan)"
            switch action["status"].text {
            case "available":
                let released = (action["attacks"].array ?? []).filter { $0["status"].text == "neutralized" }.compactMap { item -> String? in
                    guard let i = item["actorPosition"].int, (0..<4).contains(i) else { return nil }
                    return "\(labels[i])干\(stems[i])受合牵制"
                }
                return (released.isEmpty ? "" : released.joined(separator: "、") + "后，") + "\(actor)制约\(target)这条路径，在所选条文范围内可用。看这组配合的关键，是制约者本身能否起作用。"
            case "blocked": return "原本要由\(actor)制约\(target)，但\(actor)自身受到合的牵制，这条路径不能直接沿用。盘里有这个字，并不等于它能完成这项作用。"
            case "unresolved": return "\(actor)与\(target)之间虽有制约关系，但\(actor)自身还有未解条件，暂不能确定这条路径有效。这里需要继续核对的是作用条件，不是多算一次出现数量。"
            case "retained": return "\(target)在当前规则下仍保留作用，不能把\(actor)的出现直接当成已经将它去除。"
            default: return ""
            }
        }.filter { !$0.isEmpty }
        let furtherPaths = localDescriptions.dropFirst().joined(separator: "\n\n")
        let localText = localDescriptions.isEmpty
            ? "本页尚未找到通过核对、可展开说明的局部制约路径。已有候选并不等于配合成立，也不能据此断言全局无救。"
            : "同一个格局候选，根气、位置和牵制不同，局部解释也会改变。此处只解释通过核对的制约路径，其他条件仍需分别核验。"
        let paths = factPaths + ["/mingPan/geJuV2"]
        return (Entry(id: "module.pattern", title: "格局配合 · 候选怎样发挥作用",
            summary: "\(name)候选：\(headline)。" + (localDescriptions.first.map { "\n" + $0 } ?? ""),
            explanation: selectionReason + "\n\n" + localText + (furtherPaths.isEmpty ? "" : "\n\n" + furtherPaths)
                + (adjudicated.text.isEmpty ? "" : "\n\n已核对的部分条件：\n" + adjudicated.text),
            boundary: "采用《子平真诠评注》所选规则；局部可用不等于整格成败，也不直接推出财富、职业或人生结果。", reflection: nil,
            evidence: try evidence.at(paths), sources: [foundation, localConditions]), true)
    }

    /// Bounded read-back of structural.ts selectYongShen/geJuName, using the
    /// validated natal facts rather than trusting the selected label. Triple
    /// proxies and special patterns need their own interpretation and are not
    /// covered by this report yet. The priority is an engine convention, not
    /// an assertion that all schools choose the same candidate.
    private static func selectionReason(_ original: JSONValue) -> String? {
        let g = original["geJuV2"]
        guard let day = original["riZhu"]["gan"].text,
              let month = original["siZhu"]["month"]["ganZhi"]["zhi"].text,
              let hidden = NatalReadingInput.hidden[month]?.map(\.0), let main = hidden.first else { return nil }
        let stems = keys.compactMap { original["siZhu"][$0]["ganZhi"]["gan"].text }
        let branches = keys.compactMap { original["siZhu"][$0]["ganZhi"]["zhi"].text }
        guard stems.count == 4, branches.count == 4 else { return nil }
        let eligible = ["子", "午", "卯", "酉"].contains(month) ? [main] : hidden
        let exposed = eligible.firstIndex { stems.contains($0) }
        let selected: String, basis: String, reason: String
        if let rank = exposed {
            selected = eligible[rank]
            basis = ["yueling-benqi-tougan", "yueling-zhongqi-tougan", "yueling-yuqi-tougan"][rank]
            let positions = stems.enumerated().filter { $0.element == selected }.map { "\(labels[$0.offset])干" }.joined(separator: "、")
            reason = "按当前月令取格顺序，月支\(month)的\(["本气", "中气", "余气"][rank])\(selected)见于\(positions)，因此选它作为候选的起点。" + (rank > 0 ? "月令本气\(main)未透干，所以本页的格局候选与前面本气的十神名称可能不同。" : "")
        } else {
            let triples = ["申子辰", "寅午戌", "巳酉丑", "亥卯未", "寅卯辰", "巳午未", "申酉戌", "亥子丑"].map { Array($0).map(String.init) }
            guard !triples.contains(where: { $0.contains(month) && Set($0).isSubset(of: Set(branches)) }) else { return nil }
            selected = main; basis = "jianlu-yueliu"
            reason = "按当前月令取格顺序，未见优先取用的月令藏干透出，月支也未参与齐全的三合、三会；因此暂以\(month)中本气\(main)作为候选的起点。这个回退步骤本身不表示建禄或月刃。"
        }
        guard g["selectionBasis"].text == basis, g["yongShenGan"].text == selected,
              let relation = try? NatalReadingInput.relation(day: day, target: selected) else { return nil }
        let name: String
        if relation == "比肩" {
            let lu = ["甲":"寅", "乙":"卯", "丙":"巳", "丁":"午", "戊":"巳", "己":"午", "庚":"申", "辛":"酉", "壬":"亥", "癸":"子"]
            name = lu[day] == month ? "建禄格" : "比肩结构（格局待辨）"
        } else if relation == "劫财" {
            let blade = ["甲":"卯", "丙":"午", "戊":"午", "庚":"酉", "壬":"子"]
            name = blade[day] == month ? "月刃格" : ((try? NatalReadingInput.relation(day: day, target: main)) == "劫财" ? "月劫格" : "劫财透干（格局待辨）")
        } else { name = relation + "格" }
        guard g["name"].text == name else { return nil }
        return reason + "这是本页采用的取格口径；其他流派可能另有取法。"
    }

    private static func methodsEntry(_ original: JSONValue, patternUsable: Bool, evidence: NatalReadingEvidence) throws -> Entry {
        let strength = original["wuXingStrength"]
        let checked = BaziStrengthTrace.make(pillars: original["siZhu"], strength: strength, structure: original["riZhuStructure"])
        guard original["riZhuStructure"] != .null, let checked, let strong = strength["riZhuStrong"].bool,
              let element = strength["yongShen"].text,
              let chosen = BaziFrameworkReading.Element(rawValue: element),
              let day = original["riZhu"]["wuXing"].text,
              (strong ? chosen.controls : chosen.generates).rawValue == day else {
            return Entry(id: "module.methods", title: "强弱与取用 · 参考暂待核对",
                summary: "五行关系与十神位置仍可阅读，本页暂不列强弱和取用结果。",
                explanation: "强弱参考需要逐项计数与所用方法一致；本次未通过核对，不拿其他模块的标签代替。",
                boundary: "资料不会因此丢失，也无需重新填写出生信息。", reflection: nil,
                evidence: try evidence.at("/mingPan/siZhu"), sources: [counting])
        }
        let g = original["geJuV2"]
        let comparison: String
        if patternUsable, let patternElement = g["yongShen"].text {
            comparison = element == patternElement
                ? "格局候选也记为\(element)，但两者回答的问题不同，相同的字并不构成互相验证。"
                : "格局候选记为\(patternElement)，与这里的\(element)不同：一个在说明结构中的角色，一个是当前计数规则下的扶抑方向。"
        } else { comparison = "格局模块尚未通过本页核对，不能用此处的参考替它定格。" }
        let text = "当前固定权重计数列为\(strong ? "偏强" : "偏弱")，扶抑参考为\(element)。" + comparison
        return Entry(id: "module.methods", title: "强弱与取用 · 为什么会有不同说法",
            summary: text,
            explanation: "本盘计数中，帮扶为\(number(checked.supportTotal))，克泄耗为\(number(checked.drainTotal))。这能核对当前程序如何给出标签，却不是对一个人力量的测量。扶抑、格局和调候关注不同条件，不能合成一个幸运元素。调候还需单独核对寒暖燥湿与条文适用条件；本页没有自动替你选定。",
            boundary: "这里是工程计数参考：含日干一次，未综合月令、根气和调候；不能代替完整旺衰判断。", reflection: nil,
            evidence: try evidence.at(["/mingPan/siZhu", "/mingPan/wuXingStrength", "/mingPan/riZhuStructure"] + (patternUsable ? ["/mingPan/geJuV2"] : [])), sources: [counting, foundation])
    }
    private static func number(_ value: Double) -> String { String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), value) }
}
