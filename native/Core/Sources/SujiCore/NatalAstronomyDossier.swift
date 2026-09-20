import Foundation
import CryptoKit

/// Native-owned, rebuildable sidecar. Digests detect corruption, never authorize imported/model snapshots.
public struct NatalAstronomyDossier: Codable, Sendable {
    public let schemaVersion: Int
    public let ownerID: String
    public let birth: BirthProfile
    /// Hash of the actual JavaScript resource, separate from its embedded source-revision hash.
    public let engineRevision: String
    public let enginePayloadRevision: String
    public let createdAt: Date
    public let payload: Data
    private let payloadDigest: String

    public init(ownerID: String, birth: BirthProfile, engineRevision: String, enginePayloadRevision: String, payload: Data) throws {
        try birth.validated()
        guard !ownerID.isEmpty, Self.revision(engineRevision), Self.revision(enginePayloadRevision) else { throw EngineContract.Failure.invalid }
        let parsed = try NatalAstronomyPayload.validated(payload)
        guard parsed.engineRevision == enginePayloadRevision, try parsed.matches(birth: birth) else { throw EngineContract.Failure.invalid }
        schemaVersion = 1; self.ownerID = ownerID; self.birth = birth
        self.engineRevision = engineRevision; self.enginePayloadRevision = enginePayloadRevision
        self.payload = payload; createdAt = Date(); payloadDigest = Self.digest(payload)
    }
    public func matches(ownerID: String, birth: BirthProfile, engineRevision: String, enginePayloadRevision: String) -> Bool {
        guard schemaVersion == 1, self.ownerID == ownerID, self.birth == birth,
              self.engineRevision == engineRevision, self.enginePayloadRevision == enginePayloadRevision,
              payloadDigest == Self.digest(payload),
              let parsed = try? NatalAstronomyPayload.validated(payload), parsed.engineRevision == enginePayloadRevision,
              (try? parsed.matches(birth: birth)) == true else { return false }
        return true
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func revision(_ value: String) -> Bool { value.count == 64 && value.allSatisfy(\.isHexDigit) }
}

public struct NatalAstronomyPayload: Decodable, Sendable {
    public struct TimeBasis: Decodable, Sendable {
        public let wallClock: String; public let instantUTC: String; public let interpretation: String
        public let utPolicy: String; public let deltaTModel: String
        public let julianDayUT: Double; public let julianDayTT: Double; public let deltaTSeconds: Double
    }
    public struct Position: Decodable, Sendable {
        public let body: String; public let longitudeDegrees: Double; public let latitudeDegrees: Double
        public let rightAscensionDegrees: Double; public let declinationDegrees: Double; public let correctionPolicy: String
    }
    public struct SevenBodies: Decodable, Sendable {
        public let moduleID: String; public let methodVersion: String; public let inputFingerprint: String
        public let dependencyVersions: [String: String]; public let sourceIDs: [String]; public let positions: [Position]
    }
    public let schemaVersion: Int; public let engineRevision: String; public let birthKey: String
    public let time: TimeBasis; public let sevenBodies: SevenBodies; public let mansions: JSONValue
    public let unsupported: [String]; public let limitations: [String]
    public static let bodies = ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn"]

