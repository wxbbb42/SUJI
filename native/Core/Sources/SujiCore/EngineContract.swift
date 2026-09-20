import Foundation

/// Decode critical chart fields before the presentation layer's permissive Document access.
public enum EngineContract {
    public static func validate(_ data: Data, command: String) throws {
        let decoder = JSONDecoder()
        do {
            switch command {
            case "profile", "natal":
                let result = try decoder.decode(NatalCharts.self, from: data)
                guard date(result.mingPan.qiYun.startDate) != nil, date(result.mingPan.qiYun.termDate) != nil,
                      !result.mingPan.daYunList.isEmpty,
                      result.ziweiPan.palaces.count == 12,
                      Set(result.ziweiPan.palaces.map(\.name)).count == 12,
                      result.mingPan.qiYun.sect == 2,
                      result.mingPan.daYunList.allSatisfy({ validInterval($0.startDate, $0.endDate) }),
                      !result.mingPan.calculationPolicy.version.isEmpty else { throw Failure.invalid }
                for pillar in result.mingPan.siZhu.all { try pillar.ganZhi.validate() }
                for period in result.mingPan.daYunList { try period.validate() }
                if command == "profile" {
                    try decoder.decode(ForecastResponse.self, from: data).forecast.validate()
                } else {
                    let metadata = try decoder.decode(NatalMetadata.self, from: data)
                    guard metadata.schemaVersion == 1, metadata.engineRevision.count == 64,
                          metadata.engineRevision.allSatisfy({ $0.isHexDigit }), !metadata.birthKey.isEmpty,
                          metadata.calendarPolicy.version == result.mingPan.calculationPolicy.version,
                          !metadata.personality.coreTraits.isEmpty else { throw Failure.invalid }
                }
            case "forecast":
                try decoder.decode(ForecastResponse.self, from: data).forecast.validate()
            case "candidates":
                let results = try decoder.decode([Candidate].self, from: data)
                guard !results.isEmpty, results.count <= 12, Set(results.map(\.id)).count == results.count else { throw Failure.invalid }
                for result in results {
                    guard date(result.birthDate) != nil else { throw Failure.invalid }
                    try result.dayPillar.validate(); try result.hourPillar.validate()
                }
            case "relationship":
                let result = try decoder.decode(Relationship.self, from: data)
                try result.firstDayPillar.validate(); try result.secondDayPillar.validate()
            case "metadata":
                let result = try decoder.decode(Metadata.self, from: data)
                guard result.engineRevision.count == 64, result.engineRevision.allSatisfy({ $0.isHexDigit }),
                      !result.calendarPolicy.version.isEmpty else { throw Failure.invalid }
            case "calendar":
                let result = try decoder.decode(CalendarResult.self, from: data)
                guard !result.lunarDate.isEmpty, !result.ganZhi.isEmpty else { throw Failure.invalid }
            default: break
            }
        } catch { throw Failure.invalid }
    }

    public enum Failure: LocalizedError {
        case invalid
        public var errorDescription: String? { "排盘资料未能完整解析，请重新计算或更新应用。原始出生资料没有更改。" }
    }
    private static func date(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }
    private static func validInterval(_ start: String, _ end: String) -> Bool {
        guard let start = date(start), let end = date(end) else { return false }
        return start < end
    }
    private struct GanZhi: Decodable {
        let gan: String; let zhi: String
        func validate() throws {
            let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
            let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
            guard let stem = stems.firstIndex(of: gan), let branch = branches.firstIndex(of: zhi),
                  stem % 2 == branch % 2 else { throw Failure.invalid }
        }
    }
    private struct Pillar: Decodable { let ganZhi: GanZhi; let shiShen: String }
    private struct Pillars: Decodable {
        let year: Pillar; let month: Pillar; let day: Pillar; let hour: Pillar
        var all: [Pillar] { [year, month, day, hour] }
    }
    private struct Policy: Decodable { let version: String; let timezone: String }
    private struct QiYun: Decodable { let years: Int; let months: Int; let days: Int; let hours: Int; let startDate: String; let termDate: String; let termName: String; let sect: Int }
    private struct DaYun: Decodable {
        let ganZhi: GanZhi; let startDate: String; let endDate: String; let period: String
        func validate() throws {
            try ganZhi.validate()
            guard validInterval(startDate, endDate) else { throw Failure.invalid }
        }
    }
    private struct MingPan: Decodable { let siZhu: Pillars; let qiYun: QiYun; let daYunList: [DaYun]; let calculationPolicy: Policy }
    private struct Star: Decodable { let name: String; let brightness: String?; let sihua: [String]? }
    private struct Palace: Decodable { let name: String; let position: String; let ganZhi: String; let isShenGong: Bool; let mainStars: [Star]; let minorStars: [Star] }
    private struct Ziwei: Decodable { let palaces: [Palace]; let fiveElementsClass: String }
    private struct NatalCharts: Decodable { let mingPan: MingPan; let ziweiPan: Ziwei }
    private struct Personality: Decodable { let coreTraits: [String] }
    private struct NatalMetadata: Decodable { let schemaVersion: Int; let engineRevision: String; let birthKey: String; let calendarPolicy: Policy; let personality: Personality }
    private struct ForecastResponse: Decodable { let forecast: Forecast }
    private struct Forecast: Decodable {
        let year: Int; let daYun: DaYun?; let daYunStatus: String; let referenceDate: String
        func validate() throws {
            guard (1901...2100).contains(year), date(referenceDate) != nil,
                  ["active", "before-birth", "before-start", "out-of-range", "missing-exact-dates"].contains(daYunStatus),
                  (daYunStatus == "active") == (daYun != nil) else { throw Failure.invalid }
            if let daYun {
                try daYun.validate()
                guard let reference = date(referenceDate), let start = date(daYun.startDate), let end = date(daYun.endDate),
                      reference >= start, reference < end else { throw Failure.invalid }
            }
        }
    }
    private struct Events: Decodable { let bazi: [String: String]; let ziwei: [String: String] }
    private struct Candidate: Decodable { let id: String; let birthDate: String; let dayPillar: GanZhi; let hourPillar: GanZhi; let eventsBySystem: Events }
    private struct Relationship: Decodable { let firstDayPillar: GanZhi; let secondDayPillar: GanZhi }
    private struct Metadata: Decodable { let engineRevision: String; let calendarPolicy: Policy }
    private struct CalendarResult: Decodable { let lunarDate: String; let ganZhi: String; let solarTerm: String }
}
