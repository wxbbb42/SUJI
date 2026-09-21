import Foundation

public struct NatalResiduals: Decodable, Sendable {
    public struct Position: Decodable, Sendable {
        public let body: String; public let definition: String; public let longitudeDegrees: Double; public let latitudeDegrees: Double
        public let framePolicy: String; public let timeScale: String
    }
    public struct PurpleParameters: Decodable, Sendable {
        public let epochUTC: String; public let periodDays: Double; public let epochLongitudeDegrees: Double
    }
    public let moduleID: String; public let methodVersion: String; public let inputFingerprint: String
    public let nodeConvention: String; public let dependencyVersions: [String:String]; public let sourceIDs: [String]
    public let positions: [Position]; public let purpleParameters: PurpleParameters; public let limitations: [String]
}

public struct NatalLifeDegree: Decodable, Sendable {
    public struct House: Decodable, Sendable {
        public let name: String; public let branch: String; public let ruler: String
        public let startLongitudeDegrees: Double; public let endLongitudeDegrees: Double
    }
    public struct Mansion: Decodable, Sendable {
        public let body: String; public let mansion: String; public let index: Int; public let entryDegrees: Double
        public let widthDegrees: Double; public let distanceToBoundaryDegrees: Double; public let boundaryStatus: String
    }
    public let moduleID: String; public let methodVersion: String; public let inputFingerprint: String; public let sourceIDs: [String]
    public let clockPolicy: String; public let coordinatePolicy: String; public let mansionPolicy: String
    public let sunLongitudeDegrees: Double; public let birthHourBranch: String; public let sunPalaceBranch: String
    public let palaceBranch: String; public let palaceRuler: String; public let palaceDegree: Double
    public let longitudeDegrees: Double; public let rightAscensionDegrees: Double; public let declinationDegrees: Double
    public let degreeRuler: String; public let hoursUntilBranchChange: Double; public let houses: [House]
    public let mansion: Mansion; public let limitations: [String]
}