    public static func validated(_ data: Data) throws -> Self {
        let result = try JSONDecoder().decode(Self.self, from: data)
        try result.validate()
        return result
    }
    private func validate() throws {
        guard schemaVersion == 1, NatalAstronomyDossier.revision(engineRevision),
              sevenBodies.moduleID == "geocentric-seven-bodies", sevenBodies.methodVersion == "astronomy-engine-2.1.19-geocentric-v1",
              sevenBodies.inputFingerprint == birthKey,
              sevenBodies.dependencyVersions == ["ephemeris":"astronomy-engine@2.1.19", "timePolicy":"utc-as-ut1-espenak-meeus-v1", "framePolicy":"true-ecliptic-equator-of-date-v1"],
              sevenBodies.sourceIDs == ["astronomy-engine-2.1.19", "astronomy-time-policy-v1"],
              sevenBodies.positions.map(\.body) == Self.bodies,
              sevenBodies.positions.allSatisfy({ p in
                  p.longitudeDegrees.isFinite && (0..<360).contains(p.longitudeDegrees) &&
                  p.latitudeDegrees.isFinite && (-90...90).contains(p.latitudeDegrees) &&
                  p.rightAscensionDegrees.isFinite && (0..<360).contains(p.rightAscensionDegrees) &&
                  p.declinationDegrees.isFinite && (-90...90).contains(p.declinationDegrees) &&
                  p.correctionPolicy == (p.body == "Moon" ? "geomoon-no-separate-light-time-aberration" : "light-time-aberration")
              }),
              unsupported == ["four-residuals", "houses", "life-degree", "traditional-angle-units"],
              limitations.count == 8, limitations.allSatisfy({ !$0.isEmpty }),
              time.interpretation == "fixed-utc-plus-8-v1", time.utPolicy == "utc-as-ut1-v1", time.deltaTModel == "espenak-meeus-v1" else { throw EngineContract.Failure.invalid }
        try validateMansions()
        let key = try decodedBirthKey()
        let b = BirthProfile(year: key.year, month: key.month, day: key.day, hour: key.hour, minute: key.minute,
                             gender: key.gender, city: "clock-validation", longitude: key.longitude, timeZoneID: key.timeZoneID)
        try b.validated()
        guard let instant = b.date else { throw EngineContract.Failure.invalid }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedWall = String(format: "%04d-%02d-%02dT%02d:%02d", key.year, key.month, key.day, key.hour, key.minute)
        let jd = instant.timeIntervalSince1970 / 86400 + 2440587.5
        let delta = Self.deltaT(ut: jd - 2451545)
        guard time.wallClock == expectedWall, time.instantUTC == formatter.string(from: instant),
              time.julianDayUT.isFinite, abs(time.julianDayUT - jd) < 1e-8,
              time.julianDayTT.isFinite, abs(time.julianDayTT - (jd + delta / 86400)) < 1e-8,
              time.deltaTSeconds.isFinite, abs(time.deltaTSeconds - delta) < 0.00001 else { throw EngineContract.Failure.invalid }
    }
    private struct MansionBoundary: Decodable {
        let name: String; let designation: String; let hip: Int
        let rightAscensionDegrees: Double; let nextRightAscensionDegrees: Double; let widthDegrees: Double
    }
    private struct MansionPosition: Decodable {
        let body: String; let mansion: String; let index: Int; let entryDegrees: Double
        let widthDegrees: Double; let distanceToBoundaryDegrees: Double; let boundaryStatus: String
    }
    private struct Mansions: Decodable {
        let moduleID: String; let methodVersion: String; let inputFingerprint: String
        let dependencyVersions: [String: String]; let sourceIDs: [String]
        let boundaries: [MansionBoundary]; let positions: [MansionPosition]; let uncertainty: [String: JSONValue]
    }
    private func validateMansions() throws {
        let m = try JSONDecoder().decode(Mansions.self, from: JSONEncoder().encode(mansions))
        let names = Array("角亢氐房心尾箕斗牛女虚危室壁奎娄胃昴毕觜参井鬼柳星张翼轸").map(String.init)
        let hips = [65474,69427,72622,78265,80112,82514,88635,92041,100345,102618,106278,109074,113963,1067,4463,8903,12719,17499,20889,26207,26727,30343,41822,42313,46390,48356,53740,59803]
        let designations = ["* alf Vir","* kap Vir","* alf02 Lib","* pi Sco","* sig Sco","* mu01 Sco","* gam02 Sgr","* phi Sgr","* bet01 Cap","* eps Aqr","* bet Aqr","* alf Aqr","* alf Peg","* gam Peg","* eta And","* bet Ari","35 Ari","17 Tau","* eps Tau","* lam Ori","* zet Ori","* mu Gem","* tet Cnc","* del Hya","* alf Hya","* ups01 Hya","* alf Crt","* gam Crv"]
        guard m.moduleID == "chinese-28-mansions", m.methodVersion == "contemporary-first-star28-equatorial-v1", m.inputFingerprint == birthKey,
              m.dependencyVersions == ["catalog":"contemporary-first-star28-equatorial-v1@1.0.0", "transformation":"icrs-tangent-motion-precession-nutation-v1", "boundary":"left-closed-right-open-equatorial-v1"],
              m.sourceIDs == ["stellarium-contemporary-first-stars-71885f2e", "hipparcos-28-esa1997", "simbad-28-20260920"],
              m.boundaries.map(\.name) == names, m.boundaries.map(\.hip) == hips, m.boundaries.map(\.designation) == designations,
              m.positions.map(\.body) == Self.bodies,
              m.uncertainty == ["birthTimePrecision":.string("unknown"), "ephemerisErrorBoundDegrees":.null, "catalogErrorBoundDegrees":.null] else { throw EngineContract.Failure.invalid }
        var wraps = 0
        for (i,b) in m.boundaries.enumerated() {
            let next = m.boundaries[(i+1)%28].rightAscensionDegrees, gap = next-b.rightAscensionDegrees
            if gap < 0 { wraps += 1 }
            guard b.rightAscensionDegrees.isFinite, (0..<360).contains(b.rightAscensionDegrees), gap != 0,
                  b.nextRightAscensionDegrees == next, b.widthDegrees.isFinite,
                  abs(b.widthDegrees - (gap < 0 ? gap+360 : gap)) < 1e-9 else { throw EngineContract.Failure.invalid }
        }
        guard wraps == 1 else { throw EngineContract.Failure.invalid }
        for (i,p) in m.positions.enumerated() {
            let ra = sevenBodies.positions[i].rightAscensionDegrees
            guard let index = m.boundaries.firstIndex(where: { b in
                b.nextRightAscensionDegrees > b.rightAscensionDegrees
                ? ra >= b.rightAscensionDegrees && ra < b.nextRightAscensionDegrees
                : ra >= b.rightAscensionDegrees || ra < b.nextRightAscensionDegrees
            }) else { throw EngineContract.Failure.invalid }
            let b = m.boundaries[index], gap = ra-b.rightAscensionDegrees, entry = gap < 0 ? gap+360 : gap
            guard p.index == index, p.mansion == b.name, p.boundaryStatus == "uncertain-time-precision",
                  p.entryDegrees.isFinite, abs(p.entryDegrees-entry) < 1e-9,
                  p.widthDegrees == b.widthDegrees, p.distanceToBoundaryDegrees.isFinite,
                  abs(p.distanceToBoundaryDegrees-min(entry,b.widthDegrees-entry)) < 1e-9 else { throw EngineContract.Failure.invalid }
        }
    }
    func matches(birth: BirthProfile) throws -> Bool {
        try birth.validated()
        let b = try decodedBirthKey()
        return b.year == birth.year && b.month == birth.month && b.day == birth.day && b.hour == birth.hour && b.minute == birth.minute &&
            b.gender == birth.gender && b.longitude == birth.longitude && b.timeZoneID == birth.timeZoneID
    }
    private struct BirthKey: Decodable {
        let year: Int; let month: Int; let day: Int; let hour: Int; let minute: Int; let gender: String; let longitude: Double; let timeZoneID: String
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            year = try c.decode(Int.self); month = try c.decode(Int.self); day = try c.decode(Int.self)
            hour = try c.decode(Int.self); minute = try c.decode(Int.self); gender = try c.decode(String.self)
            longitude = try c.decode(Double.self); timeZoneID = try c.decode(String.self)
            guard c.isAtEnd else { throw EngineContract.Failure.invalid }
        }
    }
    private func decodedBirthKey() throws -> BirthKey {
        guard birthKey.utf8.count <= 256 else { throw EngineContract.Failure.invalid }
        return try JSONDecoder().decode(BirthKey.self, from: Data(birthKey.utf8))
    }
    /// Espenak/Meeus coefficients for the supported1901–2100 clock range, with AE2.1.19's year convention.
    /// Independently checks stored time metadata; not an independent physical ΔT accuracy claim.
    private static func deltaT(ut: Double) -> Double {
        let y = 2000 + (ut - 14) / 365.24217
        if y < 1920 { let u = y - 1900; return -2.79 + 1.494119*u - 0.0598939*u*u + 0.0061966*u*u*u - 0.000197*pow(u,4) }
        if y < 1941 { let u = y - 1920; return 21.20 + 0.84493*u - 0.076100*u*u + 0.0020936*u*u*u }
        if y < 1961 { let u = y - 1950; return 29.07 + 0.407*u - u*u/233 + u*u*u/2547 }
        if y < 1986 { let u = y - 1975; return 45.45 + 1.067*u - u*u/260 - u*u*u/718 }
        if y < 2005 { let u = y - 2000; return 63.86 + 0.3345*u - 0.060374*u*u + 0.0017275*pow(u,3) + 0.000651814*pow(u,4) + 0.00002373599*pow(u,5) }
        if y < 2050 { let u = y - 2000; return 62.92 + 0.32217*u + 0.005589*u*u }
        let u = (y - 1820) / 100; return -20 + 32*u*u - 0.5628*(2150-y)
    }
}
