import Foundation
import CryptoKit

public enum NatalReportSystem: String, CaseIterable, Sendable { case bazi, ziwei, mansions, qizheng }

/// A deterministic reading of a current local chart. IDs detect identity changes; they do not authenticate imported data.
public struct NatalReadingReport: Identifiable, Sendable, Equatable {
    public struct Evidence: Sendable, Equatable {
        /// RFC 6901 JSON pointer into the original dossier payload.
        public let pointer: String
        public let value: String
    }
    public struct Source: Identifiable, Sendable, Equatable {
        public let id, title, locator, note: String
        public let url: String?
    }
    public struct Entry: Identifiable, Sendable, Equatable {
        public let id, title, summary, explanation, boundary: String
        /// An editorial question, separate from traditional definitions and chart facts.
        public let reflection: String?
        public let evidence: [Evidence]
        public let sources: [Source]
    }
    public let id: String
    public let system: NatalReportSystem
    public let title, summary, boundary, contentVersion: String
    public let snapshotID, adapterVersion: String
    public let entries: [Entry]
}

public enum NatalReadingCompiler {
    public static let contentVersion = "natal-structure-reading-2026-09-23-v1"
    public static let adapterVersion = "natal-reading-adapter-v1"

    public static func natal(dossier: NatalDossier, ownerID: String, birth: BirthProfile, engineRevision: String) throws -> [NatalReadingReport] {
        guard !ownerID.isEmpty, !engineRevision.isEmpty,
              dossier.matches(ownerID: ownerID, birth: birth, engineRevision: engineRevision) else { throw EngineContract.Failure.invalid }
        do {
            let chart = try JSONDecoder().decode(NatalReadingInput.self, from: dossier.payload)
            try chart.validate(birth: birth)
            let evidence = try NatalReadingEvidence(dossier.payload)
            let entries = [try NatalReadingCatalog.bazi(chart, evidence), try NatalReadingCatalog.ziwei(chart, evidence)]
            let systems: [NatalReportSystem] = [.bazi, .ziwei]
            let titles = ["八字：位置与关系", "紫微：宫位与星曜"]
            let b = chart.mingPan, z = chart.ziweiPan
            let summaries = [
                "以\(b.riZhu.gan)\(b.riZhu.wuXing)日干为参照，四柱为\(b.siZhu.all.map { $0.ganZhi.gan + $0.ganZhi.zhi }.joined(separator: "、"))。先分清天干与支藏，再看同类关系落在哪些位置。",
                "命宫在\(z.mingGongPosition)，身宫在\(z.shenGongPosition)。从命宫开始读十二宫的实际星曜；空宫、同宫与生年四化分别说明。"
            ]
            return try systems.indices.map { i in
                try report(system: systems[i], title: titles[i], summary: summaries[i], boundary: i == 0 ? NatalReadingCatalog.baziBoundary : NatalReadingCatalog.ziweiBoundary,
                           entries: entries[i], evidence: evidence, ownerID: ownerID, birth: birth, engineRevision: engineRevision,
                           metadata: ["/schemaVersion", "/engineRevision", "/birthKey", "/calendarPolicy", "/mingPan/birthDateTime", "/ziweiPan/birthDateTime"])
            }
        } catch { throw EngineContract.Failure.invalid }
    }

    static func report(system: NatalReportSystem, title: String, summary: String, boundary: String, entries: [NatalReadingReport.Entry], evidence: NatalReadingEvidence,
                       ownerID: String, birth: BirthProfile, engineRevision: String, metadata: [String]) throws -> NatalReadingReport {
        // Hash the consumed fact projection, not heuristics/personality, timestamps, or current-day forecasts.
        // The original evidence pointers remain usable against the unchanged original payload.
        let paths = Set(entries.flatMap { $0.evidence.map(\.pointer) } + metadata).sorted()
        let projection = try Dictionary(uniqueKeysWithValues: paths.map { ($0, try evidence.value($0)) })
        let birthObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))
        let bytes = try JSONSerialization.data(withJSONObject: ["facts": projection, "owner": ownerID, "birth": birthObject, "bundleRevision": engineRevision], options: [.sortedKeys, .withoutEscapingSlashes])
        let snapshotID = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return NatalReadingReport(id: "\(snapshotID):\(adapterVersion):\(contentVersion):\(system.rawValue)", system: system, title: title, summary: summary, boundary: boundary,
                                  contentVersion: contentVersion, snapshotID: snapshotID, adapterVersion: adapterVersion, entries: entries)
    }
}

