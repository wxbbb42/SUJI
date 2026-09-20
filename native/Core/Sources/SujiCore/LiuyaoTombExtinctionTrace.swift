import Foundation

/// Validates references against the saved objects. No calendar, cast, strength
/// score, or event date is recomputed by this presentation layer.
enum LiuyaoTombExtinctionTrace {
    static let sourceID = "liuyao-tomb-extinction-v1"
    private enum Invalid: Error { case record }
    private static let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    private static let elements = Array("水土木木土火火土金金土水").map(String.init)
    private static let tombs = ["木":"未", "火":"戌", "土":"辰", "金":"丑", "水":"辰"]
    private static let extinctions = ["木":"申", "火":"亥", "土":"巳", "金":"寅", "水":"巳"]
    private static let generates = ["木":"火", "火":"土", "土":"金", "金":"水", "水":"木"]
    private static let controls = ["木":"土", "土":"水", "水":"火", "火":"金", "金":"木"]

    static func sections(root: JSONValue, receiptID: String, sourcePaths: [String]) throws -> [LiuyaoReferenceReading.Section] {
        func value(_ path: String) throws -> JSONValue {
            guard let value=ReadingVerificationEvidence.pointer(path,in:root) else { throw Invalid.record };return value
        }
        func string(_ path: String) throws -> String {
            guard case let .string(text)=try value(path) else { throw Invalid.record };return text
        }
        func bool(_ path: String) throws -> Bool {
            guard case let .bool(flag)=try value(path) else { throw Invalid.record };return flag
        }
        func array(_ path: String) throws -> [JSONValue] {
            guard case let .array(items)=try value(path) else { throw Invalid.record };return items
        }
        func branch(_ path: String) throws -> String {
            let ganZhi=try string(path),parts=ganZhi.map(String.init)
            guard parts.count == 2,"甲乙丙丁戊己庚辛壬癸".contains(parts[0]),branches.contains(parts[1]) else { throw Invalid.record };return parts[1]
        }
        func element(_ path: String) throws -> String {
            let b=try branch(path+"/ganZhi"),e=try string(path+"/wuXing")
            guard let i=branches.firstIndex(of:b),elements[i] == e else { throw Invalid.record };return e
        }
        func relation(_ element: String, _ branch: String) -> String {
            tombs[element] == branch ? "墓" : extinctions[element] == branch ? "绝" : "neither"
        }
        func clashes(_ a: String, _ b: String) -> Bool {
            guard let i=branches.firstIndex(of:a),let j=branches.firstIndex(of:b) else { return false }
            return (i-j+12)%12 == 6
        }
        func integers(_ items: [Int]) -> JSONValue { .array(items.map{.integer(Int64($0))}) }
        let month=try branch("/castGanZhi/month"),day=try branch("/castGanZhi/day")
        let void=try array("/xunKong")
        // Source contexts used in conditional prose must describe the actual
        // source object, including negative conditions, not a borrowed target.
        func checkContext(_ path: String) throws {
            let e=try element(path),b=try branch(path+"/ganZhi"),c=path+"/context"
            guard try bool(c+"/isVoid") == void.contains(.string(b)) else { throw Invalid.record }
            for (scope,calendar) in [("month",month),("day",day)] {
                let p=c+"/"+scope,i=branches.firstIndex(of:calendar)!,j=branches.firstIndex(of:b)!,from=elements[i]
                let rel=from == e ? "同类" : generates[from] == e ? "生爻" : controls[from] == e ? "克爻" : generates[e] == from ? "爻生" : "爻克"
                guard try string(p+"/ganZhi") == string("/castGanZhi/"+scope),
                      try string(p+"/branch") == calendar,try string(p+"/element") == from,
                      try string(p+"/elementRelation") == rel,try bool(p+"/sameBranch") == (b == calendar),
                      try bool(p+"/clash") == clashes(calendar,b),try bool(p+"/combination") == ((i+j)%12 == 1) else { throw Invalid.record }
            }
        }
        let paths=(0..<6).map{"/lines/\($0)"}
        let moving=try paths.indices.filter { try bool(paths[$0]+"/isChanging") }
        var expectedRows:[JSONValue]=[],sections:[LiuyaoReferenceReading.Section]=[]
        let base="/tombExtinction"
        for i in paths.indices {
            let original=paths[i]
            let layers=["original"] + (moving.contains(i) ? ["changed"] : []) + (ReadingVerificationEvidence.pointer(original+"/hidden",in:root) == nil ? [] : ["hidden"])
            for layer in layers {
                let p=original+(layer == "original" ? "" : "/"+layer),e=try element(p)
                try checkContext(p)
                let actors=moving.filter{$0 != i}
                let tombActors=try layer == "original" ? actors.filter{try branch(paths[$0]+"/ganZhi") == tombs[e]} : []
                let extinctActors=try layer == "original" ? actors.filter{try branch(paths[$0]+"/ganZhi") == extinctions[e]} : []
                let support=try layer == "changed" ? [] : actors.filter { actor in
                    let from=try element(paths[actor]);return from == e || generates[from] == e
                }
                var row:[String:JSONValue] = ["objectPath":.string(p),"month":.string(relation(e,month)),"day":.string(relation(e,day)),
                    "movingTombPositions":integers(tombActors.map{$0+1}),"movingExtinctionPositions":integers(extinctActors.map{$0+1}),"supportingMovingPositions":integers(support.map{$0+1})]
                var refs:[(String,String,String)]=[("月支",month,relation(e,month)),("日支",day,relation(e,day))]
                var objects:[String]=[]
                if layer == "original",moving.contains(i) {
                    let b=try branch(original+"/changed/ganZhi"),r=relation(e,b)
                    row["ownChange"] = .string(r);refs.append(("同位化爻",b,r));objects.append(original+"/changed")
                }
                if layer == "hidden" {
                    let b=try branch(original+"/ganZhi"),r=relation(e,b)
                    row["flying"] = .string(r);refs.append(("本位飞神",b,r));objects.append(original)
                }
                objects += (tombActors+extinctActors).map{paths[$0]}
                expectedRows.append(.object(row))
                var evidencePaths=[base+"/objects/\(expectedRows.count-1)",p+"/ganZhi",p+"/wuXing",p+"/context",p+"/context/month/elementRelation",p+"/context/day/elementRelation","/castGanZhi/month","/castGanZhi/day","/changingYao",base+"/assessmentStatus",base+"/efficacyEstablished",base+"/unresolved"]+sourcePaths
                // Include the inspected set even when there are no matches.
                evidencePaths += paths.flatMap{[$0+"/ganZhi",$0+"/wuXing",$0+"/isChanging"]}
                let title=layer == "original" ? "本爻" : layer == "changed" ? "变爻" : "伏神"
                var text=["第\(i+1)爻\(title)\(try string(p+"/ganZhi"))\(e)的墓绝参考：" + refs.map{label,b,r in label+b+(r == "neither" ? "非所选墓绝位" : "为"+r)}.joined(separator:"；")]
                if layer == "original" {
                    text.append("动墓爻位："+(tombActors.isEmpty ? "无" : tombActors.map{String($0+1)}.joined(separator:"、"))+"；动绝结构爻位："+(extinctActors.isEmpty ? "无" : extinctActors.map{String($0+1)}.joined(separator:"、")))
                }
                for (scope,label) in [("month","月"),("day","日")] {
                    let r=try string(p+"/context/"+scope+"/elementRelation")
                    text.append("\(label)对该对象\(r)")
                }
                if layer != "changed" {
                    text.append("其他明动生扶爻位："+(support.isEmpty ? "无" : support.map{String($0+1)}.joined(separator:"、")))
                    for actor in support { try checkContext(paths[actor]);evidencePaths.append(paths[actor]+"/context") }
                }
                var seenObjects=Set<String>()
                for object in objects where seenObjects.insert(object).inserted {
                    try checkContext(object)
                    let b=try branch(object+"/ganZhi"),r=relation(e,b)
                    guard r != "neither" else { continue }
                    let c=object+"/context",empty=try bool(c+"/isVoid"),monthClash=try bool(c+"/month/clash"),dayClash=try bool(c+"/day/clash")
                    let clashing=try moving.filter{try clashes(branch(paths[$0]+"/ganZhi"),b)}
                    text.append("\(b)\(r)参考对象："+(empty ? "旬空" : "不空")+"、"+(monthClash ? "月冲" : "无月冲")+"、"+(dayClash ? "日冲" : "无日冲")+"；与其支相冲的明动爻位："+(clashing.isEmpty ? "无" : clashing.map{String($0+1)}.joined(separator:"、")))
                    evidencePaths += [object+"/ganZhi",object+"/wuXing",c]
                }
                if e == "土",refs.contains(where:{$0.1 == "巳"}) || !extinctActors.isEmpty {
                    text.append("巳同时有火生土关系；所选原文要求区分旺而有扶与休囚无气，不能见巳就认定绝已成立")
                }
                if e == "金",refs.contains(where:{$0.1 == "丑"}) || !tombActors.isEmpty {
                    text.append("丑同时有土生金关系；所选原文保留土多生金、未冲墓等条件，不能仅凭丑支认定墓已成立")
                }
                text.append("以上为结构与条件，效力未定")
                var seen=Set<String>()
                let evidence=try evidencePaths.filter{seen.insert($0).inserted}.map{BaziFrameworkReading.FieldEvidence(toolCallID:receiptID,pointer:$0,value:try value($0))}
                sections.append(.init(id:"tomb-\(i+1)-\(layer)",text:text.joined(separator:"。")+"。",evidence:evidence))
            }
        }
        let unresolved=["selected-object","target-strength","actor-effectiveness","event-outcome"]
        let expected:JSONValue = .object(["sourceId":.string(sourceID),"assessmentStatus":.string("conditional-structure"),"efficacyEstablished":.bool(false),"objects":.array(expectedRows),"unresolved":.array(unresolved.map{.string($0)})])
        guard try value(base) == expected else { throw Invalid.record }
        sections.insert(.init(id:"tomb-policy",text:"墓绝按所选六爻五行表（土随水）核对，与八字阴阳干长生分开。旺而有扶、墓爻空破或受冲必须另审；墓爻填实不一律代表解除，不能由这些结构直接确定吉凶或日期。火绝亥以《易林补遗》共同表项补证《增删》电子本缺行，不引入其不同的土绝效力断法。",evidence:try (sourcePaths+[base+"/assessmentStatus",base+"/efficacyEstablished",base+"/unresolved"]).map{.init(toolCallID:receiptID,pointer:$0,value:try value($0))}),at:0)
        return sections
    }
}
