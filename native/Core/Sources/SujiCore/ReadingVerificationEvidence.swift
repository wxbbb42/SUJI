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
            switch name {
            case "get_today_context":
                for (key, path) in [("year", "yearGanZhi"), ("month", "monthGanZhi"), ("day", "dayGanZhi"), ("term", "solarTerm")] { add("calendar." + key, "/" + path) }
            case "get_domain":
                for column in ["year", "month", "day", "hour"] {
                    for part in ["gan", "zhi"] { add("bazi.\(column).\(part)", "/bazi/pillars/\(column)/ganZhi/\(part)") }
                    add("bazi.\(column).tenGod", "/bazi/pillars/\(column)/shiShen")
                }
                for (key, path) in [("pattern.status", "patternAnalysis/assessmentStatus"), ("pattern.stem", "patternAnalysis/yongShenGan"), ("pattern.element", "patternAnalysis/yongShen"), ("strength.status", "strengthReference/suggestionStatus"), ("strength.method", "strengthReference/suggestionBasis"), ("strength.element", "strengthReference/yongShen"), ("tiaohou.automatic", "tiaoHou/automatedSelection")] { add("bazi." + key, "/bazi/" + path) }
                for key in ["palace", "ganZhi", "mainStars", "minorStars"] { add("ziwei." + key, "/ziwei/" + key) }
            case "get_ziwei_palace":
                for key in ["palace", "ganZhi", "mainStars", "minorStars"] { add("ziwei." + key, "/" + key) }
            case "cast_liuyao":
                add("liuyao.castTime", "/castTime")
                for key in ["name", "upper", "lower"] {
                    add("liuyao.original." + key, "/benGua/" + key)
                    add("liuyao.changed." + key, "/bianGua/" + key)
                }
                for key in ["lineValues", "changingYao", "xunKong"] { add("liuyao." + key, "/" + key) }
                for index in 0..<6 {
                    for key in ["ganZhi", "liuQin", "liuShen", "isShi", "isYing", "isChanging", "isVoid", "monthClash", "dayClash"] { add("liuyao.line\(index + 1).\(key)", "/lines/\(index)/\(key)") }
                }
            case "setup_qimen":
                add("qimen.setupTime", "/setupTime")
                for key in ["yinYangDun", "juNumber", "yuan", "jieqi", "zhiFuStar", "zhiFuPalaceId", "zhiShiMen", "zhiShiPalaceId"] { add("qimen." + key, "/" + key) }
                if case let .array(palaces) = root["palaces"] {
                    for (index, palace) in palaces.enumerated() {
                        guard case let .object(p) = palace, case let .integer(id) = p["id"] else { continue }
                        for key in ["tianPanGan", "diPanGan", "bashen", "bamen", "jiuxing", "hostedTianPanGan"] { add("qimen.palace\(id).\(key)", "/palaces/\(index)/\(key)") }
                    }
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