extension NatalAstronomyPayload {
    /// Checks source/method binding and cheap derived relationships, without rerunning stellar/planetary ephemerides.
    /// Like the existing seven-body checks this is corruption detection, not authorization of imported charts.
    func validateDerivedAstronomy(hour: Int, minute: Int) throws {
        func require(_ value: Bool) throws { if !value { throw EngineContract.Failure.invalid } }
        func wrap(_ v: Double) -> Double { let r = v.truncatingRemainder(dividingBy: 360); return r < 0 ? r+360 : r }
        func near(_ a: Double,_ b: Double) -> Bool { a.isFinite && b.isFinite && abs(a-b) < 1e-8 }
        let rad = Double.pi / 180, r = fourResiduals
        try require(r.moduleID == "four-residuals" && r.methodVersion == "mean-lunar-moira-purple-v1" && r.inputFingerprint == birthKey &&
            r.nodeConvention == "rahu-ascending-ketu-descending" &&
            r.sourceIDs == ["iers2003-simon1994-mean-lunar","aa1996-mean-lunar-inclination","moira-purple-7474e5f"] &&
            r.dependencyVersions == ["lunarElements":"iers2003-simon1994-tt-v1","inclination":"aa1996-5.1453964-degrees","purpleParameters":"moira-7474e5f-19750313-10227.1792","timePolicy":"utc-as-ut1-espenak-meeus-v1"] &&
            r.positions.map(\.body) == ["Rahu","Ketu","Apogee","PurpleQi"] &&
            r.purpleParameters.epochUTC == "1975-03-13T16:00:00.000Z" && r.purpleParameters.periodDays == 10227.1792 && r.purpleParameters.epochLongitudeDegrees == 230.5 &&
            r.limitations.count == 4 && r.limitations.allSatisfy { !$0.isEmpty })
        let t = (time.julianDayTT-2451545)/36525
        func arc(_ c: [Double]) -> Double { c.reversed().reduce(0) { $0*t+$1 } / 3600 }
        let node = wrap(arc([450160.398036,-6962890.5431,7.4722,0.007702,-0.00005939]))
        let f = arc([335779.526232,1739527262.8478,-12.7512,-0.001037,0.00000417])
        let anomaly = arc([485868.249036,1717915923.2178,31.8792,0.051635,-0.00024470])
        let argument = wrap(f-anomaly+180)*rad, inclination = 5.1453964*rad
        let expected = [(node,0.0),(wrap(node+180),0.0),
            (wrap(node+atan2(sin(argument)*cos(inclination),cos(argument))/rad),asin(sin(inclination)*sin(argument))/rad),
            (wrap(230.5+360*(time.julianDayUT-(2442485+1.0/6))/10227.1792),0.0)]
        let definitions = ["mean-ascending-node","mean-descending-node","mean-lunar-apogee","uniform-symbolic-point"]
        for (i,p) in r.positions.enumerated() {
            try require(p.definition == definitions[i] && p.framePolicy == (i == 3 ? "tropical-ecliptic-parameter" : "mean-ecliptic-of-date") &&
                p.timeScale == (i == 3 ? "UT" : "TT") && (0..<360).contains(p.longitudeDegrees) &&
                near(p.longitudeDegrees,expected[i].0) && near(p.latitudeDegrees,expected[i].1))
        }
        let l = lifeDegree, branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init), zodiac = Array("戌酉申未午巳辰卯寅丑子亥").map(String.init)
        let rulers = ["子":"Saturn","丑":"Saturn","寅":"Jupiter","亥":"Jupiter","卯":"Mars","戌":"Mars","辰":"Venus","酉":"Venus","巳":"Mercury","申":"Mercury","午":"Sun","未":"Moon"]
        let names = ["命宫","财帛","兄弟","田宅","男女","奴仆","夫妻","疾厄","迁移","官禄","福德","相貌"]
        let sun = sevenBodies.positions[0].longitudeDegrees, sunIndex = Int(sun/30), hourIndex = ((hour+1)/2)%12
        let lifeIndex = (sunIndex+hourIndex-3+12)%12, degree = sun.truncatingRemainder(dividingBy: 30)
        let longitude = Double(lifeIndex)*30+degree
        try require(l.moduleID == "life-degree" && l.methodVersion == "mao-hour-tropical-solar-degree-v1" && l.inputFingerprint == birthKey &&
            l.sourceIDs == ["tushu567-mao-life-degree-rev1942530","suji-mao-modern-coordinate-policy-v1"] &&
            l.clockPolicy == "fixed-utc-plus-8-hour-branch-v1" && l.coordinatePolicy == "tropical-30-degree-palaces-true-ecliptic-date-v1" &&
            l.mansionPolicy == "modern-equatorial-reference-not-historical-degree" && near(l.sunLongitudeDegrees,sun) &&
            l.birthHourBranch == branches[hourIndex] && l.sunPalaceBranch == zodiac[sunIndex] && l.palaceBranch == zodiac[lifeIndex] &&
            l.palaceRuler == rulers[l.palaceBranch] && near(l.palaceDegree,degree) && near(l.longitudeDegrees,longitude) &&
            near(l.hoursUntilBranchChange,Double(120-((hour*60+minute+60)%120))/60) && l.houses.map(\.name) == names &&
            l.limitations.count == 4 && l.limitations.allSatisfy { !$0.isEmpty })
        for (i,h) in l.houses.enumerated() {
            let index = (lifeIndex+i)%12
            try require(h.branch == zodiac[index] && h.ruler == rulers[h.branch] &&
                h.startLongitudeDegrees == Double(index)*30 && h.endLongitudeDegrees == Double((index+1)%12)*30)
        }
        // Ecliptic -> equatorial is a rotation about x. Recover its obliquity from
        // the most well-conditioned cached body, then check the zero-latitude life point.
        let p = sevenBodies.positions.max { a,b in
            pow(sin(a.latitudeDegrees*rad),2)+pow(cos(a.latitudeDegrees*rad)*sin(a.longitudeDegrees*rad),2) <
            pow(sin(b.latitudeDegrees*rad),2)+pow(cos(b.latitudeDegrees*rad)*sin(b.longitudeDegrees*rad),2)
        }!
        let ey = cos(p.latitudeDegrees*rad)*sin(p.longitudeDegrees*rad), ez = sin(p.latitudeDegrees*rad)
        let qy = cos(p.declinationDegrees*rad)*sin(p.rightAscensionDegrees*rad), qz = sin(p.declinationDegrees*rad)
        let obliquity = atan2(ey*qz-ez*qy,ey*qy+ez*qz), lambda = longitude*rad
        try require(obliquity > 22*rad && obliquity < 25*rad &&
            near(l.rightAscensionDegrees,wrap(atan2(sin(lambda)*cos(obliquity),cos(lambda))/rad)) &&
            near(l.declinationDegrees,asin(sin(lambda)*sin(obliquity))/rad))
        struct Boundary: Decodable { let name: String; let rightAscensionDegrees: Double; let widthDegrees: Double }
        struct Boundaries: Decodable { let boundaries: [Boundary] }
        let boundaries = try JSONDecoder().decode(Boundaries.self,from:JSONEncoder().encode(mansions)).boundaries
        guard let index = boundaries.firstIndex(where:{ wrap(l.rightAscensionDegrees-$0.rightAscensionDegrees) < $0.widthDegrees }) else { throw EngineContract.Failure.invalid }
        let b = boundaries[index], entry = wrap(l.rightAscensionDegrees-b.rightAscensionDegrees), m = l.mansion
        let degreeRulers = ["Jupiter","Venus","Saturn","Sun","Moon","Mars","Mercury"]
        try require(m.body == "LifeDegree" && m.mansion == b.name && m.index == index && near(m.entryDegrees,entry) &&
            near(m.widthDegrees,b.widthDegrees) && near(m.distanceToBoundaryDegrees,min(entry,b.widthDegrees-entry)) &&
            m.boundaryStatus == "uncertain-time-precision" && l.degreeRuler == degreeRulers[index%7])
    }
}
