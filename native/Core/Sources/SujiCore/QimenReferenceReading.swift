import Foundation

/// Source-bound reference report. It does not adjudicate an event or calculate a chart.
public enum QimenReferenceReading {
    public struct Section: Encodable, Sendable {
        public let id: String
        public let text: String
        public let evidence: [BaziFrameworkReading.FieldEvidence]
    }
    public struct Report: Encodable, Sendable {
        public let sourceReceiptID: String
        public let sections: [Section]
        public var text: String { sections.map(\.text).joined(separator:"\n\n") }
    }
    public static let protocolVersion = "suji-qimen-reference-reading-1"
    public static func unavailableReply(receipts: [ToolReceipt]) -> String {
        let hasRecord = receipts.contains { receipt in
            guard receipt.name == "setup_qimen", receipt.output.utf8.count <= 60_000,
                  let root = try? CastReceiptStorage.expanded(receipt.output),
                  case let .object(object) = root, object["error"] == nil else { return false }
            return true
        }
        return hasRecord
            ? "本次计算记录缺少完整、相互一致的依据，暂时无法整理奇门参考对象。计算记录已保留；重试沿用原记录，不能靠重新起盘补出结论。"
            : "本次尚未取得可用的奇门计算记录，暂时无法整理参考对象或判断应期。"
    }

    public static func isExclusiveRequest(definitions: [ChatToolDefinition], question: String) -> Bool {
        // Capability filtering can remove natal tools in 起卦 mode. It must not
        // erase an explicit mixed-system request from the original question.
        let text = question.filter { !$0.isWhitespace }
        return definitions.count == 1 && definitions[0].name == "setup_qimen"
            && ReadingIntent.allowsQimen(question)
            && !["八字","四柱","紫微","紫薇","六爻","七政","星宿","占星"].contains(where:text.contains)
    }

    public static func render(receipts: [ToolReceipt], context: ToolContext) -> Report? {
        // One persisted cast plus up to eight reused planner calls.
        guard context.isValid, context.mode != "倾诉", !receipts.isEmpty, receipts.count <= 9 else { return nil }
        var roots: [JSONValue] = []
        for receipt in receipts {
            guard receipt.name == "setup_qimen", receipt.context == context,
                  !receipt.callID.isEmpty, receipt.callID.utf8.count <= 200,
                  receipt.output.utf8.count <= 60_000,
                  let root = try? CastReceiptStorage.expanded(receipt.output),
                  case let .object(object) = root, object["error"] == nil else { return nil }
            roots.append(root)
        }
        guard let root = roots.first, roots.allSatisfy({ $0 == root }) else { return nil }
        var builder = Builder(receipt:receipts[0],root:root,context:context)
        return try? builder.build()
    }

    private enum Incomplete: Error { case record }
    private static let stems = Set("甲乙丙丁戊己庚辛壬癸".map(String.init))
    private static let branches = Set("子丑寅卯辰巳午未申酉戌亥".map(String.init))
    private static let names = [1:"坎宫",2:"坤宫",3:"震宫",4:"巽宫",5:"中宫",6:"乾宫",7:"兑宫",8:"艮宫",9:"离宫"]
    private static let questionSource = "qimen-question-references-v1"

