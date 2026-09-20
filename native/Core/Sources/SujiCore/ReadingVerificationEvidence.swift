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
            func add(_ key: String, _ path: String) {
                guard let value = pointer(path, in: object), value != .null else { return }
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
                sources("ziwei", base)
            }
            switch name {
            case "get_today_context":
                for (key, path) in [("year", "yearGanZhi"), ("month", "monthGanZhi"), ("day", "dayGanZhi"), ("term", "solarTerm")] { add("calendar." + key, "/" + path) }
            case "get_domain":
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
                for (layer, path) in [("annual", "/annual/transformations"), ("decadal", "/decadalTransformations")] {
                    if case let .array(transformations) = pointer(path, in: object) {
                        for index in transformations.indices {
                            fields("ziwei.timing.\(layer).transformation\(index + 1)", "\(path)/\(index)", ["scope", "sourceStem", "star", "transformation", "targetPalace", "targetPosition", "sourceId"])
                        }
                    }
                }
                fields("ziwei.timing.method", "/method", ["algorithm", "civilTimeZone", "dayBoundary", "yearBoundary", "ageConvention"])
                sources("ziwei.timing")
            case "cast_liuyao":
                add("liuyao.castTime", "/castTime")
                fields("liuyao.calendar", "/castGanZhi", ["month", "day", "hour"])
                fields("liuyao.method", "/method", ["algorithm", "calendar", "dayBoundary", "caveats"])
                fields("liuyao.yongShen", "/yongShen", ["type", "yaoIndex", "wuXing", "state", "candidateYaoIndices"])
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
                }
            case "setup_qimen":
                add("qimen.setupTime", "/setupTime")
                for key in ["yinYangDun", "juNumber", "yuan", "jieqi", "zhiFuStar", "zhiFuPalaceId", "zhiShiMen", "zhiShiPalaceId", "fuTou", "zhiFuSourcePalaceId", "zhiShiSourcePalaceId", "zhiShiRawPalaceId", "tianQinPalaceId", "dayGanZhi", "hourGanZhi", "monthGanZhi", "calculationTime", "trueSolarTime"] { add("qimen." + key, "/" + key) }
                fields("qimen.method", "/method", ["algorithm", "centerPolicy", "dayBoundary", "solarTermClock", "clockPolicy", "timezone", "longitude", "caveats"])
                fields("qimen.hourVoid", "/hourVoid", ["scope", "ganZhi", "xun", "branches", "sourceId"])
                fields("qimen.horse", "/horse", ["scope", "ganZhi", "branch", "palaceId", "sourceId"])
                fields("qimen.yongShen", "/yongShen", ["type", "palaceId", "state", "selectionStatus"])
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
                        fields(key, path, ["tianPanGan", "diPanGan", "bashen", "bamen", "jiuxing", "hostedTianPanGan", "wuXing", "hostsTianQin"])
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
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? String(decoding: encoder.encode(value), as: UTF8.self)) ?? "null"
    }
}
