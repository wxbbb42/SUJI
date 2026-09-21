import Foundation

public enum QimenTimingEvidence {
    public struct Report: Sendable {
        public let text: String
        public let evidencePaths: [String]
    }
    /// Validates the engine's conditional result against its original occurrence.
    /// The caller must separately bind the receipt, engine revision and question clock.
    /// This validates calendar structure; it does not recalculate astronomical terms.
    public static func read(root: JSONValue) -> Report? { try? Reader(root:root).build() }

    private enum Invalid: Error { case record }
    private static let source="qimen-xdyy-timing-v1"
    // Pinned references: changing any URL, raw-body hash, locator or direct example requires a source-version review.
    private static let sourceReferences = #"""
    [{"url":"https://www.aqioo.com/qmdjxdyyjs/167816.html","locator":"第03章 第二节中五寄宫","sha256":"06c5d8f574ccdfcb8e9df3b8452d8c65829a225e056a3cac81d618d437ea500b","quote":"需要说明的是奇门遁甲的中五宫在一般的情况下均寄在坤二宫，也就是说中五宫中的九星天禽星和所在的三奇六仪在运转时随坤二宫的天芮星及其三奇六仪运转"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167810.html","locator":"第06章 第一步及第三步1至6","sha256":"dab3897adc647067952b8813d4979ebe3db27ed37282a0ebc47753e9b0543ad5","quote":"如果用神宫逢空亡，无论用神是否临马星、刑冲、生旺、墓绝、庚格、值使门均用冲空、填空为应期。"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167810.html","locator":"第06章 第三步3：开门入墓直接例证","sha256":"dab3897adc647067952b8813d4979ebe3db27ed37282a0ebc47753e9b0543ad5","quote":"如开门为用神，落在艮八宫入墓，戊子日预测，到丑年、月、日、时则为应期或冲丑的未年、月、日、时为应期。"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167817.html","locator":"第02章 十干长生墓支、十二地支合冲及宫位","sha256":"6caea61e307f4ced210a012c77d391f23fb01ad8172eae71c93db4ce708e8697"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167813.html","locator":"第04章 13、六仪击刑六个落宫；与第06章甲午辛例互校","sha256":"3dd0817ce52fb78ed8ee587a1ea8b5d731ec58fb9dbc91e8a23aca405cf5fa31"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167802.html","locator":"第08章 工作就业；开门为工作，日干为求测者","sha256":"cd2fc6c0238e425c2955d5d85ec0cb8ebecf01337ace2eb69a4f46d6ba1e4d01"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167807.html","locator":"经营求财：生门为利润利息；不等于一切财务事件","sha256":"e66dc4605a2ea265dc52824df511ae60aae21209d9910c96cb88aa2e70c60c40"},{"url":"https://www.aqioo.com/qmdjxdyyjs/167808.html","locator":"恋爱婚姻：六合为婚姻用神；不据性别代取伴侣","sha256":"39f14beac1bde7677c8a55e87e9113508dcc5f6bc3ee7f4ed659ba847e58a574"}]
    """#
    private static let branches=Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    private static let stems=Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    private static let palaceBranches=[1:["子"],2:["未","申"],3:["卯"],4:["辰","巳"],6:["戌","亥"],7:["酉"],8:["丑","寅"],9:["午"]]
    private static let tomb=["甲":"未","乙":"戌","丙":"戌","丁":"丑","戊":"戌","己":"丑","庚":"丑","辛":"辰","壬":"辰","癸":"未","开门":"丑"]
    private static let instrument=["戊":"子","己":"戌","庚":"申","辛":"午","壬":"辰","癸":"寅"]
    private static let punish=["戊":3,"己":2,"庚":8,"辛":9,"壬":4,"癸":4]
    private static func clash(_ branch:String)->String { branches[(branches.firstIndex(of:branch)!+6)%12] }
    private static func combine(_ branch:String)->String { branches[(13-branches.firstIndex(of:branch)!)%12] }
    private struct Rule: Equatable {
        let id:String,branches:[String],priority:Int,paths:[String]
    }
    private struct Reader {
        let root:JSONValue
        func value(_ p:String)throws->JSONValue { guard let v=ReadingVerificationEvidence.pointer(p,in:root) else { throw Invalid.record };return v }
        func string(_ p:String)throws->String { guard case let .string(v)=try value(p) else { throw Invalid.record };return v }
        func int(_ p:String)throws->Int { guard case let .integer(v)=try value(p),let n=Int(exactly:v) else { throw Invalid.record };return n }
        func bool(_ p:String)throws->Bool { guard case let .bool(v)=try value(p) else { throw Invalid.record };return v }
        func array(_ p:String)throws->[JSONValue] { guard case let .array(v)=try value(p) else { throw Invalid.record };return v }
        func strings(_ p:String)throws->[String] {
            try array(p).map { guard case let .string(v)=$0 else { throw Invalid.record };return v }
        }
        func date(_ p:String)throws->Date {
            let s=try string(p)
            guard s.range(of:#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#,options:.regularExpression) != nil else { throw Invalid.record }
            let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
            guard let d=f.date(from:s),f.string(from:d)==s else { throw Invalid.record };return d
        }
        func paths(_ p:String)throws->[String] {
            let result=try strings(p);guard !result.isEmpty,Set(result).count==result.count else { throw Invalid.record }
            for path in result { _=try value(path) };return result
        }
        func build()throws->Report {
            let t="/timing",p=t+"/searchPolicy"
            guard try string(t+"/methodVersion")==source,try !bool(t+"/outcomeEstablished"),
                  try string("/method/algorithm")=="zhuanpan-qimen-chai-bu-v1",
                  try string("/method/centerPolicy")=="fixed-kun-2; tian-qin-follows-tian-rui",
                  try strings(t+"/sourceIDs")==[source,"qimen-hour-void-horse-v1"],
                  try string(p+"/timezone")=="UTC+08:00",try string(p+"/dayBoundary")=="23:00",
                  try string(p+"/yearBoundary")=="exact-lichun",try string(p+"/monthBoundary")=="exact-jie" else { throw Invalid.record }
            let statuses=["unresolved","conditional-triggers-only","conditional-calendar-candidates"]
            let status=try string(t+"/assessmentStatus"),focus=try string(t+"/focus")
            guard statuses.contains(status),["employment","profit","relationship","self","explicit"].contains(focus),
                  try string(t+"/event").count<=200 else { throw Invalid.record }
            let sources=try array("/ruleSources")
            let matching=try sources.indices.filter { try string("/ruleSources/\($0)/id")==source }
            guard matching.count==1 else { throw Invalid.record }
            let sourcePath="/ruleSources/\(matching[0])"
            guard try string(sourcePath+"/version")=="1",try string(sourcePath+"/editionStatus")=="electronic-transcription-not-print-collated",
                  try value(sourcePath+"/references")==JSONDecoder().decode(JSONValue.self,from:Data(sourceReferences.utf8)) else { throw Invalid.record }
            let unresolved=try strings(t+"/unresolved")
            let allowed:Set<String>=["incompatible-chart-method","single-event","time-unit","calendar-window","self-subject-required","original-pillars","ambiguous-object","selected-object","outer-palace","original-hour-void","original-hour-horse","event-outcome-not-adjudicated","event-specific-strength-timing","instrument-combination-clash-target","chart-clock-policy","chart-longitude"]
            guard Set(unresolved).isSubset(of:allowed),Set(unresolved).count==unresolved.count else { throw Invalid.record }
            let dates=try array(t+"/dates"),triggers=try array(t+"/triggers"),max=try int(p+"/maxCandidates")
            guard (1...256).contains(max),dates.count<=max else { throw Invalid.record }
            var evidence=[t+"/methodVersion",t+"/assessmentStatus",t+"/outcomeEstablished",t+"/selection",t+"/triggers",t+"/supported",t+"/opposing",t+"/conflicts",t+"/unresolved",t+"/dates",p,sourcePath]
            for path in evidence { _=try value(path) }
            if try !bool(t+"/selection/established") {
                guard status=="unresolved",dates.isEmpty,triggers.isEmpty,try !bool(p+"/searchComplete"),try !bool(p+"/truncated") else { throw Invalid.record }
                return Report(text:"本次应期对象或适用条件尚未成立，不能列出日期；事件成败仍未裁决。",evidencePaths:evidence)
            }
            let selected=t+"/selection",object=try string(selected+"/objectPath"),id=try int(selected+"/palaceId"),symbol=try string(selected+"/symbol")
            let parts=object.split(separator:"/").map(String.init)
            guard parts.count==3,parts[0]=="palaces",let index=Int(parts[1]),String(index)==parts[1],
                  ["tianPanGan","hostedTianPanGan","bamen","jiuxing","bashen"].contains(parts[2]),
                  palaceBranches[id] != nil,try int("/palaces/\(index)/id")==id else { throw Invalid.record }
            let palaces=try array("/palaces"),ids=try palaces.indices.map { try int("/palaces/\($0)/id") }
            guard ids.count==9,Set(ids)==Set(1...9) else { throw Invalid.record }
            let candidate=try string(selected+"/candidateId"),carrier=try? string(selected+"/carrierStem")
            if focus=="employment" || focus=="profit" || focus=="relationship" {
                let expected=focus=="employment" ? "开门" : focus=="profit" ? "生门" : "六合"
                let field=focus=="relationship" ? "bashen" : "bamen"
                guard symbol==expected,parts[2]==field,candidate=="category-\(field=="bashen" ? "deity" : "door")-\(expected)",
                      try string(object)==expected,carrier==nil else { throw Invalid.record }
                let locations=palaces.indices.filter { (try? string("/palaces/\($0)/\(field)"))==expected }
                guard locations==[index] else { throw Invalid.record }
            } else {
                if focus=="self" { guard candidate=="day-stem",try string("/questionContext/subject")=="self" else { throw Invalid.record } }
                let candidates=try array("/yongShen/candidates")
                let found=try candidates.indices.filter { try string("/yongShen/candidates/\($0)/id")==candidate }
                guard found.count==1 else { throw Invalid.record }
                let c="/yongShen/candidates/\(found[0])"
                guard try string(c+"/symbol")==symbol else { throw Invalid.record }
                let occurrences=try array(c+"/occurrences")
                if focus=="self" {
                    let effective=occurrences.indices.filter { (try? bool(c+"/occurrences/\($0)/isEffectiveSky"))==true }
                    guard effective.count==1 else { throw Invalid.record }
                }
                let matches=try occurrences.indices.filter { try string(c+"/occurrences/\($0)/objectPath")==object }
                guard matches.count==1,try int(c+"/occurrences/\(matches[0])/palaceId")==id else { throw Invalid.record }
                if candidate=="day-stem" || candidate=="hour-stem" {
                    let pillar=Array(try string(candidate=="day-stem" ? "/dayGanZhi" : "/hourGanZhi")).map(String.init)
                    guard pillar.count==2,let si=stems.firstIndex(of:pillar[0]),let bi=branches.firstIndex(of:pillar[1]),(bi-si+12)%2==0 else { throw Invalid.record }
                    let expectedCarrier=pillar[0]=="甲" ? ["戊","癸","壬","辛","庚","己"][(bi-si+12)%12/2] : pillar[0]
                    guard symbol==pillar[0],carrier==expectedCarrier,try string(object)==expectedCarrier,
                          ["tianPanGan","hostedTianPanGan"].contains(parts[2]) else { throw Invalid.record }
                } else { guard carrier==nil,try string(object)==symbol else { throw Invalid.record } }
            }
            evidence += [object,"/palaces/\(index)/id"]
            let all=try expectedRules(id:id,object:object,symbol:symbol,carrier:carrier)
            let first=all.map(\.priority).min(),active=all.filter { $0.priority==first }
            let actual=try triggers.indices.map { i -> Rule in
                let r=t+"/triggers/\(i)"
                guard try string(r+"/sourceId")==source,try string(r+"/objectPath")==object else { throw Invalid.record }
                return Rule(id:try string(r+"/ruleId"),branches:try strings(r+"/branches"),priority:try int(r+"/priority"),paths:try paths(r+"/factPaths"))
            }
            guard active==actual else { throw Invalid.record }
            let opposing=try array(t+"/opposing"),suppressed=all.filter { $0.priority != first }
            guard opposing.count==suppressed.count else { throw Invalid.record }
            for i in opposing.indices {
                let r=t+"/opposing/\(i)"
                guard try string(r+"/ruleId")==suppressed[i].id,try paths(r+"/factPaths")==suppressed[i].paths,
                      try string(r+"/reason")==((first==1) ? "suppressed-by-void" : "suppressed-by-horse") else { throw Invalid.record }
            }
            let conflicts=try array(t+"/conflicts"),mixed=first==3 && active.contains(where:{$0.id.hasPrefix("tomb")}) && active.contains(where:{!$0.id.hasPrefix("tomb")})
            guard conflicts.count==(mixed ? 1 : 0) else { throw Invalid.record }
            if mixed { guard try strings(t+"/conflicts/0/ruleIds")==active.map(\.id),try string(t+"/conflicts/0/reason")=="source-does-not-order-tomb-versus-punishment-clash-combination" else { throw Invalid.record } }
            guard try array(t+"/supported")==expectedSupported(all:all,id:id,object:object,carrier:carrier) else { throw Invalid.record }
            if status != "conditional-calendar-candidates" {
                guard dates.isEmpty,try !bool(p+"/truncated"),try !bool(p+"/searchComplete"),try string(p+"/reason")=="not-enumerated",
                      status==(active.isEmpty ? "unresolved" : "conditional-triggers-only") else { throw Invalid.record }
                return Report(text:"本次应期对象为\(symbol)，已核对原盘位置。日期所需的明确单位、窗口或适用规则尚未齐备；事件成败仍未裁决。",evidencePaths:evidence)
            }
            guard !active.isEmpty,unresolved.contains("event-outcome-not-adjudicated"),
                  Set(unresolved).isSubset(of:["event-outcome-not-adjudicated","instrument-combination-clash-target"]),
                  [24,120,512].contains(try int(p+"/maxPeriods")) else { throw Invalid.record }
            let clock=try string(p+"/clockPolicy")
            guard ["beijing-standard","apparent-solar"].contains(clock),try string("/method/clockPolicy")==clock,
                  try string(p+"/solarInversePolicy")==(clock=="apparent-solar" ? "earliest-physical-millisecond-with-projected-clock-at-boundary" : "none") else { throw Invalid.record }
            let start=try date("/setupTime"),end=try date(p+"/requestedEnd"),searched=try date(p+"/searchedUntil")
            let truncated=try bool(p+"/truncated"),complete=try bool(p+"/searchComplete"),reason=try string(p+"/reason"),include=try bool(p+"/includeCurrent")
            guard start<end,searched>=start,searched<=end,complete != truncated,
                  complete ? (reason=="window-complete" && searched==end) : (["candidate-limit","period-limit"].contains(reason) && searched<end) else { throw Invalid.record }
            if reason=="candidate-limit" { guard dates.count==max else { throw Invalid.record } }
            var previousEnd:Date?,firstEnd:Date?,closed=false,shown:[String]=[],unit:String?
            for i in dates.indices {
                let d=t+"/dates/\(i)",u=try string(d+"/unit"),b=try string(d+"/branch"),gz=Array(try string(d+"/ganZhi")).map(String.init)
                guard let cap=["year":24,"month":120,"day":512,"hour":512][u],try int(p+"/maxPeriods")==cap,
                      unit==nil || unit==u,gz.count==2,stems.contains(gz[0]),branches.contains(b),gz[1]==b else { throw Invalid.record }
                unit=u
                let a=try date(d+"/startsAt"),z=try date(d+"/endsAt"),eligible=try date(d+"/eligibleStart"),eligibleEnd=try date(d+"/eligibleEnd")
                guard a<z,eligible==Swift.max(a,start),eligibleEnd==Swift.min(z,end),eligible<eligibleEnd,eligibleEnd<=searched,
                      previousEnd==nil || a>=previousEnd!,include || a>start else { throw Invalid.record }
                let matching=active.filter { $0.branches.contains(b) }.map(\.id)
                guard !matching.isEmpty,try strings(d+"/triggerIds")==matching else { throw Invalid.record }
                if let firstEnd,a != firstEnd { closed=true }
                guard try bool(d+"/firstWindow")==(!closed) else { throw Invalid.record }
                if !closed { firstEnd=z };previousEnd=z
                if clock=="beijing-standard" && (u=="day" || u=="hour") {
                    let step:Double=u=="day" ? 86400 : 7200
                    guard z.timeIntervalSince(a)==step,(a.timeIntervalSince1970-15*3600).truncatingRemainder(dividingBy:step)==0 else { throw Invalid.record }
                    let day=Int(floor((a.timeIntervalSince1970-1084028400)/86400)) // 2004-05-08 23:00 Beijing, 戊子 day start.
                    let dayIndex=((24+day)%60+60)%60
                    let expectedDay=stems[dayIndex%10]+branches[dayIndex%12]
                    if u=="day" { guard gz.joined()==expectedDay else { throw Invalid.record } }
                    else {
                        let hourIndex=((Int(floor((a.timeIntervalSince1970+8*3600)/3600))+1)%24+24)%24/2
                        let expectedHour=stems[((dayIndex%10)%5*2+hourIndex)%10]+branches[hourIndex]
                        guard gz.joined()==expectedHour else { throw Invalid.record }
                    }
                }
                if i<3 {
                    let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=TimeZone(secondsFromGMT:8*3600);f.dateFormat="yyyy-MM-dd HH:mm"
                    shown.append("\(gz.joined())：\(f.string(from:eligible)) 至 \(f.string(from:eligibleEnd))")
                }
            }
            let names=[1:"坎宫",2:"坤宫",3:"震宫",4:"巽宫",6:"乾宫",7:"兑宫",8:"艮宫",9:"离宫"]
            var text="本次应期对象为\(symbol)在\(names[id]!)。以下均为条件候选，事件成败仍未裁决。"
            text += shown.isEmpty ? "本次已查范围未命中候选日期。" : "北京时间候选区间（结束时刻不包含）："+shown.joined(separator:"；")+"。"
            if dates.count>3 { text += "共\(dates.count)段，先列前三段。" }
            if mixed { text += "同层规则存在竞争，保留各分支。" }
            if truncated { text += "搜索达到上限，结果已截断。" }
            text += "来源为网页电子转录，未经纸本校勘。"
            return Report(text:text,evidencePaths:evidence)
        }
        func expectedRules(id:Int,object:String,symbol:String,carrier:String?)throws->[Rule] {
            guard let empties=try? array("/hourVoid/palaces") else { return [] }
            let empty=try empties.indices.first { try int("/hourVoid/palaces/\($0)/palaceId")==id }
            if empty==nil && ReadingVerificationEvidence.pointer("/horse",in:root)==nil { return [] }
            var rules:[Rule]=[];let pb=palaceBranches[id]!
            if let empty {
                let paths=["/hourVoid/palaces/\(empty)",object]
                rules += [Rule(id:"void-fill",branches:pb,priority:1,paths:paths),Rule(id:"void-clash",branches:pb.map(clash),priority:1,paths:paths)]
            }
            if (try? int("/horse/palaceId"))==id {
                let b=try string("/horse/branch");guard ["寅","申","巳","亥"].contains(b),pb.contains(b) else { throw Invalid.record }
                rules += [Rule(id:"horse-value",branches:[b],priority:2,paths:["/horse/branch",object]),Rule(id:"horse-clash",branches:[clash(b)],priority:2,paths:["/horse/branch",object])]
            }
            if let b=tomb[symbol],pb.contains(b) {
                rules += [Rule(id:"tomb-value",branches:[b],priority:3,paths:[object]),Rule(id:"tomb-clash",branches:[clash(b)],priority:3,paths:[object])]
            }
            if let carrier,let b=instrument[carrier] {
                if punish[carrier]==id { rules.append(Rule(id:"punishment-combine",branches:[combine(b)],priority:3,paths:[object])) }
                else if pb.contains(clash(b)) { rules.append(Rule(id:"instrument-clash-combine",branches:[combine(b)],priority:3,paths:[object])) }
            }
            return rules
        }
        func expectedSupported(all:[Rule],id:Int,object:String,carrier:String?)throws->[JSONValue] {
            guard let empties=try? array("/hourVoid/palaces") else { return [] }
            let empty=try empties.indices.first { try int("/hourVoid/palaces/\($0)/palaceId")==id }
            if empty==nil && ReadingVerificationEvidence.pointer("/horse",in:root)==nil { return [] }
            var supported:[JSONValue]=[]
            if let rule=all.first(where:{$0.id=="void-fill"}) {
                let coverage=try string(rule.paths[0]+"/coverage")
                guard ["partial","full"].contains(coverage) else { throw Invalid.record }
                supported.append(["condition":"palace-void","factPaths":.array([.string(rule.paths[0])]),"coverage":.string(coverage)])
            }
            if all.contains(where:{$0.id=="horse-value"}) { supported.append(["condition":"hour-horse","factPaths":.array(["/horse",.string(object)])]) }
            if all.contains(where:{$0.id=="tomb-value"}) { supported.append(["condition":"object-tomb","factPaths":.array([.string(object)])]) }
            if let carrier,let b=instrument[carrier],punish[carrier] != id,
               !palaceBranches[id]!.contains(clash(b)),palaceBranches[id]!.contains(combine(b)) {
                supported.append(["condition":"instrument-palace-combination","factPaths":.array([.string(object)])])
            }
            return supported
        }
    }
}
