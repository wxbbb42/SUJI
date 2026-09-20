import Foundation

/// Reconstructs scoped membership from saved objects after the independent
/// fanfu Najia and tomb/context validators have authenticated those objects.
/// No strength, formed局, transformation, selected object or outcome is inferred.
enum LiuyaoTriadTrace {
    static let sourceID = "liuyao-triad-selected-v1"
    private enum Invalid: Error { case record }
    private static let tables = [("申子辰","水"),("巳酉丑","金"),("寅午戌","火"),("亥卯未","木")]
    static func sections(root: JSONValue, receiptID: String, sourcePaths: [String]) throws -> [LiuyaoReferenceReading.Section] {
        func value(_ p:String) throws -> JSONValue {
            guard let v=ReadingVerificationEvidence.pointer(p,in:root) else { throw Invalid.record };return v
        }
        func string(_ p:String) throws -> String {
            guard case let .string(v)=try value(p) else { throw Invalid.record };return v
        }
        func flag(_ p:String) throws -> Bool {
            guard case let .bool(v)=try value(p) else { throw Invalid.record };return v
        }
        func array(_ p:String) throws -> [JSONValue] {
            guard case let .array(v)=try value(p) else { throw Invalid.record };return v
        }
        func strings(_ s:[String])->JSONValue { .array(s.map{.string($0)}) }
        func branch(_ p:String) throws -> String { String(try string(p+(p.hasPrefix("/castGanZhi/") ? "" : "/ganZhi")).suffix(1)) }
        let originals=(0..<6).map{"/lines/\($0)"}
        let moving=try originals.filter{try flag($0+"/isChanging")}
        var routes:[(String,String?,[String])]=[("visible-originals",nil,originals)]
        routes += moving.map{("calendar-moving-anchor",$0,[$0,"/castGanZhi/month","/castGanZhi/day"])}
        for (scope,a,b) in [("inner-change",0,2),("outer-change",3,5)] where moving.contains(originals[a]) && moving.contains(originals[b]) {
            routes.append((scope,nil,[originals[a],originals[a]+"/changed",originals[b],originals[b]+"/changed"]))
        }
        let tombs=try array("/tombExtinction/objects")
        var tombPaths=[String:String]()
        for i in tombs.indices { tombPaths[try string("/tombExtinction/objects/\(i)/objectPath")]="/tombExtinction/objects/\(i)" }
        var groups=[JSONValue]()
        for (scope,anchor,pool) in routes {
            for (letters,element) in tables {
                let branches=letters.map(String.init)
                if let anchor,try !branches.contains(branch(anchor)) { continue }
                let matches=try branches.map{b in try pool.filter{try branch($0) == b}}
                guard matches.filter({!$0.isEmpty}).count >= 2 else { continue }
                let missing=branches.indices.filter{matches[$0].isEmpty}.map{branches[$0]}
                let objects=matches.flatMap{$0}.filter{$0.hasPrefix("/lines/")}
                let contexts=objects.map{$0+"/context"}
                let tombReferences=try objects.map{p -> String in guard let t=tombPaths[p] else { throw Invalid.record };return t}
                let dayClashes=objects.filter{originals.contains($0) && ReadingVerificationEvidence.pointer($0+"/rules/dayClash",in:root) != nil}.map{$0+"/rules/dayClash"}
                groups.append(.object(["scope":.string(scope),"anchorPath":anchor.map{.string($0)} ?? .null,"element":.string(element),
                    "members":.array(branches.indices.map{.object(["branch":.string(branches[$0]),"role":.string(["birth","center","tomb"][$0]),"objectPaths":strings(matches[$0])])}),
                    "missingBranches":strings(missing),"complete":.bool(missing.isEmpty),"centerPresent":.bool(!matches[1].isEmpty),
                    "contextPaths":strings(contexts),"tombReferencePaths":strings(tombReferences),"dayClashRulePaths":strings(dayClashes)]))
            }
        }
        let base="/triads",unresolved=["motion-threshold","dark-movement","member-strength","void-break-effectiveness","tomb-effectiveness","clash-effectiveness","binding-or-transformation","selected-object","event-outcome"]
        let expected:JSONValue = .object(["sourceId":.string(sourceID),"assessmentStatus":.string("structural-only"),"efficacyEstablished":.bool(false),"groups":.array(groups),"unresolved":strings(unresolved)])
        guard try value(base) == expected else { throw Invalid.record }
        let policy=sourcePaths+[base+"/sourceId",base+"/assessmentStatus",base+"/efficacyEstablished",base+"/unresolved","/lineValues","/changingYao"]
        func section(_ id:String,_ text:String,_ paths:[String]) throws -> LiuyaoReferenceReading.Section {
            var seen=Set<String>()
            return .init(id:id,text:text,evidence:try (paths+policy).filter{seen.insert($0).inserted}.map{.init(toolCallID:receiptID,pointer:$0,value:try value($0))})
        }
        var result=[try section("triads-policy","三合只核对限定范围的支成员。静卦可见三支齐备也不判经典成局；《增删》一、两、三爻发动文字有冲突，发动门槛与效力未决。日月加实际动爻路线来自日月世例，非世动爻属于结构推广。《易林补遗》有中神的两支成局说与这里三支齐备标准不同。生、中、墓为表内身份，墓支不代表已经入墓；空破、墓、冲、合绊或化局、用神与结果仍须另审。",[base+"/groups"])]
        let scopes=["visible-originals":"六个可见本爻","calendar-moving-anchor":"日月与单一实际动爻","inner-change":"内卦初、三爻及各自化爻","outer-change":"外卦四、六爻及各自化爻"]
        for i in groups.indices {
            let p=base+"/groups/\(i)",scope=try string(p+"/scope"),element=try string(p+"/element")
            var descriptions=[String](),evidence=[p]
            for j in 0..<3 {
                let m=p+"/members/\(j)",b=try string(m+"/branch")
                let objects=try array(m+"/objectPaths").map{v -> String in guard case let .string(s)=v else { throw Invalid.record };return s}
                if objects.isEmpty { descriptions.append("缺"+b);continue }
                for object in objects {
                    if object.hasPrefix("/castGanZhi/") {
                        descriptions.append((object.hasSuffix("month") ? "月建" : "日辰")+(try string(object)));evidence.append(object)
                    } else {
                        let c=object+"/context",void=try flag(c+"/isVoid"),mc=try flag(c+"/month/clash"),dc=try flag(c+"/day/clash")
                        let position=Int(object.split(separator:"/")[1])!+1
                        let label="第\(position)爻"+(object.hasSuffix("/changed") ? "化爻" : "本爻")
                        descriptions.append("\(label)\(try string(object+"/ganZhi"))："+(void ? "旬空" : "不空")+"、"+(mc ? "月冲" : "无月冲")+"、"+(dc ? "日冲" : "无日冲")+"；月\(try string(c+"/month/elementRelation"))、日\(try string(c+"/day/elementRelation"))")
                        evidence += [object+"/ganZhi",c,tombPaths[object]!]
                        if ReadingVerificationEvidence.pointer(object+"/rules/dayClash",in:root) != nil { evidence.append(object+"/rules/dayClash") }
                    }
                }
            }
            result.append(try section("triads-group-\(i+1)","\(scopes[scope]!)的\(element)组三合成员："+descriptions.joined(separator:"；")+"。"+(try flag(p+"/complete") ? "三支齐备" : "三支未齐")+"，"+(try flag(p+"/centerPresent") ? "中神在列" : "缺中神")+"；以上仅为成员与各自条件，不能确定成局或效力。",evidence))
        }
        return result
    }
}