    private struct Builder {
        let receipt: ToolReceipt
        let root: JSONValue
        let context: ToolContext
        var sections: [Section] = []
        var palaceIndices: [Int:Int] = [:]
        func value(_ path: String) throws -> JSONValue {
            guard let value = ReadingVerificationEvidence.pointer(path,in:root) else { throw Incomplete.record }
            return value
        }
        func string(_ path: String) throws -> String {
            guard case let .string(text) = try value(path) else { throw Incomplete.record }; return text
        }
        func array(_ path: String) throws -> [JSONValue] {
            guard case let .array(items) = try value(path) else { throw Incomplete.record }; return items
        }
        func int(_ path: String) throws -> Int {
            guard case let .integer(number) = try value(path), let result = Int(exactly:number) else { throw Incomplete.record }; return result
        }
        func allowed(_ path: String, _ options: Set<String>) throws -> String {
            let result = try string(path); guard options.contains(result) else { throw Incomplete.record }; return result
        }
        func stem(_ path: String) throws -> String { try allowed(path,stems) }
        func ganZhi(_ path: String) throws -> String {
            let text = try string(path), parts = text.map(String.init)
            guard parts.count == 2, stems.contains(parts[0]), branches.contains(parts[1]) else { throw Incomplete.record }; return text
        }
        func name(_ id: Int) throws -> String {
            guard let text = names[id] else { throw Incomplete.record }; return text
        }
        func palace(_ id: Int) throws -> String {
            guard let index = palaceIndices[id] else { throw Incomplete.record }; return "/palaces/\(index)"
        }
        func source(_ id: String, edition: String) throws -> [String] {
            let sources = try array("/ruleSources")
            let found = try sources.indices.filter { try string("/ruleSources/\($0)/id") == id }
            guard found.count == 1 else { throw Incomplete.record }
            let path = "/ruleSources/\(found[0])"
            guard try string(path + "/version") == "1", try string(path + "/editionStatus") == edition else { throw Incomplete.record }
            return [path + "/id",path + "/version",path + "/editionStatus",path + "/references"]
        }
        mutating func append(_ id: String, _ text: String, _ paths: [String]) throws {
            var seen = Set<String>()
            let evidence = try paths.filter { seen.insert($0).inserted }.map {
                BaziFrameworkReading.FieldEvidence(toolCallID:receipt.callID,pointer:$0,value:try value($0))
            }
            guard !evidence.isEmpty else { throw Incomplete.record }
            sections.append(Section(id:id,text:text,evidence:evidence))
        }
        mutating func build() throws -> Report {
            guard try string("/provenance/engineRevision") == context.engineRevision,
                  try string("/method/algorithm") == "zhuanpan-qimen-chai-bu-v1",
                  try string("/method/centerPolicy") == "fixed-kun-2; tian-qin-follows-tian-rui" else { throw Incomplete.record }
            let timestamp = try string("/setupTime")
            let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
            let time = iso.date(from:timestamp) ?? ISO8601DateFormatter().date(from:timestamp)
            // ChatSession preserves the full question Date but serializes `now`
            // at whole-second precision. Compare to that exact request instant.
            let wireClock = ISO8601DateFormatter()
            let requestedTime = wireClock.date(from:wireClock.string(from:context.referenceDate))
            guard let time, time == requestedTime else { throw Incomplete.record }
            let palaces = try array("/palaces")
            guard palaces.count == 9 else { throw Incomplete.record }
            for index in palaces.indices {
                let id = try int("/palaces/\(index)/id")
                guard names[id] != nil, palaceIndices[id] == nil else { throw Incomplete.record }
                palaceIndices[id] = index
            }
            let day = try ganZhi("/dayGanZhi"), hour = try ganZhi("/hourGanZhi")
            let dun = try allowed("/yinYangDun",["阴","阳"]), ju = try int("/juNumber")
            guard (1...9).contains(ju) else { throw Incomplete.record }
            let yuan = try allowed("/yuan",["上","中","下"])
            let clock = try allowed("/method/clockPolicy",["beijing-standard","apparent-solar"])
            let clockText = clock == "beijing-standard" ? "北京时间标准时" : "本次指定经度的真太阳时"
            try append("chart","本次奇门盘：\(dun)遁\(ju)局，\(yuan)元；日柱\(day)，时柱\(hour)。日时按\(clockText)，采用拆补法、中五固定寄坤二、天禽随天芮。",
                       ["/setupTime","/dayGanZhi","/hourGanZhi","/yinYangDun","/juNumber","/yuan","/method/algorithm","/method/centerPolicy","/method/clockPolicy","/provenance/engineRevision"])

            let provenance = try source(questionSource,edition:"product-policy")
            guard try string("/yongShen/sourceId") == questionSource,
                  try value("/yongShen/selectionEstablished") == .bool(false), try value("/yongShen/selectedCandidateId") == .null else { throw Incomplete.record }
            let candidates = try array("/yongShen/candidates")
            guard (2...5).contains(candidates.count) else { throw Incomplete.record }
            var seen = Set<String>(), roles = Set<String>(), categoryCount = 0
            for index in candidates.indices {
                let path = "/yongShen/candidates/\(index)", id = try string(path + "/id")
                guard seen.insert(id).inserted else { throw Incomplete.record }
                let role = try allowed(path + "/role",["day-reference","hour-reference","category-reference"])
                let symbol = try string(path + "/symbol")
                let isStem = role != "category-reference"
                let carrier: String, fields: [String], heading: String
                var paths = [path + "/id",path + "/role",path + "/symbol",path + "/occurrences"] + provenance
                if isStem {
                    guard roles.insert(role).inserted, id == (role == "day-reference" ? "day-stem" : "hour-stem"), stems.contains(symbol) else { throw Incomplete.record }
                    let calendarPath = role == "day-reference" ? "/dayGanZhi" : "/hourGanZhi"
                    guard try string(path + "/calendarPath") == calendarPath, try string(calendarPath).hasPrefix(symbol) else { throw Incomplete.record }
                    carrier = try stem(path + "/carrierStem")
                    guard try string(path + "/carrierMethod") == (symbol == "甲" ? "own-pillar-xun" : "direct-stem"), symbol == "甲" || carrier == symbol else { throw Incomplete.record }
                    if symbol == "甲" {
                        let ownPillar = try string(calendarPath)
                        guard ["甲子":"戊","甲戌":"己","甲申":"庚","甲午":"辛","甲辰":"壬","甲寅":"癸"][ownPillar] == carrier else { throw Incomplete.record }
                    }
                    fields = ["diPanGan","hostedDiPanGan","tianPanGan","hostedTianPanGan"]
                    heading = (role == "day-reference" ? "日干" : "时干") + symbol + (symbol == "甲" ? "（按本柱旬仪\(carrier)定位，生克仍用甲木）" : "")
                    paths += [calendarPath,path + "/calendarPath",path + "/carrierStem",path + "/carrierMethod"]
                } else {
                    categoryCount += 1
                    let options: [(String,String,Set<String>)] = [
                        ("door","bamen",["休门","生门","伤门","杜门","景门","死门","惊门","开门"]),
                        ("deity","bashen",["值符","腾蛇","太阴","六合","白虎","玄武","九地","九天"]),
                        ("star","jiuxing",["天蓬","天芮","天冲","天辅","天禽","天心","天柱","天任","天英"]),
                    ]
                    guard let option = options.first(where: { id == "category-\($0.0)-\(symbol)" && $0.2.contains(symbol) }) else { throw Incomplete.record }
                    fields = [option.1]; carrier = symbol; heading = "事项类别参考\(symbol)"
                }
                var expected: [String:(Int,String)] = [:]
                for (pid,pindex) in palaceIndices where isStem || pid != 5 {
                    for field in fields {
                        let p = "/palaces/\(pindex)/\(field)"
                        guard ReadingVerificationEvidence.pointer(p,in:root) == .string(carrier) else { continue }
                        let plate = field == "tianPanGan" && pid == 5 ? "center-record" : ["diPanGan":"earth","hostedDiPanGan":"hosted-earth","tianPanGan":"sky","hostedTianPanGan":"hosted-sky","bamen":"door","bashen":"deity","jiuxing":"star"][field]!
                        expected[p] = (pid,plate)
                    }
                }
                var descriptions: [String] = [], referenced = Set<String>()
                let occurrences = try array(path + "/occurrences")
                for occurrence in occurrences.indices {
                    let p = path + "/occurrences/\(occurrence)", pointer = try string(p + "/objectPath")
                    guard referenced.insert(pointer).inserted, let (pid,plate) = expected[pointer],
                          try int(p + "/palaceId") == pid, try string(p + "/plate") == plate else { throw Incomplete.record }
                    if isStem {
                        guard try value(p + "/isEffectiveSky") == .bool(plate == "sky" || plate == "hosted-sky") else { throw Incomplete.record }
                    }
                    let label = ["earth":"地盘","hosted-earth":"地盘寄干","sky":"天盘","hosted-sky":"天禽寄干","center-record":"中宫留存记录","door":"门","deity":"神","star":"星"][plate]!
                    descriptions.append("\(isStem ? label : "")\(carrier)在\(try name(pid))")
                    paths += [pointer,try palace(pid) + "/id",p + "/objectPath",p + "/plate",p + "/palaceId"]
                }
                guard referenced == Set(expected.keys) else { throw Incomplete.record }
                let locations = descriptions.isEmpty ? "本次未返回对应位置" : descriptions.joined(separator:"；")
                try append(id,"\(heading)：\(locations)。这是独立参考，尚未定用。",paths)
            }
            guard roles == Set(["day-reference","hour-reference"]) else { throw Incomplete.record }
            if categoryCount == 0 {
                try append("category-absence","本次没有单列事项类别候选，事项对象仍未选定。",["/yongShen/candidates","/yongShen/selectedCandidateId"] + provenance)
            }

            let center = try palace(5), earthHost = try palace(2), hostedID = try int("/tianQinPalaceId"), skyHost = try palace(hostedID)
            guard hostedID != 5 else { throw Incomplete.record }
            let earthStem = try stem(earthHost + "/hostedDiPanGan"), skyStem = try stem(skyHost + "/hostedTianPanGan")
            guard try stem(center + "/diPanGan") == earthStem, earthStem == skyStem,
                  try value(skyHost + "/hostsTianQin") == .bool(true),
                  try string(skyHost + "/jiuxing") == "天芮" else { throw Incomplete.record }
            for (pid,index) in palaceIndices {
                let p = "/palaces/\(index)"
                _ = try stem(p + "/diPanGan"); _ = try stem(p + "/tianPanGan")
                if pid != 2, ReadingVerificationEvidence.pointer(p + "/hostedDiPanGan",in:root) != nil { throw Incomplete.record }
                if pid != hostedID {
                    guard ReadingVerificationEvidence.pointer(p + "/hostedTianPanGan",in:root) == nil,
                          ReadingVerificationEvidence.pointer(p + "/hostsTianQin",in:root) == nil,
                          ReadingVerificationEvidence.pointer(p + "/jiuxing",in:root) != .string("天芮") else { throw Incomplete.record }
                }
            }
            try append("hosted-plates","地盘寄干\(earthStem)在坤宫；天禽寄干\(skyStem)在\(try name(hostedID))。地盘寄干固定寄坤，天禽寄干随天禽转动；中宫保留记录，不另算一处有效天盘。",
                       [earthHost + "/id",earthHost + "/hostedDiPanGan",skyHost + "/id",skyHost + "/hostedTianPanGan",skyHost + "/hostsTianQin",skyHost + "/jiuxing",center + "/diPanGan","/tianQinPalaceId","/method/centerPolicy"])
            let missing = try array("/yongShen/missingContext").map { item -> String in
                guard case let .string(key) = item, let text = ["subject":"所问对象","event":"具体事件","time-horizon":"时间范围","proxy-perspective":"代占的取用视角","category-subject-conflict":"问题类别与所问对象的冲突","day-sky-reference":"日干的有效天盘参考","hour-sky-reference":"时干的有效天盘参考"][key] else { throw Incomplete.record }
                return text
            }
            guard try string("/yongShen/selectionStatus") == (missing.isEmpty ? "candidates-only" : "requires-clarification") else { throw Incomplete.record }
            let pending = missing.isEmpty ? "" : "本次计算记录尚缺：" + missing.joined(separator:"、") + "。"
            try append("reference-policy","日干、时干和事项候选采用产品参考约定，各有自己的盘层位置；同干也不合并身份。\(pending)这些基础候选尚未整体定用；若下方提供条件应期，仅按其明确选定的对象与适用规则核对，不能通过自行选宫得出结论。",
                       ["/yongShen/selectionStatus","/yongShen/selectionEstablished","/yongShen/selectedCandidateId","/yongShen/missingContext","/yongShen/sourceId"] + provenance)
            guard try string("/yingQi/assessmentStatus") == "unresolved", try value("/yingQi/outcomeEstablished") == .bool(false),
                  try string("/yingQi/timeScale") == "unresolved", try string("/yingQi/sourceId") == questionSource,
                  try array("/yingQi/triggers").isEmpty, try array("/yingQi/dates").isEmpty else { throw Incomplete.record }
            if ReadingVerificationEvidence.pointer("/timing",in:root) != nil {
                guard let timing = QimenTimingEvidence.read(root:root) else { throw Incomplete.record }
                try append("timing",timing.text,timing.evidencePaths)
            } else {
                guard !((try array("/ruleSources")).contains { ReadingVerificationEvidence.pointer("/id",in:$0) == "qimen-xdyy-timing-v1" }) else { throw Incomplete.record }
                try append("timing","事件成败和应期仍未确定，不能确定日期。本次没有可用的应期触发或日期，不按宫数推天数，也不套用六爻应期。",
                           ["/yingQi/assessmentStatus","/yingQi/outcomeEstablished","/yingQi/timeScale","/yingQi/sourceId","/yingQi/triggers","/yingQi/dates","/yingQi/unresolved"] + provenance)
            }
            return Report(sourceReceiptID:receipt.callID,sections:sections)
        }
    }
}
