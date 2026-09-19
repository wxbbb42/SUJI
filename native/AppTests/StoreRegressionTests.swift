import Foundation
import SwiftData
import XCTest
import SujiCore
@testable import Suji

@MainActor
final class StoreRegressionTests: XCTestCase {
    private var testContainers: [ModelContainer] = []

    func testPersistenceBootstrapUsesExplicitAppPrivateStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-private-store-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privateURL = directory.appendingPathComponent("private/default.store")
        let absentLegacyURL = directory.appendingPathComponent("shared/default.store")

        let container = try PersistenceBootstrap.makeContainer(
            isStoredInMemoryOnly: false,
            privateStoreURL: privateURL,
            legacySharedStoreURL: absentLegacyURL,
            backupDirectoryURL: directory.appendingPathComponent("private/backups")
        )
        let configuration = try XCTUnwrap(container.configurations.first)

        XCTAssertEqual(configuration.url.standardizedFileURL, privateURL.standardizedFileURL)
        XCTAssertNil(configuration.groupAppContainerIdentifier)
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
        XCTAssertTrue(FileManager.default.fileExists(atPath: privateURL.path))
    }

    func testPersistenceBootstrapMigratesAndRemovesLegacySharedStoreAfterPrivateBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-shared-migration-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privateURL = directory.appendingPathComponent("private/default.store")
        let legacyURL = directory.appendingPathComponent("shared/default.store")
        let backupRoot = directory.appendingPathComponent("private/backups", isDirectory: true)

        var localState = AppState()
        localState.recordMood(day: "2026-09-19", mood: .calm, note: "legacy-local")
        var accountState = AppState()
        accountState.recordMood(day: "2026-09-20", mood: .bright, note: "legacy-account")
        var existingPrivateState = AppState()
        existingPrivateState.recordMood(day: "2026-09-18", mood: .unsettled, note: "private-wins")
        try seedSavedStates(
            [("local", JSONEncoder().encode(existingPrivateState))],
            at: privateURL
        )
        try seedSavedStates(
            [
                ("local", JSONEncoder().encode(localState)),
                ("user:test-user", JSONEncoder().encode(accountState))
            ],
            at: legacyURL
        )
        let unrelatedURL = legacyURL.deletingLastPathComponent()
            .appendingPathComponent("default.store-unrelated")
        let unrelatedData = Data("must-remain-shared".utf8)
        try unrelatedData.write(to: unrelatedURL)
        let externalStorageURL = legacyURL.deletingLastPathComponent()
            .appendingPathComponent(".default.store_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
        try FileManager.default.createDirectory(at: externalStorageURL, withIntermediateDirectories: true)
        try Data("legacy-external-data".utf8)
            .write(to: externalStorageURL.appendingPathComponent("blob"))

        let container = try PersistenceBootstrap.makeContainer(
            isStoredInMemoryOnly: false,
            privateStoreURL: privateURL,
            legacySharedStoreURL: legacyURL,
            backupDirectoryURL: backupRoot
        )

        let migrated = try container.mainContext.fetch(FetchDescriptor<SavedState>())
        let stateByKey = try Dictionary(uniqueKeysWithValues: migrated.map {
            ($0.key, try JSONDecoder().decode(AppState.self, from: $0.data))
        })
        XCTAssertEqual(stateByKey["local"]?.journal.first?.note, "private-wins")
        XCTAssertEqual(stateByKey["user:test-user"]?.journal.first?.note, "legacy-account")
        XCTAssertTrue(FileManager.default.fileExists(atPath: privateURL.path))

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: legacyURL.deletingLastPathComponent().appendingPathComponent(".default.store_SUPPORT").path
        ))
        XCTAssertEqual(try Data(contentsOf: unrelatedURL), unrelatedData)

        let backup = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: nil).first
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("default.store").path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: backup.appendingPathComponent(".default.store_SUPPORT/_EXTERNAL_DATA/blob").path
        ))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: backup.appendingPathComponent("default.store-unrelated").path
        ))
        let archiveURL = backup.appendingPathComponent("saved-state-records.json")
        let archive = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: archiveURL)) as? [[String: Any]])
        XCTAssertEqual(Set(archive.compactMap { $0["key"] as? String }), ["local", "user:test-user"])
    }

    func testPersistenceBootstrapRetriesAfterBackupCreationFailureWithoutLosingOrDuplicatingData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-migration-retry-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let privateURL = directory.appendingPathComponent("private/default.store")
        let legacyURL = directory.appendingPathComponent("shared/default.store")
        let blockedBackupURL = directory.appendingPathComponent("private/blocked-backup")

        var privateState = AppState()
        privateState.recordMood(day: "2026-09-18", mood: .calm, note: "private-remains-authoritative")
        var legacyLocalState = AppState()
        legacyLocalState.recordMood(day: "2026-09-19", mood: .low, note: "legacy-conflict")
        var legacyAccountState = AppState()
        legacyAccountState.recordMood(day: "2026-09-20", mood: .bright, note: "legacy-account")
        try seedSavedStates(
            [("local", JSONEncoder().encode(privateState))],
            at: privateURL
        )
        try seedSavedStates(
            [
                ("local", JSONEncoder().encode(legacyLocalState)),
                ("user:test-user", JSONEncoder().encode(legacyAccountState))
            ],
            at: legacyURL
        )
        try Data("this-file-blocks-directory-creation".utf8).write(to: blockedBackupURL)

        XCTAssertThrowsError(
            try PersistenceBootstrap.makeContainer(
                isStoredInMemoryOnly: false,
                privateStoreURL: privateURL,
                legacySharedStoreURL: legacyURL,
                backupDirectoryURL: blockedBackupURL
            )
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: legacyURL.path))
        let legacyAfterFailure = try loadSavedStates(at: legacyURL)
        XCTAssertEqual(legacyAfterFailure["local"]?.journal.first?.note, "legacy-conflict")
        XCTAssertEqual(legacyAfterFailure["user:test-user"]?.journal.first?.note, "legacy-account")
        let privateAfterFailure = try loadSavedStates(at: privateURL)
        XCTAssertEqual(privateAfterFailure["local"]?.journal.first?.note, "private-remains-authoritative")

        try FileManager.default.removeItem(at: blockedBackupURL)
        let container = try PersistenceBootstrap.makeContainer(
            isStoredInMemoryOnly: false,
            privateStoreURL: privateURL,
            legacySharedStoreURL: legacyURL,
            backupDirectoryURL: blockedBackupURL
        )
        let records = try container.mainContext.fetch(FetchDescriptor<SavedState>())
        let migrated = try Dictionary(uniqueKeysWithValues: records.map {
            ($0.key, try JSONDecoder().decode(AppState.self, from: $0.data))
        })

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(Set(records.map(\.key)), ["local", "user:test-user"])
        XCTAssertEqual(migrated["local"]?.journal.first?.note, "private-remains-authoritative")
        XCTAssertEqual(migrated["user:test-user"]?.journal.first?.note, "legacy-account")
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    func testDiskBackedStateRestoresAfterRebuildingModelContainer() throws {
        let script = try makeScript()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("state.sqlite")
        try seedDiskStore(at: storeURL, scriptURL: script)

        let restored = try loadDiskState(at: storeURL, scriptURL: script)
        XCTAssertEqual(restored.journal.count, 1)
        XCTAssertEqual(restored.journal.first?.mood, .calm)
        XCTAssertEqual(restored.journal.first?.note, "survives-container-rebuild")
    }

    func testOlderSlowBirthCalculationCannotOverwriteNewerResult() async throws {
        let store = try makeStore()
        let oldBirth = birth(year: 1990)
        let newBirth = birth(year: 2000)

        let oldUpdate = Task { try await store.updateBirth(oldBirth) }
        await waitUntilComputing(store)
        try await store.updateBirth(newBirth)
        try await oldUpdate.value

        XCTAssertEqual(store.state.birth, newBirth)
        XCTAssertEqual(store.profile?["marker"].text, "new")
        XCTAssertEqual(store.profile?["year"].number, 2000)
        XCTAssertFalse(store.computing)
    }

    func testDelayedResultFromOldScopeCannotEnterNewAccount() async throws {
        let store = try makeStore()
        let localBirth = birth(year: 1990)
        let accountBirth = birth(year: 2001)

        try await store.switchAccount(from: nil, to: "target-user")
        store.state.birth = accountBirth
        try store.saveThrowing()
        try await store.switchAccount(from: "target-user", to: nil)
        store.state.birth = localBirth
        try store.saveThrowing()

        let localCalculation = Task { await store.calculateProfile() }
        await waitUntilComputing(store)
        try await store.switchAccount(from: nil, to: "target-user")
        await localCalculation.value

        XCTAssertEqual(store.scopeKey, "user:target-user")
        XCTAssertEqual(store.state.birth, accountBirth)
        XCTAssertEqual(store.profile?["marker"].text, "new")
        XCTAssertEqual(store.profile?["year"].number, 2001)
        XCTAssertFalse(store.computing)
    }

    func testClearingBirthDuringSlowCalculationDiscardsResultAndStopsComputing() async throws {
        let store = try makeStore()
        store.state.birth = birth(year: 1990)
        try store.saveThrowing()

        let calculation = Task { await store.calculateProfile() }
        await waitUntilComputing(store)
        store.state.birth = nil
        try store.saveThrowing()
        await store.calculateProfile()
        await calculation.value

        XCTAssertNil(store.state.birth)
        XCTAssertNil(store.profile)
        XCTAssertFalse(store.computing)
    }

    private func seedDiskStore(at storeURL: URL, scriptURL: URL) throws {
        let container = try ModelContainer(
            for: SavedState.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        let store = try AppStore(context: container.mainContext, scriptURL: scriptURL)
        store.recordMood(.calm, note: "survives-container-rebuild")
        try store.saveThrowing()
    }

    private func seedSavedStates(_ records: [(key: String, data: Data)], at storeURL: URL) throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let container = try ModelContainer(
            for: SavedState.self,
            configurations: ModelConfiguration("LegacyTest", url: storeURL, cloudKitDatabase: .none)
        )
        for record in records {
            container.mainContext.insert(SavedState(data: record.data, key: record.key))
        }
        try container.mainContext.save()
    }

    private func loadSavedStates(at storeURL: URL) throws -> [String: AppState] {
        let container = try ModelContainer(
            for: SavedState.self,
            configurations: ModelConfiguration("StoredStateTest", url: storeURL, cloudKitDatabase: .none)
        )
        return try Dictionary(uniqueKeysWithValues: container.mainContext.fetch(FetchDescriptor<SavedState>()).map {
            ($0.key, try JSONDecoder().decode(AppState.self, from: $0.data))
        })
    }

    private func loadDiskState(at storeURL: URL, scriptURL: URL) throws -> AppState {
        let container = try ModelContainer(
            for: SavedState.self,
            configurations: ModelConfiguration(url: storeURL)
        )
        return try AppStore(context: container.mainContext, scriptURL: scriptURL).state
    }

    private func makeStore() throws -> AppStore {
        let container = try ModelContainer(
            for: SavedState.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        testContainers.append(container)
        return try AppStore(context: container.mainContext, scriptURL: makeScript())
    }

    private func waitUntilComputing(_ store: AppStore) async {
        for _ in 0..<100 {
            if store.computing { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("The slow profile calculation did not start")
    }

    private func birth(year: Int) -> BirthProfile {
        BirthProfile(
            year: year,
            month: 6,
            day: 15,
            hour: 12,
            minute: 0,
            gender: "女",
            city: "上海",
            longitude: 121.47
        )
    }

    private func makeScript() throws -> URL {
        let source = """
        var SujiNative = {
          run: function(json, resolve, reject) {
            var input = JSON.parse(json);
            if (input.command === "calendar") {
              resolve(JSON.stringify({
                lunarDate: "测试",
                ganZhi: "测试",
                solarTerm: ""
              }));
              return;
            }
            if (input.command === "profile") {
              var year = input.birth.year;
              if (year === 1990) {
                var until = Date.now() + 150;
                while (Date.now() < until) {}
              }
              resolve(JSON.stringify({
                marker: year === 1990 ? "old" : "new",
                year: year
              }));
              return;
            }
            reject("unexpected command");
          }
        };
        """
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("suji-store-bridge-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("bridge.js")
        try Data(source.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return url
    }
}
