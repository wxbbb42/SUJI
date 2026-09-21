import Foundation

enum BaziAdjudicationTrace {
    private static let foundationHash="8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596"
    private static let hidden:[String:[String]]=["子":["癸"],"丑":["己","癸","辛"],"寅":["甲","丙","戊"],"卯":["乙"],"辰":["戊","乙","癸"],"巳":["丙","戊","庚"],"午":["丁","己"],"未":["己","丁","乙"],"申":["庚","壬","戊"],"酉":["辛"],"戌":["戊","辛","丁"],"亥":["壬","甲"]]
    private static let elements=["甲":"木","乙":"木","丙":"火","丁":"火","戊":"土","己":"土","庚":"金","辛":"金","壬":"水","癸":"水"]
    private static let controls=["木":"土","火":"金","土":"水","金":"木","水":"火"]
    private static let formations:[String:[(String,[String])]]=["木":[("direction",["寅","卯","辰"]),("triad",["亥","卯","未"])],"火":[("direction",["巳","午","未"]),("triad",["寅","午","戌"])],"土":[("four-stores",["辰","戌","丑","未"])],"金":[("direction",["申","酉","戌"]),("triad",["巳","酉","丑"])],"水":[("direction",["亥","子","丑"]),("triad",["申","子","辰"])]]
    private static let seasons=["木":["寅","卯","辰"],"火":["巳","午","未"],"土":["辰","戌","丑","未"],"金":["申","酉","戌"],"水":["亥","子","丑"]]
    private static let names=["木":"曲直格","火":"炎上格","土":"稼穑格","金":"从革格","水":"润下格"]
    private static let commanders:[String:[([String],Double)]]=["寅":[(["戊"],7),(["丙"],7),(["甲"],16)],"卯":[(["甲"],10),(["乙"],20)],"辰":[(["乙"],9),(["癸"],3),(["戊"],18)],"巳":[(["戊"],5),(["庚"],9),(["丙"],16)],"午":[(["丙"],10),(["己"],9),(["丁"],11)],"未":[(["丁"],9),(["乙"],3),(["己"],18)],"申":[(["戊","己"],10),(["壬"],3),(["庚"],17)],"酉":[(["庚"],10),(["辛"],20)],"戌":[(["辛"],9),(["丁"],3),(["戊"],18)],"亥":[(["戊"],7),(["甲"],5),(["壬"],18)],"子":[(["壬"],10),(["癸"],20)],"丑":[(["癸"],9),(["辛"],3),(["己"],18)]]