/// Strict access only: missing data never becomes an empty string, zero coordinate, or empty palace.
struct NatalReadingEvidence {
    let root: Any
    init(_ data: Data) throws { root = try JSONSerialization.jsonObject(with: data) }
    func value(_ pointer: String) throws -> Any {
        guard pointer.hasPrefix("/") else { throw EngineContract.Failure.invalid }
        var current = root
        for raw in pointer.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            let key = raw.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
            if let object = current as? [String: Any], let next = object[key] { current = next }
            else if let array = current as? [Any], let index = Int(key), array.indices.contains(index) { current = array[index] }
            else { throw EngineContract.Failure.invalid }
        }
        return current
    }
    func at(_ pointers: String...) throws -> [NatalReadingReport.Evidence] { try at(pointers) }
    func at(_ pointers: [String]) throws -> [NatalReadingReport.Evidence] {
        try pointers.map { pointer in
            let raw = try value(pointer)
            let text: String
            if let string = raw as? String { text = string }
            else { text = String(decoding: try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes]), as: UTF8.self) }
            return .init(pointer: pointer, value: text)
        }
    }
}

struct NatalReadingInput: Decodable {
    struct Stem: Decodable { let gan, wuXing, yinYang: String }
    struct GanZhi: Decodable { let gan, zhi, ganWuXing, ganYinYang, zhiWuXing, zhiYinYang: String }
    struct Hidden: Decodable { let gan, wuXing, shiShen: String; let weight: Double }
    struct Pillar: Decodable { let ganZhi: GanZhi; let shiShen: String; let cangGan: [Hidden] }
    struct Pillars: Decodable {
        let year, month, day, hour: Pillar
        var all: [Pillar] { [year, month, day, hour] }
    }
    struct Policy: Decodable {
        let version, provider, timezone, yearBoundary, monthBoundary, dayBoundary, lunarDayBoundary, solarTimeScope, yun: String
        let supportedCivilYears: [Int]
        func validate() throws {
            guard version == "suji-calendar-2", provider == "lunar-javascript@1.7.7", timezone == "UTC+08:00", yearBoundary == "exact-lichun",
                  monthBoundary == "exact-jie", dayBoundary == "zi-hour-23:00", lunarDayBoundary == "civil-midnight", solarTimeScope == "day-and-hour-only",
                  yun == "year-polarity-gender; jie; three-days-per-year; sect-2-minute-conversion", supportedCivilYears == [1901,2100] else { throw EngineContract.Failure.invalid }
        }
    }
    struct Calculation: Decodable {
        let civilBirthTime, effectiveSolarTime: String
        let solarTimeApplied: Bool
        let longitude: Double
        let policy: Policy
        private enum CodingKeys: String, CodingKey { case civilBirthTime, effectiveSolarTime, solarTimeApplied, longitude }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            civilBirthTime = try c.decode(String.self, forKey: .civilBirthTime)
            effectiveSolarTime = try c.decode(String.self, forKey: .effectiveSolarTime)
            solarTimeApplied = try c.decode(Bool.self, forKey: .solarTimeApplied)
            longitude = try c.decode(Double.self, forKey: .longitude)
            policy = try Policy(from: decoder)
        }
    }
    struct Bazi: Decodable {
        let birthDateTime, gender: String; let riZhu: Stem; let siZhu: Pillars; let calculationPolicy: Calculation
    }
    struct Star: Decodable { let name, type, source: String; let brightness: String?; let sihua: [String]? }
    struct Palace: Decodable { let name, position, ganZhi: String; let isShenGong: Bool; let mainStars, minorStars: [Star] }
    struct NatalYear: Decodable { let lunarYear: Int; let stem, branch, ganZhi: String }
    struct Method: Decodable { let algorithm, dayBoundary, leapMonth, yearBoundary, calculationDate, civilTimeZone: String }
    struct Ziwei: Decodable {
        let birthDateTime, gender, mingGongPosition, shenGongPosition, fiveElementsClass: String
        let palaces: [Palace]; let natalYear: NatalYear; let method: Method
    }
    private struct BirthKey: Decodable {
        let year, month, day, hour, minute: Int
        let gender: String
        let longitude: Double
        let timeZoneID: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            year = try c.decode(Int.self); month = try c.decode(Int.self); day = try c.decode(Int.self)
            hour = try c.decode(Int.self); minute = try c.decode(Int.self); gender = try c.decode(String.self)
            longitude = try c.decode(Double.self); timeZoneID = try c.decode(String.self)
            guard c.isAtEnd else { throw EngineContract.Failure.invalid }
        }
        func matches(_ b: BirthProfile) -> Bool {
            year == b.year && month == b.month && day == b.day && hour == b.hour && minute == b.minute && gender == b.gender && longitude == b.longitude && timeZoneID == b.timeZoneID
        }
    }
    let schemaVersion: Int
    let engineRevision, birthKey: String
    let calendarPolicy: Policy
    let mingPan: Bazi
    let ziweiPan: Ziwei
    static let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    static let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    static let elements = Array("木火土金水").map(String.init)
    static let hidden: [String: [(String, Double)]] = [
        "子": [("癸",1)], "丑": [("己",0.6),("癸",0.2),("辛",0.2)], "寅": [("甲",0.6),("丙",0.2),("戊",0.2)], "卯": [("乙",1)],
        "辰": [("戊",0.6),("乙",0.2),("癸",0.2)], "巳": [("丙",0.6),("戊",0.2),("庚",0.2)], "午": [("丁",0.7),("己",0.3)],
        "未": [("己",0.6),("丁",0.2),("乙",0.2)], "申": [("庚",0.6),("壬",0.2),("戊",0.2)], "酉": [("辛",1)],
        "戌": [("戊",0.6),("辛",0.2),("丁",0.2)], "亥": [("壬",0.7),("甲",0.3)]
    ]
    static let transformations = ["化禄","化权","化科","化忌"]
    static let transformed: [String: [String]] = [
        "甲":["廉贞","破军","武曲","太阳"], "乙":["天机","天梁","紫微","太阴"], "丙":["天同","天机","文昌","廉贞"],
        "丁":["太阴","天同","天机","巨门"], "戊":["贪狼","太阴","右弼","天机"], "己":["武曲","贪狼","天梁","文曲"],
        "庚":["太阳","武曲","太阴","天同"], "辛":["巨门","太阳","文曲","文昌"], "壬":["天梁","紫微","左辅","武曲"], "癸":["破军","巨门","太阴","贪狼"]
    ]
    static func relation(day: String, target: String) throws -> String {
        guard let d = stems.firstIndex(of: day), let t = stems.firstIndex(of: target) else { throw EngineContract.Failure.invalid }
        let distance = (t / 2 - d / 2 + 5) % 5
        return [["比肩","劫财"],["食神","伤官"],["偏财","正财"],["七杀","正官"],["偏印","正印"]][distance][d % 2 == t % 2 ? 0 : 1]
    }
    func validate(birth: BirthProfile) throws {
        try birth.validated(); try calendarPolicy.validate(); try mingPan.calculationPolicy.policy.validate()
        func require(_ value: Bool) throws { if !value { throw EngineContract.Failure.invalid } }
        try require(birthKey.utf8.count <= 256)
        let key = try JSONDecoder().decode(BirthKey.self, from: Data(birthKey.utf8))
        try require(key.matches(birth))
        try require(schemaVersion == 1 && NatalAstronomyDossier.revision(engineRevision))
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedTime = formatter.string(from: birth.date!)
        let b = mingPan, z = ziweiPan
        try require(b.birthDateTime == expectedTime && z.birthDateTime == expectedTime && b.gender == birth.gender && z.gender == birth.gender)
        try require(b.calculationPolicy.civilBirthTime == expectedTime && b.calculationPolicy.longitude == birth.longitude && b.calculationPolicy.solarTimeApplied)
        try require(formatter.date(from: b.calculationPolicy.effectiveSolarTime) != nil)
        guard let d = Self.stems.firstIndex(of: b.riZhu.gan) else { throw EngineContract.Failure.invalid }
        try require(b.riZhu.gan == b.siZhu.day.ganZhi.gan && b.riZhu.wuXing == Self.elements[d/2] && b.riZhu.yinYang == (d%2 == 0 ? "阳" : "阴"))
        let branchElements = Array("水土木木土火火土金金土水").map(String.init)
        for p in b.siZhu.all {
            guard let g = Self.stems.firstIndex(of: p.ganZhi.gan), let j = Self.branches.firstIndex(of: p.ganZhi.zhi), let hidden = Self.hidden[p.ganZhi.zhi] else { throw EngineContract.Failure.invalid }
            try require(g%2 == j%2 && p.ganZhi.ganWuXing == Self.elements[g/2] && p.ganZhi.ganYinYang == (g%2 == 0 ? "阳" : "阴") && p.ganZhi.zhiWuXing == branchElements[j] && p.ganZhi.zhiYinYang == (j%2 == 0 ? "阳" : "阴"))
            try require(p.shiShen == Self.relation(day: b.riZhu.gan, target: p.ganZhi.gan))
            try require(p.cangGan.count == hidden.count)
            for (i,h) in p.cangGan.enumerated() {
                guard let g = Self.stems.firstIndex(of: h.gan) else { throw EngineContract.Failure.invalid }
                try require(h.gan == hidden[i].0 && h.weight == hidden[i].1 && h.wuXing == Self.elements[g/2] && h.shiShen == Self.relation(day: b.riZhu.gan, target: h.gan))
            }
        }
        let m = z.method
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 8*3600)!
        let chartDate = calendar.date(byAdding: .day, value: birth.hour == 23 ? 1 : 0, to: birth.date!)!
        let dateFormatter = DateFormatter(); dateFormatter.calendar = calendar; dateFormatter.timeZone = calendar.timeZone; dateFormatter.locale = Locale(identifier: "en_US_POSIX"); dateFormatter.dateFormat = "yyyy-MM-dd"
        try require(m.algorithm == "iztro-2.5.8-default" && m.dayBoundary == "zi-hour" && m.leapMonth == "split-at-day-15" && m.yearBoundary == "lunar-new-year" && m.civilTimeZone == "UTC+08:00" && m.calculationDate == dateFormatter.string(from: chartDate))
        try require(["水二局","木三局","金四局","土五局","火六局"].contains(z.fiveElementsClass))
        try require(z.palaces.count == 12 && Set(z.palaces.map(\.name)) == Set(NatalReadingCatalog.palaceOrder) && Set(z.palaces.map(\.position)) == Set(Self.branches))
        try require(z.palaces.first { $0.name == "命宫" }?.position == z.mingGongPosition && z.palaces.filter(\.isShenGong).count == 1 && z.palaces.first(where: \.isShenGong)?.position == z.shenGongPosition)
        guard let yearStem = Self.stems.firstIndex(of: z.natalYear.stem), let yearBranch = Self.branches.firstIndex(of: z.natalYear.branch), let transform = Self.transformed[z.natalYear.stem] else { throw EngineContract.Failure.invalid }
        try require((z.natalYear.lunarYear - 4)%10 == yearStem && (z.natalYear.lunarYear - 4)%12 == yearBranch && z.natalYear.ganZhi == z.natalYear.stem + z.natalYear.branch && (birth.year-1...birth.year+1).contains(z.natalYear.lunarYear))
        let knownMain = z.palaces.flatMap(\.mainStars).filter { NatalReadingCatalog.starSymbols[$0.name] != nil }.map(\.name)
        try require(knownMain.count == 14 && Set(knownMain) == Set(NatalReadingCatalog.starSymbols.keys))
        var transformationCounts = [Int](repeating: 0, count: 4)
        for palace in z.palaces {
            let chars = palace.ganZhi.map(String.init)
            guard chars.count == 2, let stem = Self.stems.firstIndex(of: chars[0]), let branch = Self.branches.firstIndex(of: palace.position) else { throw EngineContract.Failure.invalid }
            try require(chars[1] == palace.position && stem%2 == branch%2)
            let stars = palace.mainStars + palace.minorStars
            try require(Set(stars.map(\.name)).count == stars.count)
            for (index,star) in stars.enumerated() {
                let major = index < palace.mainStars.count
                try require(!star.name.isEmpty && (major ? star.type == "major" && star.source == "major" : ["soft","tough","lucky","unlucky","flower","helper","other"].contains(star.type) && ["minor","adjective"].contains(star.source)))
                if major { try require(star.brightness.map { ["庙","旺","得","利","平","闲","不","陷"].contains($0) } == true) }
                else if let brightness = star.brightness { try require(["","庙","旺","得","利","平","闲","不","陷"].contains(brightness)) }
                let expected = transform.firstIndex(of: star.name).map { [Self.transformations[$0]] } ?? []
                try require((star.sihua ?? []) == expected)
                if let i = transform.firstIndex(of: star.name) { transformationCounts[i] += 1 }
            }
        }
        try require(transformationCounts == [1,1,1,1])
    }
}
