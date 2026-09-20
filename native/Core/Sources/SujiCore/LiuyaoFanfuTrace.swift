import Foundation

/// Reconstructs the selected structural observations from the saved six values.
/// No new cast, calendar calculation, strength or event verdict is performed.
enum LiuyaoFanfuTrace {
    static let sourceID = "liuyao-fanfu-selected-v1"
    private enum Invalid: Error { case record }
    // Bottom to top binary order. Literal Najia rows also bind full projections;
    // agreeing but jointly corrupted trigram labels and branch flags cannot pass.
    private static let names = ["坤", "震", "坎", "兑", "艮", "离", "巽", "乾"]
    private static let inner = ["乙未乙巳乙卯", "庚子庚寅庚辰", "戊寅戊辰戊午", "丁巳丁卯丁丑", "丙辰丙午丙申", "己卯己丑己亥", "辛丑辛亥辛酉", "甲子甲寅甲辰"]
    private static let outer = ["癸丑癸亥癸酉", "庚午庚申庚戌", "戊申戊戌戊子", "丁亥丁酉丁未", "丙戌丙子丙寅", "己酉己未己巳", "辛未辛巳辛卯", "壬午壬申壬戌"]
    private static let clashes = ["子":"午", "丑":"未", "寅":"申", "卯":"酉", "辰":"戌", "巳":"亥", "午":"子", "未":"丑", "申":"寅", "酉":"卯", "戌":"辰", "亥":"巳"]
    private static let directions = ["乾":"巽", "巽":"乾", "坎":"离", "离":"坎", "震":"兑", "兑":"震", "艮":"坤", "坤":"艮"]

