import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class NatalDossierStoreTests: XCTestCase {
    private let birth = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "上海", longitude: 121.47)
    private func store(_ container: ModelContainer, user: String = "one") throws -> AppStore {
        try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: user)
    }
    func testSimultaneousFirstRequestsCreateOneDossier() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        app.state.birth = birth; try app.saveThrowing()
        async let first = app.ensureNatalDossier()
        async let second = app.ensureNatalDossier()
        let results = try await [first, second]
        XCTAssertEqual(results[0].createdAt, results[1].createdAt)
        XCTAssertEqual(results[0].payload, results[1].payload)
        XCTAssertTrue(app.hasNatalDossier)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedState>()).filter { $0.key.hasPrefix("natal:") }.count, 1)
    }
    func testReusesSavedChartAcrossLaunchesConcurrentRequestsAndNewQuestionTimes() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let first = try store(container)
        try await first.updateBirth(birth)
        let saved = try XCTUnwrap(first.natalDossier)
        let nextLaunch = try store(container)
        async let one = nextLaunch.ensureNatalDossier()
        async let two = nextLaunch.ensureNatalDossier()
        let values = try await [one, two]
        XCTAssertEqual(values.map(\.createdAt), [saved.createdAt, saved.createdAt])
        let request: [String: Any] = ["command": "tool", "name": "get_today_context", "arguments": [:], "birth": try nextLaunch.birthJSON(birth)]
        var before = request; before["now"] = "2024-02-04T04:00:00Z"
        var after = request; after["now"] = "2024-02-04T09:00:00Z"
        let earlier = try await nextLaunch.request(before)
        let later = try await nextLaunch.request(after)
        XCTAssertEqual(earlier["result"]["yearGanZhi"].text, "癸卯")
        XCTAssertEqual(later["result"]["yearGanZhi"].text, "甲辰")
        XCTAssertEqual(nextLaunch.natalDossier?.createdAt, saved.createdAt)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<SavedState>()).filter { $0.key.hasPrefix("natal:") }.count, 1)
    }
    func testChangedBirthAndAccountNeverReusePreviousChart() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let old = try XCTUnwrap(app.natalDossier)
        var changed = birth; changed.hour = 10
        try await app.updateBirth(changed)
        XCTAssertNotEqual(app.natalDossier?.payload, old.payload)
        XCTAssertEqual(app.natalDossier?.birth, changed)
        try await app.switchAccount(from: "one", to: "two")
        XCTAssertNil(app.natalDossier)
        XCTAssertNil(app.state.birth)
        XCTAssertFalse(app.hasNatalDossier)
        try await app.updateBirth(birth)
        XCTAssertEqual(app.natalDossier?.ownerID, "user:two")
        try await app.switchAccount(from: "two", to: "one")
        XCTAssertEqual(app.natalDossier?.birth, changed)
        XCTAssertEqual(app.natalDossier?.ownerID, "user:one")
    }
    func testCorruptRecordRebuildsAndNotebookDeletionRemovesDossier() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let old = try XCTUnwrap(app.natalDossier)
        let record = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedState>()).first { $0.key == "natal:user:one" })
        record.data = Data("corrupt".utf8); try container.mainContext.save()
        let nextLaunch = try store(container)
        let rebuilt = try await nextLaunch.ensureNatalDossier()
        XCTAssertNotEqual(rebuilt.createdAt, old.createdAt)
        XCTAssertEqual(rebuilt.payload, old.payload)
        try nextLaunch.replaceNotebook(AppState())
        XCTAssertNil(nextLaunch.natalDossier)
        XCTAssertNil(nextLaunch.state.birth)
        XCTAssertFalse(try container.mainContext.fetch(FetchDescriptor<SavedState>()).contains { $0.key.hasPrefix("natal:") })
    }
    func testNotebookArchiveContainsNoComputedDossier() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let app = try store(container)
        try await app.updateBirth(birth)
        let archive = try ArchiveCodec.encode(app.state)
        XCTAssertFalse(String(decoding: archive, as: UTF8.self).contains("mingPan"))
        let imported = try ArchiveCodec.decode(archive)
        try app.replaceNotebook(imported)
        XCTAssertNil(app.natalDossier)
        XCTAssertEqual(app.state.birth, birth)
        let rebuilt = try await app.ensureNatalDossier()
        XCTAssertEqual(rebuilt.ownerID, "user:one")
    }

    func testLoginRestoresCloudBirthAndOfflineEditRetriesWithoutLosingDossier() async throws {
        let oldSession = try KeychainStore.read("supabase-session")
        defer { try? KeychainStore.write(oldSession, name: "supabase-session"); DossierAccountProtocol.handler = nil }
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let app = try AppStore(context: container.mainContext, scriptURL: script)
        app.recordMood(.calm, note: "guest-original")
        var offline = false
        var uploaded: [String: Any]?
        let cloud: [String: Any] = ["id": "one", "birth_date": "1995-08-15T11:30:00Z", "gender": "女", "birth_city": "上海", "birth_longitude": 121.47, "has_onboarded": true, "created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z"]
        DossierAccountProtocol.handler = { request in
            if offline { throw URLError(.notConnectedToInternet) }
            switch (request.url!.path, request.httpMethod!) {
            case ("/auth/v1/token", "POST"):
                return ["access_token": "test-access", "refresh_token": "test-refresh", "expires_in": 3600, "token_type": "bearer", "user": ["id": "one", "email": "test@example.com"]]
            case ("/rest/v1/profiles", "GET"): return [cloud]
            case ("/rest/v1/profiles", "POST"):
                uploaded = try JSONSerialization.jsonObject(with: Self.body(request)) as? [String: Any]
                return [cloud]
            case ("/auth/v1/logout", "POST"): return [:]
            default: throw URLError(.badURL)
            }
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DossierAccountProtocol.self]
        app.accountSession = AccountSession(urlSession: URLSession(configuration: config), restoreSession: false) { [weak app] previous, next in
            try await app?.switchAccount(from: previous, to: next)
        }
        await app.accountSession.signIn(email: "test@example.com", password: "test-password")
        XCTAssertTrue(app.isSignedIn)
        XCTAssertFalse(app.accountSession.hasPendingAccountChange)
        XCTAssertTrue(app.state.journal.isEmpty)
        offline = true
        await app.prepareAccount()
        XCTAssertNil(app.state.birth)
        XCTAssertFalse(app.hasNatalDossier)
        XCTAssertNotNil(app.cloudProfileStatus)
        offline = false
        await app.prepareAccount()
        XCTAssertEqual(app.state.birth, birth)
        XCTAssertTrue(app.hasNatalDossier)
        XCTAssertNil(app.cloudProfileStatus)
        let beforeEdit = try XCTUnwrap(app.natalDossier)
        offline = true
        var edited = birth; edited.hour = 10
        try await app.updateBirth(edited)
        XCTAssertEqual(app.state.birth, edited)
        XCTAssertEqual(app.state.profileNeedsUpload, true)
        XCTAssertNotNil(app.cloudProfileStatus)
        XCTAssertNotEqual(app.natalDossier?.payload, beforeEdit.payload)
        let afterEdit = app.natalDossier?.createdAt
        offline = false
        await app.syncBirthProfile()
        XCTAssertEqual(app.state.profileNeedsUpload, false)
        XCTAssertNil(app.cloudProfileStatus)
        XCTAssertEqual(uploaded?["id"] as? String, "one")
        XCTAssertEqual(uploaded?["birth_date"] as? String, "1995-08-15T02:30:00Z")
        XCTAssertNil(uploaded?["mingPan"])
        XCTAssertEqual(app.natalDossier?.createdAt, afterEdit)
        await app.accountSession.signOut()
        XCTAssertFalse(app.isSignedIn)
        XCTAssertNil(app.natalDossier)
        XCTAssertEqual(app.state.journal.first?.note, "guest-original")
    }

    nonisolated private static func body(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open(); defer { stream.close() }
        var output = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            output.append(buffer, count: count)
        }
        return output
    }
}

private final class DossierAccountProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> Any)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let object = try XCTUnwrap(Self.handler)(request)
            let data = try JSONSerialization.data(withJSONObject: object)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
