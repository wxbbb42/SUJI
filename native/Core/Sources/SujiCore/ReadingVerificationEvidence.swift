import Foundation

/// A closed index of explicit fields, not model-generated interpretations.
enum ReadingVerificationEvidence {
    struct Fact: Encodable {
        let factKey: String
        let toolCallID: String
        let pointer: String
        let value: JSONValue
    }

    static func facts(_ history: [ChatMessage]) -> [Fact] {
        let calls = Dictionary(history.flatMap { $0.toolCalls ?? [] }.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        var facts: [Fact] = []
        for message in history where message.role == .tool {
            guard let id = message.toolCallID, let name = calls[id], let raw = message.content,
                  let object = try? JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8)),
                  case let .object(root) = object, root["error"] == nil else { continue }
            func add(_ key: String, _ path: String, preserveNull: Bool = false) {
                guard let value = pointer(path, in: object), preserveNull || value != .null else { return }
                facts.append(Fact(factKey: key, toolCallID: id, pointer: path, value: value))
            }
            func fields(_ prefix: String, _ path: String, _ keys: [String]) {
                func scalar(_ value: JSONValue) -> Bool {
                    switch value {
                    case .string, .integer, .double, .bool: return true
                    default: return false
                    }
                }
                for key in keys {
                    guard let value = pointer(path + "/" + key, in: object) else { continue }
                    if case let .array(values) = value {
                        guard values.allSatisfy(scalar) else { continue }
                    } else if !scalar(value) { continue }
                    add(prefix + "." + key, path + "/" + key)
                }
            }
            func sources(_ prefix: String, _ base: String = "") {
                guard case let .array(sources) = pointer(base + "/ruleSources", in: object) else { return }
                for (index, source) in sources.enumerated() {
                    let key = "\(prefix).ruleSource\(index + 1)", path = base + "/ruleSources/\(index)"
                    fields(key, path, ["id", "version", "title", "editionStatus", "scope", "limitations"])
                    guard case let .object(source) = source, case let .array(references) = source["references"] else { continue }
                    for reference in references.indices {
                        fields("\(key).reference\(reference + 1)", "\(path)/references/\(reference)", ["url", "locator", "sha256", "quote"])
                    }
                }
            }
            func ziwei(_ base: String) {
                func palace(_ path: String) {
                    guard case let .string(name) = pointer(path + "/palace", in: object),
                          ["命宫", "兄弟宫", "夫妻宫", "子女宫", "财帛宫", "疾厄宫", "迁移宫", "仆役宫", "官禄宫", "田宅宫", "福德宫", "父母宫"].contains(name) else { return }
                    let key = "ziwei." + name
                    fields(key, path, ["palace", "position", "ganZhi", "mainStars", "minorStars", "isShenGong", "emptyMainPalace", "relation", "sihua"])
                    if case let .array(stars) = pointer(path + "/starDetails", in: object) {
                        for index in stars.indices {
                            fields("\(key).star\(index + 1)", path + "/starDetails/\(index)", ["name", "group", "type", "source", "brightness", "sihua"])
                        }
                    }
                    if case let .array(transformations) = pointer(path + "/natalTransformations", in: object) {
                        for index in transformations.indices {
                            fields("\(key).transformation\(index + 1)", path + "/natalTransformations/\(index)", ["scope", "sourceStem", "star", "transformation", "targetPalace", "targetPosition", "sourceId"])
                        }
                    }
                }
                palace(base)
                if case let .array(related) = pointer(base + "/relatedPalaces", in: object) {
                    for index in related.indices { palace(base + "/relatedPalaces/\(index)") }
                }
                fields("ziwei.emptyPalaceReference", base + "/emptyPalaceReference", ["status", "sourcePalace", "sourcePosition", "mainStars"])
                fields("ziwei.natalYear", base + "/natalYear", ["lunarYear", "ganZhi", "stem", "branch"])
                fields("ziwei.method", base + "/method", ["algorithm", "dayBoundary", "yearBoundary", "leapMonth", "calculationDate", "civilTimeZone", "caveats"])
                let flightPath = base + "/palaceFlights", flightKey = "ziwei.palaceFlights"
                fields(flightKey, flightPath, ["status", "reason", "scope", "algorithm", "assessmentStatus", "sourceId", "incoming", "outgoing"])
                for direction in ["outgoing", "incoming"] {
                    if case let .array(edges) = pointer(flightPath + "/" + direction, in: object) {
                        for index in edges.indices {
                            fields("\(flightKey).\(direction)\(index + 1)", "\(flightPath)/\(direction)/\(index)", ["scope", "sourcePalace", "sourcePosition", "sourceStem", "star", "transformation", "targetPalace", "targetPosition", "isSelf", "sourceId"])
                        }
                    }
                }
                sources("ziwei", base)
            }
            func patternConditions() {
                let base = "/bazi/patternAnalysis/conditionalEvidence", prefix = "bazi.pattern.conditions"
                fields(prefix,base,["assessmentStatus","outcomeEstablished","limitations"])
                func rows(_ key: String,_ path: String,_ keys: [String]) {
                    guard case let .array(items) = pointer(path,in:object) else { return }
                    for index in items.indices { fields(key + String(index + 1),path + "/\(index)",keys) }
                }
                if case let .array(stems) = pointer(base + "/stems",in:object) {
                    for index in stems.indices {
                        let p = base + "/stems/\(index)",k = prefix + ".stem\(index + 1)"
                        fields(k,p,["position","gan","element","shiShen","generatingStemPositions","combinationAdjudication"])
                        fields(k + ".month",p + "/month",["branch","element","state"])
                        rows(k + ".root",p + "/sameElementRoots",["position","branch","gan","tier","sameStem"])
                        rows(k + ".support",p + "/generatingSupport",["position","branch","gan","tier"])
                        rows(k + ".constraint",p + "/constraints",["actorPosition","actorGan","relation","adjacent","interveningPositions"])
                    }
                }
                rows(prefix + ".helper",base + "/helperCandidates",["layer","position","gan","branch","tier","shiShen","context"])
                rows(prefix + ".rescue",base + "/rescueCandidates",["triggerPosition","remedyPosition","relation","fromPosition","toPosition","adjacent","interveningPositions","triggerContext","remedyContext","effectiveness"])
                rows(prefix + ".protection",base + "/helperProtectionCandidates",["helperPosition","attackerPosition","remedyPosition","relation","adjacent","interveningPositions","helperContext","attackerContext","remedyContext","effectiveness"])
                if case let .array(clashes) = pointer(base + "/monthClashes",in:object) {
                    for index in clashes.indices {
                        let p = base + "/monthClashes/\(index)",k = prefix + ".monthClash\(index + 1)"
                        fields(k,p,["monthPosition","otherPosition","branches","reliefEstablished"])
                        rows(k + ".combination",p + "/combinationCandidates",["position","branch","combinesWithPosition","adjacent","interveningPositions","challengedByPositions"])
                        rows(k + ".mediation",p + "/mediationCandidates",["position","branch","element","challengedByPositions"])
                    }
                }
                rows(prefix + ".source",base + "/sources",["id","document","sha256","locator","quote","additionalQuotes","editionStatus"])
            }
            switch name {
            case "get_today_context":
                for (key, path) in [("year", "yearGanZhi"), ("month", "monthGanZhi"), ("day", "dayGanZhi"), ("term", "solarTerm")] { add("calendar." + key, "/" + path) }
            case "get_domain":
                patternConditions()
                for column in ["year", "month", "day", "hour"] {
                    for part in ["gan", "zhi"] { add("bazi.\(column).\(part)", "/bazi/pillars/\(column)/ganZhi/\(part)") }
                    add("bazi.\(column).tenGod", "/bazi/pillars/\(column)/shiShen")
                }
                for (key, path) in [("pattern.status", "patternAnalysis/assessmentStatus"), ("pattern.stem", "patternAnalysis/yongShenGan"), ("pattern.element", "patternAnalysis/yongShen"), ("strength.status", "strengthReference/suggestionStatus"), ("strength.method", "strengthReference/suggestionBasis"), ("strength.element", "strengthReference/yongShen"), ("tiaohou.automatic", "tiaoHou/automatedSelection")] { add("bazi." + key, "/bazi/" + path) }
                ziwei("/ziwei")
            case "get_ziwei_palace":
                ziwei("")
            case "get_ziwei_timing":
                fields("ziwei.timing", "", ["referenceDate", "referenceMode", "civilDate", "calculationDate", "nominalAge", "status", "direction", "startAge", "calendarWarnings"])
                fields("ziwei.timing.natalYear", "/natalYear", ["lunarYear", "ganZhi", "stem", "branch"])
                fields("ziwei.timing.activeDecade", "/activeDecade", ["index", "startAge", "endAge", "startLunarYear", "endLunarYear", "palace", "position", "ganZhi"])
                fields("ziwei.timing.annual", "/annual", ["lunarYear", "ganZhi", "stem", "branch", "appliesToBirth"])
                fields("ziwei.timing.annual.taiSui", "/annual/taiSui", ["position", "natalPalace"])
                for (layer, path) in [("annual", "/annual/transformations"), ("decadal", "/decadalTransformations"), ("monthly", "/monthly/transformations")] {
                    if case let .array(transformations) = pointer(path, in: object) {
                        for index in transformations.indices {
                            fields("ziwei.timing.\(layer).transformation\(index + 1)", "\(path)/\(index)", ["scope", "sourceStem", "star", "transformation", "targetPalace", "targetPosition", "sourceId"])
                        }
                    }
                }
                fields("ziwei.timing.monthly", "/monthly", ["status", "reason", "scope", "assessmentStatus", "appliesToBirth", "sourceId", "ganZhi", "stem", "branch", "transformations"])
                fields("ziwei.timing.monthly.calendar", "/monthly/calendar", ["lunarYear", "month", "day", "isLeapMonth", "effectiveMonth"])
                fields("ziwei.timing.monthly.birthBasis", "/monthly/birthBasis", ["algorithm", "lunarMonth", "lunarDay", "isLeapMonth", "effectiveMonth", "hourBranch"])
                for field in ["douJun", "mingGong"] {
                    fields("ziwei.timing.monthly." + field, "/monthly/" + field, ["position", "natalPalace"])
                }
                if case let .array(palaces) = pointer("/monthly/palaces", in: object) {
                    for index in palaces.indices {
                        fields("ziwei.timing.monthly.palace\(index + 1)", "/monthly/palaces/\(index)", ["palace", "position", "natalPalace"])
                    }
                }
                fields("ziwei.timing.monthly.method", "/monthly/method", ["algorithm", "monthBoundary", "leapMonth", "stemMethod", "palaceMethod"])
                fields("ziwei.timing.method", "/method", ["algorithm", "civilTimeZone", "dayBoundary", "yearBoundary", "ageConvention"])
                sources("ziwei.timing")
            case "cast_liuyao":
                add("liuyao.castTime", "/castTime")
                fields("liuyao.calendar", "/castGanZhi", ["month", "day", "hour"])
                fields("liuyao.method", "/method", ["algorithm", "calendar", "dayBoundary", "caveats"])
                fields("liuyao.question", "/questionContext", ["subject", "timeHorizon"])
                fields("liuyao.lineContextPolicy", "/lineContextPolicy", ["assessmentStatus", "sourceIds"])
                fields("liuyao.guaRelations", "/guaRelations", ["assessmentStatus", "outcomeEstablished", "sourceId"])
                fields("liuyao.guaRelations.transition", "/guaRelations/transition", ["hasChange", "kind", "fromKind", "toKind", "factPaths"])
                for side in ["original", "resulting"] {
                    let key = "liuyao.guaRelations." + side, path = "/guaRelations/" + side
                    fields(key, path, ["guaPath", "kind", "ganZhi"])
                    if case let .array(pairs) = pointer(path + "/pairs", in: object) {
                        for index in pairs.indices {
                            fields(key + ".pair\(index + 1)", path + "/pairs/\(index)", ["positions", "relation"])
                        }
                    }
                }
                fields("liuyao.yongShen", "/yongShen", ["type", "yaoIndex", "wuXing", "state", "candidateYaoIndices", "selectionStatus", "selectionEstablished", "missingContext", "querentReference", "sourceId", "candidates", "related", "excluded"])
                for (collection, label) in [("candidates", "candidate"), ("related", "related"), ("excluded", "excluded")] {
                    if case let .array(items) = pointer("/yongShen/" + collection,in:object) {
                        for index in items.indices {
                            fields("liuyao.yongShen.\(label)\(index + 1)","/yongShen/\(collection)/\(index)",["id", "layer", "position", "objectPath", "contextPath", "reason"])
                        }
                    }
                }
                fields("liuyao.timing", "/yingQi", ["assessmentStatus", "outcomeEstablished", "sourceId", "timeScale", "unresolved", "branchesByCandidate"])
                if case let .array(candidates) = pointer("/yingQi/branchesByCandidate",in:object) {
                    for index in candidates.indices {
                        let k = "liuyao.timing.candidate\(index + 1)",p = "/yingQi/branchesByCandidate/\(index)"
                        fields(k,p,["candidateId", "objectPath", "conditionsPath", "unresolved", "rules"])
                        if case let .array(rules) = pointer(p + "/rules",in:object) {
                            for rule in rules.indices { fields(k + ".rule\(rule + 1)",p + "/rules/\(rule)",["id", "branches", "factPaths"]) }
                        }
                    }
                }
                sources("liuyao")
                for key in ["name", "upper", "lower"] {
                    add("liuyao.original." + key, "/benGua/" + key)
                    add("liuyao.changed." + key, "/bianGua/" + key)
                }
                for key in ["lineValues", "changingYao", "xunKong", "shiYao", "yingYao"] { add("liuyao." + key, "/" + key) }
                for index in 0..<6 {
                    let key = "liuyao.line\(index + 1)", path = "/lines/\(index)"
                    fields(key, path, ["ganZhi", "wuXing", "liuQin", "liuShen", "isShi", "isYing", "isChanging", "isVoid", "monthClash", "dayClash", "dayCombination"])
                    for layer in ["", "changed", "hidden"] {
                        let layerKey = layer.isEmpty ? key : key + "." + layer
                        let layerPath = layer.isEmpty ? path : path + "/" + layer
                        if !layer.isEmpty { fields(layerKey, layerPath, ["ganZhi", "wuXing", "liuQin"]) }
                        fields(layerKey + ".context", layerPath + "/context", ["isVoid", "monthState", "assessmentStatus", "sourceIds"])
                        for scope in ["month", "day"] {
                            fields(layerKey + ".context." + scope, layerPath + "/context/" + scope, ["ganZhi", "branch", "element", "elementRelation", "sameBranch", "clash", "combination"])
                        }
                    }
                    for rule in ["returning", "advanceRetreat", "flyingHidden", "dayClash"] {
                        let ruleKey = key + ".rules." + rule, rulePath = path + "/rules/" + rule
                        fields(ruleKey, rulePath, ["relation", "kind", "from", "to", "fromBranch", "toBranch", "assessmentStatus", "effectiveness", "sourceId", "conditionsFrom", "candidates", "voidClash", "movingGenerationPositions", "movingControlPositions", "flyingChallengedByPositions"])
                        if rule == "returning" { fields(ruleKey, rulePath, ["branchRelation", "branchSourceId"]) }
                        let conditionIDs: Set<String> = ["changed-void", "changed-month-break", "changed-day-clash", "combined-effectiveness", "changed-month-generation", "changed-day-support", "original-day-presence", "hidden-month-generation", "hidden-day-generation", "flying-generates-hidden", "moving-generates-hidden", "calendar-challenges-flying", "moving-challenges-flying", "flying-void", "flying-month-break", "hidden-month-clash", "hidden-day-clash", "hidden-month-control", "hidden-day-control", "flying-controls-hidden", "hidden-void", "hidden-combined-strength", "flying-combined-strength", "hidden-tomb-or-extinction", "flying-tomb-or-extinction", "static-line", "day-clash", "month-support", "day-support", "month-control", "moving-generation", "moving-control", "void-clash", "combined-strength", "moving-actors-effectiveness"]
                        if case let .array(conditions) = pointer(rulePath + "/conditions", in: object) {
                            for (index, condition) in conditions.enumerated() {
                                guard case let .object(condition) = condition,
                                      case let .string(id) = condition["id"], conditionIDs.contains(id),
                                      case let .string(state) = condition["state"], ["matched", "not-matched", "unresolved"].contains(state) else { continue }
                                add(ruleKey + ".condition." + id, rulePath + "/conditions/\(index)/state")
                            }
                        }
                    }
                }
            case "setup_qimen":
                add("qimen.setupTime", "/setupTime")
                for key in ["yinYangDun", "juNumber", "yuan", "jieqi", "zhiFuStar", "zhiFuPalaceId", "zhiShiMen", "zhiShiPalaceId", "fuTou", "zhiFuSourcePalaceId", "zhiShiSourcePalaceId", "zhiShiRawPalaceId", "tianQinPalaceId", "dayGanZhi", "hourGanZhi", "monthGanZhi", "calculationTime", "trueSolarTime"] { add("qimen." + key, "/" + key) }
                fields("qimen.method", "/method", ["algorithm", "centerPolicy", "dayBoundary", "solarTermClock", "clockPolicy", "timezone", "longitude", "caveats"])
                fields("qimen.hourVoid", "/hourVoid", ["scope", "ganZhi", "xun", "branches", "sourceId"])
                fields("qimen.horse", "/horse", ["scope", "ganZhi", "branch", "palaceId", "sourceId"])
                fields("qimen.question", "/questionContext", ["subject", "timeHorizon"])
                fields("qimen.yongShen", "/yongShen", ["type", "palaceId", "state", "selectionStatus", "selectionEstablished", "missingContext", "sourceId", "candidates"])
                if pointer("/yongShen/selectedCandidateId", in: object) == .null {
                    add("qimen.yongShen.selectedCandidateId", "/yongShen/selectedCandidateId", preserveNull: true)
                }
                if case let .array(candidates) = pointer("/yongShen/candidates", in: object) {
                    for index in candidates.indices {
                        let k = "qimen.yongShen.candidate\(index + 1)", p = "/yongShen/candidates/\(index)"
                        fields(k, p, ["id", "role", "symbol", "calendarPath", "carrierStem", "carrierMethod", "occurrences"])
                        if case let .array(occurrences) = pointer(p + "/occurrences", in: object) {
                            for occurrence in occurrences.indices {
                                let key = k + ".occurrence\(occurrence + 1)", path = p + "/occurrences/\(occurrence)"
                                fields(key, path, ["palaceId", "plate", "objectPath", "isEffectiveSky"])
                                fields(key + ".elementRelation", path + "/elementRelation", ["stemElement", "palaceElement", "relation", "assessmentStatus"])
                            }
                        }
                    }
                }
                fields("qimen.timing", "/yingQi", ["assessmentStatus", "outcomeEstablished", "sourceId", "timeScale", "unresolved", "triggers", "dates", "observedFactPaths"])
                sources("qimen")
                if case let .array(emptyPalaces) = pointer("/hourVoid/palaces", in: object) {
                    for (index, emptyPalace) in emptyPalaces.enumerated() {
                        guard case let .object(p) = emptyPalace, case let .integer(id) = p["palaceId"] else { continue }
                        fields("qimen.hourVoid.palace\(id)", "/hourVoid/palaces/\(index)", ["branches", "palaceBranches", "coverage"])
                    }
                }
                if case let .array(palaces) = root["palaces"] {
                    for (index, palace) in palaces.enumerated() {
                        guard case let .object(p) = palace, case let .integer(id) = p["id"] else { continue }
                        let key = "qimen.palace\(id)", path = "/palaces/\(index)"
                        fields(key, path, ["tianPanGan", "diPanGan", "bashen", "bamen", "jiuxing", "hostedDiPanGan", "hostedTianPanGan", "wuXing", "hostsTianQin"])
                        fields(key + ".doorRelation", path + "/doorRelation", ["door", "doorElement", "palaceElement", "relation", "isPressure", "sourceId", "assessmentStatus"])
                        for scope in ["starSeason", "hostedStarSeason"] {
                            fields(key + "." + scope, path + "/" + scope, ["scope", "star", "element", "monthGanZhi", "monthBranch", "monthElement", "state", "sourceId", "assessmentStatus"])
                        }
                    }
                }
                if case let .array(references) = pointer("/yongShen/references", in: object) {
                    for index in references.indices { fields("qimen.yongShen.reference\(index + 1)", "/yongShen/references/\(index)", ["label", "palaceId"]) }
                }
            default: break
            }
        }
        return facts
    }

    static func pointer(_ path: String, in root: JSONValue) -> JSONValue? {
        guard path.hasPrefix("/") else { return nil }
        var value = root
        for raw in path.dropFirst().components(separatedBy: "/") {
            guard raw.range(of: #"~(?![01])"#, options: .regularExpression) == nil else { return nil }
            let key = raw.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
            switch value {
            case let .object(object): guard let next = object[key] else { return nil }; value = next
            case let .array(array): guard let index = Int(key), String(index) == key, array.indices.contains(index) else { return nil }; value = array[index]
            default: return nil
            }
        }
        return value
    }

    static func sentences(_ draft: String) -> [String] {
        draft.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func literal(_ quote: String, matches value: JSONValue) -> Bool {
        switch value {
        case let .string(text): return quote == text
        case .integer, .double, .bool: return (try? JSONDecoder().decode(JSONValue.self, from: Data(quote.utf8))) == value
        case .array:
            if (try? JSONDecoder().decode(JSONValue.self, from: Data(quote.utf8))) == value { return true }
            let text = quote.replacingOccurrences(of: "、", with: ",").replacingOccurrences(of: "，", with: ",")
            return (try? JSONDecoder().decode(JSONValue.self, from: Data(("[" + text + "]").utf8))) == value
        default: return false
        }
    }

    static func encoded<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? String(decoding: encoder.encode(value), as: UTF8.self)) ?? "null"
    }
}
