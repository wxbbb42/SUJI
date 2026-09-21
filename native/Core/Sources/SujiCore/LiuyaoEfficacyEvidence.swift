import Foundation

/// Rebuilds the selected sufficient-condition profile from authenticated saved
/// objects. Packed engine verdicts and their indices are compared, never trusted.
enum LiuyaoEfficacyEvidence {
    static let sourceID="liuyao-efficacy-zengshan-v1"
    static let references=[
        ("09","f3ea262ad33a465dc5e1213c1474bcd5e4998c9e10545a60c6a7ebae0ef2a5ea"),
        ("11","74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb"),
        ("18","4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018"),
        ("22","af41ab6a4f2c336c4f6452acd2cd1e4762bf187bd4d14c7f42c1fe207190b739"),
        ("31","7ed19e9471c398c386a04fb195a1a752469a5e5d307b5eeaca490fcb727affa6"),
        ("38","dda2b500d22d6d43979dae3339ce90cb21289de61aef82a0f8cb17ca11205da5"),
        ("40","e74764848deb4fd0ffe5e3bd16d696701dd5b06de034a085d74f24a35f0f2c2f")
    ].map{("https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy"+$0.0+".html",$0.1)}
    private enum Invalid:Error { case record }
    private static let generates=["木":"火","火":"土","土":"金","金":"水","水":"木"]
    private static let controls=["木":"土","土":"水","水":"火","火":"金","金":"木"]
    private static let branches="子丑寅卯辰巳午未申酉戌亥".map(String.init)
    private static func clash(_ a:String,_ b:String)->Bool { guard let i=branches.firstIndex(of:a),let j=branches.firstIndex(of:b) else{return false};return (i+6)%12==j }
    private static func combine(_ a:String,_ b:String)->Bool { guard let i=branches.firstIndex(of:a),let j=branches.firstIndex(of:b) else{return false};return (13-i)%12==j }
    private static func strings(_ a:[String])->JSONValue { .array(a.map{.string($0)}) }
    private struct Evidence:Equatable {
        var id:String;var paths:[String]
        var json:JSONValue { .object(["id":.string(id),"factPaths":strings(paths)]) }
    }
    private static func ev(_ id:String,_ paths:String...)->Evidence { .init(id:id,paths:paths) }
    private struct Decision {
        var status:String;var conditions:[Evidence]=[];var blockers:[Evidence]=[]
        var json:JSONValue { .object(["status":.string(status),"conditions":.array(conditions.map(\.json)),"blockers":.array(blockers.map(\.json))]) }
    }
    private struct Reference {
        var scope:String;var source:String;var decision:Decision
        var json:JSONValue { guard case var .object(o)=decision.json else{preconditionFailure()};o["scope"] = .string(scope);o["sourcePath"] = .string(source);return .object(o) }
    }
    private struct ObjectRow {
        var path:String;var original:String;var layer:String;var element:String;var branch:String
        var calendar:String;var support:[String];var restraint:[String]
        var vitality:Decision;var activity:Decision;var availability:Decision
        var tombs:[Reference]=[];var extinctions:[Reference]=[]
        var json:JSONValue { .object(["objectPath":.string(path),"calendarStrength":.object(["status":.string(calendar),"supportPaths":strings(support),"restraintPaths":strings(restraint)]),"vitality":vitality.json,"activity":activity.json,"availability":availability.json,"tombs":.array(tombs.map(\.json)),"extinctions":.array(extinctions.map(\.json))]) }
    }
    private struct Reader {
        let root:JSONValue
        func value(_ p:String)throws->JSONValue { guard let v=ReadingVerificationEvidence.pointer(p,in:root) else{throw Invalid.record};return v }
        func string(_ p:String)throws->String { guard case let .string(v)=try value(p) else{throw Invalid.record};return v }
        func bool(_ p:String)throws->Bool { guard case let .bool(v)=try value(p) else{throw Invalid.record};return v }
        func array(_ p:String)throws->[JSONValue] { guard case let .array(v)=try value(p) else{throw Invalid.record};return v }
        func strings(_ p:String)throws->[String] { try array(p).map{guard case let .string(v)=$0 else{throw Invalid.record};return v} }
        func exists(_ p:String)->Bool { ReadingVerificationEvidence.pointer(p,in:root) != nil }
        func branch(_ p:String)throws->String { String(try string(p+"/ganZhi").suffix(1)) }
    }
    static func sections(root:JSONValue,receiptID:String,sourcePaths:[String])throws->[LiuyaoReferenceReading.Section] {
        let r=Reader(root:root),originals=(0..<6).map{"/lines/\($0)"}
        let movers=try originals.filter{try r.bool($0+"/isChanging")}
        try validateCandidates(r)
        let candidates=try r.array("/yongShen/candidates")
        let calendarCandidates=candidates.filter{["day","month"].contains(ReadingVerificationEvidence.pointer("/layer",in:$0).flatMap{if case let .string(s)=$0{return s};return nil} ?? "")}
        let eligible=calendarCandidates.isEmpty ? candidates : calendarCandidates
        let subject=ReadingVerificationEvidence.pointer("/questionContext/subject",in:root)
        let event=ReadingVerificationEvidence.pointer("/questionContext/event",in:root)
        let explicitSubject:Bool;if case let .string(s)=subject {explicitSubject = !s.isEmpty && s != "unknown"} else {explicitSubject=false}
        let explicitEvent:Bool;if case let .string(s)=event {explicitEvent = !s.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty} else {explicitEvent=false}
        let explicit=try explicitSubject && explicitEvent && (r.strings("/yongShen/missingContext")).allSatisfy{!["category-subject-conflict","proxy-perspective","question-object"].contains($0)}
        let selected=explicit && eligible.count==1 ? eligible.first : nil
        let selectedReader=selected.map{Reader(root:$0)}
        let selectedLayer=try selectedReader?.string("/layer")
        let selectionStatus = !explicit ? "requires-context" : eligible.isEmpty ? "absent" : eligible.count>1 ? "multiple-candidates" : ["month","day"].contains(selectedLayer ?? "") ? "calendar-reference" : "selected"
        let selection:JSONValue = .object(["status":.string(selectionStatus),"selectedCandidateId":try selectedReader.map{try $0.value("/id")} ?? .null,"candidateIds":.array(try candidates.map{try Reader(root:$0).value("/id")}),"eligibleCandidateIds":.array(try eligible.map{try Reader(root:$0).value("/id")}),"factPaths":strings(["/questionContext","/yongShen/candidates","/yongShen/missingContext"])])
        var basics=[ObjectRow]()
        for original in originals {
            let paths=[original]+["changed","hidden"].map{original+"/"+$0}.filter{r.exists($0)}
            for p in paths {
                let layer=p==original ? "original" : p.hasSuffix("/changed") ? "changed" : "hidden"
                let c=p+"/context",element=try r.string(p+"/wuXing"),b=try r.branch(p)
                let support=try ["month","day"].filter{try ["同类","生爻"].contains(r.string(c+"/"+$0+"/elementRelation"))}.map{c+"/"+$0+"/elementRelation"}
                var restraint=try ["month","day"].filter{try r.string(c+"/"+$0+"/elementRelation")=="克爻"}.map{c+"/"+$0+"/elementRelation"}
                let monthClash=try r.bool(c+"/month/clash"),dayClash=try r.bool(c+"/day/clash")
                if monthClash {restraint.append(c+"/month/clash")}
                let rootless=try monthClash && (r.string(c+"/day/elementRelation"))=="克爻"
                let strength=rootless ? "rootless-condition" : !support.isEmpty && !restraint.isEmpty ? "balanced" : !support.isEmpty ? "supported" : !restraint.isEmpty ? "opposed" : "neutral"
                let conditions=support.map{ev("calendar-support",$0)}
                var blockers=restraint.map{ev("calendar-restraint",$0)},rescue=[Evidence]()
                if layer != "changed" {
                    for actor in movers where actor != original {
                        let ae=try r.string(actor+"/wuXing"),ab=try r.branch(actor)
                        if controls[ae]==element {blockers.append(ev("moving-control",actor+"/isChanging",actor+"/wuXing",p+"/wuXing"))}
                        if combine(ab,b) {blockers.append(ev("moving-combination",actor+"/isChanging",actor+"/ganZhi",p+"/ganZhi"))}
                        if clash(ab,b) {blockers.append(ev("moving-clash",actor+"/isChanging",actor+"/ganZhi",p+"/ganZhi"))}
                        if ae==element || generates[ae]==element {rescue.append(ev("moving-support-requires-actor",actor+"/isChanging",actor+"/wuXing",p+"/wuXing"))}
                    }
                }
                if layer=="original",r.exists(original+"/changed") {
                    let cp=original+"/changed",ce=try r.string(cp+"/wuXing"),cb=try r.branch(cp)
                    if controls[ce]==element {blockers.append(ev("return-control",cp+"/wuXing",p+"/wuXing"))}
                    if combine(b,cb) {blockers.append(ev("return-combination",p+"/ganZhi",cp+"/ganZhi"))}
                    if clash(b,cb) {blockers.append(ev("return-clash",p+"/ganZhi",cp+"/ganZhi"))}
                    if generates[ce]==element {rescue.append(ev("return-generation",cp+"/wuXing",p+"/wuXing"))}
                }
                if layer=="hidden" {
                    let fe=try r.string(original+"/wuXing")
                    if controls[fe]==element {blockers.append(ev("flying-control",original+"/wuXing",p+"/wuXing"))}
                    if generates[fe]==element {rescue.append(ev("flying-generation",original+"/wuXing",p+"/wuXing"))}
                }
                for scope in ["month","day"] where try r.bool(c+"/"+scope+"/combination") {blockers.append(ev("calendar-combination",c+"/"+scope+"/combination"))}
                let moving=try r.bool(original+"/isChanging")
                if layer=="original" && !moving && dayClash {blockers.append(ev("day-clash-needs-strength",p+"/isChanging",c+"/day/clash"))}
                let exceptional=rescue.contains{["return-generation","flying-generation"].contains($0.id)}
                let vitalityStatus=rootless && !exceptional ? "rootless" : !support.isEmpty && blockers.isEmpty ? "supported-unopposed" : support.isEmpty && !restraint.isEmpty && rescue.isEmpty ? "opposed-unrescued" : !blockers.isEmpty || !rescue.isEmpty ? "contested" : "neutral"
                let vitality=Decision(status:vitalityStatus,conditions:conditions+rescue,blockers:blockers)
                let activity=Decision(status:layer=="changed" ? "dependent" : layer=="hidden" ? "hidden" : moving ? "explicit-moving" : dayClash ? "requires-dark-movement" : "static",conditions:layer=="original" ? [ev("motion-fact",p+"/isChanging")] : [])
                let isVoid=try r.bool(c+"/isVoid"),sameDay=try r.bool(c+"/day/sameBranch")
                let availability=Decision(status:isVoid ? "awaiting-void-fill" : monthClash && !sameDay ? "awaiting-break-fill" : layer=="hidden" ? "requires-emergence" : "present",conditions:(isVoid ? [ev("current-void",c+"/isVoid")] : [])+(monthClash ? [ev("month-break",c+"/month/clash",c+"/day/sameBranch")] : []))
                basics.append(.init(path:p,original:original,layer:layer,element:element,branch:b,calendar:strength,support:support,restraint:restraint,vitality:vitality,activity:activity,availability:availability))
            }
        }
        let structural=try r.array("/tombExtinction/objects")
        var objects=[ObjectRow]()
        for var row in basics {
            let p=row.path
            guard let ti=structural.firstIndex(where:{ReadingVerificationEvidence.pointer("/objectPath",in:$0) == .string(p)}) else{throw Invalid.record}
            let tp="/tombExtinction/objects/\(ti)"
            var refs=[(scope:String,source:String,branch:String,path:String,kind:String)]()
            for scope in ["month","day"] {
                let kind=try r.string(tp+"/"+scope)
                if kind != "neither" {refs.append((scope,"/castGanZhi/"+scope,try r.string(p+"/context/"+scope+"/branch"),tp+"/"+scope,kind))}
            }
            for (key,scope,source) in [("ownChange","own-change",p+"/changed"),("flying","flying",row.original)] where r.exists(tp+"/"+key) {
                let kind=try r.string(tp+"/"+key)
                if kind != "neither" {refs.append((scope,source,try r.branch(source),tp+"/"+key,kind))}
            }
            for (key,kind) in [("movingTombPositions","墓"),("movingExtinctionPositions","绝")] {
                for position in try r.array(tp+"/"+key) {
                    guard case let .integer(n)=position,(1...6).contains(n) else{throw Invalid.record}
                    let source="/lines/\(n-1)";refs.append(("moving",source,try r.branch(source),tp+"/"+key,kind))
                }
            }
            for ref in refs {
                var d=Decision(status:"conditional",conditions:[ev("structural-reference",ref.path)])
                if ref.kind=="墓" {
                    let opening=try ["month","day"].filter{try clash(r.string(p+"/context/"+$0+"/branch"),ref.branch)}
                    if !opening.isEmpty {d.status="opened";d.conditions += opening.map{ev("calendar-opens-tomb","/castGanZhi/"+$0,ref.path)}}
                    else if row.vitality.status=="supported-unopposed" {d.status="nonbinding-strength";d.conditions += row.vitality.conditions}
                    else if ["opposed-unrescued","rootless"].contains(row.vitality.status) {d.status="binding";d.conditions += row.vitality.blockers}
                    else {d.blockers += row.vitality.blockers+row.vitality.conditions.filter{$0.id.contains("requires-actor")}}
                    for actor in movers where try actor != ref.source && clash(r.branch(actor),ref.branch) {
                        d.blockers.append(ev("moving-tomb-opening-requires-actor",actor+"/isChanging",actor+"/ganZhi",ref.path))
                        if d.status=="binding" {d.status="conditional"}
                    }
                    if ["moving","own-change","flying"].contains(ref.scope) {
                        guard let source=basics.first(where:{$0.path==ref.source}) else{throw Invalid.record}
                        if source.availability.status != "present" && d.status=="binding" {d.status="conditional";d.blockers += source.availability.conditions}
                    }
                    row.tombs.append(.init(scope:ref.scope,source:ref.source,decision:d))
                } else {
                    let independent=row.support.contains{!(["month","day"].contains(ref.scope) && $0==p+"/context/"+ref.scope+"/elementRelation")}
                    if row.element=="土" && ref.branch=="巳" && row.vitality.status=="supported-unopposed" && independent {d.status="overridden-by-generation";d.conditions += row.vitality.conditions}
                    else if ["opposed-unrescued","rootless"].contains(row.vitality.status) {
                        d.status="effective";d.conditions += row.vitality.blockers
                        if ["moving","flying"].contains(ref.scope) {d.status="conditional";d.blockers.append(ev("extinction-actor-requires-effectiveness",ref.source+"/context",ref.path))}
                    } else {d.blockers += row.vitality.blockers}
                    if ref.scope=="own-change" && d.status=="effective" {
                        guard let source=basics.first(where:{$0.path==ref.source}) else{throw Invalid.record}
                        if source.availability.status != "present" {d.status="conditional";d.blockers += source.availability.conditions}
                    }
                    row.extinctions.append(.init(scope:ref.scope,source:ref.source,decision:d))
                }
            }
            objects.append(row)
        }
        var triads=[JSONValue]()
        for i in try r.array("/triads/groups").indices {
            let gp="/triads/groups/\(i)",scope=try r.string(gp+"/scope"),complete=try r.bool(gp+"/complete")
            let paths=try (0..<3).flatMap{try r.strings(gp+"/members/\($0)/objectPaths")}
            let moving=movers.filter{paths.contains($0)}
            let movingBranches=Set(try moving.map{try r.branch($0)})
            let state:String
            if scope=="calendar-moving-anchor" {let anchor=try r.string(gp+"/anchorPath");state=try r.bool(anchor+"/isShi") ? (complete ? "formed" : "awaiting-member") : "requires-scope-evidence"}
            else if ["inner-change","outer-change"].contains(scope) {state=complete ? "formed" : "awaiting-member"}
            else {state=moving.isEmpty ? "not-formed" : !complete ? "awaiting-member" : movingBranches.count==3 ? "formed" : "competing-text"}
            let formation=Decision(status:state,conditions:[ev("scoped-members",gp+"/scope",gp+"/members",gp+"/missingBranches")]+moving.map{ev("actual-moving-member",$0+"/isChanging")},blockers:state=="competing-text" ? [ev("motion-text-competition",gp+"/scope",gp+"/members")] : [])
            var effect=Decision(status:state)
            if state=="formed" {
                let members=objects.filter{paths.contains($0.path)},pending=members.filter{["awaiting-void-fill","awaiting-break-fill"].contains($0.availability.status)}
                let bound=members.flatMap(\.tombs).filter{$0.decision.status=="binding"}
                for member in members {
                    effect.blockers += member.vitality.blockers
                    for life in member.tombs+member.extinctions where ["conditional","effective"].contains(life.decision.status) {
                        effect.blockers.append(.init(id:"member-lifecycle-condition",paths:[member.path+"/context"]+life.decision.conditions.flatMap(\.paths)))
                    }
                }
                if !pending.isEmpty {effect.status="awaiting-void-break";effect.conditions += pending.flatMap{$0.availability.conditions}}
                else if !bound.isEmpty {effect.status="awaiting-tomb-open";effect.conditions += bound.flatMap{$0.decision.conditions}}
                else {effect.status=effect.blockers.isEmpty ? "effective-under-selected-rule" : "conditional"}
            }
            triads.append(.object(["groupPath":.string(gp),"formation":formation.json,"efficacy":effect.json]))
        }
        var selectedEffect=Decision(status:"requires-selection",blockers:[ev("selection-prerequisite","/questionContext","/yongShen/candidates")])
        if let selectedReader {
            let path=try selectedReader.string("/objectPath")
            if let target=objects.first(where:{$0.path==path}) {
                let bound=target.tombs.contains{$0.decision.status=="binding"} || target.extinctions.contains{$0.decision.status=="effective"}
                let pending=target.availability.status != "present" || target.tombs.contains{$0.decision.status=="nonbinding-strength"}
                let ambiguous=(target.tombs+target.extinctions).contains{$0.decision.status=="conditional"}
                let status=target.vitality.status=="rootless" || bound ? "blocked" : pending ? "awaiting-condition" : target.vitality.status=="supported-unopposed" && !ambiguous ? "effective-under-selected-rule" : "conditional"
                selectedEffect=Decision(status:status,conditions:target.vitality.conditions+target.availability.conditions+target.tombs.flatMap{$0.decision.conditions}+target.extinctions.flatMap{$0.decision.conditions},blockers:target.vitality.blockers)
            } else {selectedEffect=Decision(status:"calendar-reference",conditions:[ev("selected-calendar",path)])}
        }
        let expected:JSONValue = .object(["methodVersion":.string("zengshan-sufficient-conditions-v1"),"sourceId":.string(sourceID),"assessmentStatus":.string("source-selected-conditional"),"selection":selection,"objects":.array(objects.map(\.json)),"triads":.array(triads),"selectedEffect":selectedEffect.json,"outcomeEstablished":.bool(false),"limitations":strings(["current-rule-effects-only","no-event-or-date-verdict","competing-actors-not-automatically-resolved","two-appearance-selection-not-fixed-ranking"])])
        let expanded=try decodedReport(root:root)
        guard expanded==expected else{throw Invalid.record}
        let policy=sourcePaths+["/efficacy/methodVersion","/efficacy/sourceId","/efficacy/assessmentStatus","/efficacy/outcomeEstablished","/efficacy/limitations","/efficacy/evidenceLayout","/efficacy/evidenceColumns","/efficacy/evidence","/efficacy/factPaths","/efficacy/indexBase","/efficacy/objectColumns","/efficacy/calendarStrengthColumns","/efficacy/referenceColumns","/efficacy/triadColumns","/efficacy/decisionColumns","/efficacy/decisions","/efficacy/states","/efficacy/ruleIDs","/efficacy/factPathColumns","/efficacy/pathRoots","/efficacy/pathSuffixes"]
        func section(_ id:String,_ text:String,_ paths:[String])throws->LiuyaoReferenceReading.Section {
            var seen=Set<String>()
            return .init(id:id,text:text,evidence:try (paths+policy).filter{seen.insert($0).inserted}.map{.init(toolCallID:receiptID,pointer:$0,value:try r.value($0))})
        }
        let labels=["requires-context":"仍缺明确所问","absent":"未找到适用对象","multiple-candidates":"多候选并存，尚未唯一选定","calendar-reference":"日月参照对象","selected":"已唯一选定所问对象","requires-selection":"待定用","blocked":"当前规则受阻","awaiting-condition":"仍待条件","effective-under-selected-rule":"所选条文的当前前提满足","conditional":"竞争条件未解"]
        var sections=[try section("efficacy-selection","按《增删卜易》选定条文：\(labels[selectionStatus] ?? selectionStatus)；当前效力为\(labels[selectedEffect.status] ?? selectedEffect.status)。日月生扶只作局部证据；动克、回头克、合冲及施动者条件逐对象审查。两现不按空破固定排序。这些状态不是事件吉凶或应期日期。",["/efficacy/selection","/efficacy/selectedEffect","/questionContext","/yongShen/candidates","/yongShen/missingContext"])]
        let stateLabels=["rootless":"月破并日克的无根条件","supported-unopposed":"已有日月支持且未见本层竞争","opposed-unrescued":"受制且未见本层救应","contested":"存在竞争条件","neutral":"未形成充分强弱条件","present":"当前在位","awaiting-void-fill":"旬空待填","awaiting-break-fill":"月破待填","requires-emergence":"伏神待出","opened":"墓源已被日月冲开","nonbinding-strength":"旺而非真墓，仍待开墓","binding":"符合所选真墓前提","conditional":"条件待审","effective":"符合所选绝的前提","overridden-by-generation":"旺土遇巳按生论"]
        for (i,row) in objects.enumerated() {
            let position=Int(row.original.split(separator:"/")[1])!+1,layer=row.layer=="changed" ? "化爻" : row.layer=="hidden" ? "伏神" : "本爻"
            let life=(row.tombs+row.extinctions).map{"\($0.scope)：\(stateLabels[$0.decision.status] ?? $0.decision.status)"}.joined(separator:"；")
            var evidence: [Evidence] = row.vitality.conditions
            evidence.append(contentsOf: row.vitality.blockers)
            evidence.append(contentsOf: row.availability.conditions)
            for reference in row.tombs {
                evidence.append(contentsOf: reference.decision.conditions)
                evidence.append(contentsOf: reference.decision.blockers)
            }
            for reference in row.extinctions {
                evidence.append(contentsOf: reference.decision.conditions)
                evidence.append(contentsOf: reference.decision.blockers)
            }
            var paths: [String] = ["/efficacy/objects/\(i)", row.path]
            paths.append(contentsOf: evidence.flatMap(\.paths))
            let text = "第\(position)爻\(layer)：\(stateLabels[row.vitality.status]!)；\(stateLabels[row.availability.status]!)。"
                + (life.isEmpty ? "" : life + "。")
            sections.append(try section("efficacy-object-\(i)", text, paths))
        }
        let formationLabels=["formed":"本范围成局前提满足","awaiting-member":"尚缺成员","not-formed":"静支齐备不成动局","competing-text":"动静条文竞争，暂不判定成局","requires-scope-evidence":"非世日月锚点缺效力依据","awaiting-void-break":"待填空破","awaiting-tomb-open":"待开真墓","conditional":"仍有竞争条件","effective-under-selected-rule":"本层效力前提满足"]
        let decodedReader=Reader(root:.object(["efficacy":expanded]))
        for i in triads.indices {
            let p="/efficacy/triads/\(i)",formation=try decodedReader.string(p+"/formation/status"),effect=try decodedReader.string(p+"/efficacy/status")
            sections.append(try section("efficacy-triad-\(i)","第\(i+1)组三合：\(formationLabels[formation]!)；\(formationLabels[effect]!)。成局与当前效力分别判断，未据此断合化或事件结果。",[p,"/triads/groups/\(i)"]))
        }
        return sections
    }
    /// Authenticating individual coordinates is insufficient: omissions could turn
    /// two appearances into an apparently unique object. Rebuild the full set.
    private static func validateCandidates(_ r:Reader)throws {
        let context=Reader(root:try r.value("/questionContext"))
        let subject=context.exists("/subject") ? try context.string("/subject") : "unknown"
        let event=context.exists("/event") ? try context.string("/event") : ""
        let horizon=context.exists("/timeHorizon") ? try context.string("/timeHorizon") : "unspecified"
        let qt=try r.string("/questionType")
        guard ["self","parent","child","sibling","wife","husband","other","unknown"].contains(subject),["near","far","unspecified"].contains(horizon),["general","event","health","marriage","parents","kids","career","wealth"].contains(qt) else{throw Invalid.record}
        var missing=[String](),target:String?,selfReference=false,reason="category-role"
        if subject=="unknown" {missing.append("subject")}
        if event.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {missing.append("event")}
        if horizon=="unspecified" {missing.append("time-horizon")}
        if qt=="health" {target=["parent":"父母","child":"子孙","sibling":"兄弟","wife":"妻财","husband":"官鬼"][subject];selfReference=subject=="self";reason="explicit-person-role"}
        else if qt=="marriage" {target=subject=="wife" ? "妻财" : subject=="husband" ? "官鬼" : nil;reason="explicit-partner-role"}
        else if ["parents","kids"].contains(qt) {
            if subject=="unknown" || subject==(qt=="parents" ? "parent" : "child") {target=qt=="parents" ? "父母" : "子孙"}
            else {missing.append("category-subject-conflict")}
        } else if ["career","wealth"].contains(qt) {
            if ["self","unknown"].contains(subject) {target=qt=="career" ? "官鬼" : "妻财"}
            else {missing.append("proxy-perspective")}
        }
        if target==nil && !selfReference {missing.append("question-object")}
        let originals=(0..<6).map{"/lines/\($0)"}
        func matches(_ p:String)throws->Bool {if selfReference{return try r.bool(p+"/isShi")};return try target != nil && r.string(p+"/liuQin")==target}
        let matching=try originals.filter{try matches($0)}
        func candidate(_ p:String,_ layer:String,_ reason:String)throws->JSONValue {
            let position=Int(p.split(separator:"/")[1])!+1
            return .object(["id":.string(layer+"-\(position)"),"layer":.string(layer),"position":.integer(Int64(position)),"objectPath":.string(p),"contextPath":.string(p+"/context"),"reason":.string(reason)])
        }
        var candidates=try matching.map{try candidate($0,"original",selfReference ? "querent-self-reference" : reason)}
        if matching.isEmpty,let target {
            let palace=try r.string("/benGua/palace")
            guard let element=["乾":"金","兑":"金","离":"火","震":"木","巽":"木","坎":"水","艮":"土","坤":"土"][palace] else{throw Invalid.record}
            let elements=["水","土","木","木","土","火","火","土","金","金","土","水"]
            for scope in ["month","day"] {
                let b=String(try r.string("/castGanZhi/"+scope).suffix(1))
                guard let i=branches.firstIndex(of:b) else{throw Invalid.record}
                let e=elements[i],role=e==element ? "兄弟" : generates[e]==element ? "父母" : generates[element]==e ? "子孙" : controls[element]==e ? "妻财" : "官鬼"
                if role==target {candidates.append(.object(["id":.string(scope),"layer":.string(scope),"objectPath":.string("/castGanZhi/"+scope),"reason":.string("absent-visible-calendar-role")]))}
            }
            for p in originals where try r.exists(p+"/hidden") && r.string(p+"/hidden/liuQin")==target {candidates.append(try candidate(p+"/hidden","hidden","absent-visible-pure-palace-role"))}
        }
        var related=[JSONValue](),excluded=[JSONValue]()
        if target != nil || selfReference {
            for p in originals {
                if try !matches(p) {excluded.append(.object(["objectPath":.string(p),"reason":.string(selfReference ? "not-querent-line" : "different-role")]))}
                if r.exists(p+"/changed") {
                    let match=try selfReference ? r.bool(p+"/isShi") : r.string(p+"/changed/liuQin")==target
                    if match {related.append(try candidate(p+"/changed","changed","dependent-changing-reference-only"))}
                }
            }
        }
        let type=try target ?? (matching.first.map{try r.string($0+"/liuQin")})
        guard try r.value("/yongShen/candidates") == .array(candidates),try r.value("/yongShen/related") == .array(related),try r.value("/yongShen/excluded") == .array(excluded),try r.strings("/yongShen/missingContext")==missing,
              try r.string("/yongShen/selectionStatus")==((target != nil || selfReference) ? "candidates-only" : "requires-clarification"),
              try r.value("/yongShen/candidateYaoIndices") == .array(matching.map{.integer(Int64(Int($0.split(separator:"/")[1])!+1))}),
              ReadingVerificationEvidence.pointer("/yongShen/type",in:r.root)==type.map({.string($0)}) else{throw Invalid.record}
    }
    /// Maps canonical logical coordinates to the exact original receipt cells.
    /// Shared fact indexing can retain the original tuple pointer and raw value.
    static func canonicalPointers(root:JSONValue)throws->[String:String] { try unpackRows(root:root).pointers }
    private static func unpackRows(root:JSONValue)throws->(report:JSONValue,pointers:[String:String]) {
        let r=Reader(root:root),base="/efficacy"
        let objectColumns=["objectPath","calendarStrength","vitality","activity","availability","tombs","extinctions"]
        let strengthColumns=["statusIndex","supportPaths","restraintPaths"],referenceColumns=["scope","sourcePath","decisionIndex"],triadColumns=["groupPath","formation","efficacy"],decisionColumns=["statusIndex","conditions","blockers"]
        guard try r.string(base+"/evidenceLayout")=="indexed-object-decision-evidence-tuples-v2",try r.value(base+"/indexBase") == .integer(0),
              try r.strings(base+"/objectColumns")==objectColumns,try r.strings(base+"/calendarStrengthColumns")==strengthColumns,
              try r.strings(base+"/referenceColumns")==referenceColumns,try r.strings(base+"/triadColumns")==triadColumns,
              try r.strings(base+"/decisionColumns")==decisionColumns,case var .object(data)=try r.value(base) else{throw Invalid.record}
        let decisions=try r.array(base+"/decisions"),states=try r.strings(base+"/states")
        guard Set(states).count==states.count else{throw Invalid.record}
        var pointers=[String:String](),used=Set<Int>(),usedStates=Set<Int>()
        func copied(_ value:JSONValue,_ canonical:String,_ original:String)->JSONValue {
            pointers[canonical]=original
            switch value {
            case let .object(o):for (k,v) in o {_ = copied(v,canonical+"/"+k,original+"/"+k)}
            case let .array(a):for (i,v) in a.enumerated() {_ = copied(v,canonical+"/\(i)",original+"/\(i)")}
            default:break
            }
            return value
        }
        func fields(_ columns:[String],_ path:String,_ canonical:String)throws->[String:JSONValue] {
            let values=try r.array(path);guard values.count==columns.count else{throw Invalid.record}
            pointers[canonical]=path
            return Dictionary(uniqueKeysWithValues:columns.indices.map{(columns[$0],copied(values[$0],canonical+"/"+columns[$0],path+"/\($0)"))})
        }
        for (i,d) in decisions.enumerated() {
            guard case let .array(a)=d,a.count==3,case .integer=a[0],case .array=a[1],case .array=a[2],!decisions.prefix(i).contains(d) else{throw Invalid.record}
        }
        func withStatus(_ row:[String:JSONValue],_ canonical:String)throws->[String:JSONValue] {
            var data=row
            guard case let .integer(i)=data.removeValue(forKey:"statusIndex"),i>=0,i<Int64(states.count) else{throw Invalid.record}
            usedStates.insert(Int(i));data["status"] = .string(states[Int(i)]);pointers[canonical+"/status"] = base+"/states/\(i)"
            return data
        }
        func decision(_ indexPath:String,_ canonical:String)throws->JSONValue {
            guard case let .integer(i)=try r.value(indexPath),i>=0,i<Int64(decisions.count) else{throw Invalid.record}
            used.insert(Int(i));return .object(try withStatus(fields(decisionColumns,base+"/decisions/\(i)",canonical),canonical))
        }
        func references(_ path:String,_ canonical:String)throws->JSONValue {
            .array(try r.array(path).indices.map{i in
                let p=path+"/\(i)",c=canonical+"/\(i)"
                var ref=try fields(referenceColumns,p,c)
                guard case let .object(d)=try decision(p+"/2",c) else{throw Invalid.record}
                ref.removeValue(forKey:"decisionIndex")
                return .object(ref.merging(d){_,new in new})
            })
        }
        var objects=[JSONValue]()
        for i in try r.array(base+"/objects").indices {
            let p=base+"/objects/\(i)"
            var row=try fields(objectColumns,p,p)
            row["calendarStrength"] = .object(try withStatus(fields(strengthColumns,p+"/1",p+"/calendarStrength"),p+"/calendarStrength"))
            for (key,col) in [("vitality",2),("activity",3),("availability",4)] {row[key]=try decision(p+"/\(col)",p+"/"+key)}
            row["tombs"]=try references(p+"/5",p+"/tombs");row["extinctions"]=try references(p+"/6",p+"/extinctions")
            objects.append(.object(row))
        }
        var triads=[JSONValue]()
        for i in try r.array(base+"/triads").indices {
            let p=base+"/triads/\(i)"
            var row=try fields(triadColumns,p,p)
            row["formation"]=try decision(p+"/1",p+"/formation");row["efficacy"]=try decision(p+"/2",p+"/efficacy")
            triads.append(.object(row))
        }
        for (key,value) in data where !["objects","triads","selectedEffect"].contains(key) {_ = copied(value,base+"/"+key,base+"/"+key)}
        data["objects"] = .array(objects);data["triads"] = .array(triads);data["selectedEffect"] = try decision(base+"/selectedEffect",base+"/selectedEffect")
        guard used.count==decisions.count,usedStates.count==states.count else{throw Invalid.record}
        for key in ["indexBase","objectColumns","calendarStrengthColumns","referenceColumns","triadColumns","decisionColumns","decisions","states"] {data.removeValue(forKey:key)}
        return (.object(data),pointers)
    }
    /// Strict tuple/path decoding rejects extra columns, invalid indices, unused
    /// rows, duplicate entries and pointers into the verdict being verified.
    static func decodedReport(root:JSONValue)throws->JSONValue {
        let r=Reader(root:root)
        let unpacked=try unpackRows(root:root)
        guard try r.strings("/efficacy/evidenceColumns")==["ruleIndex","factPathIndices"],try r.strings("/efficacy/factPathColumns")==["rootIndex","suffixIndex"],case var .object(data)=unpacked.report else{throw Invalid.record}
        let roots=try r.strings("/efficacy/pathRoots"),suffixes=try r.strings("/efficacy/pathSuffixes"),rules=try r.strings("/efficacy/ruleIDs")
        guard Set(roots).count==roots.count,Set(suffixes).count==suffixes.count,Set(rules).count==rules.count else{throw Invalid.record}
        var usedRoots=Set<Int>(),usedSuffixes=Set<Int>(),usedRules=Set<Int>()
        func bounded(_ value:JSONValue,_ bound:Int)throws->Int {guard case let .integer(i)=value,i>=0,i<Int64(bound) else{throw Invalid.record};return Int(i)}
        let paths=try r.array("/efficacy/factPaths").map{value->String in
            guard case let .array(row)=value,row.count==2 else{throw Invalid.record}
            let a=try bounded(row[0],roots.count),b=try bounded(row[1],suffixes.count)
            usedRoots.insert(a);usedSuffixes.insert(b)
            guard roots[a].hasPrefix("/"),suffixes[b].isEmpty || suffixes[b].hasPrefix("/") else{throw Invalid.record}
            return roots[a]+suffixes[b]
        },tuples=try r.array("/efficacy/evidence")
        guard Set(paths).count==paths.count else{throw Invalid.record}
        for p in paths {guard !p.hasPrefix("/efficacy"),r.exists(p) else{throw Invalid.record}}
        var usedPaths=Set<Int>(),usedRows=Set<Int>()
        func index(_ value:JSONValue,_ bound:Int)throws->Int {guard case let .integer(v)=value,v>=0,v<Int64(bound),let n=Int(exactly:v) else{throw Invalid.record};return n}
        func decodePaths(_ value:JSONValue)throws->JSONValue {
            guard case let .array(values)=value else{throw Invalid.record}
            return .array(try values.map{let n=try index($0,paths.count);usedPaths.insert(n);return .string(paths[n])})
        }
        var evidence=[JSONValue]()
        for tuple in tuples {
            guard case let .array(row)=tuple,row.count==2 else{throw Invalid.record}
            let rule=try bounded(row[0],rules.count),id=rules[rule];usedRules.insert(rule)
            guard !id.isEmpty else{throw Invalid.record}
            let decoded:JSONValue = .object(["id":.string(id),"factPaths":try decodePaths(row[1])])
            guard !evidence.contains(decoded) else{throw Invalid.record};evidence.append(decoded)
        }
        func visit(_ value:JSONValue,_ key:String="")throws->JSONValue {
            if ["conditions","blockers"].contains(key) {
                guard case let .array(values)=value else{throw Invalid.record}
                return .array(try values.map{let n=try index($0,evidence.count);usedRows.insert(n);return evidence[n]})
            }
            if ["factPaths","supportPaths","restraintPaths"].contains(key) {return try decodePaths(value)}
            switch value {
            case let .object(o):return .object(Dictionary(uniqueKeysWithValues:try o.map{($0.key,try visit($0.value,$0.key))}))
            case let .array(a):return .array(try a.map{try visit($0)})
            default:return value
            }
        }
        for key in ["evidenceLayout","evidenceColumns","evidence","factPaths","ruleIDs","factPathColumns","pathRoots","pathSuffixes"] {data.removeValue(forKey:key)}
        let decoded=try visit(.object(data))
        guard usedRows.count==evidence.count,usedPaths.count==paths.count,usedRoots.count==roots.count,usedSuffixes.count==suffixes.count,usedRules.count==rules.count else{throw Invalid.record}
        return decoded
    }
}
