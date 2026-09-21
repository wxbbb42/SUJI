import Foundation

/// Independent validation of the question-to-object binding. Coordinate checks
/// alone cannot detect a complete, internally consistent answer to an OLD question.
/// This projects only declared candidates; it never casts, selects a final object,
/// or computes calendars, strength, efficacy or dates.
enum CastQuestionBinding {
    static func validate(_ root: JSONValue, method: String) throws {
        let r = Reader(root: root)
        let category = try r.string("/questionType")
        guard CastQuestionDraft.questionTypes.contains(category) else { throw Invalid.record }
        let subject = r.optionalString("/questionContext/subject") ?? "unknown"
        let horizon = r.optionalString("/questionContext/timeHorizon") ?? "unspecified"
        guard CastQuestionDraft.subjects.contains(subject), CastQuestionDraft.timeHorizons.contains(horizon) else { throw Invalid.record }
        var missing: [String] = []
        if subject == "unknown" { missing.append("subject") }
        if (r.optionalString("/questionContext/event") ?? "").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { missing.append("event") }
        if horizon == "unspecified" { missing.append("time-horizon") }
        if method == "cast_liuyao" {
            let people = ["parent":"父母","child":"子孙","sibling":"兄弟","wife":"妻财","husband":"官鬼"]
            var target: String?, selfReference=false, reason="category-role"
            switch category {
            case "health": target=people[subject];selfReference=subject == "self";reason="explicit-person-role"
            case "marriage": target=["wife":"妻财","husband":"官鬼"][subject];reason="explicit-partner-role"
            case "parents", "kids":
                if subject == "unknown" || subject == (category == "parents" ? "parent":"child") { target=category == "parents" ? "父母":"子孙" }
                else { missing.append("category-subject-conflict") }
            case "career", "wealth":
                if ["self","unknown"].contains(subject) { target=category == "career" ? "官鬼":"妻财" }
                else { missing.append("proxy-perspective") }
            default: break
            }
            if target == nil && !selfReference { missing.append("question-object") }
            let lines = try r.array("/lines")
            let matching = try lines.indices.filter { i in
                if selfReference { return r.value("/lines/\(i)/isShi") == .bool(true) }
                guard let target else { return false };return try r.string("/lines/\(i)/liuQin") == target
            }
            var candidates: [JSONValue]=[], related: [JSONValue]=[], excluded: [JSONValue]=[]
            func candidate(_ id:String,_ layer:String,_ path:String,_ position:Int?,_ reason:String) -> JSONValue {
                var c: [String:JSONValue] = ["id":.string(id),"layer":.string(layer),"objectPath":.string(path),"reason":.string(reason)]
                if let position { c["position"] = .integer(Int64(position));c["contextPath"] = .string(path+"/context") };return .object(c)
            }
            for i in matching { candidates.append(candidate("original-\(i+1)","original","/lines/\(i)",i+1,selfReference ? "querent-self-reference":reason)) }
            if matching.isEmpty, let target {
                let palace=try r.string("/benGua/palace")
                guard let element=["乾":"金","兑":"金","离":"火","震":"木","巽":"木","坎":"水","艮":"土","坤":"土"][palace] else { throw Invalid.record }
                let branchElements=["子":"水","丑":"土","寅":"木","卯":"木","辰":"土","巳":"火","午":"火","未":"土","申":"金","酉":"金","戌":"土","亥":"水"]
                for scope in ["month","day"] {
                    let branch=String(try r.string("/castGanZhi/"+scope).suffix(1))
                    guard let wx=branchElements[branch] else { throw Invalid.record }
                    if kin(element,wx) == target { candidates.append(candidate(scope,scope,"/castGanZhi/"+scope,nil,"absent-visible-calendar-role")) }
                }
                for i in lines.indices where r.optionalString("/lines/\(i)/hidden/liuQin") == target {
                    candidates.append(candidate("hidden-\(i+1)","hidden","/lines/\(i)/hidden",i+1,"absent-visible-pure-palace-role"))
                }
            }
            if target != nil || selfReference {
                for i in lines.indices {
                    let path="/lines/\(i)"
                    if !matching.contains(i) { excluded.append(["objectPath":.string(path),"reason":.string(selfReference ? "not-querent-line":"different-role")]) }
                    if let changed=r.optionalString(path+"/changed/liuQin"), selfReference ? matching.contains(i) : changed == target {
                        related.append(candidate("changed-\(i+1)","changed",path+"/changed",i+1,"dependent-changing-reference-only"))
                    }
                }
            }
            let expectedType = target ?? (selfReference ? matching.first.flatMap{r.optionalString("/lines/\($0)/liuQin")} : nil)
            try r.equal("/yongShen/type",expectedType.map(JSONValue.string))
            try r.equal("/yongShen/candidates",.array(candidates));try r.equal("/yongShen/related",.array(related));try r.equal("/yongShen/excluded",.array(excluded))
            try r.equal("/yongShen/candidateYaoIndices",.array(matching.map{.integer(Int64($0+1))}))
            try r.equal("/yongShen/selectionStatus",.string(target != nil || selfReference ? "candidates-only":"requires-clarification"))
            try r.equal("/yingQi/timeScale",.string(horizon == "near" ? "day-hour-reference":horizon == "far" ? "year-month-reference":"unresolved"))
            try r.equal("/yingQi/unresolved",.array((["selected-object","combined-strength","event-outcome"]+missing).map(JSONValue.string)))
        } else {
            if !["self","unknown"].contains(subject) { missing.append("proxy-perspective") }
            if ["kids","parents"].contains(category), subject != "unknown", subject != (category == "kids" ? "child":"parent") { missing.append("category-subject-conflict") }
            let candidates=try r.array("/yongShen/candidates")
            for (i,scope) in ["day","hour"].enumerated() {
                guard candidates.indices.contains(i) else { throw Invalid.record }
                if !(try r.array("/yongShen/candidates/\(i)/occurrences")).contains(where:{
                    if case let .object(o)=$0 { return o["isEffectiveSky"] == .bool(true) };return false
                }) { missing.append(scope+"-sky-reference") }
            }
            let expected: [(String,String,String)]
            switch category {
            case "career":expected=[("door","开门","bamen"),("deity","值符","bashen")]
            case "wealth":expected=[("door","生门","bamen")]
            case "marriage":expected=[("deity","六合","bashen")]
            case "health":expected=[("star","天芮","jiuxing")]
            default:expected=[]
            }
            let categoryIDs=try candidates.indices.compactMap { i -> String? in
                try r.string("/yongShen/candidates/\(i)/role") == "category-reference" ? r.string("/yongShen/candidates/\(i)/id") : nil
            }
            guard categoryIDs == expected.map({"category-"+$0.0+"-"+$0.1}) else { throw Invalid.record }
            var references: [JSONValue]=[];var sourcePalaces: [String:JSONValue]=[:]
            let palaces=try r.array("/palaces")
            for scope in ["day","hour"] {
                let pillar=try r.string("/"+scope+"GanZhi"),stem=String(try r.string("/"+scope+"GanZhi").prefix(1))
                let carrier=stem == "甲" ? ["甲子":"戊","甲戌":"己","甲申":"庚","甲午":"辛","甲辰":"壬","甲寅":"癸"][pillar] : stem
                guard let carrier, let index=palaces.indices.first(where:{r.value("/palaces/\($0)/id") != .integer(5) && [r.optionalString("/palaces/\($0)/tianPanGan"),r.optionalString("/palaces/\($0)/hostedTianPanGan")].contains(carrier)}),let id=r.value("/palaces/\(index)/id") else { throw Invalid.record }
                sourcePalaces[scope]=id
                references.append(["label":.string((scope == "day" ? "日干":"时干")+stem+"参考"),"palaceId":id])
            }
            for i in palaces.indices { for (_,symbol,field) in expected where r.optionalString("/palaces/\(i)/"+field) == symbol {
                guard let id=r.value("/palaces/\(i)/id") else { throw Invalid.record };references.append(["label":.string(symbol),"palaceId":id])
            } }
            let selectedScope=category == "event" ? "hour":"day"
            try r.equal("/yongShen/type",.string(String(try r.string("/"+selectedScope+"GanZhi").prefix(1))))
            try r.equal("/yongShen/palaceId",sourcePalaces[selectedScope]);try r.equal("/yongShen/references",.array(references))
            try r.equal("/yongShen/selectionStatus",.string(missing.isEmpty ? "candidates-only":"requires-clarification"))
            try r.equal("/yingQi/unresolved",.array((["selected-object","event-outcome","qimen-timing-convention","time-unit"]+missing).map(JSONValue.string)))
        }
        try r.equal("/yongShen/missingContext",.array(missing.map(JSONValue.string)))
    }
    private static func kin(_ a:String,_ b:String) -> String {
        let sheng=["木":"火","火":"土","土":"金","金":"水","水":"木"],ke=["木":"土","土":"水","水":"火","火":"金","金":"木"]
        return a == b ? "兄弟":sheng[a] == b ? "子孙":ke[a] == b ? "妻财":sheng[b] == a ? "父母":"官鬼"
    }
    private enum Invalid: LocalizedError {
        case record
        var errorDescription: String? { "补充资料与候选依据不一致。原记录已保留，请重新核对这次占问。" }
    }
    private struct Reader {
        let root:JSONValue
        func value(_ path:String) -> JSONValue? { ReadingVerificationEvidence.pointer(path,in:root) }
        func optionalString(_ path:String) -> String? { if case let .string(s)=value(path) { return s };return nil }
        func string(_ path:String) throws -> String { guard let s=optionalString(path) else { throw Invalid.record };return s }
        func array(_ path:String) throws -> [JSONValue] { guard case let .array(a)=value(path) else { throw Invalid.record };return a }
        func equal(_ path:String,_ expected:JSONValue?) throws { guard value(path) == expected else { throw Invalid.record } }
    }
}