    /// Only locally checked source/profile/column claims become prose. This does
    /// not independently solve relative power, source conflicts or global rescue.
    static func make(root: JSONValue) -> (text:String, brief:String, paths:[String])? {
        func value(_ path:String)->JSONValue?{ReadingVerificationEvidence.pointer(path,in:root)}
        func string(_ path:String)->String?{if case let .string(s)=value(path){return s};return nil}
        func number(_ path:String)->Double?{switch value(path){case let .integer(n):return Double(n);case let .double(n):return n;default:return nil}}
        func source(_ path:String,_ id:String,_ document:String,_ hash:String)->Bool{
            string(path+"/id")==id && string(path+"/document")=="docs/mingli/source-texts/bazi/"+document && string(path+"/sha256")==hash
        }
        let columns=["year","month","day","hour"],labels=["年干","月干","日干","时干"]
        let stems=columns.compactMap{string("/bazi/pillars/"+$0+"/ganZhi/gan")}
        let branches=columns.compactMap{string("/bazi/pillars/"+$0+"/ganZhi/zhi")}
        guard stems.count==4,branches.count==4,stems.allSatisfy({elements[$0] != nil}),branches.allSatisfy({hidden[$0] != nil}) else{return nil}
        let day=stems[2],month=branches[1],element=elements[day]!
        let hasRoot:(String)->Bool={gan in branches.contains{hidden[$0]!.contains{elements[$0]==elements[gan]}}}
        let signature=(0..<4).map{stems[$0]+branches[$0]}.joined(separator:" ")
        var text:[String]=[],paths=["/bazi/pillars"]
        let s="/bazi/patternAnalysis/specialPatternEvidence"
        if value(s) != nil {
            guard string(s+"/methodVersion")=="zhuanwang-adjudication-v1",string(s+"/profileId")=="ditianshui-ren-full-formation-v1",
                  value(s+"/outcomeEstablished")==false,string(s+"/dayElement")==element,string(s+"/name")==names[element],
                  string(s+"/season/monthBranch")==month,
                  source(s+"/sources/0","ditianshui-ren-duxiang-v1","ditianshui-chanwei/tongshen-10-xingxiang-bage.md","141085eeb8f5faba79a29dd1a08c8130fbdea9d2d6b81cea234c188dc6fe8183"),
                  source(s+"/sources/1","ziping-xu-special-v1","ziping-zhenquan/43-zage.md","a7998453fbfd09d9e1e32e5b4b36b56ae79e81a408348a64d5ae1995dd961e56"),
                  source(s+"/sources/2","ziping-xu-earth-command-v1","ziping-zhenquan/01-foundations.md",foundationHash) else{return nil}
            let found=formations[element]!.filter{pair in pair.1.allSatisfy{branches.contains($0)}}
            let expected=found.map{kind,members in JSONValue.object(["kind":.string(kind),"branches":.array(members.map(JSONValue.string)),"positions":.array(branches.indices.filter{members.contains(branches[$0])}.map{.integer(Int64($0))})])}
            guard value(s+"/formation") == .array(expected) else{return nil}
            let participants=Set(found.flatMap{pair in branches.indices.filter{pair.1.contains(branches[$0])}})
            let controller=controls.first{$0.value==element}!.key
            let exposed=stems.contains{elements[$0]==controller}
            let external=branches.indices.contains{!participants.contains($0)&&elements[hidden[branches[$0]]![0]]==controller}
            let externalHidden=branches.indices.contains{i in !participants.contains(i)&&hidden[branches[i]]!.contains{elements[$0]==controller}}
            var commanderElement:String?,commanderText=""
            let c=s+"/season/birthMonthContext",m=s+"/season/commander"
            if value(c) != nil && value(c) != .null {
                let jieNames=["小寒","立春","惊蛰","清明","立夏","芒种","小暑","立秋","白露","寒露","立冬","大雪"]
                let jieBranches=["丑","寅","卯","辰","巳","午","未","申","酉","戌","亥","子"]
                guard string(c+"/methodVersion")=="birth-month-jie-context-v1",string(c+"/monthBranch")==month,
                      string(c+"/timeBasis")=="civil-instant-utc",value(c+"/solarTimeApplied")==false,
                      string(c+"/termPrecision")=="provider-second",let birth=string(c+"/civilBirthTime"),birth==string("/bazi/birthDateTime"),
                      let birthDate=date(birth),let jieRaw=string(c+"/jie/instant"),let jieDate=date(jieRaw),
                      let nextRaw=string(c+"/nextJie/instant"),let nextDate=date(nextRaw),birthDate>=jieDate,birthDate<nextDate,
                      let jieName=string(c+"/jie/name"),let jieIndex=jieNames.firstIndex(of:jieName),jieBranches[jieIndex]==month,
                      string(c+"/nextJie/name")==jieNames[(jieIndex+1)%12],let days=number(c+"/daysAfterJie"),days.isFinite,days>=0,
                      let millis=number(c+"/elapsedMillis"),abs(days*86_400_000-millis)<0.01,
                      abs(birthDate.timeIntervalSince(jieDate)*1_000-millis)<0.01,
                      string(c+"/calendarPolicyVersion")=="suji-calendar-2",
                      string(c+"/provider")=="lunar-javascript@1.7.7" else{return nil}
                var start=0.0,chosen:[String]=[],end=0.0
                for (index,segment) in commanders[month]!.enumerated(){
                    end=start+segment.1
                    if days<end || index==commanders[month]!.count-1{chosen=segment.0;break}
                    start=end
                }
                commanderElement=elements[chosen[0]]
                guard string(m+"/tableId")=="ziping-xu-renyuan-v1",source(m+"/source","ziping-xu-renyuan-v1","ziping-zhenquan/01-foundations.md",foundationHash),
                      value(m+"/gans") == .array(chosen.map(JSONValue.string)),value(m+"/gan")==((chosen.count==1) ? .string(chosen[0]):.null),
                      string(m+"/element")==commanderElement,number(m+"/interval/startDay")==start,number(m+"/interval/endDay")==end,
                      string(m+"/interval/convention")=="left-closed-right-open" else{return nil}
                commanderText="按原出生时刻所属月节和徐注分段，\(chosen.joined())\(commanderElement!)司令。"
            } else if value(m) != nil && value(m) != .null {return nil}
            let transition=["辰","戌","丑","未"].contains(month)
            let seasonal=seasons[element]!.contains(month)
            let seasonStatus = !seasonal ? "out-of-season" : transition && commanderElement==nil ? "needs-month-commander" : transition && commanderElement != element ? "out-of-season" : "in-season"
            let status = found.isEmpty || exposed || external || externalHidden || seasonStatus=="out-of-season" ? "not-established-in-selected-profile" : seasonStatus=="needs-month-commander" ? "needs-month-commander" : "established"
            guard string(s+"/status")==status,string(s+"/season/status")==seasonStatus else{return nil}
            if status=="established"{
                text.append("\(names[element]!)规则子集成立：方局、时令及所选克神条件已核对。"+commanderText+"这不代表全局成败、等级或现实结果已成立。")
                paths += ["/bazi/birthDateTime",c,m]
            } else if status=="needs-month-commander"{text.append("专旺方局具备，但该季末月尚缺所选司令依据，暂不能认定规则子集成立。")}
            if status != "not-established-in-selected-profile"{
                paths += [s+"/methodVersion",s+"/profileId",s+"/status",s+"/outcomeEstablished",s+"/sources",s+"/formation",s+"/season/status"]
            }
        }
        let r="/bazi/patternAnalysis/rescueEvidence"
        if value(r) != nil {
            guard string(r+"/methodVersion")=="bazi-rescue-adjudication-v1",string(r+"/profileId")=="ziping-xu-local-role-dependencies-v1",
                  string(r+"/globalResolution")=="unresolved",value(r+"/outcomeEstablished")==false,
                  source(r+"/sources/0","ziping-helper-constraints-v1","ziping-zhenquan/00-abstract-chapters.md","5b930c11310899b50703696870d9024ba4e00fca6ad177e57d6fa5e3f8a4964f"),
                  source(r+"/sources/1","ziping-position-season-v1","ziping-zhenquan/01-foundations.md",foundationHash),
                  source(r+"/sources/2","ziping-xu-combination-limits-v1","ziping-zhenquan/01-foundations.md",foundationHash),
                  source(r+"/sources/3","ziping-xu-hidden-action-cases-v1","ziping-zhenquan/35-yinshou.md","d87e8f7df9f15175b26a75e9acee2a1b6e50b2df1b4ef1b5f189c38d8aa7a63c"),
                  case let .array(raw)=value(r+"/combinations") else{return nil}
            let pairCount=stems.indices.reduce(0){sum,a in sum+stems.indices.filter{$0 != a&&combines(stems[a],stems[$0])}.count}
            guard raw.count==pairCount else{return nil}
            var seen=Set<String>(),findings:[String]=[]
            for i in raw.indices {
                let p=r+"/combinations/\(i)"
                guard let a=number(p+"/actorPosition"),let b=number(p+"/targetPosition"),a.rounded()==a,b.rounded()==b,(0..<4).contains(a),(0..<4).contains(b),a != b else{return nil}
                let actor=Int(a),target=Int(b),ag=stems[actor],tg=stems[target]
                guard combines(ag,tg),string(p+"/actorGan")==ag,string(p+"/targetGan")==tg,seen.insert("\(actor)-\(target)").inserted else{return nil}
                let middle=Array((min(actor,target)+1)..<max(actor,target))
                let blockers=middle.filter{Set([ag,tg])==Set(["甲","己"])&&stems[$0]=="庚"}
                let competing=Set(stems.indices.filter{$0 != actor&&$0 != target&&$0 != 2&&(combines(stems[$0],ag)||combines(stems[$0],tg))})
                let actorAttacked=stems.indices.contains{$0 != actor&&$0 != target&&$0 != 2&&controls[elements[stems[$0]]!]==elements[ag]}
                let remotePair=Set([ag,tg])==Set(["戊","癸"])&&month=="酉"&&((day=="甲"&&stems.contains("丁"))||(day=="乙"&&stems[0]=="丁"&&stems[1]=="癸"&&stems[3]=="戊")) || Set([ag,tg])==Set(["甲","己"])&&day=="丁"&&month=="酉"&&stems.contains("癸")
                let expected:String
                if actor==2||target==2{expected="day-master-no-removal"}
                else if !blockers.isEmpty{expected="blocked-by-intervening-geng"}
                else if signature=="丙午 辛卯 戊寅 甲寅"&&actor<2&&target<2{expected="source-conflict"}
                else if hasRoot(tg){expected="rooted-role-retained"}
                else if !competing.isEmpty{expected="unresolved-competing-pairs"}
                else if abs(actor-target)>1 && !remotePair{expected="unresolved-remote-configuration"}
                else if !hasRoot(ag)||actorAttacked{expected="unresolved-relative-strength"}
                else if day=="甲"&&ag=="乙"&&tg=="庚"{expected="killing-role-redirected"}
                else{expected="role-disabled-in-selected-profile"}
                let sourceIDs = remotePair ? ["ziping-xu-combination-limits-v1","ziping-helper-constraints-v1"] : ["ziping-xu-combination-limits-v1"]
                guard string(p+"/status")==expected,value(p+"/removalEstablished") == .bool(expected=="role-disabled-in-selected-profile"),
                      value(p+"/sourceIds") == .array(sourceIDs.map(JSONValue.string)) else{return nil}
                let pairText=labels[actor]+ag+"合"+labels[target]+tg
                var finding:String?
                if expected=="rooted-role-retained"{finding=pairText+"；\(tg)有根，不能据五合认定已合去。"}
                else if expected=="day-master-no-removal"{finding=pairText+"属日主自合，不能作合去。"}
                else if expected=="blocked-by-intervening-geng"{finding=pairText+"中隔庚克甲，按所选条文不能越克作合。"}
                else if expected=="role-disabled-in-selected-profile"{finding=pairText+"；所选徐注条件下，无根的\(tg)原作用受合牵制，不等于全局获救。"}
                else if expected=="killing-role-redirected"{finding=pairText+"属于煞不攻身的作用转向，不能说庚已被删除。"}
                if let finding,findings.count<2{findings.append(finding);paths.append(p)}
            }
            if !findings.isEmpty{
                text.append(findings.joined()+"其余救应竞争、藏干效力和全局成败仍需分别裁定。")
                paths += [r+"/methodVersion",r+"/profileId",r+"/globalResolution",r+"/outcomeEstablished",r+"/sources"]
            }
        }
        guard value(s) != nil || value(r) != nil else{return nil}
        return (text.joined(),text.joined(),paths)
    }

    private static func combines(_ a:String,_ b:String)->Bool{["甲己","己甲","乙庚","庚乙","丙辛","辛丙","丁壬","壬丁","戊癸","癸戊"].contains(a+b)}
    private static func date(_ value:String)->Date?{
        let format=ISO8601DateFormatter();format.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return format.date(from:value)
    }
}
