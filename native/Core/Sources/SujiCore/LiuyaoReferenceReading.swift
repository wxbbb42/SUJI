import Foundation

/// Projects saved cast facts and independently verifies optional source-selected
/// efficacy. It never calculates a new cast or invents an event date.
public enum LiuyaoReferenceReading {
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
    public static let protocolVersion = "suji-liuyao-reference-reading-1"
    public static func isExclusiveRequest(definitions: [ChatToolDefinition], question: String) -> Bool {
        let text = ReadingIntent.normalizedMethods(question).filter { !$0.isWhitespace }
        guard text.range(of:"(?:不要|不用|不需要|无需|别)[^，,。；;！？]{0,12}(?:起卦|六爻)",options:.regularExpression) == nil,
              text.range(of:"(?:什么是|介绍|解释|讲解|学习)(?:用)?六爻|六爻(?:是什么|的含义|怎么|如何)",options:.regularExpression) == nil else { return false }
        let considered = text.replacingOccurrences(of:"(?:^|[，,。；;])(?:不要|不用|不需要|无需|别)(?:用|看|讲|谈)?(?:八字|四柱|紫微|紫薇|奇门|七政|星宿|占星)(?:了)?(?=$|[，,。；;])",with:"",options:.regularExpression)
        return definitions.count == 1 && definitions[0].name == "cast_liuyao"
            && !["八字","四柱","紫微","紫薇","奇门","七政","星宿","占星"].contains(where:considered.contains)
    }
    public static func unavailableReply(receipts: [ToolReceipt]) -> String {
        let present = receipts.contains { receipt in
            guard receipt.name == "cast_liuyao", let root = try? LiuyaoReceiptStorage.expanded(receipt.output),
                  case let .object(object) = root, object["error"] == nil else { return false }
            return true
        }
        return present
            ? "本次卦记录缺少完整、相互一致的依据，暂时无法整理六爻解读。原记录已保留；重试沿用原卦，不能靠重新起卦补出结论。"
            : "本次尚未取得可用的六爻计算记录，暂时无法判断用神或应期。"
    }
    public static func render(receipts: [ToolReceipt], context: ToolContext, referenceOnly: Bool = false) -> Report? {
        // One persisted cast plus up to eight reused planner calls.
        guard context.isValid, context.mode != "倾诉", (1...9).contains(receipts.count) else { return nil }
        var roots: [JSONValue] = []
        for receipt in receipts {
            guard receipt.name == "cast_liuyao", receipt.context == context,
                  !receipt.callID.isEmpty, receipt.callID.utf8.count <= 200, receipt.output.utf8.count <= 60_000,
                  let root = try? LiuyaoReceiptStorage.expanded(receipt.output),
                  case let .object(object) = root, object["error"] == nil else { return nil }
            roots.append(root)
        }
        guard let root = roots.first, roots.allSatisfy({$0 == root}) else { return nil }
        var builder = Builder(receipt:receipts[0],root:root,context:context)
        // Validate the complete report before narrowing presentation. Reference-only
        // mode cannot make a forged event layer acceptable or discard stored evidence.
        guard let report = try? builder.build() else { return nil }
        return referenceOnly ? Report(sourceReceiptID: report.sourceReceiptID,
                                      sections: report.sections.filter { !$0.id.hasPrefix("event-") }) : report
    }
    private enum Incomplete: Error { case record }
    private static let branches = Set("子丑寅卯辰巳午未申酉戌亥".map(String.init))
    private static let stems = Set("甲乙丙丁戊己庚辛壬癸".map(String.init))
    private static let elements = Set("木火土金水".map(String.init))
    private static let kin: Set<String> = ["父母","兄弟","子孙","妻财","官鬼"]
    private static let calendarSource = "liuyao-calendar-relations-v1"
    private static let questionSource = "liuyao-question-timing-v1"
    private static let roleSource = "liuyao-candidate-roles-v1"
    private static let labels: [String:String] = [
        "changed-void":"变爻旬空","changed-month-break":"变爻月破","changed-day-clash":"变爻日冲","combined-effectiveness":"综合效力",
        "changed-month-generation":"月生变爻","changed-day-support":"日扶变爻","original-day-presence":"本爻临日",
        "hidden-month-generation":"月生伏神","hidden-day-generation":"日生伏神","flying-generates-hidden":"飞生伏","moving-generates-hidden":"动爻生伏",
        "calendar-challenges-flying":"日月冲克飞神","moving-challenges-flying":"动爻冲克飞神","flying-void":"飞神旬空","flying-month-break":"飞神月破",
        "hidden-month-clash":"伏神月冲","hidden-day-clash":"伏神日冲","hidden-month-control":"月克伏神","hidden-day-control":"日克伏神",
        "flying-controls-hidden":"飞克伏","hidden-void":"伏神旬空","hidden-combined-strength":"伏神综合旺衰","flying-combined-strength":"飞神综合旺衰",
        "hidden-tomb-or-extinction":"伏神墓绝","flying-tomb-or-extinction":"飞神墓绝","static-line":"静爻前提","day-clash":"日冲",
        "month-support":"月扶","day-support":"日扶","month-control":"月克","moving-generation":"动爻生扶","moving-control":"动爻克制",
        "void-clash":"冲空","combined-strength":"综合旺衰","moving-actors-effectiveness":"施动爻效力",
        "selected-object":"选用对象","event-outcome":"事件成败","combined-efficacy":"综合效力","binding":"合住效力",
        "dark-movement":"暗动条件","hidden-emergence":"能否出伏","calendar-object-timing":"日月对象的应期适用性",
        "subject":"所问对象","event":"具体事件","time-horizon":"时间范围","question-object":"事项取用视角",
        "category-subject-conflict":"问题类别与对象的冲突","proxy-perspective":"代占取用视角"
    ]
    private struct Builder {
        let receipt: ToolReceipt
        let root: JSONValue
        let context: ToolContext
        var sections: [Section] = []
        var sourcePaths: [String:[String]] = [:]
        func value(_ p: String) throws -> JSONValue {
            guard let v = ReadingVerificationEvidence.pointer(p,in:root) else { throw Incomplete.record };return v
        }
        func string(_ p: String) throws -> String { guard case let .string(v) = try value(p) else { throw Incomplete.record };return v }
        func array(_ p: String) throws -> [JSONValue] { guard case let .array(v) = try value(p) else { throw Incomplete.record };return v }
        func int(_ p: String) throws -> Int { guard case let .integer(v) = try value(p),let n=Int(exactly:v) else { throw Incomplete.record };return n }
        func bool(_ p: String) throws -> Bool { guard case let .bool(v) = try value(p) else { throw Incomplete.record };return v }
        func allowed(_ p: String, _ options: Set<String>) throws -> String { let s=try string(p);guard options.contains(s) else { throw Incomplete.record };return s }
        func strings(_ p: String) throws -> [String] { try array(p).map { guard case let .string(s)=$0 else { throw Incomplete.record };return s } }
        func ganZhi(_ p: String) throws -> String {
            let s=try string(p),parts=s.map(String.init)
            guard parts.count == 2,stems.contains(parts[0]),branches.contains(parts[1]) else { throw Incomplete.record };return s
        }
        func source(_ p: String, expected: String) throws -> [String] {
            guard try string(p) == expected,let paths=sourcePaths[expected] else { throw Incomplete.record };return [p]+paths
        }
        func terms(_ p: String) throws -> String {
            try strings(p).map { guard let label=labels[$0] else { throw Incomplete.record };return label }.joined(separator:"、")
        }
        mutating func append(_ id: String, _ text: String, _ paths: [String]) throws {
            var seen=Set<String>()
            let evidence=try paths.filter{seen.insert($0).inserted}.map { BaziFrameworkReading.FieldEvidence(toolCallID:receipt.callID,pointer:$0,value:try value($0)) }
            guard !evidence.isEmpty else { throw Incomplete.record }
            sections.append(.init(id:id,text:text,evidence:evidence))
        }
        mutating func build() throws -> Report {
            guard try string("/provenance/engineRevision") == context.engineRevision,
                  try string("/method/algorithm") == "jingfang-najia-v1" else { throw Incomplete.record }
            let stamp=try string("/castTime"),fractional=ISO8601DateFormatter();fractional.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
            let clock=ISO8601DateFormatter()
            guard let time=fractional.date(from:stamp) ?? clock.date(from:stamp),time == clock.date(from:clock.string(from:context.referenceDate)) else { throw Incomplete.record }
            let sources=try array("/ruleSources")
            let hasRoles = ReadingVerificationEvidence.pointer("/roleRelations",in:root) != nil
            let hasRoleSource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(roleSource) }
            guard hasRoles == hasRoleSource else { throw Incomplete.record }
            let hasTombs = ReadingVerificationEvidence.pointer("/tombExtinction",in:root) != nil
            let hasTombSource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(LiuyaoTombExtinctionTrace.sourceID) }
            guard hasTombs == hasTombSource else { throw Incomplete.record }
            let hasFanfu = ReadingVerificationEvidence.pointer("/fanfu",in:root) != nil
            let hasFanfuSource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(LiuyaoFanfuTrace.sourceID) }
            guard hasFanfu == hasFanfuSource else { throw Incomplete.record }
            let hasTriads = ReadingVerificationEvidence.pointer("/triads",in:root) != nil
            let hasTriadSource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(LiuyaoTriadTrace.sourceID) }
            guard hasTriads == hasTriadSource, !hasTriads || (hasFanfu && hasTombs) else { throw Incomplete.record }
            let hasEfficacy = ReadingVerificationEvidence.pointer("/efficacy",in:root) != nil
            let hasEfficacySource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(LiuyaoEfficacyEvidence.sourceID) }
            guard hasEfficacy == hasEfficacySource, !hasEfficacy || (hasRoles && hasTombs && hasFanfu && hasTriads) else { throw Incomplete.record }
            let hasEvent = ReadingVerificationEvidence.pointer("/eventAssessment",in:root) != nil
            let hasEventSource = sources.contains { ReadingVerificationEvidence.pointer("/id",in:$0) == .string(LiuyaoEventAssessment.sourceID) }
            guard hasEvent == hasEventSource, !hasEvent || hasEfficacy else { throw Incomplete.record }
            var accepted: [String] = [calendarSource, questionSource, "liuyao-changing-relations-v1", "liuyao-flying-hidden-v1", "liuyao-day-clash-v1"]
            if hasRoles { accepted.append(roleSource) }
            if hasTombs { accepted.append(LiuyaoTombExtinctionTrace.sourceID) }
            if hasFanfu { accepted.append(LiuyaoFanfuTrace.sourceID) }
            if hasTriads { accepted.append(LiuyaoTriadTrace.sourceID) }
            if hasEfficacy { accepted.append(LiuyaoEfficacyEvidence.sourceID) }
            if hasEvent { accepted.append(LiuyaoEventAssessment.sourceID) }
            for i in sources.indices {
                let p="/ruleSources/\(i)",id=try string(p+"/id")
                guard accepted.contains(id),sourcePaths[id] == nil,
                      try string(p+"/editionStatus") == "electronic-transcription-not-print-collated",
                      try (id == calendarSource ? Set(["1","2"]) : Set(["1"])).contains(string(p+"/version")),
                      !(try array(p+"/references")).isEmpty else { throw Incomplete.record }
                try validateReferences(p+"/references",source:id)
                sourcePaths[id]=[p+"/id",p+"/version",p+"/editionStatus",p+"/references"]
            }
            guard Set(sourcePaths.keys) == Set(accepted),try array("/lines").count == 6,try array("/lineValues").count == 6 else { throw Incomplete.record }
            let moving=try array("/changingYao"),shi=try int("/shiYao"),ying=try int("/yingYao")
            guard (1...6).contains(shi),(1...6).contains(ying),shi != ying else { throw Incomplete.record }
            var actualMoving: [JSONValue]=[]
            for i in 0..<6 {
                let p="/lines/\(i)",v=try int("/lineValues/\(i)")
                guard try int(p+"/position") == i+1,try int(p+"/value") == v,(6...9).contains(v),
                      try bool(p+"/isChanging") == (v == 6 || v == 9),
                      try bool(p+"/isShi") == (shi == i+1),try bool(p+"/isYing") == (ying == i+1) else { throw Incomplete.record }
                if v == 6 || v == 9 { actualMoving.append(.integer(Int64(i+1))) }
            }
            guard moving == actualMoving else { throw Incomplete.record }
            let original=try string("/benGua/name"),changed=try string("/bianGua/name")
            guard !original.isEmpty,original.count <= 5,!changed.isEmpty,changed.count <= 5 else { throw Incomplete.record }
            let month=try ganZhi("/castGanZhi/month"),day=try ganZhi("/castGanZhi/day"),hour=try ganZhi("/castGanZhi/hour")
            let void=try strings("/xunKong");guard void.count == 2,Set(void).count == 2,void.allSatisfy(branches.contains) else { throw Incomplete.record }
            let moveText=actualMoving.isEmpty ? "静卦，无明动爻" : "明动爻位" + actualMoving.compactMap { if case let .integer(v)=$0 { return String(v) };return nil }.joined(separator:"、")
            try append("chart","本次六爻：\(original)→\(changed)，\(moveText)。月建\(month)，日辰\(day)，时柱\(hour)，旬空\(void.joined(separator:"、"))；世在第\(shi)爻，应在第\(ying)爻。",["/benGua/name","/bianGua/name","/castTime","/castGanZhi","/xunKong","/changingYao","/lineValues","/shiYao","/yingYao","/method","/provenance/engineRevision"])
            if ReadingVerificationEvidence.pointer("/guaRelations",in:root) != nil {
                let p="/guaRelations",o=try allowed(p+"/original/kind",["六合","六冲","ordinary"]),r=try allowed(p+"/resulting/kind",["六合","六冲","ordinary"])
                guard try string(p+"/assessmentStatus") == "structural-only",try bool(p+"/outcomeEstablished") == false,
                      try bool(p+"/transition/hasChange") == !actualMoving.isEmpty else { throw Incomplete.record }
                let transition=try allowed(p+"/transition/kind",["static","other-change","六合变六合","六合变六冲","六冲变六合","六冲变六冲"])
                let expected=actualMoving.isEmpty ? "static" : o != "ordinary" && r != "ordinary" ? o+"变"+r : "other-change"
                guard transition == expected else { throw Incomplete.record }
                let kindText=transition == "static" ? "静卦" : transition == "other-change" ? "不属于整卦冲合互变" : transition
                try append("gua-relations","整卦支关系：本卦\(o == "ordinary" ? "非六合六冲" : o)，完整变卦\(r == "ordinary" ? "非六合六冲" : r)，\(kindText)。完整变卦投影不代表六爻全部发动；结构冲合尚不能确定事件成败。",[p] + source(p+"/sourceId",expected:calendarSource))
            }
            for i in 0..<6 { try line(i) }
            if hasTombs {
                sections += try LiuyaoTombExtinctionTrace.sections(root:root,receiptID:receipt.callID,sourcePaths:sourcePaths[LiuyaoTombExtinctionTrace.sourceID]!)
            }
            if hasFanfu {
                sections += try LiuyaoFanfuTrace.sections(root:root,receiptID:receipt.callID,sourcePaths:sourcePaths[LiuyaoFanfuTrace.sourceID]!)
            }
            if hasTriads {
                sections += try LiuyaoTriadTrace.sections(root:root,receiptID:receipt.callID,sourcePaths:sourcePaths[LiuyaoTriadTrace.sourceID]!)
            }
            try selectionAndTiming()
            if hasRoles { try candidateRoles() }
            if hasEfficacy {
                sections += try LiuyaoEfficacyEvidence.sections(root:root,receiptID:receipt.callID,sourcePaths:sourcePaths[LiuyaoEfficacyEvidence.sourceID]!)
            }
            if hasEvent {
                sections += try LiuyaoEventAssessment.sections(root:root,receiptID:receipt.callID,sourcePaths:sourcePaths[LiuyaoEventAssessment.sourceID]!)
            }
            return Report(sourceReceiptID:receipt.callID,sections:sections)
        }
        func object(_ p: String, label: String, paths: inout [String]) throws -> String {
            let gz=try ganZhi(p+"/ganZhi"),wx=try allowed(p+"/wuXing",elements),q=try allowed(p+"/liuQin",kin)
            paths += [p+"/ganZhi",p+"/wuXing",p+"/liuQin"]
            return "\(label)\(gz)\(wx)（\(q)）"
        }
        func calendar(_ p: String, paths: inout [String]) throws -> String {
            var text: [String]=[]
            let empty=try bool(p+"/isVoid");text.append(empty ? "旬空" : "不空");paths.append(p+"/isVoid")
            if ReadingVerificationEvidence.pointer("/lineContextPolicy",in:root) != nil {
                guard try string("/lineContextPolicy/assessmentStatus") == "calendar-relations-only",try strings("/lineContextPolicy/sourceIds") == [calendarSource] else { throw Incomplete.record }
                paths.append("/lineContextPolicy")
            } else {
                guard try string(p+"/assessmentStatus") == "calendar-relations-only",try strings(p+"/sourceIds") == [calendarSource] else { throw Incomplete.record }
                paths += [p+"/assessmentStatus",p+"/sourceIds"]
            }
            for (scope,label) in [("month","月"),("day","日")] {
                let b=p+"/"+scope,branch=try allowed(b+"/branch",branches),rel=try allowed(b+"/elementRelation",["同类","生爻","克爻","爻生","爻克"])
                let same=try bool(b+"/sameBranch"),clash=try bool(b+"/clash"),combination=try bool(b+"/combination")
                text.append("\(label)支\(branch)：\(rel)" + (same ? "、临\(label)" : "") + (clash ? "、\(label)冲" : "") + (combination ? "、\(label)合" : ""))
                paths += [b+"/branch",b+"/elementRelation",b+"/sameBranch",b+"/clash",b+"/combination"]
            }
            paths += sourcePaths[calendarSource]!
            return text.joined(separator:"；")
        }
        func conditions(_ p: String, paths: inout [String]) throws -> String {
            var grouped: [String:[String]]=[:],seen=Set<String>()
            let expected=try expectedConditions(p),items=try array(p)
            guard items.count == expected.count else { throw Incomplete.record }
            for i in items.indices {
                let c=p+"/\(i)",id=try string(c+"/id")
                guard let label=labels[id],seen.insert(id).inserted else { throw Incomplete.record }
                let state=try allowed(c+"/state",["matched","not-matched","unresolved"]),facts=try strings(c+"/factPaths")
                guard let (test,expectedPaths)=expected[id],facts == expectedPaths,
                      state == (test.map { $0 ? "matched" : "not-matched" } ?? "unresolved") else { throw Incomplete.record }
                for fact in facts { guard fact.hasPrefix("/lines/") || fact == "/changingYao" else { throw Incomplete.record };_ = try value(fact) }
                grouped[state,default:[]].append(label);paths += [c+"/id",c+"/state",c+"/factPaths"]+facts
            }
            return [("matched","已满足"),("not-matched","未满足"),("unresolved","未裁定")].compactMap { key,label in
                guard let items=grouped[key],!items.isEmpty else { return nil };return label+"："+items.joined(separator:"、")
            }.joined(separator:"；")
        }
        mutating func line(_ i: Int) throws {
            let p="/lines/\(i)",moving=try bool(p+"/isChanging")
            var paths=[p+"/position",p+"/isChanging"],parts: [String]=[]
            parts.append("第\(i+1)爻：" + (try object(p,label:"本爻",paths:&paths)) + (moving ? "明动" : "静爻") + "；" + (try calendar(p+"/context",paths:&paths)))
            if moving {
                let c=p+"/changed",r=p+"/rules/returning",a=p+"/rules/advanceRetreat"
                parts.append(try object(c,label:"变爻",paths:&paths) + "；" + calendar(c+"/context",paths:&paths))
                guard try string(r+"/from") == c,try string(r+"/to") == p,try string(r+"/conditionsFrom") == a+"/conditions",
                      try string(a+"/from") == p,try string(a+"/to") == c else { throw Incomplete.record }
                let relation=try allowed(r+"/relation",["比和","回头生","回头克","本爻生变","本爻克变"]),advance=try allowed(a+"/kind",["进神","退神","not-listed"])
                let originalElement=try string(p+"/wuXing"),changedElement=try string(c+"/wuXing")
                let sheng=["木":"火","火":"土","土":"金","金":"水","水":"木"],ke=["木":"土","土":"水","水":"火","火":"金","金":"木"]
                let expectedRelation=changedElement == originalElement ? "比和" : sheng[changedElement] == originalElement ? "回头生" : ke[changedElement] == originalElement ? "回头克" : sheng[originalElement] == changedElement ? "本爻生变" : "本爻克变"
                let originalBranch=String((try ganZhi(p+"/ganZhi")).suffix(1)),changedBranch=String((try ganZhi(c+"/ganZhi")).suffix(1))
                let advancePairs=["亥子","寅卯","巳午","申酉","丑辰","辰未","未戌"]
                let expectedAdvance=advancePairs.contains(originalBranch+changedBranch) ? "进神" : advancePairs.contains(changedBranch+originalBranch) ? "退神" : "not-listed"
                guard relation == expectedRelation,advance == expectedAdvance,
                      try string(a+"/fromBranch") == originalBranch,try string(a+"/toBranch") == changedBranch else { throw Incomplete.record }
                paths += [r+"/from",r+"/to",r+"/relation",r+"/conditionsFrom",a+"/kind",a+"/from",a+"/to"] + (try source(r+"/sourceId",expected:"liuyao-changing-relations-v1")) + (try source(a+"/sourceId",expected:"liuyao-changing-relations-v1"))
                var relationText="同位动化五行关系：\(relation)；" + (advance == "not-listed" ? "未列入所选七组进退表" : advance+"结构")
                if ReadingVerificationEvidence.pointer(r+"/branchRelation",in:root) != nil {
                    let branch=try allowed(r+"/branchRelation",["六合","六冲","同支","neither"])
                    let from=String((try ganZhi(p+"/ganZhi")).suffix(1)),to=String((try ganZhi(c+"/ganZhi")).suffix(1))
                    let combination=try paired(from,combine:true),clash=try paired(from,combine:false)
                    guard branch == (to == combination ? "六合" : to == clash ? "六冲" : from == to ? "同支" : "neither") else { throw Incomplete.record }
                    relationText += "；支关系"+(branch == "neither" ? "非六合六冲且不同支" : branch)
                    paths += [r+"/branchRelation"] + (try source(r+"/branchSourceId",expected:calendarSource))
                }
                parts.append(relationText+"，效力未裁定")
                parts.append(try conditions(a+"/conditions",paths:&paths));parts.append(try conditions(r+"/conditions",paths:&paths))
            } else if ReadingVerificationEvidence.pointer(p+"/changed",in:root) != nil || ReadingVerificationEvidence.pointer(p+"/rules/returning",in:root) != nil { throw Incomplete.record }
            if ReadingVerificationEvidence.pointer(p+"/hidden",in:root) != nil {
                let h=p+"/hidden",r=p+"/rules/flyingHidden"
                guard try string(r+"/from") == p,try string(r+"/to") == h else { throw Incomplete.record }
                let rel=try allowed(r+"/relation",["飞伏比和","飞生伏","飞克伏","伏生飞","伏克飞"])
                let flying=try string(p+"/wuXing"),hidden=try string(h+"/wuXing")
                let sheng=["木":"火","火":"土","土":"金","金":"水","水":"木"],ke=["木":"土","土":"水","水":"火","火":"金","金":"木"]
                let expected=flying == hidden ? "飞伏比和" : sheng[flying] == hidden ? "飞生伏" : ke[flying] == hidden ? "飞克伏" : sheng[hidden] == flying ? "伏生飞" : "伏克飞"
                guard rel == expected else { throw Incomplete.record }
                parts.append(try object(h,label:"伏神",paths:&paths)+"；"+calendar(h+"/context",paths:&paths)+"；"+rel+"，能否出伏未裁定")
                paths += [r+"/from",r+"/to",r+"/relation"] + (try source(r+"/sourceId",expected:"liuyao-flying-hidden-v1"))
                parts.append(try conditions(r+"/conditions",paths:&paths))
            }
            if ReadingVerificationEvidence.pointer(p+"/rules/dayClash",in:root) != nil {
                let r=p+"/rules/dayClash",candidates=try strings(r+"/candidates")
                guard try bool(p+"/context/day/clash"),try string(r+"/kind") == (moving ? "moving-day-clash" : "static-day-clash"),
                      candidates.allSatisfy({["暗动","日破","冲空待审"].contains($0)}),!moving || candidates.isEmpty else { throw Incomplete.record }
                parts.append(moving ? "明动爻受日冲，保留其动爻身份" : "静爻日冲；候选："+(candidates.isEmpty ? "无" : candidates.joined(separator:"、"))+"，未裁定")
                paths += [r+"/kind",r+"/candidates"] + (try source(r+"/sourceId",expected:"liuyao-day-clash-v1"))
                parts.append(try conditions(r+"/conditions",paths:&paths))
            }
            try append("line-\(i+1)",parts.filter{!$0.isEmpty}.joined(separator:"。")+"。",paths)
        }
        func candidate(_ p: String, related: Bool, paths: inout [String]) throws -> (id:String,object:String,layer:String,label:String,reason:String) {
            let layer=try allowed(p+"/layer",related ? ["changed"] : ["original","hidden","month","day"]),id=try string(p+"/id"),objectPath=try string(p+"/objectPath")
            var label: String
            if layer == "month" || layer == "day" {
                guard id == layer,objectPath == "/castGanZhi/"+layer else { throw Incomplete.record }
                label=(layer == "month" ? "月建" : "日辰")+(try ganZhi(objectPath))
                paths.append(objectPath)
            } else {
                let position=try int(p+"/position")
                guard (1...6).contains(position),id == layer+"-\(position)" else { throw Incomplete.record }
                let linePath="/lines/\(position-1)",expected=linePath+(layer == "original" ? "" : "/"+layer)
                guard objectPath == expected,try string(p+"/contextPath") == expected+"/context",try int(linePath+"/position") == position,
                      try (layer != "changed" || bool(linePath+"/isChanging")) else { throw Incomplete.record }
                label="第\(position)爻"+(try object(expected,label:layer == "original" ? "本爻" : layer == "hidden" ? "伏神" : "变爻",paths:&paths))
                paths += [p+"/position",p+"/contextPath",linePath+"/position"]
            }
            let reason=try allowed(p+"/reason",["category-role","explicit-person-role","explicit-partner-role","querent-self-reference","absent-visible-calendar-role","absent-visible-pure-palace-role","dependent-changing-reference-only"])
            let reasons: [String:Set<String>] = ["original":["category-role","explicit-person-role","explicit-partner-role","querent-self-reference"],"hidden":["absent-visible-pure-palace-role"],"month":["absent-visible-calendar-role"],"day":["absent-visible-calendar-role"],"changed":["dependent-changing-reference-only"]]
            guard related == (reason == "dependent-changing-reference-only"),reasons[layer]?.contains(reason) == true else { throw Incomplete.record }
            paths += [p+"/id",p+"/layer",p+"/objectPath",p+"/reason"]
            return (id,objectPath,layer,label,reason)
        }
        mutating func selectionAndTiming() throws {
            let y="/yongShen",t="/yingQi",provenance=try source(y+"/sourceId",expected:questionSource)
            guard try bool(y+"/selectionEstablished") == false,try value(y+"/selectedCandidateId") == .null else { throw Incomplete.record }
            _ = try allowed(y+"/selectionStatus",["candidates-only","requires-clarification"])
            let missing=try terms(y+"/missingContext")
            let candidates=try array(y+"/candidates")
            guard candidates.count <= 8 else { throw Incomplete.record }
            try append("selection",(candidates.isEmpty ? "本次没有确定候选对象。" : "候选层尚未定用；不按顺序或单独空破决定取舍，独立效力校验另列。")+(missing.isEmpty ? "" : "本次计算记录尚缺：\(missing)。"),[y+"/selectionStatus",y+"/selectionEstablished",y+"/selectedCandidateId",y+"/missingContext",y+"/candidates"]+provenance)
            var byID: [String:(object:String,layer:String,label:String)]=[:]
            for i in candidates.indices {
                var paths=provenance
                let c=try candidate(y+"/candidates/\(i)",related:false,paths:&paths)
                guard byID[c.id] == nil else { throw Incomplete.record };byID[c.id]=(c.object,c.layer,c.label)
                let basis = ["category-role":"按所问事项类别映射六亲；用神章提供类别依据，现代事项映射保留限制", "explicit-person-role":"按明确的亲属角色映射六亲", "explicit-partner-role":"按明确的伴侣角色映射六亲，不由性别猜测", "querent-self-reference":"世爻保留本人所问之参考", "absent-visible-calendar-role":"明现爻缺该六亲，按飞伏章另列日月候选", "absent-visible-pure-palace-role":"明现爻缺该六亲，按飞伏章另列纯宫伏神候选"][c.reason]!
                try append("candidate-"+c.id,"候选：\(c.label)。\(basis)；候选层未裁定该对象的效力。",paths)
            }
            for i in try array(y+"/related").indices {
                var paths=provenance
                let c=try candidate(y+"/related/\(i)",related:true,paths:&paths)
                try append("related-"+c.id,"依附参考：\(c.label)，依附本位动爻，不替代上述候选成为独立用神。",paths)
            }
            let timingSource=try source(t+"/sourceId",expected:questionSource)
            guard try string(t+"/assessmentStatus") == "conditional-triggers-only",try bool(t+"/outcomeEstablished") == false else { throw Incomplete.record }
            _ = try allowed(t+"/timeScale",["day-hour-reference","year-month-reference","unresolved"])
            let timing=try array(t+"/branchesByCandidate")
            guard timing.count == byID.count else { throw Incomplete.record }
            var seen=Set<String>()
            for i in timing.indices {
                let p=t+"/branchesByCandidate/\(i)",id=try string(p+"/candidateId")
                guard seen.insert(id).inserted,let c=byID[id],try string(p+"/objectPath") == c.object else { throw Incomplete.record }
                var paths=[p+"/candidateId",p+"/objectPath",p+"/unresolved"]+timingSource,phrases: [String]=[]
                if c.layer == "original" || c.layer == "hidden" {
                    guard try string(p+"/conditionsPath") == c.object+"/context" else { throw Incomplete.record }
                    paths += [p+"/conditionsPath",c.object+"/context"]
                } else if ReadingVerificationEvidence.pointer(p+"/conditionsPath",in:root) != nil { throw Incomplete.record }
                let rules=try array(p+"/rules")
                var ruleIDs=Set<String>()
                for j in rules.indices {
                    let r=p+"/rules/\(j)",ruleID=try string(r+"/id"),trigger=try strings(r+"/branches"),facts=try strings(r+"/factPaths")
                    guard ruleIDs.insert(ruleID).inserted,trigger.count == 2,trigger.allSatisfy(branches.contains),c.layer == "original" || c.layer == "hidden" else { throw Incomplete.record }
                    let branch=String((try ganZhi(c.object+"/ganZhi")).suffix(1)),prefix: String,expectedFacts: [String],expectedBranches: [String]
                    // Validate reported trigger coordinates against this same object;
                    // these small relation checks do not calculate or replace its cast.
                    switch ruleID {
                    case "moving-value-combine", "static-value-clash":
                        let moving=ruleID == "moving-value-combine"
                        guard c.layer == "original",try bool(c.object+"/isChanging") == moving else { throw Incomplete.record }
                        prefix=moving ? "动值合" : "静值冲"
                        expectedFacts=[c.object+"/ganZhi",c.object+"/isChanging"]
                        expectedBranches=[branch,try paired(branch,combine:moving)]
                    case "changed-combination-open":
                        guard c.layer == "original",try bool(c.object+"/isChanging") else { throw Incomplete.record }
                        let changed=String((try ganZhi(c.object+"/changed/ganZhi")).suffix(1))
                        guard try paired(branch,combine:true) == changed else { throw Incomplete.record }
                        prefix="本爻\(branch)与变爻\(changed)相合，待冲开"
                        expectedFacts=[c.object+"/ganZhi",c.object+"/changed/ganZhi"]
                        expectedBranches=[try paired(branch,combine:false),try paired(changed,combine:false)]
                    case "month-break-fill-combine":
                        guard try bool(c.object+"/context/month/clash") else { throw Incomplete.record }
                        prefix="月破待填合";expectedFacts=[c.object+"/ganZhi",c.object+"/context/month/clash"]
                        expectedBranches=[branch,try paired(branch,combine:true)]
                    case "void-fill-clash":
                        guard try bool(c.object+"/context/isVoid") else { throw Incomplete.record }
                        prefix="空待填冲";expectedFacts=[c.object+"/ganZhi",c.object+"/context/isVoid"]
                        expectedBranches=[branch,try paired(branch,combine:false)]
                    case "month-combination-open":
                        guard try bool(c.object+"/context/month/combination") else { throw Incomplete.record }
                        let month=try string(c.object+"/context/month/branch")
                        guard try paired(branch,combine:true) == month else { throw Incomplete.record }
                        prefix="月合待冲开";expectedFacts=[c.object+"/context/month/combination","/castGanZhi/month"]
                        expectedBranches=[try paired(branch,combine:false),try paired(month,combine:false)]
                    default: throw Incomplete.record
                    }
                    guard facts == expectedFacts,trigger == expectedBranches else { throw Incomplete.record }
                    phrases.append(prefix+"："+trigger.joined(separator:"、"))
                    paths += [r+"/id",r+"/branches",r+"/factPaths"]+facts
                }
                let pending=try terms(p+"/unresolved")
                let unresolved=try strings(p+"/unresolved")
                if unresolved.contains("dark-movement") {
                    guard c.layer == "original",try bool(c.object+"/isChanging") == false,try bool(c.object+"/context/day/clash") else { throw Incomplete.record }
                }
                try append("timing-"+id,"\(c.label)的条件应期（《增删卜易·各门类应期总注》）："+(phrases.isEmpty ? "没有返回触发支" : phrases.joined(separator:"；"))+"。未裁定：\(pending)。触发支仅是条件，不等于事件发生。",paths)
            }
            let pending=try terms(t+"/unresolved")
            try append("timing-limit","条件应期层尚未定用，\(pending)仍未裁定，不能确定到账或其他事件日期。月令生克标签、明动及冲合结构不单独证明综合效力。",[t+"/assessmentStatus",t+"/outcomeEstablished",t+"/timeScale",t+"/unresolved"]+timingSource)
        }
        mutating func candidateRoles() throws {
            let base="/roleRelations",provenance=try source(base+"/sourceId",expected:roleSource)
            guard try string(base+"/assessmentStatus") == "candidate-relative-structure",try bool(base+"/outcomeEstablished") == false,
                  try strings(base+"/inspectedOriginalPaths") == (0..<6).map({"/lines/\($0)"}) else { throw Incomplete.record }
            let candidates=try array("/yongShen/candidates")
            var byID:[String:(object:String,layer:String,label:String,context:String?)]=[:]
            for i in candidates.indices {
                var paths:[String]=[]
                let c=try candidate("/yongShen/candidates/\(i)",related:false,paths:&paths)
                byID[c.id]=(c.object,c.layer,c.label,c.layer == "original" || c.layer == "hidden" ? c.object+"/context" : nil)
            }
            let hasStaticClash=try (0..<6).contains { try bool("/lines/\($0)/isChanging") == false && bool("/lines/\($0)/context/day/clash") }
            let unresolved=["selected-object","actor-effectiveness","target-viability","binding","tomb-or-extinction","event-outcome"]+(hasStaticClash ? ["dark-movement"] : [])+(byID.values.contains{$0.layer == "hidden"} ? ["hidden-emergence"] : [])
            guard try strings(base+"/unresolved") == unresolved else { throw Incomplete.record }
            // Independent literal relation table validates the reported role names;
            // it does not calculate a cast, strength or event judgment.
            let table=["木":["水","金","土"],"火":["木","水","金"],"土":["火","木","水"],"金":["土","火","木"],"水":["金","土","火"]]
            var seen=Set<String>(),seenElements=Set<String>()
            let groups=try array(base+"/groups")
            guard groups.count <= 5 else { throw Incomplete.record }
            for i in groups.indices {
                let p=base+"/groups/\(i)",target=try allowed(p+"/targetElement",elements)
                guard seenElements.insert(target).inserted,let row=table[target] else { throw Incomplete.record }
                var positions:[[Int]]=[],actorPaths:[String]=[]
                for (j,role) in ["yuan","ji","chou"].enumerated() {
                    guard try string(p+"/elements/"+role) == row[j] else { throw Incomplete.record }
                    let expected=try (0..<6).filter { try string("/lines/\($0)/wuXing") == row[j] }.map{$0+1}
                    guard try value(p+"/"+role+"Positions") == .array(expected.map{.integer(Int64($0))}) else { throw Incomplete.record }
                    positions.append(expected)
                    for n in expected {
                        let a="/lines/\(n-1)"
                        actorPaths += [a+"/position",a+"/ganZhi",a+"/wuXing",a+"/isChanging",a+"/context"]
                        if ReadingVerificationEvidence.pointer(a+"/rules/returning",in:root) != nil {
                            actorPaths += [a+"/rules/returning/branchRelation",a+"/rules/returning/relation",a+"/rules/advanceRetreat"]
                        }
                    }
                }
                func moving(_ positions:[Int]) throws -> [Int] { try positions.filter { try bool("/lines/\($0-1)/isChanging") } }
                let yuan=try moving(positions[0]),ji=try moving(positions[1]),chou=try moving(positions[2])
                let jy: [JSONValue]=ji.flatMap { j in yuan.map { y in ["jiPosition":.integer(Int64(j)),"yuanPosition":.integer(Int64(y))] } }
                let cj: [JSONValue]=chou.flatMap { c in ji.map { j in ["chouPosition":.integer(Int64(c)),"jiPosition":.integer(Int64(j))] } }
                guard try value(p+"/jiYuanMovingPairs") == .array(jy),try value(p+"/chouJiMovingPairs") == .array(cj) else { throw Incomplete.record }
                let refs=try array(p+"/candidateRefs");guard !refs.isEmpty else { throw Incomplete.record }
                for j in refs.indices {
                    let r=p+"/candidateRefs/\(j)",id=try string(r+"/id")
                    guard seen.insert(id).inserted,let c=byID[id],let ctx=c.context,
                          try string(r+"/objectPath") == c.object,try string(r+"/contextPath") == ctx,
                          try string(c.object+"/wuXing") == target else { throw Incomplete.record }
                    func label(_ p:[Int]) -> String { p.isEmpty ? "无" : "第"+p.map(String.init).joined(separator:"、")+"爻" }
                    var chains:[String]=[]
                    for j in ji { for y in yuan { chains.append("第\(j)爻→第\(y)爻→此候选（忌生元、元生用；忌克用的直接关系仍保留）") } }
                    for c in chou { for j in ji { chains.append("第\(c)爻→第\(j)爻（仇生忌；仇的\(row[2])同时克元的\(row[0])，不表示盘中必有元神爻）") } }
                    let text="以候选\(c.label)为参照，元神：\(label(positions[0]))；忌神：\(label(positions[1]))；仇神：\(label(positions[2]))。静爻也保留角色身份，以上只检索六个实际原爻。"+(chains.isEmpty ? "没有元忌或忌仇共同明动的组合。" : "共同明动结构："+chains.joined(separator:"；")+"。")+"此候选仍未定用；各爻原有的空破、日月支持与同位变化分别保留，施力、合住、候选能否受生\(hasStaticClash ? "、静爻日冲效力" : "")、墓绝条件及事件方向尚未裁定，不能据此确定吉凶。"
                    try append("roles-"+id,text,[base+"/assessmentStatus",base+"/outcomeEstablished",base+"/inspectedOriginalPaths",base+"/unresolved",p,r,c.object+"/wuXing",ctx]+actorPaths+provenance)
                }
            }
            for i in try array(base+"/unsupportedCandidates").indices {
                let p=base+"/unsupportedCandidates/\(i)",id=try string(p+"/id")
                guard seen.insert(id).inserted,let c=byID[id],c.context == nil,["month","day"].contains(c.layer),
                      try string(p+"/objectPath") == c.object,try string(p+"/reason") == "calendar-target-outside-line-role-scope" else { throw Incomplete.record }
                try append("roles-"+id,"候选\(c.label)属于日月参考，本层只对本爻及伏神候选列元忌仇关系，未给日月候选套用爻的施力规则。",[p,c.object,base+"/assessmentStatus"]+provenance)
            }
            guard seen == Set(byID.keys) else { throw Incomplete.record }
            if byID.isEmpty { try append("roles-unavailable","本次尚无明确用神候选，暂不指定元神、忌神或仇神。",[base+"/groups",base+"/unsupportedCandidates","/yongShen/candidates",base+"/inspectedOriginalPaths"]+provenance) }
        }
        func validateReferences(_ p: String, source: String) throws {
            if source == LiuyaoEventAssessment.sourceID {
                let base=String(p.dropLast("/references".count))
                try LiuyaoEventAssessment.validateSource(value(base));return
            }
            if source == LiuyaoEfficacyEvidence.sourceID {
                let references=LiuyaoEfficacyEvidence.references
                guard try array(p).count == references.count else { throw Incomplete.record }
                for (i,reference) in references.enumerated() {
                    guard try string(p+"/\(i)/url") == reference.0,try string(p+"/\(i)/sha256") == reference.1,
                          !(try string(p+"/\(i)/locator")).isEmpty else { throw Incomplete.record }
                }
                return
            }
            let rootURL="https://zh.wikisource.org/wiki/增刪卜易"
            if source == LiuyaoFanfuTrace.sourceID || source == LiuyaoTriadTrace.sourceID {
                let references=[
                    (source == LiuyaoTriadTrace.sourceID ? rootURL+"/19" : rootURL+"/25",source == LiuyaoTriadTrace.sourceID ? "087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf" : "10c6f672b4b68ea46217d8f053a8668034a757d5899447fda3f0934b82537fa2"),
                    (rootURL,"897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07"),
                    ("https://zh.wikisource.org/wiki/易林補遺/1","abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967")
                ]
                guard try array(p).count == references.count else { throw Incomplete.record }
                for (i,reference) in references.enumerated() {
                    guard try string(p+"/\(i)/url") == reference.0,try string(p+"/\(i)/sha256") == reference.1,
                          !(try string(p+"/\(i)/locator")).isEmpty else { throw Incomplete.record }
                }
                return
            }
            if source == LiuyaoTombExtinctionTrace.sourceID {
                let references=[
                    (rootURL+"/26又1","630f38b037ae720e90e55faff10a1c044f7edf9e3a85ce7dc645b8693ada2008"),
                    (rootURL+"/26又3","dc529f9dc18f3620c1975fe3463f744fd8732000c4f9d01eecf318d45528eea4"),
                    (rootURL+"/15","0df8223b0c65616826c8caf86b592526b46b1dee51332e0c2707486f2d7ee4e5"),
                    (rootURL,"897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07"),
                    ("https://zh.wikisource.org/wiki/易林補遺/1","abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967")
                ]
                guard try array(p).count == references.count else { throw Incomplete.record }
                for (i,reference) in references.enumerated() {
                    guard try string(p+"/\(i)/url") == reference.0,try string(p+"/\(i)/sha256") == reference.1,
                          !(try string(p+"/\(i)/locator")).isEmpty else { throw Incomplete.record }
                }
                return
            }
            let hashes=["/9":"e84db11ae9a316ba00cb301e4e25c71496b32d9fcc495f16e09a575eb2159412","/10":"3afc338a9c87a3df29583d36cf608abe381d44a5736e33641ca6d95c1cf387b9","":"897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07", "/8":"da83c3e47c04bb4813040e6cf5c3e43f8775e2293da3b32c9a8e2fb542e72a90", "/17":"e70bfbed847449facf08d1801c5cfe37c3655761ad635b484d7c24e5a4361623", "/19":"087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf", "/20":"8aec9b6625a18b4c487e45e92c9de662929597fa74a3653ce9ed9dd2d0b7e49b", "/22":"c8d2e339a0bf86b1e09e290ff191eac06c6c0bfce190c3d1e7942cc3fab874d5", "/26":"29213289bfd323be3206860ee2904f61c05f6f9941313745ae5e8b2bc6620d41", "/26又3":"dc529f9dc18f3620c1975fe3463f744fd8732000c4f9d01eecf318d45528eea4"]
            let suffixes=[roleSource:["/9","/10"],calendarSource:["/17","/19","/20","/26"],questionSource:["/8","","/26又3"],"liuyao-changing-relations-v1":["/17",""],"liuyao-flying-hidden-v1":[""],"liuyao-day-clash-v1":["/22"]]
            guard let expected=suffixes[source],try array(p).count == expected.count else { throw Incomplete.record }
            for i in expected.indices {
                let path=p+"/\(i)"
                guard try string(path+"/url") == rootURL+expected[i],try string(path+"/sha256") == hashes[expected[i]],!(try string(path+"/locator")).isEmpty else { throw Incomplete.record }
            }
        }
        /// Verify the condition's own evidence coordinates, including its boolean
        /// predicate. Actor relations are checked against existing line facts;
        /// no chart or strength verdict is recomputed here.
        func expectedConditions(_ p: String) throws -> [String:(Bool?,[String])] {
            let parts=p.split(separator:"/")
            guard parts.count == 5,parts[0] == "lines",let i=Int(parts[1]),(0..<6).contains(i),parts[2] == "rules",parts[4] == "conditions" else { throw Incomplete.record }
            let base="/lines/\(i)",c=base+"/changed",h=base+"/hidden",ctx=base+"/context"
            var expected: [String:(Bool?,[String])]=[:]
            func add(_ id: String, _ test: Bool?, _ paths: [String]=[]) { expected[id]=(test,paths) }
            func flag(_ id: String, _ path: String) throws { add(id,try bool(path),[path]) }
            func relation(_ id: String, _ path: String, _ values: Set<String>) throws { add(id,values.contains(try string(path)),[path]) }
            let sheng=["木":"火","火":"土","土":"金","金":"水","水":"木"],ke=["木":"土","土":"水","水":"火","火":"金","金":"木"]
            let rule=String(parts[3])
            let moving=try (0..<6).filter { try $0 != i && bool("/lines/\($0)/isChanging") }
            let target=try allowed((rule == "flyingHidden" ? h : base)+"/wuXing",elements)
            let generating=try moving.filter { sheng[try string("/lines/\($0)/wuXing")] == target }
            let controlling=try moving.filter { ke[try string("/lines/\($0)/wuXing")] == target }
            func actorPaths(_ indices: [Int]) -> [String] { indices.flatMap { ["/lines/\($0)/isChanging","/lines/\($0)/wuXing"] } }
            func inspected(_ indices: [Int]) -> [String] { ["/changingYao"]+actorPaths(indices.isEmpty ? moving : indices) }
            switch rule {
            case "advanceRetreat":
                try flag("changed-void",c+"/context/isVoid");try flag("changed-month-break",c+"/context/month/clash");try flag("changed-day-clash",c+"/context/day/clash");add("combined-effectiveness",nil)
            case "returning":
                try relation("changed-month-generation",c+"/context/month/elementRelation",["生爻"])
                try relation("changed-day-support",c+"/context/day/elementRelation",["同类","生爻"])
                try flag("original-day-presence",ctx+"/day/sameBranch")
            case "flyingHidden":
                try relation("hidden-month-generation",h+"/context/month/elementRelation",["生爻"])
                try relation("hidden-day-generation",h+"/context/day/elementRelation",["生爻"])
                let flying=try string(base+"/wuXing")
                add("flying-generates-hidden",sheng[flying] == target,[base+"/wuXing",h+"/wuXing"])
                add("moving-generates-hidden",!generating.isEmpty,inspected(generating)+[h+"/wuXing"])
                let challenged=try ["month","day"].contains { try bool(ctx+"/"+$0+"/clash") || string(ctx+"/"+$0+"/elementRelation") == "克爻" }
                add("calendar-challenges-flying",challenged,[ctx+"/month/clash",ctx+"/day/clash",ctx+"/month/elementRelation",ctx+"/day/elementRelation"])
                let flyBranch=String((try ganZhi(base+"/ganZhi")).suffix(1)),opposite=try paired(flyBranch,combine:false)
                let actors=try moving.filter { try String(ganZhi("/lines/\($0)/ganZhi").suffix(1)) == opposite || ke[string("/lines/\($0)/wuXing")] == flying }
                let actorFields=(actors.isEmpty ? moving : actors).flatMap { ["/lines/\($0)/isChanging","/lines/\($0)/ganZhi","/lines/\($0)/wuXing"] }
                add("moving-challenges-flying",!actors.isEmpty,["/changingYao"]+actorFields+[base+"/ganZhi",base+"/wuXing"])
                try flag("flying-void",ctx+"/isVoid");try flag("flying-month-break",ctx+"/month/clash")
                for scope in ["month","day"] {
                    try flag("hidden-"+scope+"-clash",h+"/context/"+scope+"/clash")
                    try relation("hidden-"+scope+"-control",h+"/context/"+scope+"/elementRelation",["克爻"])
                }
                add("flying-controls-hidden",ke[flying] == target,[base+"/wuXing",h+"/wuXing"])
                try flag("hidden-void",h+"/context/isVoid")
                for id in ["hidden-combined-strength","flying-combined-strength","hidden-tomb-or-extinction","flying-tomb-or-extinction"] { add(id,nil) }
            case "dayClash":
                add("static-line",try !bool(base+"/isChanging"),[base+"/isChanging"]);try flag("day-clash",ctx+"/day/clash")
                for scope in ["month","day"] { try relation(scope+"-support",ctx+"/"+scope+"/elementRelation",["同类","生爻"]) }
                try relation("month-control",ctx+"/month/elementRelation",["克爻"])
                add("moving-generation",!generating.isEmpty,inspected(generating)+[base+"/wuXing"])
                add("moving-control",!controlling.isEmpty,inspected(controlling)+[base+"/wuXing"])
                try flag("void-clash",ctx+"/isVoid");add("combined-strength",nil);add("moving-actors-effectiveness",nil)
            default: throw Incomplete.record
            }
            return expected
        }
        func paired(_ branch: String, combine: Bool) throws -> String {
            let pairs=combine ? ["子丑","寅亥","卯戌","辰酉","巳申","午未"] : ["子午","丑未","寅申","卯酉","辰戌","巳亥"]
            guard let pair=pairs.first(where:{$0.contains(branch)}),let other=pair.map(String.init).first(where:{$0 != branch}) else { throw Incomplete.record };return other
        }
    }
}