    static func sections(root: JSONValue, receiptID: String, sourcePaths: [String]) throws -> [LiuyaoReferenceReading.Section] {
        func value(_ path: String) throws -> JSONValue {
            guard let result=ReadingVerificationEvidence.pointer(path,in:root) else { throw Invalid.record };return result
        }
        func string(_ path: String) throws -> String {
            guard case let .string(result)=try value(path) else { throw Invalid.record };return result
        }
        func integer(_ path: String) throws -> Int {
            guard case let .integer(result)=try value(path) else { throw Invalid.record };return Int(result)
        }
        func array(_ path: String) throws -> [JSONValue] {
            guard case let .array(result)=try value(path) else { throw Invalid.record };return result
        }
        func integers(_ values: [Int]) -> JSONValue { .array(values.map{.integer(Int64($0))}) }
        func strings(_ values: [String]) -> JSONValue { .array(values.map{.string($0)}) }
        func najia(_ text: String) -> [String] {
            let parts=Array(text);return stride(from:0,to:parts.count,by:2).map{String(parts[$0...($0+1)])}
        }
        let base="/fanfu"
        let inputs=try array("/lineValues")
        guard inputs.count == 6,try array("/lines").count == 6 else { throw Invalid.record }
        let values=try (0..<6).map{try integer("/lineValues/\($0)")}
        guard values.allSatisfy({(6...9).contains($0)}) else { throw Invalid.record }
        let moving=values.indices.filter{values[$0] == 6 || values[$0] == 9}
        guard try value("/changingYao") == integers(moving.map{$0+1}) else { throw Invalid.record }
        var original=[String](),resulting=[String](),trigramRows=[JSONValue]()
        for half in 0..<2 {
            let indices=Array((half*3)..<(half*3+3)),side=half == 0 ? "lower" : "upper"
            let before=indices.enumerated().reduce(0){$0 + ((values[$1.element]%2 == 1 ? 1 : 0) << $1.offset)}
            let after=indices.enumerated().reduce(0){$0 + (([6,7].contains(values[$1.element]) ? 1 : 0) << $1.offset)}
            let from=names[before],to=names[after],table=half == 0 ? inner : outer
            let a=najia(table[before]),b=najia(table[after])
            original += a;resulting += b
            guard try string("/benGua/"+side) == from,try string("/bianGua/"+side) == to else { throw Invalid.record }
            let same=zip(a,b).allSatisfy{$0.suffix(1) == $1.suffix(1)}
            let opposite=zip(a,b).allSatisfy{clashes[String($0.suffix(1))] == String($1.suffix(1))}
            let relation=from == to ? "unchanged" : same ? "repeated" : opposite ? "opposed" : "neither"
            trigramRows.append(.object(["side":.string(side),"from":.string(from),"to":.string(to),
                "movingPositions":integers(indices.filter{moving.contains($0)}.map{$0+1}),
                "branchRelation":.string(relation),"directionalOpposition":.bool(directions[from] == to)]))
        }
        guard try value("/guaRelations/original/ganZhi") == strings(original),
              try value("/guaRelations/resulting/ganZhi") == strings(resulting) else { throw Invalid.record }
        var lineRows=[JSONValue]()
        for i in 0..<6 {
            let p="/lines/\(i)",isMoving=moving.contains(i)
            guard try string(p+"/ganZhi") == original[i],try value(p+"/isChanging") == .bool(isMoving) else { throw Invalid.record }
            if !isMoving {
                guard ReadingVerificationEvidence.pointer(p+"/changed",in:root) == nil else { throw Invalid.record }
                continue
            }
            guard try string(p+"/changed/ganZhi") == resulting[i] else { throw Invalid.record }
            lineRows.append(.object(["originalPath":.string(p),"changedPath":.string(p+"/changed"),
                "sameStem":.bool(original[i].prefix(1) == resulting[i].prefix(1)),
                "sameBranch":.bool(original[i].suffix(1) == resulting[i].suffix(1)),
                "branchClash":.bool(clashes[String(original[i].suffix(1))] == String(resulting[i].suffix(1)))]))
        }
        let expected:JSONValue = .object(["sourceId":.string(sourceID),"assessmentStatus":.string("structural-only"),
            "efficacyEstablished":.bool(false),"lines":.array(lineRows),"trigrams":.array(trigramRows),
            "unresolved":strings(["selected-object","target-strength","actor-effectiveness","event-outcome"])])
        guard try value(base) == expected else { throw Invalid.record }
        let policyPaths=sourcePaths+[base+"/sourceId",base+"/assessmentStatus",base+"/efficacyEstablished",base+"/unresolved"]
        func section(_ id: String, _ text: String, _ paths: [String]) throws -> LiuyaoReferenceReading.Section {
            var seen=Set<String>()
            return .init(id:id,text:text,evidence:try (paths+policyPaths).filter{seen.insert($0).inserted}.map{.init(toolCallID:receiptID,pointer:$0,value:try value($0))})
        }
        var sections=[try section("fanfu-policy","反吟、伏吟分开核对实际动爻同位变化、内外卦三支投影与《易林补遗》所列方位相对。异干同支仍保留同支事实；未变卦体不列动态伏吟。选用方位对为乾巽、坎离、震兑、艮坤；《增删》电子本乾坤、坤震等异文保留分歧，不混作同一规则。这些结构尚未确定用神、旺衰、作用效力或事件结果。",["/lineValues","/changingYao"])]
        for (j,i) in moving.enumerated() {
            let p="/lines/\(i)",row=base+"/lines/\(j)"
            let sameStem=original[i].prefix(1) == resulting[i].prefix(1),sameBranch=original[i].suffix(1) == resulting[i].suffix(1)
            let clash=clashes[String(original[i].suffix(1))] == String(resulting[i].suffix(1))
            let text="第\(i+1)动爻同位变化：\(original[i])→\(resulting[i])；"+(sameStem ? "同干" : "异干")+"、"+(sameBranch ? "同支" : "不同支")+"、"+(clash ? "支相冲" : "支不相冲")+"。此处只比较该动爻与它自己的化爻，效力未定。"
            sections.append(try section("fanfu-line-\(i+1)",text,[row,p+"/ganZhi",p+"/isChanging",p+"/changed/ganZhi","/lineValues","/changingYao"]))
        }
        for (j,side) in ["lower","upper"].enumerated() {
            let p=base+"/trigrams/\(j)",from=try string(p+"/from"),to=try string(p+"/to"),relation=try string(p+"/branchRelation")
            let labels=["unchanged":"卦体未变，不列动态伏吟","repeated":"变后投影三支全同（卦体伏吟参考）","opposed":"变后投影三支全冲（卦体反吟参考）","neither":"变后投影三支非全同也非全冲"]
            let members=moving.filter{($0/3) == j}.map{String($0+1)}
            let text="\(side == "lower" ? "内卦" : "外卦")\(from)→\(to)：\(labels[relation]!)；实际明动爻位"+(members.isEmpty ? "无" : members.joined(separator:"、"))+"。《易林补遗》方位相对："+(directions[from] == to ? "匹配" : "不匹配")+"。三支是完整卦体的纳甲投影，不能把其中静爻当作实际化爻，也不能据此直接断成败。"
            sections.append(try section("fanfu-"+side,text,[p,"/benGua/"+side,"/bianGua/"+side,"/guaRelations/original/ganZhi","/guaRelations/resulting/ganZhi","/lineValues","/changingYao"]))
        }
        return sections
    }
}
