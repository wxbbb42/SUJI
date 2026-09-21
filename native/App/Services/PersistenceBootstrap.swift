import Foundation
import SwiftData

enum PersistenceBootstrapError: LocalizedError {
    case migrationVerificationFailed
    case backupVerificationFailed

    var errorDescription: String? {
        switch self {
        case .migrationVerificationFailed:
            return "旧版数据未能完整迁移，原数据仍保留在共享容器中。"
        case .backupVerificationFailed:
            return "旧版数据备份未能通过校验，原数据仍保留在共享容器中。"
        }
    }
}

@MainActor
enum PersistenceBootstrap {
    static let appGroupIdentifier = "group.app.suji.native"
    static let storeFilename = "default.store"
    static let backupDirectoryName = "SujiPersistenceBackups"

    /// Opens the app-private SwiftData store and, once, imports the prerelease
    /// store that SwiftData's `.automatic` group selection placed in App Group.
    /// The shared store is removed only after the imported rows and an
    /// app-private backup have both been verified.
    static func makeContainer(
        isStoredInMemoryOnly: Bool,
        privateStoreURL: URL? = nil,
        legacySharedStoreURL: URL? = nil,
        backupDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> ModelContainer {
        let schema = Schema([SavedState.self])
        let configuration: ModelConfiguration

        if let privateStoreURL {
            try fileManager.createDirectory(
                at: privateStoreURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            configuration = ModelConfiguration(
                "SujiPrivate",
                schema: schema,
                url: privateStoreURL,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "SujiPrivate",
                schema: schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }

        let container = try ModelContainer(for: schema, configurations: configuration)
        guard !isStoredInMemoryOnly else { return container }

        let legacyURL = legacySharedStoreURL ?? defaultLegacySharedStoreURL(fileManager: fileManager)
        guard let legacyURL,
              legacyURL.standardizedFileURL != configuration.url.standardizedFileURL,
              fileManager.fileExists(atPath: legacyURL.path) else {
            return container
        }

        let legacyRecords = try readRecords(at: legacyURL)
        let privateRecordsBeforeMigration = try records(in: container.mainContext)
        try importRecords(legacyRecords, into: container.mainContext)
        try verifyMigration(
            legacyRecords,
            preserving: privateRecordsBeforeMigration,
            in: container.mainContext
        )

        let backupRoot = backupDirectoryURL
            ?? configuration.url.deletingLastPathComponent().appendingPathComponent(backupDirectoryName, isDirectory: true)
        try backupLegacyStore(
            at: legacyURL,
            records: legacyRecords,
            into: backupRoot,
            fileManager: fileManager
        )
        try removeLegacyStore(at: legacyURL, fileManager: fileManager)
        return container
    }

    static func defaultLegacySharedStoreURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(storeFilename)
    }

    private struct RecordBackup: Codable, Equatable {
        let key: String
        let data: Data
    }

    private static func readRecords(at storeURL: URL) throws -> [RecordBackup] {
        let configuration = ModelConfiguration(
            "SujiLegacyShared",
            schema: Schema([SavedState.self]),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let legacyContainer = try ModelContainer(for: SavedState.self, configurations: configuration)
        return try legacyContainer.mainContext.fetch(FetchDescriptor<SavedState>())
            .map { RecordBackup(key: $0.key, data: $0.data) }
    }

    private static func importRecords(_ records: [RecordBackup], into context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<SavedState>())
        var recordsByKey = Dictionary(uniqueKeysWithValues: existing.map { ($0.key, $0) })
        for legacy in records {
            if recordsByKey[legacy.key] == nil {
                let record = SavedState(data: legacy.data, key: legacy.key)
                context.insert(record)
                recordsByKey[legacy.key] = record
            }
        }
        try context.save()
    }

    private static func verifyMigration(
        _ legacyRecords: [RecordBackup],
        preserving privateRecords: [RecordBackup],
        in context: ModelContext
    ) throws {
        let actualByKey = Dictionary(uniqueKeysWithValues: try records(in: context).map { ($0.key, $0.data) })
        let privateByKey = Dictionary(uniqueKeysWithValues: privateRecords.map { ($0.key, $0.data) })
        let privateWasPreserved = privateRecords.allSatisfy { actualByKey[$0.key] == $0.data }
        let missingLegacyWasImported = legacyRecords.allSatisfy { legacy in
            privateByKey[legacy.key] != nil || actualByKey[legacy.key] == legacy.data
        }
        guard privateWasPreserved, missingLegacyWasImported else {
            throw PersistenceBootstrapError.migrationVerificationFailed
        }
    }

    private static func records(in context: ModelContext) throws -> [RecordBackup] {
        try context.fetch(FetchDescriptor<SavedState>())
            .map { RecordBackup(key: $0.key, data: $0.data) }
    }

    private static func backupLegacyStore(
        at storeURL: URL,
        records: [RecordBackup],
        into backupRoot: URL,
        fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let destination = backupRoot
            .appendingPathComponent("legacy-shared-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: false)

        do {
            for artifact in try storeArtifacts(at: storeURL, fileManager: fileManager) {
                try fileManager.copyItem(
                    at: artifact,
                    to: destination.appendingPathComponent(artifact.lastPathComponent, isDirectory: artifact.hasDirectoryPath)
                )
            }
            let archiveURL = destination.appendingPathComponent("saved-state-records.json")
            let archive = try JSONEncoder().encode(records)
            try archive.write(to: archiveURL, options: .atomic)
            let restored = try JSONDecoder().decode([RecordBackup].self, from: Data(contentsOf: archiveURL))
            guard restored == records else { throw PersistenceBootstrapError.backupVerificationFailed }
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
    }

    private static func removeLegacyStore(at storeURL: URL, fileManager: FileManager) throws {
        let artifacts = try storeArtifacts(at: storeURL, fileManager: fileManager)
        let primary = storeURL.standardizedFileURL
        for artifact in artifacts.sorted(by: { left, right in
            let leftOrder = left.standardizedFileURL == primary ? 1 : 0
            let rightOrder = right.standardizedFileURL == primary ? 1 : 0
            return leftOrder < rightOrder
        }) {
            try fileManager.removeItem(at: artifact)
        }
    }

    private static func storeArtifacts(at storeURL: URL, fileManager: FileManager) throws -> [URL] {
        let directory = storeURL.deletingLastPathComponent()
        let filename = storeURL.lastPathComponent
        let artifactNames: Set<String> = [
            filename,
            filename + "-shm",
            filename + "-wal",
            filename + "-journal",
            filename + "_SUPPORT",
            "." + filename + "_SUPPORT"
        ]
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ).filter { artifactNames.contains($0.lastPathComponent) }
    }
}
