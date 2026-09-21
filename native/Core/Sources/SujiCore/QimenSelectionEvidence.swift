import Foundation

public enum QimenSelectionEvidence {
    public struct Report:Sendable {public let text:String;public let evidencePaths:[String]}
    static let sourceIDs:Set<String>=["qimen-xdyy-weather-selection-v1","qimen-xdyy-dwelling-selection-v1"]
    public static func read(root:JSONValue,arguments:JSONValue)->Report? {try? Reader(root:root,arguments:arguments).build()}
    private enum Invalid:Error {case record}
    private struct Role {let id:String,label:String,field:String,symbol:String
        init(_ id:String,_ label:String,_ field:String,_ symbol:String="") {self.id=id;self.label=label;self.field=field;self.symbol=symbol}
    }
    // Independent role table, derived from the pinned source sentences below.
    private static let roles:[String:[Role]]=[
        "weather-rain":[Role("rain-master","雨师参考","jiuxing","天柱"),Role("water-spirit","水神参考","jiuxing","天蓬")],
        "weather-snow":[Role("snow-heart","占雪天心参考","jiuxing","天心"),Role("snow-pillar","占雪天柱参考","jiuxing","天柱")],
        "weather-wind":[Role("wind-star","占风参考","jiuxing","天辅")],
        "weather-river-level":[Role("river-star","河水天蓬参考","jiuxing","天蓬"),Role("river-door","河水休门参考","bamen","休门")],
        "dwelling-residence":[Role("residence-hour","住宅时干参考","hour"),Role("residence-door","住宅生门参考","bamen","生门")],
        "dwelling-entrance":[Role("entrance-duty-door","住宅大门参考","duty-door")],
        "dwelling-stove":[Role("stove-stem","灶具、燃火参考","stem","丙")],
        "dwelling-tap-water":[Role("tap-water-stem","饮用自来水参考","stem","壬")],
        "dwelling-utensils":[Role("utensils-stem","锅碗瓢盆参考","stem","辛")],
        "dwelling-courtyard":[Role("courtyard-deity","院落九天参考","bashen","九天"),Role("courtyard-star","院落天芮参考","jiuxing","天芮")],
        "dwelling-skywell":[Role("skywell-stem","天井参考","stem","己")],
        "dwelling-living-room":[Role("living-room-deity","客厅参考","bashen","六合")]
    ]
    private static let names=[1:"坎宫",2:"坤宫",3:"震宫",4:"巽宫",5:"中宫",6:"乾宫",7:"兑宫",8:"艮宫",9:"离宫"]
    private static let plateLabels=["earth":"地盘","hosted-earth":"地盘寄干","sky":"天盘","hosted-sky":"天盘寄干","center-record":"中宫留存记录","star":"星","door":"门","deity":"神"]
    private static func strings(_ items:[String])->JSONValue {.array(items.map(JSONValue.string))}
    private static func trim(_ value:String)->String {
        value.trimmingCharacters(in:CharacterSet(charactersIn:"\u{0009}\u{000A}\u{000B}\u{000C}\u{000D}\u{0020}\u{00A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}"))
    }
    private struct Reader {
        let root:JSONValue,arguments:JSONValue
        func value(_ path:String)->JSONValue? {ReadingVerificationEvidence.pointer(path,in:root)}
        func string(_ path:String)->String? {guard case let .string(s)=value(path) else{return nil};return s}
        func build()throws->Report {
            guard case let .object(args)=arguments,case let .object(request)=args["selectionRequest"],request.count==1,
                  case let .string(focus)=request["focus"],let roles=roles[focus],
                  let questionType=string("/questionType"),
                  (args["questionType"] ?? .string("general")) == .string(questionType),
                  case let .array(palaces)=value("/palaces"),case let .array(sources)=value("/ruleSources") else {throw Invalid.record}
            let event=trim(string("/questionContext/event") ?? "")
            let argumentEvent:String
            if let supplied=args["event"] {guard case let .string(s)=supplied else {throw Invalid.record};argumentEvent=trim(s)} else {argumentEvent=""}
            guard argumentEvent==event else {throw Invalid.record}
            let sourceID="qimen-xdyy-"+(focus.hasPrefix("weather-") ? "weather" : "dwelling")+"-selection-v1"
            let optionalSources=sources.enumerated().filter { item in
                guard case let .string(id)=ReadingVerificationEvidence.pointer("/id",in:item.element) else {return false}
                return sourceIDs.contains(id)
            }
            guard optionalSources.count==1,let source=optionalSources.first,
                  let pinned=try JSONDecoder().decode([String:JSONValue].self,from:Data(pinnedSources.utf8))[sourceID],source.element==pinned else {throw Invalid.record}
            var evidence=["/specializedSelection","/questionType","/method","/palaces","/ruleSources/\(source.offset)"]
            if value("/questionContext") != nil {evidence.append("/questionContext")}
            let ids=palaces.indices.map {index->Int? in guard case let .integer(id)=value("/palaces/\(index)/id") else{return nil};return Int(exactly:id)}
            let originalNine=palaces.count==9 && Set(ids.compactMap{$0})==Set(1...9)
            // Malformed palace identities cannot safely be used as display evidence.
            guard ids.allSatisfy({$0 != nil && names[$0!] != nil}) else {throw Invalid.record}
            let checks:[(String,Bool,[String])]=[
                ("single-event",!event.isEmpty && event.utf16.count<=200,["/questionContext"]),
                ("event-question-category",["event","general"].contains(questionType),["/questionType"]),
                ("compatible-chart-method",string("/method/algorithm")=="zhuanpan-qimen-chai-bu-v1" && string("/method/centerPolicy")=="fixed-kun-2; tian-qin-follows-tian-rui",["/method"]),
                ("original-nine-palaces",originalNine,["/palaces"])
            ]
            var missing=checks.filter{!$0.1 && $0.0 != "event-question-category"}.map{$0.0}
            var conflicts:[JSONValue]=checks[1].1 ? [] : [["id":"question-category-conflict","factPaths":strings(["/questionType"])]]
            var references:[JSONValue]=[],descriptions:[String]=[],ambiguous=false
            for role in roles {
                let isStem=role.field=="stem" || role.field=="hour"
                let symbol=role.field=="hour" ? String((string("/hourGanZhi") ?? "").prefix(1)) : role.field=="duty-door" ? (string("/zhiShiMen") ?? "") : role.symbol
                var carrier:String?=isStem ? symbol : nil
                let factPaths=role.field=="hour" ? ["/hourGanZhi"] : role.field=="duty-door" ? ["/zhiShiMen","/zhiShiPalaceId"] : []
                if role.field=="hour" {
                    let pillar=string("/hourGanZhi") ?? "",parts=pillar.map(String.init),stems="甲乙丙丁戊己庚辛壬癸".map(String.init),branches="子丑寅卯辰巳午未申酉戌亥".map(String.init)
                    if parts.count != 2 || !stems.contains(parts[0]) || !branches.contains(parts[1]) || (branches.firstIndex(of:parts[1])!-stems.firstIndex(of:parts[0])!+12)%2 != 0 {
                        missing.append("original-hour-pillar");carrier=nil
                    } else if symbol=="甲" {carrier=["甲子":"戊","甲戌":"己","甲申":"庚","甲午":"辛","甲辰":"壬","甲寅":"癸"][pillar]}
                }
                let fields=isStem ? ["diPanGan","hostedDiPanGan","tianPanGan","hostedTianPanGan"] : [role.field=="duty-door" ? "bamen" : role.field]
                var occurrences:[JSONValue]=[],effective:[(Int,String)]=[],locations:[String]=[]
                for index in palaces.indices {
                    let id=ids[index]!
                    for field in fields {
                        let path="/palaces/\(index)/\(field)"
                        guard !symbol.isEmpty,(!isStem || carrier != nil),string(path)==(isStem ? carrier : symbol),(isStem || id != 5) else {continue}
                        let plate=field=="tianPanGan" && id==5 ? "center-record" : ["diPanGan":"earth","hostedDiPanGan":"hosted-earth","tianPanGan":"sky","hostedTianPanGan":"hosted-sky","jiuxing":"star","bamen":"door","bashen":"deity"][field]!
                        let isEffective=plate=="sky" || plate=="hosted-sky"
                        var occurrence:[String:JSONValue]=["palaceId":.integer(Int64(id)),"plate":.string(plate),"objectPath":.string(path)]
                        if isStem {occurrence["isEffectiveSky"] = .bool(isEffective)}
                        occurrences.append(.object(occurrence));if !isStem || isEffective {effective.append((id,path))}
                        locations.append("\(plateLabels[plate]!)\(isStem ? carrier! : symbol)在\(names[id]!)")
                        evidence += [path,"/palaces/\(index)/id"]
                    }
                }
                var resolution=isStem ? "multiple-plate-references" : "single-object"
                if effective.isEmpty {resolution="missing-object";missing.append("role-object:"+role.id)}
                else if effective.count>1 {resolution="conflicting-object";conflicts.append(["id":"duplicate-role-object","factPaths":strings(effective.map{$0.1})])}
                if role.field=="duty-door" && (effective.count != 1 || value("/zhiShiPalaceId") != .integer(Int64(effective[0].0))) {
                    resolution="conflicting-object";conflicts.append(["id":"duty-door-palace-conflict","factPaths":strings(factPaths)])
                }
                var reference:[String:JSONValue]=["id":.string(role.id),"label":.string(role.label),"symbol":.string(symbol),"factPaths":strings(factPaths),"occurrences":.array(occurrences),"resolution":.string(resolution),"selectedObjectPath":resolution=="single-object" ? .string(effective[0].1) : .null]
                if let carrier {reference["carrierStem"] = .string(carrier);reference["carrierMethod"] = .string(symbol=="甲" ? "own-pillar-xun" : "direct-stem")}
                references.append(.object(reference));ambiguous = ambiguous || resolution=="multiple-plate-references"
                let location=locations.isEmpty ? "原盘对象缺失" : locations.joined(separator:"；")
                descriptions.append(role.label+"："+location+(resolution=="conflicting-object" ? "（对象冲突）" : "")+"。")
                evidence += factPaths.filter{value($0) != nil}
            }
            let established=missing.isEmpty && conflicts.isEmpty
            let expected:JSONValue=["methodVersion":"qimen-xdyy-selection-v1","sourceId":.string(sourceID),"request":.object(request),"event":.string(event),
                "assessmentStatus":.string(established ? "role-references-established" : "requires-clarification"),"roleMappingEstablished":.bool(established),"outcomeEstablished":false,
                "references":.array(references),"conditions":.array(checks.map{["id":.string($0.0),"met":.bool($0.1),"factPaths":strings($0.2)]}),
                "missingContext":strings(missing),"conflicts":.array(conflicts),"unresolved":strings(["event-outcome-not-adjudicated"]+(ambiguous ? ["stem-plate-not-uniquely-selected"] : []))]
            guard value("/specializedSelection")==expected,evidence.allSatisfy({value($0) != nil}) else {throw Invalid.record}
            var text="本次专门取用"+(established ? "已核对原文角色与原盘位置。" : "尚缺适用条件或存在对象冲突。")+descriptions.joined()
            if !checks[0].1 {text += "需要一个不超过200字符的明确事项。"}
            if !checks[1].1 {text += "问题类别与本专门取用不相容，需先澄清。"}
            if ambiguous {text += "干的盘层尚未唯一选定，各盘层分别保留。"}
            text += "以上只建立传统参考对象；事件成败仍未裁决，未据此推断现实天气、房屋布局或日期。来源为网页电子转录，未经纸本校勘。"
            var seen=Set<String>()
            return Report(text:text,evidencePaths:evidence.filter{seen.insert($0).inserted})
        }
    }
    // Full source metadata is pinned independently of the receipt.
    private static let pinnedSources = #"""
{
  "qimen-xdyy-weather-selection-v1": {
    "id": "qimen-xdyy-weather-selection-v1",
    "version": "1",
    "title": "奇门遁甲现代应用技术：天气专门对象",
    "editionStatus": "electronic-transcription-not-print-collated",
    "scope": "明确占雨、雪、风、河水的原盘参考对象；不裁定实际天气",
    "references": [
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167806.html",
        "sha256": "4bc953e3ba511c0461a8d709c2bb9b32fc576d2ec447401fa6678c1a2872779b",
        "locator": "第04章 天气情况；占雨；文字稿第16行",
        "quote": "测是否下雨以天柱星代表雨师，天蓬星代表水神"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167806.html",
        "sha256": "4bc953e3ba511c0461a8d709c2bb9b32fc576d2ec447401fa6678c1a2872779b",
        "locator": "第04章 天气情况；占雪；文字稿第17行",
        "quote": "占雪、专看天心、天柱二星。"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167806.html",
        "sha256": "4bc953e3ba511c0461a8d709c2bb9b32fc576d2ec447401fa6678c1a2872779b",
        "locator": "第04章 天气情况；占风；文字稿第19行",
        "quote": "占风、专看天辅星落何宫"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167806.html",
        "sha256": "4bc953e3ba511c0461a8d709c2bb9b32fc576d2ec447401fa6678c1a2872779b",
        "locator": "第04章 天气情况；河水；文字稿第20行",
        "quote": "占河水消长，专看天蓬、休门为用神。"
      }
    ],
    "limitations": [
      "仅核对原文指定对象及原盘位置；不推断降水、风力、洪水或适宜出行日期",
      "并列对象共同保留，不按首项、落宫或旺衰替换",
      "只读原盘，不重起局；转录实例有日期勘误，未用其应验叙述证明预测有效"
    ]
  },
  "qimen-xdyy-dwelling-selection-v1": {
    "id": "qimen-xdyy-dwelling-selection-v1",
    "version": "1",
    "title": "奇门遁甲现代应用技术：住宅专门对象",
    "editionStatus": "electronic-transcription-not-print-collated",
    "scope": "明确住宅及设施角色的原盘参考对象；不判现实房屋位置、宅运或安全",
    "references": [
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167799.html",
        "sha256": "46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc",
        "locator": "第10章；住宅自身条件；文字稿第96–97行",
        "quote": "时干、生门所落宫位是否得令。"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167799.html",
        "sha256": "46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc",
        "locator": "第10章；住宅大门；文字稿第98行",
        "quote": "值使门代表住宅的大门及在使用住宅期间的各种影响。"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167799.html",
        "sha256": "46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc",
        "locator": "第10章；厨房设施；文字稿第99行",
        "quote": "丙奇代表灶具、燃火，壬水为饮用自来水，辛为锅碗瓢盆"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167799.html",
        "sha256": "46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc",
        "locator": "第10章；院落、天井；文字稿第101行",
        "quote": "九天、天芮星代表院落，己代表天井"
      },
      {
        "url": "https://www.aqioo.com/qmdjxdyyjs/167799.html",
        "sha256": "46a78f7549a6c48255d20909904990bb4844eecafc04a978361d7fbcdf0108fc",
        "locator": "第10章；住宅房间；文字稿第102行",
        "quote": "六合为客厅所在之宫，大多为客厅的位置。"
      }
    ],
    "limitations": [
      "原文角色对应不是实际房间方位或房屋吉凶的证据",
      "干的盘层未由该取用句唯一限定，地盘、寄地盘、天盘及寄天盘分列，不选首项",
      "住宅大门只取本盘值使门；日干和年命及大环境总裁定、移宫法、阴宅未实现",
      "只读原盘；不由此推断健康、灾害、财运或购房决策"
    ]
  }
}
"""#
}
