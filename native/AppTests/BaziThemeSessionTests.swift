import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Negative transport fixtures only; separate live tests exercise deployed DeepSeek.
@MainActor final class BaziThemeSessionTests: XCTestCase {
    private func fixture() async throws -> (ModelContainer, AppStore, BaziThemeBinding) {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: "theme-synthetic")
        try await store.updateBirth(BirthProfile(year: 1987, month: 2, day: 14, hour: 14, minute: 20, gender: "女", city: "明确合成主题测试", longitude: 120))
        return (container, store, try store.makeThemeBinding(await store.currentBaziTheme()))
    }
    private func client() -> ChatClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ThemeFixtureTransport.self]
        return ChatClient(configuration: .init(baseURL: URL(string: "https://theme-fixture.invalid/v1")!, model: "synthetic", api: .chatCompletions, authentication: .none), credential: nil, session: URLSession(configuration: config))
    }
    private func wait(_ session: ChatSession) async throws {
        for _ in 0..<2000 { if !session.working { return }; try await Task.sleep(for: .milliseconds(5)) }
        throw EngineError.execution("Theme test timed out")
    }
    func testRealProjectionAndRejectedSelectorPreserveFactsForRetry() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        let theme = try await store.currentBaziTheme(), created = store.natalDossier?.createdAt
        ThemeFixtureTransport.reset(reject: true)
        let session = ChatSession(makeClient: { _ in self.client() })
        session.send("这页为什么把表达与规则放在一起", mode: "命理", store: store, themeBinding: binding)
        try await wait(session)
        XCTAssertEqual(ThemeFixtureTransport.count, 2, "One repair only; actual projection must reach selector")
        XCTAssertTrue(session.failure?.contains("主题依据核对") == true)
        XCTAssertEqual(store.state.conversations.count, 1)
        let source = try XCTUnwrap(store.state.conversations.first)
        let receipt = try XCTUnwrap(source.toolReceipts?.first)
        XCTAssertEqual(receipt.name, "get_domain")
        XCTAssertNoThrow(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: receipt, context: XCTUnwrap(source.toolContext)))
        ThemeFixtureTransport.reset()
        session.send(source.text, mode: "命理", store: store, appendUser: false)
        try await wait(session)
        XCTAssertNil(session.failure); XCTAssertEqual(ThemeFixtureTransport.count, 1)
        XCTAssertEqual(store.state.conversations.first?.toolReceipts, source.toolReceipts)
        XCTAssertEqual(store.natalDossier?.createdAt, created)
        XCTAssertEqual(store.state.conversations.last?.themeAction, .explain)
        XCTAssertEqual(store.state.conversations.last?.text, BaziThemeAnswer.render(theme: theme, action: .explain))
        let replay = try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: "theme-synthetic")
        XCTAssertEqual(replay.state.conversations.last?.text, store.state.conversations.last?.text)
        XCTAssertThrowsError(try replay.validateThemeBinding(binding), "Relaunch preserves history, requires fresh theme intent")
        let imported = try ArchiveCodec.decode(ArchiveCodec.encode(store.state))
        XCTAssertTrue(imported.conversations.allSatisfy { $0.themeBinding == nil && $0.themeAction == nil })
        XCTAssertEqual(imported.conversations.last?.text, store.state.conversations.last?.text)
    }
    func testOnlyVerifiedAdjacentFollowupCanAuthorizeShortAnswer() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        let session = ChatSession(makeClient: { _ in self.client() })
        ThemeFixtureTransport.reset(followUp: "goalOrMethod")
        session.send("举个具体例子", mode: "命理", store: store, themeBinding: binding)
        try await wait(session)
        XCTAssertNil(session.failure)
        let verifiedHistory = store.state.conversations
        let theme = try await store.currentBaziTheme()
        let source = try XCTUnwrap(verifiedHistory.first), reply = try XCTUnwrap(verifiedHistory.last)
        let record = try XCTUnwrap(reply.themeReply)
        XCTAssertTrue(record.isWellFormed)
        XCTAssertEqual(record.followUp, .goalOrMethod)
        XCTAssertEqual(record.context, source.toolContext)
        XCTAssertEqual(record.context.birthFingerprint, binding.birthFingerprint)
        XCTAssertEqual(record.context.engineRevision, binding.payloadRevision)
        XCTAssertEqual(reply.text, BaziThemeAnswer.render(theme: theme, action: record.action, followUp: record.followUp))
        XCTAssertEqual(record.evidenceIDs, theme.evidence.map(\.id))
        XCTAssertNoThrow(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: XCTUnwrap(source.toolReceipts?.first), context: record.context))
        let next = ConversationEntry(role: "user", text: "方法")
        XCTAssertEqual(BaziThemeHistory.verifiedFollowUp(entries: verifiedHistory + [next], before: next.id, binding: binding, theme: theme), .goalOrMethod)
        ThemeFixtureTransport.reset()
        session.send("方法", mode: "命理", store: store, themeBinding: binding)
        try await wait(session)
        XCTAssertNil(session.failure); XCTAssertEqual(ThemeFixtureTransport.count, 1)
        XCTAssertEqual(store.state.conversations.last?.themeAction, .methodStep)
        XCTAssertTrue(store.state.conversations.last?.text.contains("现代沟通练习") == true)
        for tamper in 0..<5 {
            store.state.conversations = verifiedHistory
            switch tamper {
            case 0: store.state.conversations[1].text += "未经核验的新增断语"
            case 1: store.state.conversations[0].toolReceipts = []
            case 2: store.state.conversations[0].id = UUID()
            case 3: store.state.conversations[1].themeBinding = nil
            default: store.state.conversations[0].toolContext = nil
            }
            ThemeFixtureTransport.reset()
            session.send("方法", mode: "命理", store: store, themeBinding: binding)
            try await wait(session)
            XCTAssertNil(session.failure); XCTAssertEqual(ThemeFixtureTransport.count, 0)
            XCTAssertNil(store.state.conversations.last?.themeAction, "Untrusted previous question must not authorize a short answer")
        }
    }
    func testBirthABARejectsOldBindingBeforeClientAndKeepsQuestion() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        let a = try XCTUnwrap(store.state.birth); var b = a; b.hour = 6
        try await store.updateBirth(b); try await store.updateBirth(a)
        var called = 0
        let session = ChatSession(makeClient: { _ in called += 1; return self.client() })
        session.send("这页为什么这么说", mode: "命理", store: store, themeBinding: binding)
        try await wait(session)
        XCTAssertEqual(called, 0); XCTAssertNotNil(session.failure)
        XCTAssertEqual(store.state.conversations.last?.role, "user")
        XCTAssertNotNil(store.natalDossier)
    }
    func testAccountSwitchAndChangedSnapshotCannotAuthorize() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        try await store.switchAccount(from: "theme-synthetic", to: "another-synthetic")
        XCTAssertThrowsError(try store.validateThemeBinding(binding))
        XCTAssertTrue(store.state.conversations.isEmpty)
    }
    func testAmbiguousDynamicAndOtherQuestionsDoNotCallModelOrUseThemeFacts() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        var called = 0
        for question in ["明年也这样吗", "那我姐姐呢", "这样合适吗", "这件事能成吗"] {
            let session = ChatSession(makeClient: { _ in called += 1; return self.client() })
            session.send(question, mode: "命理", store: store, themeBinding: binding)
            try await wait(session)
            XCTAssertNil(session.failure)
            XCTAssertNil(store.state.conversations.last?.themeBinding)
            XCTAssertTrue(store.state.conversations.suffix(2).allSatisfy { $0.toolReceipts?.isEmpty ?? true })
        }
        XCTAssertEqual(called, 0)
    }
    func testSameBirthConfirmationDuringModelWaitDropsLateAnswer() async throws {
        let (container, store, binding) = try await fixture(); defer { withExtendedLifetime(container) {} }
        ThemeFixtureTransport.reset(delay: 0.4)
        let session = ChatSession(makeClient: { _ in self.client() })
        session.send("这页为什么这么说", mode: "命理", store: store, themeBinding: binding)
        for _ in 0..<200 { if ThemeFixtureTransport.count > 0 { break }; try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertEqual(ThemeFixtureTransport.count, 1)
        try await store.updateBirth(XCTUnwrap(store.state.birth))
        try await wait(session)
        XCTAssertTrue(session.failure?.contains("出生资料已更改") == true)
        XCTAssertFalse(store.state.conversations.contains { $0.role == "assistant" })
    }
}

private final class ThemeFixtureTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var calls = 0, reject = false
    private static var delay = 0.0
    private static var followUp = "none"
    static var count: Int { lock.withLock { calls } }
    static func reset(reject: Bool = false, delay: Double = 0, followUp: String = "none") { lock.withLock { calls = 0; Self.reject = reject; Self.delay = delay; Self.followUp = followUp } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "theme-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }; var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n)) }
            }
            let flags = Self.lock.withLock { Self.calls += 1; return (Self.reject, Self.delay, Self.followUp) }
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
            let raw = try XCTUnwrap(messages.first { $0["role"] as? String == "user" }?["content"] as? String)
            let packet = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
            let selection: [String: Any] = ["protocolVersion": BaziThemeAnswer.protocolVersion, "snapshotID": packet["snapshotID"]!, "action": (packet["allowedActions"] as? [String])!.first!, "followUp": flags.2]
            let content = flags.0 ? "你天生反叛，必与上司冲突" : String(decoding: try JSONSerialization.data(withJSONObject: selection), as: UTF8.self)
            let response = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": content]]]])
            if flags.1 > 0 { Thread.sleep(forTimeInterval: flags.1) }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
