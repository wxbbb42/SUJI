import Foundation
import CryptoKit

/// Rebuildable local computation, deliberately separate from AppState and archives.
/// The digest detects damaged storage; it does not authenticate external snapshots.
public struct NatalDossier: Codable, Sendable {
    public let schemaVersion: Int
    public let ownerID: String
    public let birth: BirthProfile
    public let engineRevision: String
    public let createdAt: Date
    public let payload: Data
    private let payloadDigest: String

    public init(ownerID: String, birth: BirthProfile, engineRevision: String, payload: Data) throws {
        try birth.validated()
        try EngineContract.validate(payload, command: "natal")
        schemaVersion = 1
        self.ownerID = ownerID
        self.birth = birth
        self.engineRevision = engineRevision
        self.payload = payload
        createdAt = Date()
        payloadDigest = Self.digest(payload)
    }

    public func matches(ownerID: String, birth: BirthProfile, engineRevision: String) -> Bool {
        guard schemaVersion == 1, self.ownerID == ownerID, self.birth == birth,
              self.engineRevision == engineRevision, payloadDigest == Self.digest(payload),
              (try? EngineContract.validate(payload, command: "natal")) != nil else { return false }
        return true
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
