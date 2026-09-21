import Foundation

/// Rebuilds the event profile after LiuyaoEfficacyEvidence has independently
/// authenticated its inputs. This layer never treats a profile as a realized event.
enum LiuyaoEventAssessment {
    static let sourceID="liuyao-event-zengshan-v1"
    private enum Invalid:Error { case record }
    private static let generates=["木":"火","火":"土","土":"金","金":"水","水":"木"]
    private static let controls=["木":"土","土":"水","水":"火","火":"金","金":"木"]
    private static let limits=["source-profile-not-realized-outcome","no-date-verdict","no-fixed-two-appearance-ranking","unmodeled-special-event-semantics"]
    private static func strings(_ values:[String])->JSONValue { .array(values.map(JSONValue.string)) }
    private struct Reader {
        let root:JSONValue
        func value(_ path:String)throws->JSONValue {guard let v=ReadingVerificationEvidence.pointer(path,in:root) else{throw Invalid.record};return v}
        func string(_ path:String)throws->String {guard case let .string(v)=try value(path) else{throw Invalid.record};return v}
        func bool(_ path:String)throws->Bool {guard case let .bool(v)=try value(path) else{throw Invalid.record};return v}
        func array(_ path:String)throws->[JSONValue] {guard case let .array(v)=try value(path) else{throw Invalid.record};return v}
        func strings(_ path:String)throws->[String] {try array(path).map {guard case let .string(v)=$0 else{throw Invalid.record};return v}}
        func exists(_ path:String)->Bool {ReadingVerificationEvidence.pointer(path,in:root) != nil}
    }
    private struct Evidence {
        var rule:String;var paths:[String]
        var json:JSONValue {.object(["ruleId":.string(rule),"factPaths":strings(paths)])}
    }
    private static func ev(_ rule:String,_ paths:String...)->Evidence {.init(rule:rule,paths:paths)}
    private struct Transmission {
        var ji:String;var yuan:String;var status:String;var conditions:[Evidence];var blockers:[Evidence]
        var json:JSONValue {.object(["jiPath":.string(ji),"yuanPath":.string(yuan),"status":.string(status),"conditions":.array(conditions.map(\.json)),"blockers":.array(blockers.map(\.json))])}
    }
    private struct Candidate {
        var id:String;var path:String;var outcome:String;var conditions:[Evidence];var blockers:[Evidence];var transmissions:[Transmission]
        var json:JSONValue {.object(["candidateId":.string(id),"objectPath":.string(path),"outcome":.string(outcome),"conditions":.array(conditions.map(\.json)),"blockers":.array(blockers.map(\.json)),"transmissions":.array(transmissions.map(\.json))])}
    }
    static func validateSource(_ source:JSONValue)throws {
        let r=Reader(root:source)
        guard try r.string("/id")==sourceID,try r.string("/version")=="1",
              try r.string("/title")=="增删卜易：事件方向与元忌传递的充分条件",
              try r.string("/editionStatus")=="electronic-transcription-not-print-collated",
              try r.string("/scope")=="明确取用后，逐候选检查无根、无伤月建与有效元忌传递；事件方向限于本条文剖面，不是现实结果或日期",
              try r.strings("/limitations")==["电子转录未校印本；现代按语不参与","条文方向成立不代表现实事件已经成立；不输出概率、医疗结论或日期","元忌仅用实际原动爻；元神须有独立日月支持且无未决伤克、空破墓绝；保留所有残余攻击","多候选逐一检查；全部同向只表示对象选择不改变本剖面方向，不替代具体定用或应期定用","合冲、复杂三合、伏神出伏、多占与专门事类反向取用不在充分条件范围"] else{throw Invalid.record}
        let refs=[
            ("11","74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb","元神忌神衰旺章：有力无力全条件、元忌同动、无根反例","上论元神、忌神之有力、无力者，亦要用神有气。倘若用神无根，谓之元神有力亦难生，忌神无力亦休喜。"),
            ("18","4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018","月将章：无伤月建、日月相敌与增生克","此言用神临月建，并无他爻以伤克者，凡占皆吉。忌神临月建，而用神休囚无救者，诸占大凶。"),
            ("40","e74764848deb4fd0ffe5e3bd16d696701dd5b06de034a085d74f24a35f0f2c2f","两现章：小畜的事件与应期对象；豫之归妹须结合前占","应临月建之财以克世，许之必得。彼问：何日到手？"),
            ("11","74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb","元神有力第一条；effective-yuan-supports-viable-target 的前提","元神旺相，或临日月，或得日月动爻生扶者，一也。"),
            ("11","74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb","大过之鼎；元忌传递与目标能否承接必须合读","幸得元神酉金亦动，忌神未土反生元神之酉金，金生亥水，接续相生，化凶而为吉矣。岂知亥水月冲日克，值月破而被克，虽有生扶，奈何生之不起"),
            ("18","4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018","balanced-calendar-receives-moving-support；生克相敌后的额外生扶","月克日生，遇帮扶而愈旺，月生日克，逢克制而亦衰。"),
            ("11","74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb","元神生用的旺相总前提；与有力第一条分段核对","元神虽生用神，须要旺相，方能生得用神。")
        ]
        guard try r.array("/references").count==refs.count else{throw Invalid.record}
        for (i,ref) in refs.enumerated() {
            let p="/references/\(i)"
            guard try r.string(p+"/url")=="https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy"+ref.0+".html",
                  try r.string(p+"/sha256")==ref.1,try r.string(p+"/locator")==ref.2,try r.string(p+"/quote")==ref.3 else{throw Invalid.record}
        }
    }
    static func sections(root:JSONValue,receiptID:String,sourcePaths:[String])throws->[LiuyaoReferenceReading.Section] {
        let r=Reader(root:root),effects=Reader(root:try LiuyaoEfficacyEvidence.decodedReport(root:root))
        let originals=(0..<6).map{"/lines/\($0)"},moving=try originals.filter{try r.bool($0+"/isChanging")}
        var entries=[String:Reader]()
        for row in try effects.array("/objects") {let read=Reader(root:row);entries[try read.string("/objectPath")]=read}
        func inherited(_ row:Reader)throws->[Evidence] {
            try row.array("/vitality/blockers").map{v in let x=Reader(root:v);return try Evidence(rule:x.string("/id"),paths:x.strings("/factPaths"))}
        }
        func lifecycle(_ row:Reader)throws->[Reader] {try (row.array("/tombs")+row.array("/extinctions")).map{Reader(root:$0)}}
        func changedPending(_ p:String)throws->Bool {
            guard r.exists(p+"/changed") else{return false}
            let c=p+"/changed/context"
            return try r.bool(c+"/isVoid") || (r.bool(c+"/month/clash") && !r.bool(c+"/day/sameBranch"))
        }
        func gate(_ p:String)throws->[Evidence] {
            guard let row=entries[p] else{throw Invalid.record}
            var reasons=try inherited(row)
            if try row.string("/vitality/status") != "supported-unopposed" {reasons.append(ev("actor-needs-unopposed-calendar-support",p+"/context"))}
            if try row.string("/availability/status") != "present" {reasons.append(ev("actor-awaiting-availability",p+"/context"))}
            for ref in try lifecycle(row) where try !["opened","overridden-by-generation"].contains(ref.string("/status")) {
                reasons.append(try ev("actor-lifecycle-unresolved",p,ref.string("/sourcePath")))
            }
            if try changedPending(p) {reasons.append(ev("changed-object-awaiting-availability",p+"/changed/context"))}
            return reasons
        }
        var candidates=[Candidate]()
        for c in try r.array("/yongShen/candidates") {
            let cr=Reader(root:c),p=try cr.string("/objectPath"),isOriginal=try cr.string("/layer")=="original"
            var candidate=Candidate(id:try cr.string("/id"),path:p,outcome:"unresolved",conditions:[],blockers:[],transmissions:[])
            guard isOriginal,let row=entries[p] else {
                candidate.blockers=[ev("original-target-required","/yongShen/candidates")];candidates.append(candidate);continue
            }
            let element=try r.string(p+"/wuXing"),yuan=try moving.filter{try generates[r.string($0+"/wuXing")]==element},ji=try moving.filter{try controls[r.string($0+"/wuXing")]==element}
            let rootless=try row.string("/vitality/status")=="rootless",calendar=try row.string("/calendarStrength/status")
            let effectiveYuan=try yuan.filter{try gate($0).isEmpty}
            let viable=try ["supported","balanced"].contains(calendar) && !r.bool(p+"/context/month/clash")
            for j in ji {for y in yuan {
                var reasons=try gate(j)+gate(y)
                if !viable {reasons.append(ev("target-reception-unresolved",p))}
                let effective=reasons.isEmpty
                var conditions=[ev("ji-yuan-both-moving",j+"/isChanging",j+"/wuXing",y+"/isChanging",y+"/wuXing",p+"/wuXing")]
                if effective {conditions.append(ev("yuan-can-transmit",y,"/efficacy"))}
                let blockers=rootless ? [ev("month-break-day-control-no-root",p+"/context/month/clash",p+"/context/day/elementRelation")] : reasons
                candidate.transmissions.append(.init(ji:j,yuan:y,status:rootless ? "target-cannot-receive" : effective ? "redirected-through-yuan" : "conditional",conditions:conditions,blockers:blockers))
            }}
            if rootless {
                candidate.outcome="adverse-under-selected-rule"
                candidate.conditions=[ev("month-break-day-control-no-root",p+"/context/month/clash",p+"/context/day/elementRelation",p)]
            } else {
                let redirected=Set(candidate.transmissions.filter{$0.status=="redirected-through-yuan"}.map(\.ji))
                let balanced=calendar=="balanced" && viable && !effectiveYuan.isEmpty
                for evidence in try inherited(row) {
                    if evidence.rule=="moving-control",let actor=evidence.paths.first,redirected.contains(actor.replacingOccurrences(of:"/isChanging",with:"")){continue}
                    if evidence.rule=="calendar-restraint" && balanced {continue}
                    candidate.blockers.append(evidence)
                }
                for ref in try lifecycle(row) where try !["opened","overridden-by-generation"].contains(ref.string("/status")) {
                    candidate.blockers.append(try ev("target-lifecycle-unresolved",p,ref.string("/sourcePath")))
                }
                if try changedPending(p) {candidate.blockers.append(ev("changed-target-awaiting-availability",p+"/changed/context"))}
                let monthly=try r.bool(p+"/context/month/sameBranch")
                if candidate.blockers.isEmpty && viable && (monthly || !effectiveYuan.isEmpty) {
                    candidate.conditions.append(ev(monthly ? "uninjured-monthly-target" : "effective-yuan-supports-viable-target",p+"/context",p,"/lines"))
                    if balanced {candidate.conditions.append(.init(rule:"balanced-calendar-receives-moving-support",paths:[p+"/context"]+effectiveYuan))}
                    candidate.outcome=try row.string("/availability/status")=="present" ? "favorable-under-selected-rule" : "awaiting-condition"
                    if candidate.outcome=="awaiting-condition" {candidate.blockers.append(ev("target-awaiting-availability",p+"/context"))}
                } else {
                    let monthlyAttack=try ji.contains{try r.bool($0+"/context/month/sameBranch") && gate($0).isEmpty}
                    if try row.string("/vitality/status")=="opposed-unrescued" && monthlyAttack {
                        candidate.outcome="adverse-under-selected-rule";candidate.conditions.append(ev("monthly-ji-unrescued-target",p,"/lines"))
                    } else {
                        candidate.outcome=candidate.blockers.isEmpty ? "unresolved" : "contested"
                        if candidate.blockers.isEmpty {candidate.blockers.append(ev("event-sufficient-conditions-not-met",p,"/efficacy"))}
                    }
                }
            }
            candidates.append(candidate)
        }
        let ready=try ["selected","multiple-candidates"].contains(effects.string("/selection/status")) && !candidates.isEmpty && candidates.allSatisfy{originals.contains($0.path)}
        let unanimous=ready && candidates.allSatisfy{$0.outcome==candidates.first?.outcome}
        let outcome=unanimous ? candidates[0].outcome : "unresolved"
        let selectionStatus = !ready ? "requires-selection" : candidates.count==1 ? "unique-object" : unanimous && ["favorable-under-selected-rule","adverse-under-selected-rule"].contains(outcome) ? "candidate-invariant-direction" : "multiple-object-ambiguity"
        let expected:JSONValue = .object([
            "methodVersion":.string("zengshan-event-sufficient-v1"),"sourceId":.string(sourceID),"assessmentStatus":.string("source-profile-event-direction"),
            "outcome":.string(outcome),"ruleOutcomeEstablished":.bool(["favorable-under-selected-rule","adverse-under-selected-rule"].contains(outcome)),"outcomeEstablished":.bool(false),
            "selectionStatus":.string(selectionStatus),"eventObjectPaths":strings(candidates.map(\.path)),"timingObjectStatus":.string("not-selected"),
            "conditions":.array([ev("selection-prerequisites","/questionContext","/yongShen/candidates","/yongShen/missingContext").json]),
            "candidates":.array(candidates.map(\.json)),"limitations":strings(limits)
        ])
        guard try decodedReport(root:root)==expected else{throw Invalid.record}
        func section(_ id:String,_ text:String,_ paths:[String])throws->LiuyaoReferenceReading.Section {
            var seen=Set<String>();let evidence=try (paths+sourcePaths).filter{seen.insert($0).inserted}.map{
                BaziFrameworkReading.FieldEvidence(toolCallID:receiptID,pointer:$0,value:try r.value($0))
            }
            return .init(id:id,text:text,evidence:evidence)
        }
        let labels=["favorable-under-selected-rule":"有利方向","adverse-under-selected-rule":"不利方向","awaiting-condition":"须待条件","contested":"条件竞争，尚不能定向","unresolved":"尚不能定向"]
        let selectionText=selectionStatus=="candidate-invariant-direction" ? "多个候选在本剖面下方向一致，具体定用仍保留。" : selectionStatus=="multiple-object-ambiguity" ? "多个事件对象有不同条件，未强行排序。" : ""
        var result=[try section("event-direction","事件方向（《增删卜易》充分条件）：\(labels[outcome]!)。\(selectionText)这是选定条文的判断，不是现实事件已经发生或必然发生；尚未选择应期对象，也未推定日期。",["/eventAssessment","/questionContext","/yongShen/candidates"])]
        func objectName(_ p:String)throws->String {
            if p=="/castGanZhi/month" {return "月建"};if p=="/castGanZhi/day" {return "日辰"}
            let parts=p.split(separator:"/")
            guard parts.count>=2,let index=Int(parts[1]) else{throw Invalid.record}
            let layer=p.hasSuffix("/hidden") ? "伏神" : p.hasSuffix("/changed") ? "变爻" : "爻"
            return "第\(index+1)\(layer)（\(try r.string(p+"/ganZhi"))）"
        }
        for (i,c) in candidates.enumerated() {
            let t=try c.transmissions.map { item in
                let status=item.status=="redirected-through-yuan" ? "忌生元、元生用的有效传递" : item.status=="target-cannot-receive" ? "用神无根，不能承接救应" : "传递条件未齐"
                return try "\(objectName(item.ji))→\(objectName(item.yuan))→\(objectName(c.path))：\(status)"
            }.joined(separator:"；")
            let reasons=c.blockers.map(\.rule).map{reasonLabels[$0] ?? "未决条件（\($0)）"}.joined(separator:"、")
            var text=try "事件候选\(objectName(c.path))：\(labels[c.outcome]!)。"
            if !t.isEmpty {text += t+"。"};if !reasons.isEmpty {text += "保留：\(reasons)。"}
            var paths: [String] = ["/eventAssessment/candidates/\(i)", c.path]
            for evidence in c.conditions { paths.append(contentsOf: evidence.paths) }
            for evidence in c.blockers { paths.append(contentsOf: evidence.paths) }
            for transmission in c.transmissions {
                for evidence in transmission.conditions { paths.append(contentsOf: evidence.paths) }
                for evidence in transmission.blockers { paths.append(contentsOf: evidence.paths) }
            }
            result.append(try section("event-candidate-\(i)",text,paths))
        }
        return result
    }
    /// The dictionary is part of the saved receipt; no external/default evidence is accepted.
    static func decodedReport(root:JSONValue)throws->JSONValue {
        let r=Reader(root:root),base="/eventAssessment"
        guard try r.string(base+"/evidenceLayout")=="indexed-event-evidence-v1",
              try r.value(base+"/indexBase") == .integer(0),
              try r.strings(base+"/evidenceColumns")==["ruleIndex","factPathIndices"],
              case var .object(data)=try r.value(base) else{throw Invalid.record}
        let rules=try r.strings(base+"/ruleIDs"),paths=try r.strings(base+"/factPaths"),rows=try r.array(base+"/evidence")
        guard Set(rules).count==rules.count,Set(paths).count==paths.count else{throw Invalid.record}
        for p in paths {guard !p.hasPrefix(base),p.hasPrefix("/"),r.exists(p) else{throw Invalid.record}}
        func index(_ value:JSONValue,_ count:Int)throws->Int {
            guard case let .integer(i)=value,i>=0,i<Int64(count) else{throw Invalid.record};return Int(i)
        }
        var usedRules=Set<Int>(),usedPaths=Set<Int>(),usedRows=Set<Int>(),evidence=[JSONValue]()
        for row in rows {
            guard case let .array(cells)=row,cells.count==2,case let .array(indices)=cells[1] else{throw Invalid.record}
            let rule=try index(cells[0],rules.count);usedRules.insert(rule)
            let factPaths=try indices.map{v->String in let i=try index(v,paths.count);usedPaths.insert(i);return paths[i]}
            let e:JSONValue = .object(["ruleId":.string(rules[rule]),"factPaths":strings(factPaths)])
            guard !evidence.contains(e) else{throw Invalid.record};evidence.append(e)
        }
        func expand(_ value:JSONValue,_ key:String="")throws->JSONValue {
            if ["conditions","blockers"].contains(key) {
                guard case let .array(indices)=value else{throw Invalid.record}
                return .array(try indices.map{v in let i=try index(v,evidence.count);usedRows.insert(i);return evidence[i]})
            }
            switch value {
            case let .object(object):return .object(Dictionary(uniqueKeysWithValues:try object.map{($0.key,try expand($0.value,$0.key))}))
            case let .array(array):return .array(try array.map{try expand($0)})
            default:return value
            }
        }
        for key in ["evidenceLayout","indexBase","evidenceColumns","ruleIDs","factPaths","evidence"] {data.removeValue(forKey:key)}
        let result=try expand(.object(data))
        guard usedRules.count==rules.count,usedPaths.count==paths.count,usedRows.count==evidence.count else{throw Invalid.record}
        return result
    }
    private static let reasonLabels=["calendar-restraint":"日月克制或月破","moving-control":"动爻克制尚未化解","moving-combination":"动爻相合待审","moving-clash":"动爻相冲待审","return-control":"回头克","return-combination":"动化合","return-clash":"动化冲","calendar-combination":"日月合待审","day-clash-needs-strength":"日冲暗动待审","target-lifecycle-unresolved":"目标墓绝条件","changed-target-awaiting-availability":"本位变爻空破待实","target-awaiting-availability":"目标旬空或月破待实","event-sufficient-conditions-not-met":"未满足所选充分条件","original-target-required":"日月或伏神对象尚不在本层范围"]
}
