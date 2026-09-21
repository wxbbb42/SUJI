import Foundation

/// Independently reconstructs the source-scoped dependency stage from pillars.
/// Pair findings have already been checked by BaziAdjudicationTrace; neither the
/// engine's condition graph nor its action/coverage statuses are trusted here.
enum BaziRescueDependencies {
    private static let stemsOrder=Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    private static let element=["甲":0,"乙":0,"丙":1,"丁":1,"戊":2,"己":2,"庚":3,"辛":3,"壬":4,"癸":4]
    private static let hidden=["子":"癸","丑":"己癸辛","寅":"甲丙戊","卯":"乙","辰":"戊乙癸","巳":"丙戊庚","午":"丁己","未":"己丁乙","申":"庚壬戊","酉":"辛","戌":"戊辛丁","亥":"壬甲"]
    private static let threats=["正官":["伤官"],"七杀":["正财"],"正财":["比肩","劫财"],"偏财":["比肩","劫财"],"正印":["正财","偏财"],"偏印":["正财","偏财"],"食神":["偏印"],"伤官":["正官"],"比肩":[],"劫财":[]]
    private static let helperSource="ziping-helper-constraints-v1",orderSource="ziping-xu-occurrence-selection-v1"
    private struct Spec {let actor:Int,target:Int,layer:String,gan:String,relation:String,rule:String}
    private static func controls(_ a:String,_ b:String)->Bool{(element[a]!+2)%5==element[b]!}
    private static func generates(_ a:String,_ b:String)->Bool{(element[a]!+1)%5==element[b]!}
    private static func combines(_ a:String,_ b:String)->Bool{abs(stemsOrder.firstIndex(of:a)!-stemsOrder.firstIndex(of:b)!)==5}
    private static func god(_ day:String,_ gan:String)->String {
        let same=stemsOrder.firstIndex(of:day)!%2==stemsOrder.firstIndex(of:gan)!%2
        if element[day]==element[gan]{return same ? "比肩":"劫财"}
        if generates(day,gan){return same ? "食神":"伤官"}
        if controls(day,gan){return same ? "偏财":"正财"}
        if controls(gan,day){return same ? "七杀":"正官"}
        return same ? "偏印":"正印"
    }
    private static func json(_ value:Any)->JSONValue? {
        guard let data=try? JSONSerialization.data(withJSONObject:value,options:[.fragmentsAllowed]) else{return nil}
        return try? JSONDecoder().decode(JSONValue.self,from:data)
    }
    static func make(root:JSONValue,stems:[String],branches:[String])->(text:String,paths:[String])? {
        let r="/bazi/patternAnalysis/rescueEvidence",p=r+"/dependencyResolution"
        func value(_ path:String)->JSONValue?{ReadingVerificationEvidence.pointer(path,in:root)}
        func string(_ path:String)->String?{if case let .string(s)=value(path){return s};return nil}
        guard case let .array(sources)=value(r+"/sources") else{return nil}
        if value(p)==nil{return sources.count==4 ? ("",[]):nil}
        let source:[String:Any]=["id":orderSource,"document":"docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md",
            "sha256":"8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596",
            "locator":"五、论十干合而不合：月时两辛、林森克一留一及各家异说",
            "quote":"如甲生寅卯，月时两透辛官，以年丙合月辛，是为合一留一，官星反轻",
            "additionalQuotes":["戊辰、甲寅、丁卯、戊申","用甲克去年上伤官，而留时上伤官以生财损印","各家所说不同也"],
            "editionStatus":"electronic-transcription-not-print-collated"]
        guard sources.count==5,value(r+"/sources/4")==json(source),let yong=string("/bazi/patternAnalysis/yongShenShiShen"),
              string("/bazi/patternAnalysis/conditionalEvidence/selectedYong")==yong,
              let ji=threats[yong],case let .array(pairs)=value(r+"/combinations") else{return nil}
        let requiredQuotes=[
            "/sources/0/quote":"甲用酉官，透丁逢癸印，制伤以护官矣，而又逢戊，癸合戊而不制丁，癸水之相伤矣",
            "/sources/0/additionalQuotes/0":"乙用酉煞，年丁月癸，时上逢戊，则合去癸印以使丁得制煞者，全赖戊之相",
            "/sources/0/additionalQuotes/1":"丁用酉财，透癸逢己，食制煞以生财矣，而又透甲，己合甲而不制癸",
            "/sources/2/quote":"如地支通根，则虽合而不失其用，喜忌依然存在",
            "/sources/2/additionalQuotes/0":"甲己中间，以庚间隔之，则甲岂能越克我之庚而合己",
            "/sources/2/additionalQuotes/1":"日元之干相合，除合而化，变更性质之外，皆不以合论",
            "/sources/2/additionalQuotes/2":"相合则煞不攻身，非谓去之也",
        ]
        guard requiredQuotes.allSatisfy({string(r+$0.key)==$0.value}) else{return nil}
        let day=stems[2],month=branches[1],signature=(0..<4).map{stems[$0]+branches[$0]}.joined(separator:" ")
        let rooted:(String)->Bool={gan in branches.contains{branch in hidden[branch]!.contains{element[String($0)]==element[gan]}}}
        func indexes(_ predicate:(Int,Int,String)->Bool)->[Int] {
            pairs.indices.filter { i in
                guard case let .integer(a)=value(r+"/combinations/\(i)/actorPosition"),
                      case let .integer(t)=value(r+"/combinations/\(i)/targetPosition"),let s=string(r+"/combinations/\(i)/status") else{return false}
                return predicate(Int(a),Int(t),s)
            }
        }
        func removed(_ position:Int)->[Int]{indexes{_,t,s in t==position&&s=="role-disabled-in-selected-profile"}}
        let order=stems.joined()=="丙辛甲辛"&&["寅","卯"].contains(month),lin=signature=="戊辰 甲寅 丁卯 戊申"
        var selections:[[String:Any]]=[]
        if order{selections.append(["ruleId":"bing-selects-month-xin","actorPosition":0,"selectedTargetPosition":1,"retainedTargetPositions":[3],"sourceIds":[orderSource]])}
        if lin{selections.append(["ruleId":"lin-sen-control-one-retain-one","actorPosition":1,"selectedTargetPosition":0,"retainedTargetPositions":[3],"sourceIds":[orderSource]])}
        var threatPositions=(0..<4).filter{$0 != 2&&ji.contains(god(day,stems[$0]))}
        if day=="丁"&&month=="酉"&&["正财","偏财"].contains(yong){threatPositions += (0..<4).filter{$0 != 2&&stems[$0]=="癸"}}
        var specs:[Spec]=[]
        func put(_ a:Int,_ t:Int,_ layer:String,_ gan:String,_ relation:String,_ rule:String){
            if !specs.contains(where:{$0.actor==a&&$0.target==t&&$0.layer==layer&&$0.relation==relation}){
                specs.append(Spec(actor:a,target:t,layer:layer,gan:gan,relation:relation,rule:rule))
            }
        }
        for t in threatPositions {for a in 0..<4 where a != 2&&a != t {
            let ss=god(day,stems[a]),resource=["正印","偏印"].contains(ss),scope=["正官","七杀","伤官"].contains(yong)
            var relations:[String]=[]
            if combines(stems[a],stems[t]){relations.append("合")}
            if controls(stems[a],stems[t])&&(["食神","伤官"].contains(ss)||(resource&&scope)){relations.append("克")}
            if resource&&scope&&generates(stems[t],stems[a]){relations.append("生")}
            for relation in relations {
                let canonical=relation=="克"&&month=="酉"&&((day=="甲"&&yong=="正官"&&stems[a]=="癸"&&stems[t]=="丁")||(day=="丁"&&["正财","偏财"].contains(yong)&&stems[a]=="己"&&stems[t]=="癸"))
                put(a,t,"stem",stems[t],relation,relation=="合" ? "xu-combination-role":canonical ? "canonical-helper-control":"unscoped-action")
            }
        }}
        if day=="乙"&&month=="酉"&&yong=="七杀"&&stems[0]=="丁"&&stems[1]=="癸"&&stems[3]=="戊" {
            put(0,1,"month-main-qi","辛","克","ding-controls-killing-after-wu-binds-gui")
        }
        for s in selections {
            let a=s["actorPosition"] as! Int,t=s["selectedTargetPosition"] as! Int,rule=s["ruleId"] as! String
            for target in [t,3]{put(a,target,"stem",stems[target],order ? "合":"克",rule)}
        }
        var actions:[[String:Any]]=[]
        for s in specs {
            let id=(s.relation=="合" ? "combine":s.relation=="克" ? "control":"generate")+":\(s.actor):\(s.layer):\(s.target)"
            let incoming=indexes{_,t,_ in t==s.actor},blocked=removed(s.actor)
            let attacks:[[String:Any]]=(0..<4).filter{$0 != s.actor&&$0 != 2&&controls(stems[$0],stems[s.actor])}.map { a in
                let protection=removed(a)
                return ["actorPosition":a,"protectionCombinationIndexes":protection,"status":protection.isEmpty ? "unresolved":"neutralized"]
            }
            let opposed=attacks.contains{$0["status"] as? String=="unresolved"}
            let selection=selections.first{($0["actorPosition"] as? Int)==s.actor&&($0["ruleId"] as? String)==s.rule}
            var status="unresolved",reasons:[String]=[]
            if selection != nil&&s.target==3{status="retained"}
            else if !blocked.isEmpty{status="blocked"}
            else if s.rule=="unscoped-action"{reasons=["unresolved-rule-scope"]}
            else if s.relation=="合" {
                guard let pair=indexes({a,t,_ in a==s.actor&&t==s.target}).first, var pairStatus=string(r+"/combinations/\(pair)/status") else{return nil}
                if selection != nil&&pairStatus=="unresolved-competing-pairs"{pairStatus = !rooted(stems[s.actor])||opposed ? "unresolved-relative-strength":"role-disabled-in-selected-profile"}
                if ["role-disabled-in-selected-profile","killing-role-redirected"].contains(pairStatus){status="available"}
                else if ["rooted-role-retained","day-master-no-removal","blocked-by-intervening-geng"].contains(pairStatus){status="retained";reasons=[pairStatus]}
                else{reasons=[pairStatus]}
            }else if incoming.contains(where:{i in let state=string(r+"/combinations/\(i)/status")!;return state.hasPrefix("unresolved")||state=="source-conflict"}){reasons=["unresolved-helper-combination"]}
            else if opposed{reasons=["unresolved-relative-strength"]}
            else{status="available"}
            actions.append(["id":id,"ruleId":s.rule,"actorPosition":s.actor,"targetLayer":s.layer,"targetPosition":s.target,"targetGan":s.gan,"relation":s.relation,
                "status":status,"localEffectEstablished":status=="available","actorCombinationIndexes":incoming,"blockingCombinationIndexes":blocked,"attacks":attacks,"unresolvedReasons":reasons,
                "sourceIds":selection != nil ? [orderSource]:s.relation=="合" ? ["ziping-xu-combination-limits-v1"]:[helperSource]])
        }
        var targets=threatPositions.map{("stem",$0,stems[$0])}
        targets += specs.filter{$0.layer=="month-main-qi"}.map{($0.layer,$0.target,$0.gan)}
        var resolutions:[[String:Any]]=[]
        for (layer,position,gan) in targets {
            let paths=actions.filter{($0["targetLayer"] as? String)==layer&&($0["targetPosition"] as? Int)==position}
            let available=paths.filter{$0["status"] as? String=="available"}.map{$0["id"] as! String}
            let unresolved=paths.filter{$0["status"] as? String=="unresolved"}.map{$0["id"] as! String}
            let blocked=paths.filter{["blocked","retained"].contains($0["status"] as! String)}.map{$0["id"] as! String}
            let status=available.count>1 ? "co-supported-local-paths":available.count==1 ? "supported-local-path": !unresolved.isEmpty ? "unresolved": !blocked.isEmpty ? "known-paths-blocked":"no-scanned-path"
            resolutions.append(["targetLayer":layer,"targetPosition":position,"targetGan":gan,"availableActionIds":available,"blockedActionIds":blocked,"unresolvedActionIds":unresolved,"status":status])
        }
        let expected:[String:Any]=["methodVersion":"bazi-rescue-dependencies-v1","profileId":"ziping-xu-source-scoped-competition-v1","selectedYong":yong,"outcomeEstablished":false,
            "actions":actions,"occurrenceSelections":selections,"threatResolutions":resolutions,
            "unresolvedScopes":["local-paths-do-not-establish-global-outcome","unresolved-attacks-are-not-cancelled-by-unresolved-protections","source-conflicts-and-cycles-have-no-universal-priority","hidden-actors-outside-explicit-month-role-or-attested-case-unresolved"]]
        guard value(p)==json(expected) else{return nil}
        let labels=["年干","月干","日干","时干"]
        var text:[String]=[],paths=[p+"/methodVersion",p+"/profileId",p+"/selectedYong",p+"/outcomeEstablished",p+"/unresolvedScopes"]
        func bindAction(_ i:Int){
            paths.append(p+"/actions/\(i)")
            let action=actions[i],attacks=action["attacks"] as! [[String:Any]]
            let dependencies=(action["actorCombinationIndexes"] as! [Int])+(action["blockingCombinationIndexes"] as! [Int])+attacks.flatMap{$0["protectionCombinationIndexes"] as! [Int]}
            for pair in dependencies{paths.append(r+"/combinations/\(pair)")}
        }
        for (i,s) in selections.enumerated(){
            let a=s["actorPosition"] as! Int,t=s["selectedTargetPosition"] as! Int
            text.append("所选条文以\(labels[a])\(stems[a])作用于\(labels[t])\(stems[t])，保留时干\(stems[3])；位置选择与实际效力分开核对。")
            paths.append(p+"/occurrenceSelections/\(i)")
            if let chosen=actions.firstIndex(where:{($0["actorPosition"] as? Int)==a&&($0["targetPosition"] as? Int)==t}){
                let status=actions[chosen]["status"] as! String
                if status=="available"{text.append("所选\(labels[t])\(stems[t])的局部受制作用成立。")}
                else if status=="retained"{text.append("所选\(labels[t])\(stems[t])仍保留作用，不能由位置选择推定已合去。")}
                else{text.append("所选\(labels[t])\(stems[t])的实际效力仍未定。")}
                bindAction(chosen)
            }
        }
        for (i,a) in actions.enumerated() where (a["relation"] as? String)=="克" && (a["ruleId"] as? String) != "unscoped-action" {
            let actor=a["actorPosition"] as! Int,target=a["targetPosition"] as! Int,status=a["status"] as! String
            let targetName=(a["targetLayer"] as? String)=="month-main-qi" ? "月令本气\(a["targetGan"] as! String)":labels[target]+stems[target]
            let name=labels[actor]+stems[actor]+"制"+targetName
            if status=="available" {
                let neutralized=(a["attacks"] as! [[String:Any]]).filter{$0["status"] as? String=="neutralized"}.map{stems[$0["actorPosition"] as! Int]+"受合牵制"}
                text.append((neutralized.isEmpty ? "":neutralized.joined(separator:"、")+"后，")+name+"的局部路径可用。")
            }else if status=="blocked"{text.append(name+"的救应路径受阻，相神自身受合牵制。")}
            else if status=="unresolved"{text.append(name+"仍有未解制约，局部效力未定。")}
            if status != "retained"{bindAction(i)}
        }
        for (i,t) in resolutions.enumerated() where t["status"] as? String=="co-supported-local-paths" {
            text.append("同一病点的多条局部路径并存，条文没有给出同时出现时的优先胜者。")
            paths.append(p+"/threatResolutions/\(i)")
        }
        if !text.isEmpty{text.append("这些依赖结论不等于全局成败；未解力量、循环及各家异说仍保留。")}
        var seen=Set<String>()
        return (text.joined(),text.isEmpty ? []:(paths+[r+"/sources/4"]).filter{seen.insert($0).inserted})
    }
}
