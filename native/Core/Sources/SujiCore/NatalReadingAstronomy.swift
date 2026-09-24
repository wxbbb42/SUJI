import Foundation

extension NatalReadingCompiler {
    public static func astronomy(dossier: NatalAstronomyDossier, ownerID: String, birth: BirthProfile, engineRevision: String, enginePayloadRevision: String) throws -> [NatalReadingReport] {
        guard dossier.matches(ownerID: ownerID, birth: birth, engineRevision: engineRevision, enginePayloadRevision: enginePayloadRevision) else { throw EngineContract.Failure.invalid }
        do {
            let payload = try NatalAstronomyPayload.validated(dossier.payload)
            let e = try NatalReadingEvidence(dossier.payload)
            return try NatalReadingAstronomy.reports(payload, e, ownerID: ownerID, birth: birth, engineRevision: engineRevision)
        } catch { throw EngineContract.Failure.invalid }
    }
}

private enum NatalReadingAstronomy {
    typealias Entry = NatalReadingReport.Entry
    typealias Source = NatalReadingReport.Source
    struct Mansion: Decodable {
        let body, mansion, boundaryStatus: String
        let index: Int
        let entryDegrees, widthDegrees, distanceToBoundaryDegrees: Double
    }
    struct Mansions: Decodable { let methodVersion: String; let positions: [Mansion] }
    static let bodies = ["Sun":"太阳","Moon":"月亮","Mercury":"水星","Venus":"金星","Mars":"火星","Jupiter":"木星","Saturn":"土星","Rahu":"罗睺","Ketu":"计都","Apogee":"月孛","PurpleQi":"紫气"]
    static let ephemeris = Source(id: "astronomy-engine-2.1.19", title: "Astronomy Engine 2.1.19", locator: "地心七曜；true-ecliptic-equator-of-date-v1", note: "使用当日真黄道、真赤道坐标及模块所列改正策略；显示小数不是误差上界。", url: "https://github.com/cosinekitty/astronomy")
    static let mansionSource = Source(id: "contemporary-first-star28-equatorial-v1", title: "中国二十八宿·现代距星赤经分段", locator: "Stellarium contemporary-first-stars 71885f2e；Hipparcos ESA 1997；SIMBAD 2026-09-20", note: "将28颗所选距星转换到出生时刻赤道坐标，以赤经左闭右开分段；不是历史宿度复原或农历宿曜。", url: "https://github.com/Stellarium/stellarium-skycultures")
    static let residualSource = Source(id: "mean-lunar-moira-purple-v1", title: "四余的所选约定", locator: "IERS 2003 / Simon 1994 平均月球要素；AA1996倾角；Moira purple 7474e5f", note: "罗睺为平均升交点、计都为平均降交点，月孛为平均远地点；紫气使用1975-03-13T16:00Z、230.5°、10227.1792日的周期参数。均不等于四颗实体天体。", url: "https://iers-conventions.obspm.fr/content/chapter5/icc5.pdf")
    static let lifeSource = Source(id: "mao-hour-tropical-solar-degree-v1", title: "遇卯安命与现代坐标约定", locator: "《古今图书集成》博物汇编艺术典第567卷；SUJI lifeDegree.ts", note: "时支安命、等分30°回归黄道宫、命度转现代距星赤经宿；宫主按宫支，度主按命度所在宿取。现代坐标约定不冒称历史实测宿度。", url: "https://zh.wikisource.org/wiki/欽定古今圖書集成/博物彙編/藝術典/第567卷")
    static let timeSource = Source(id: "astronomy-time-policy-v1", title: "出生时刻口径", locator: "固定UTC+08:00；UTC代UT1；Espenak–Meeus ΔT", note: "该版本将输入解释为北京时间；记录精度未知，没有声称到秒的出生时间准确度。", url: nil)
    static func number(_ value: Double) -> String { NatalReadingCatalog.number(value) }
    static func reports(_ p: NatalAstronomyPayload, _ e: NatalReadingEvidence, ownerID: String, birth: BirthProfile, engineRevision: String) throws -> [NatalReadingReport] {
        let m = try JSONDecoder().decode(Mansions.self, from: JSONEncoder().encode(p.mansions))
        guard let moonIndex = m.positions.firstIndex(where: { $0.body == "Moon" }) else { throw EngineContract.Failure.invalid }
        let moon = m.positions[moonIndex], moonPath = "/mansions/positions/\(moonIndex)"
        let bodyIndex = p.sevenBodies.positions.firstIndex { $0.body == "Moon" }!
        let body = p.sevenBodies.positions[bodyIndex]
        let mansionEntries = [
            Entry(id: "moon.mansion", title: "出生月亮的参照宿", summary: "月亮落在\(moon.mansion)宿，入宿\(number(moon.entryDegrees))°；出生时刻的月亮赤经为\(number(body.rightAscensionDegrees))°。",
                  explanation: "这份结果先求出生时刻月亮的地心位置，再把赤经放入28颗所选距星划出的区间，得到\(moon.mansion)宿。入宿\(number(moon.entryDegrees))°表示从本宿起界向前量的赤经差；本宿宽\(number(moon.widthDegrees))°，并不是每宿等宽，也不是月亮的黄经宫内度。",
                  boundary: "这是出生月亮的天文参照宿，不是择日值日宿、农历本命宿、宿曜配对或人格测量。", reflection: nil,
                  evidence: try e.at(moonPath,"/sevenBodies/positions/\(bodyIndex)","/mansions/boundaries/\(moon.index)"), sources: [ephemeris,mansionSource]),
            Entry(id: "moon.boundary", title: "宿界与出生时间精度", summary: "月亮距最近宿界\(number(moon.distanceToBoundaryDegrees))°；记录精度标记为未知。",
                  explanation: "当前月亮位于\(moon.mansion)宿区间内，距两侧宿界中较近的一侧为\(number(moon.distanceToBoundaryDegrees))°。出生时间变化会改变月亮赤经，距星边界也按出生时刻转换。现有数据没有出生记录的误差范围，因此不能由这个角距直接换算为‘宿名一定稳定’或精确的安全分钟数。",
                  boundary: "小数位数不等于实际观测精度；不把未知时间精度默认为准确。若需要校时，应回到出生资料与实际记录。", reflection: nil,
                  evidence: try e.at(moonPath + "/distanceToBoundaryDegrees",moonPath + "/boundaryStatus","/mansions/uncertainty","/time"), sources: [mansionSource,timeSource]),
            Entry(id: "mansion.method", title: "为什么与其他星宿表可能不同", summary: "方法：现代距星、赤经分段；时刻按北京时间解释。",
                  explanation: "这套方法把距星目录、坐标转换和区间边界版本分别固定。按农历日期查宿、按日轮值的值日宿，以及历史距星选择都可能采用其他口径，不能只凭同一个‘宿’字互换结果。太阳与其余天体也有各自入宿字段，可在专业档案查看，月亮条目没有代替它们。",
                  boundary: "本报告没有采用宿曜关系法，不生成荣亲、安坏、危成等配对关系。", reflection: nil,
                  evidence: try e.at("/mansions/methodVersion","/mansions/sourceIDs","/mansions/dependencyVersions","/time/interpretation"), sources: [mansionSource,timeSource])
        ]
        var qizhengEntries: [Entry] = []
        let l = p.lifeDegree
        let palaceRuler = bodies[l.palaceRuler]!, degreeRuler = bodies[l.degreeRuler]!
        qizhengEntries.append(Entry(id: "life.rulers", title: "安命 → 宫主 → 命度 → 度主", summary: "命宫在\(l.palaceBranch)，宫主\(palaceRuler)；命度入\(l.mansion.mansion)宿，度主\(degreeRuler)。",
            explanation: "此法由太阳所在\(l.sunPalaceBranch)宫与出生\(l.birthHourBranch)时安命，得命宫\(l.palaceBranch)，沿用太阳宫内\(number(l.palaceDegree))°作为命度。宫主\(palaceRuler)由命宫地支映射；命度转成赤经后落入\(l.mansion.mansion)宿，度主\(degreeRuler)由该宿的七曜归属映射。" + (l.palaceRuler == l.degreeRuler ? "两条路径这次同归一曜，仍是两个不同的定位步骤。" : "两条路径得出不同星名并不矛盾，分别回答宫支与入宿的归属。"),
            boundary: "安命是所选规则的计算点，不是实体天体。宫主、度主不直接等同恩星、用星、财星或难星；此处没有判强弱吉凶。", reflection: nil,
            evidence: try e.at("/lifeDegree/palaceBranch","/lifeDegree/palaceRuler","/lifeDegree/palaceDegree","/lifeDegree/degreeRuler","/lifeDegree/mansion","/lifeDegree/sunPalaceBranch","/lifeDegree/birthHourBranch","/lifeDegree/methodVersion"), sources: [lifeSource,mansionSource]))
        for (i,position) in p.sevenBodies.positions.enumerated() {
            let mansion = m.positions[i], name = bodies[position.body]!
            guard let house = l.houses.first(where: { house in
                let start = house.startLongitudeDegrees, end = house.endLongitudeDegrees, v = position.longitudeDegrees
                return end > start ? v >= start && v < end : v >= start || v < end
            }) else { throw EngineContract.Failure.invalid }
            let houseIndex = l.houses.firstIndex { $0.name == house.name }!
            let within = position.longitudeDegrees - house.startLongitudeDegrees
            qizhengEntries.append(Entry(id: "body.\(position.body)", title: "\(name) · 七曜", summary: "黄经落\(house.name)\(house.branch)宫内\(number(within))°；赤经入\(mansion.mansion)宿\(number(mansion.entryDegrees))°。",
                explanation: "\(name)的地心黄经为\(number(position.longitudeDegrees))°，在以命宫起排的十二宫中落\(house.name)\(house.branch)。它的赤经为\(number(position.rightAscensionDegrees))°，按距星边界落\(mansion.mansion)宿。前者沿黄道量宫内位置，后者沿赤道量入宿位置，两组角度参照不同，不能把它们的小数直接相减来判强弱。",
                boundary: "这里只解释坐标和落点，没有昼夜、庙旺、相位或事件裁定。宫位名称不构成健康、婚育、财务与职业结论。", reflection: nil,
                evidence: try e.at("/sevenBodies/positions/\(i)","/mansions/positions/\(i)","/lifeDegree/houses/\(houseIndex)"), sources: [ephemeris,mansionSource,lifeSource]))
        }
        let residualDefinitions = [
            "罗睺是所选平均月球轨道与黄道的升交点。它描述轨道相交的几何位置，不是一颗可独立观测的行星。",
            "计都是所选平均月球轨道与黄道的降交点，与本盘罗睺相差180°。两者属于同一组交点约定，不是两颗行星。",
            "月孛是由平均月球要素和固定倾角计算的平均远地点方向。它不是月亮当时的实体位置，也不是瞬时真远地点。",
            "紫气采用固定起点和10227.1792日周期匀速推进。这是约定的符号点，不是天文实测天体；换一套起点或周期会得到另一位置。"
        ]
        for (i,position) in p.fourResiduals.positions.enumerated() {
            let name = bodies[position.body]!
            qizhengEntries.append(Entry(id: "residual.\(position.body)", title: "\(name) · 约定位置", summary: "黄经\(number(position.longitudeDegrees))°；采用\(["平均升交点", "平均降交点", "平均远地点", "约定周期点"][i])口径。",
                explanation: residualDefinitions[i] + "本盘记录的黄经为\(number(position.longitudeDegrees))°。" + (i == 3 ? "其参数以UT时间推进，不能把周期模型的多位小数当成预测精度。" : "此项使用平均黄道坐标与TT时间要素；七曜使用的真黄道坐标及改正策略另列，不能不加区别地并成同一套强弱判断。"),
                boundary: "保留四余的具体定义与坐标口径，不衍生恩用财难仇、余奴或事件好坏。", reflection: nil,
                evidence: try e.at(["/fourResiduals/positions/\(i)","/fourResiduals/methodVersion","/fourResiduals/nodeConvention"] + (i == 3 ? ["/fourResiduals/purpleParameters"] : [])), sources: [residualSource]))
        }
        let metadata = ["/schemaVersion","/engineRevision","/birthKey","/time","/sevenBodies/methodVersion","/mansions/methodVersion","/fourResiduals/methodVersion","/lifeDegree/methodVersion"]
        return [
            try NatalReadingCompiler.report(system: .mansions, title: "出生星宿：月亮参照宿", summary: "出生月亮位于\(moon.mansion)宿。本页解释这一参照宿如何得到，以及出生时间精度带来的边界。", boundary: "覆盖天文月宿与方法说明；不提供宿人格、择日值日宿或宿曜关系。", entries: mansionEntries, evidence: e, ownerID: ownerID, birth: birth, engineRevision: engineRevision, metadata: metadata),
            try NatalReadingCompiler.report(system: .qizheng, title: "七政四余：排盘与安命", summary: "命宫\(l.palaceBranch)，宫主\(palaceRuler)，度主\(degreeRuler)。七曜实体天体与四余约定位置分别阅读。", boundary: "覆盖出生坐标、所选四余及安命链条；完整角色、格局与生活主题尚未审定，不生成成功概率。", entries: qizhengEntries, evidence: e, ownerID: ownerID, birth: birth, engineRevision: engineRevision, metadata: metadata)
        ]
    }
}
