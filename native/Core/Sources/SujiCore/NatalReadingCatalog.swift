import Foundation

/// Versioned, bundled copy: no repository file or network is needed to read an existing report.
/// Quotations were checked against ziwei-symbol-sources.json (retrieved 2026-09-23).
/// This catalog supplies definitions and structural reading, never personality/event adjudication.
enum NatalReadingCatalog {
    typealias Entry = NatalReadingReport.Entry
    typealias Source = NatalReadingReport.Source
    static let baziBoundary = "这页帮助你读懂四柱中的位置与关系。性格、事业与关系的综合解读仍待补充；十神名称和数量本身不代表人生结果。"
    static let ziweiBoundary = "这页帮助你读懂十二宫与星曜的联系。性格、事业与关系的综合解读仍待补充；传统象义需结合全盘条件理解。"
    static let baziRule = Source(id: "bazi-relations-v1", title: "十神与藏干的计算口径", locator: "BaziEngine.computeShiShen / CANG_GAN", note: "相对日干的五行与阴阳关系。藏干权重为工程约定，不是实测力量。", url: nil)
    static let baziText = Source(id: "yuanhai-shishen-v1", title: "《渊海子平》十神诸论", locator: "论伤官、论食神、论正财、正官论、论七杀、论印绶、论劫财", note: "Wikisource电子转录未与纸本逐字校勘；仅作术语解释，不抽取条件判词作人格结论。", url: "https://zh.wikisource.org/wiki/淵海子平")
    static let baziPosition = Source(id: "ziping-gongfen-v1", title: "《子平真诠评注》论宫分用神配六亲", locator: "第二十三章：‘非可刻舟求剑，以为论定’‘更须察其宫分地位，以及喜忌’", note: "电子PDF转录未校勘，原文与评注交错。这里仅据此保留位置与整体条件，不统一不同流派六亲配法。", url: nil)
    static let ziweiStructure = Source(id: "ziwei-palace-structure-v1", title: "十二宫与对宫、三方参照", locator: "《紫微斗数全书》卷二·安十二宫例；SUJI ziwei/context.ts", note: "十二宫为传统话题分类；关联位置由本宫地支位移4、8、6取得。对宫只作参照，星曜不迁入本宫。电子转录未校勘。", url: "https://zh.wikisource.org/zh-hans/紫微斗數全書/卷二")
    static let ziweiTransform = Source(id: "ziwei-natal-transform-v1", title: "生年四化：所选十干表", locator: "iztro 2.5.8 默认 mutagen；SUJI transformations.ts", note: "仅生年干四化。壬年采用左辅化科，所读《全书》电子本为天府化科，保留异文；不同于宫干飞化或流年四化。", url: "https://unpkg.com/iztro@2.5.8/lib/data/heavenlyStems.js")
    static let palaceOrder = ["命宫","兄弟宫","夫妻宫","子女宫","财帛宫","疾厄宫","迁移宫","仆役宫","官禄宫","田宅宫","福德宫","父母宫"]
    static let palaceTopics: [String: String] = [
        "命宫":"命盘阅读的起点与自我处事这一传统话题", "兄弟宫":"同辈与兄弟关系这一传统话题", "夫妻宫":"伴侣与相处关系这一传统话题",
        "子女宫":"子女关系这一传统话题", "财帛宫":"财物收支这一传统话题", "疾厄宫":"身体疾患这一传统话题",
        "迁移宫":"外出及外部环境这一传统话题", "仆役宫":"交往与协作关系这一传统话题", "官禄宫":"事务与职务这一传统话题",
        "田宅宫":"居住与田宅这一传统话题", "福德宫":"福享与精神生活这一传统话题", "父母宫":"长辈关系这一传统话题"
    ]
    // Each quote is lexical attribution, not a claim that the person has the attributed trait.
    static let starSymbols: [String: (quote: String, gloss: String)] = [
        "紫微": ("为众星之枢纽", "原典以枢纽说明它在星系中的统摄角色"),
        "天机": ("有灵机应变之志", "这是原典赋予星曜的机变意象，不能据此认定人的应变能力"),
        "太阳": ("乃官禄之枢机", "官禄是星的传统角色称谓，不表示太阳此盘必在官禄宫"),
        "武曲": ("在数司财", "司财是财物相关的传统角色，不是个人财富数量"),
        "天同": ("化福最喜遇吉曜", "原句的福义带有‘遇吉曜’条件，本条没有据此裁定得福"),
        "廉贞": ("在数司权令", "权令是传统角色意象，不代表已经取得职位或权力"),
        "天府": ("天府为禄库", "禄库是蓄藏的传统意象，不是现实资产或储蓄结论"),
        "太阴": ("为田宅主", "田宅主是传统角色称谓，与实际落宫分开"),
        "贪狼": ("化气为桃花", "桃花是原典术语，本条不据此断感情经历或道德品性"),
        "巨门": ("化气为暗", "暗是原典象义，本条不把它转为人的阴暗性格"),
        "天相": ("化气曰印", "印是星的传统象义，不能混作八字正印或生年四化"),
        "天梁": ("化气为荫", "荫是传统庇荫意象，不代表现实中必得他人帮助"),
        "七杀": ("乃斗中之上将", "上将是原典角色比喻，不是职业建议或性格标签"),
        "破军": ("在数为耗星", "耗是传统术语，不据此判财产损失，也不直接改写为改革能力")
    ]
    static func starSource(_ name: String) -> Source {
        Source(id: "ziwei-symbol-\(name)-v1", title: "《紫微斗数全书》卷一", locator: "诸星问答论·\(name)；‘\(starSymbols[name]!.quote)’", note: "2026-09-23核对简体电子页；未与纸本校勘。摘录只支持词义，条件断语、疾病与贬损表述不作为用户结论。", url: "https://zh.wikisource.org/zh-hans/紫微斗數全書/卷一")
    }
    static let relationDefinitions: [String: String] = [
        "比肩":"与日干同五行、同阴阳的‘同我’关系", "劫财":"与日干同五行、异阴阳的‘同我’关系",
        "食神":"日干所生、同阴阳的‘我生’关系", "伤官":"日干所生、异阴阳的‘我生’关系",
        "偏财":"日干所克、同阴阳的‘我克’关系", "正财":"日干所克、异阴阳的‘我克’关系",
        "七杀":"克制日干、同阴阳的‘克我’关系", "正官":"克制日干、异阴阳的‘克我’关系",
        "偏印":"生助日干、同阴阳的‘生我’关系", "正印":"生助日干、异阴阳的‘生我’关系"
    ]
    static let pillarKeys = ["year","month","day","hour"]
    static let pillarLabels = ["年","月","日","时"]
    static let positionReading = [
        "年柱位于四柱起首。这里先辨年干与年支各自的关系，不把柱位直接替换成家世或童年结论。",
        "月柱要把月干与月支分开阅读：月支还是节令的定位点，月干出现某十神并不自动确定月令格局。",
        "日干是全盘十神的参照，日支则仍须逐个读其藏干；日支关系不等于伴侣的性格或处境。",
        "时柱由出生时刻定位，需结合记录精度阅读；这里的十神不直接等于子女状况或晚年结果。"
    ]
    struct Occurrence { let gan, relation, location, pointer: String; let exposed: Bool }
    static func bazi(_ chart: NatalReadingInput, _ e: NatalReadingEvidence) throws -> [Entry] {
        let b = chart.mingPan, day = b.riZhu.gan
        var entries = [Entry(id: "day.reference", title: "先找到日干这个参照点", summary: "日干\(day)，属\(b.riZhu.yinYang)\(b.riZhu.wuXing)。",
            explanation: "所有十神都以日干\(day)为参照，比较其他天干与它的五行生克、阴阳同异。同一个天干换一个日干，关系名称就可能改变。日干本身只作为参照，不另计一处比肩；日支里所藏的天干则分别与它比较。",
            boundary: "日干是理解十神关系的起点，单凭这一项还不能说明一个人的性格。", reflection: nil,
            evidence: try e.at("/mingPan/riZhu/gan", "/mingPan/riZhu/wuXing", "/mingPan/riZhu/yinYang", "/mingPan/siZhu/day/shiShen"), sources: [baziRule])]
        var occurrences: [Occurrence] = []
        for (i,p) in b.siZhu.all.enumerated() {
            let key = pillarKeys[i], label = pillarLabels[i], base = "/mingPan/siZhu/\(key)"
            if i != 2 {
                let other = b.siZhu.all.enumerated().filter { $0.offset != 2 && $0.offset != i && $0.element.ganZhi.gan == p.ganZhi.gan }.map { "\(pillarLabels[$0.offset])干" }
                let hidden = b.siZhu.all.enumerated().filter { $0.element.cangGan.contains { $0.gan == p.ganZhi.gan } }.map { "\(pillarLabels[$0.offset])支\($0.element.ganZhi.zhi)" }
                var structure = hidden.isEmpty ? "四支藏干中没有同一个\(p.ganZhi.gan)干；这里只记录透干位置，不能据此断其有力或无力。" : "同一个\(p.ganZhi.gan)还见于\(hidden.joined(separator: "、"))的藏干，形成透干与支藏相互对照的位置；这不等于已经裁定得根强弱。"
                if !other.isEmpty { structure += "另有\(other.joined(separator: "、"))同干透出，须保留各柱位置，不合并成一项人格特征。" }
                entries.append(Entry(id: "stem.\(key)", title: "\(label)干\(p.ganZhi.gan) · \(p.shiShen)", summary: "\(p.ganZhi.gan)透在\(label)干，相对\(day)为\(p.shiShen)。",
                    explanation: "\(p.shiShen)是\(relationDefinitions[p.shiShen]!)。\(positionReading[i])\(structure)",
                    boundary: "透干表示写在天干层，不等于更外向、更明显的人格表现；需要全盘条件才能再谈格局与作用。", reflection: nil,
                    evidence: try e.at([base + "/ganZhi/gan",base + "/shiShen"] + pillarKeys.map { "/mingPan/siZhu/\($0)/cangGan" } + pillarKeys.filter { $0 != "day" }.map { "/mingPan/siZhu/\($0)/ganZhi/gan" }), sources: [baziRule,baziText,baziPosition]))
                occurrences.append(.init(gan: p.ganZhi.gan, relation: p.shiShen, location: "\(label)干\(p.ganZhi.gan)", pointer: base + "/shiShen", exposed: true))
            }
            for (j,h) in p.cangGan.enumerated() {
                let layer = j == 0 ? "本气" : "其余藏干第\(j)项"
                let exposed = b.siZhu.all.enumerated().filter { $0.offset != 2 && $0.element.ganZhi.gan == h.gan }.map { "\(pillarLabels[$0.offset])干" }
                let presence = exposed.isEmpty ? "\(h.gan)没有在年、月、时干透出；本条只说支内有这层关系，不能把藏干写成透干。" : "\(h.gan)同时透在\(exposed.joined(separator: "、"))，阅读时可把这些位置互相对照，但不能将重复出现当作力量加分。"
                let multiplicity = p.cangGan.count == 1 ? "\(p.ganZhi.zhi)支在所选藏干表中只有\(h.gan)一项。" : "\(p.ganZhi.zhi)支含\(p.cangGan.map { "\($0.gan)（\($0.shiShen)）" }.joined(separator: "、"))，本条只读其中\(h.gan)，不能用本气替代整支。"
                entries.append(Entry(id: "hidden.\(key).\(j)", title: "\(label)支\(p.ganZhi.zhi)藏\(h.gan) · \(h.shiShen)", summary: "\(layer)\(h.gan)，相对\(day)为\(h.shiShen)。",
                    explanation: "\(h.shiShen)是\(relationDefinitions[h.shiShen]!)。\(multiplicity)\(presence)\(positionReading[i])",
                    boundary: "本气与其余藏干按当前表的顺序列出，尚未由此判定作用强弱。具体权重可在计算字段中核对。", reflection: nil,
                    evidence: try e.at([base + "/ganZhi/zhi",base + "/cangGan/\(j)",base + "/cangGan"] + pillarKeys.filter { $0 != "day" }.map { "/mingPan/siZhu/\($0)/ganZhi/gan" }), sources: [baziRule,baziText,baziPosition]))
                occurrences.append(.init(gan: h.gan, relation: h.shiShen, location: "\(label)支\(p.ganZhi.zhi)藏\(h.gan)", pointer: base + "/cangGan/\(j)/shiShen", exposed: false))
            }
        }
        let groups: [(String,String,[String],String)] = [
            ("peer","比劫：同类关系",["比肩","劫财"],"在协作时，你如何分配共同承担与个人负责的部分？"),
            ("output","食伤：输出关系",["食神","伤官"],"表达想法时，你更习惯先说出来，还是先做成可展示的结果？"),
            ("wealth","财：所克关系",["偏财","正财"],"处理资源时，你通常先核对哪些约束和实际需要？"),
            ("authority","官杀：克我关系",["七杀","正官"],"面对规则和要求时，你会怎样区分可协商与必须遵守的部分？"),
            ("resource","印：生我关系",["偏印","正印"],"遇到新知识时，哪些具体帮助能让你理解得更清楚？")
        ]
        for (id,title,names,question) in groups {
            let selected = occurrences.filter { names.contains($0.relation) }
            let exposed = selected.filter(\.exposed), hidden = selected.filter { !$0.exposed }
            let positions = selected.map { "\($0.location)为\($0.relation)" }.joined(separator: "；")
            let structure: String
            if selected.isEmpty { structure = "年、月、时干及四支藏干没有这一组关系。这里的‘未见’是字段范围内的结果，不能转成缺乏某种能力、关系或人生资源；日干的自我对照没有额外计入。" }
            else if exposed.isEmpty { structure = "这组关系只在支藏层出现。先看各自藏在哪个支、是否与同支其他关系并列，不能把它写成天干透出的组合。藏而不透也不是现实能力被隐藏的测量结果。" }
            else if hidden.isEmpty { structure = "这组关系只见于天干层，在所选四支藏干表中没有同组条目。可定位透出在哪一柱，但仅凭这个分布不能推出无根、力量弱或一种固定人格。" }
            else { structure = "这组关系跨天干与支藏两层出现：透出位置为\(exposed.map(\.location).joined(separator: "、"))；支藏位置为\(hidden.map(\.location).joined(separator: "、"))。先保留这些不同位置，再对照各干是否相同；同组名称并不自动构成相生、制化或格局。" }
            let both = names.allSatisfy { n in selected.contains { $0.relation == n } } ? "本盘\(names.joined(separator: "与"))均有出现，只表示两种阴阳关系并见，不据此裁定混杂、好坏或成功条件。" : ""
            entries.append(Entry(id: "group.\(id)", title: title, summary: selected.isEmpty ? "当前天干与藏干范围内未见这一组。" : positions,
                explanation: structure + both, boundary: "以下是现代编辑的自我观察问题，供你结合真实经历思考；并非古籍判词或已经测得的性格。", reflection: question,
                evidence: try e.at(pillarKeys.map { "/mingPan/siZhu/\($0)" }), sources: [baziRule,baziText,baziPosition]))
        }
        return entries
    }
    static func ziwei(_ chart: NatalReadingInput, _ e: NatalReadingEvidence) throws -> [Entry] {
        let z = chart.ziweiPan
        var entries = [Entry(id: "palace-reference", title: "命宫与身宫分开定位", summary: "命宫\(z.mingGongPosition)，身宫\(z.shenGongPosition)。",
            explanation: z.mingGongPosition == z.shenGongPosition ? "命宫与身宫标记落在同一地支位置。命宫是十二宫排列的阅读起点，身宫是另一项安身标记；同处一宫不代表两份星曜，也不能因此把该宫力量加倍。后面的宫位条目只列一次实际驻星。" : "命宫与身宫标记位于不同地支。命宫提供十二宫阅读起点，身宫标在另一宫位上；它不是第十三宫，不会另添一套主星。可分别查看这两个位置的实际星曜，避免只读命宫就把其余结构省略。",
            boundary: "命身位置是所选流派的排盘结果，不据此推出人生前后半程或处事性格。", reflection: nil,
            evidence: try e.at("/ziweiPan/mingGongPosition","/ziweiPan/shenGongPosition","/ziweiPan/method"), sources: [ziweiStructure])]
        for name in palaceOrder {
            let i = z.palaces.firstIndex { $0.name == name }!, p = z.palaces[i], base = "/ziweiPan/palaces/\(i)"
            let position = NatalReadingInput.branches.firstIndex(of: p.position)!
            let relatedIndices = [4,8,6].map { offset in z.palaces.firstIndex { $0.position == NatalReadingInput.branches[(position+offset)%12] }! }
            let opposite = z.palaces[relatedIndices[2]]
            let oppositeNames = opposite.mainStars.isEmpty ? "也没有十四主星" : "列有" + opposite.mainStars.map(\.name).joined(separator: "、")
            let main = p.mainStars.map(\.name).joined(separator: "、")
            let unknown = p.mainStars.filter { starSymbols[$0.name] == nil }.map(\.name)
            let structure: String
            if !unknown.isEmpty {
                structure = "本宫主星字段含未收录项\(unknown.joined(separator: "、"))，本版保留原字段但不判定空宫、单星或同宫组合。已识别的十四主星成员各自释义另列，未收录项不加入这套象义解释。"
            } else if p.mainStars.isEmpty {
                structure = "此宫没有十四主星，‘空宫’只指这一层；本宫另列辅杂曜\(p.minorStars.count)项。对宫是\(opposite.name)\(opposite.position)，\(oppositeNames)，只能作为对照，不能把其星曜移写成本宫驻星。"
            } else if p.mainStars.count == 1 {
                structure = "此宫由\(main)一颗主星定位。单星不等于可以单独判事：还须把本宫辅杂曜与\(opposite.name)\(opposite.position)的对照分开读，再核对会照条件。"
            } else {
                structure = "\(main)在此宫同宫并列。要保留各星不同象义，不能把它们当作多数投票，也不能只挑一颗套人物类型；本宫组合与\(opposite.name)\(opposite.position)的对照是不同层次。"
            }
            let definitions = p.mainStars.map { star in
                if let symbol = starSymbols[star.name] { return "\(star.name)原称‘\(symbol.quote)’，\(symbol.gloss)。" }
                return "\(star.name)保留实际字段；当前内容库未审定该星象义，暂不解读。"
            }.joined()
            let brightness = p.mainStars.map { "\($0.name)\($0.brightness!)" }.joined(separator: "、")
            let trines = relatedIndices.prefix(2).map { "\(z.palaces[$0].name)\(z.palaces[$0].position)" }.joined(separator: "、")
            let reading = "\(name)在传统分类中讨论\(palaceTopics[name]!)。\(structure)\(definitions)" + (brightness.isEmpty ? "" : "当前亮度记为\(brightness)，这是所选表的标签。") + "本宫三方另见\(trines)，这些是参照位置，尚未作会照吉凶裁定。"
            let boundary: String
            switch name {
            case "疾厄宫": boundary = "只读位置与象义；不能据此诊断疾病、推寿命或替代医疗检查。"
            case "夫妻宫": boundary = "只读位置与象义；不能据此判断配偶性格、婚姻好坏或相处概率。"
            case "子女宫": boundary = "只读位置与象义；不能据此预测生育能力、子女数量或子女健康。"
            case "财帛宫": boundary = "司财、禄库等是传统角色名称；不能据此估计资产、投资回报或发财机会。"
            case "官禄宫": boundary = "星的权令、上将等意象不等于真实职务，也不足以推荐职业或预测晋升。"
            default: boundary = "宫位话题、星的传统角色、实际落宫分开阅读；庙旺不保证成功，同宫或会照仍有未裁定条件。"
            }
            let summary = !unknown.isEmpty ? "主星字段含未收录项；原字段为\(main)。" : p.mainStars.isEmpty ? "本宫没有十四主星；对宫参照另列。" : "本宫主星：\(main)" + (p.isShenGong ? "；身宫也在此处。" : "。")
            entries.append(Entry(id: "palace.\(name)", title: "\(name) · \(p.position)", summary: summary,
                explanation: reading, boundary: boundary + "辅杂曜保留原字段，本版未逐星解读。", reflection: nil,
                evidence: try e.at([base + "/name",base + "/position",base + "/mainStars",base + "/minorStars",base + "/isShenGong"] + relatedIndices.map { "/ziweiPan/palaces/\($0)" }),
                sources: [ziweiStructure] + p.mainStars.compactMap { starSymbols[$0.name] == nil ? nil : starSource($0.name) }))
        }
        var facts: [String] = [], paths = ["/ziweiPan/natalYear", "/ziweiPan/method"]
        for (i,p) in z.palaces.enumerated() {
            for (group,stars) in [("mainStars",p.mainStars),("minorStars",p.minorStars)] {
                for (j,s) in stars.enumerated() where !(s.sihua ?? []).isEmpty {
                    facts.append("\(s.name)\(s.sihua!.joined(separator: "、"))在\(p.name)\(p.position)")
                    paths += ["/ziweiPan/palaces/\(i)/\(group)/\(j)","/ziweiPan/palaces/\(i)/name","/ziweiPan/palaces/\(i)/position"]
                }
            }
        }
        entries.append(Entry(id: "natal-transformations", title: "生年四化 · 来源干\(z.natalYear.stem)", summary: facts.joined(separator: "；"),
            explanation: "这里以紫微所选农历年\(z.natalYear.ganZhi)的年干\(z.natalYear.stem)查默认十干表，再把四化标签定位到已经驻宫的星。四化没有把星移到另一宫。某星原典的‘化气为印、荫、耗’属于词义，和这里的化禄、化权、化科、化忌不是同一字段；宫干飞化和流年四化也未混入。",
            boundary: "生年忌不等于事件必坏，禄权科也不是成功保证；这里只确认四化来源与落点。", reflection: "阅读这些传统标签时，你是否能把符号名称与自己的实际经历分别记录？",
            evidence: try e.at(paths), sources: [ziweiTransform]))
        return entries
    }
    static func number(_ value: Double) -> String { String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value) }
}
