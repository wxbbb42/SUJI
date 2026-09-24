import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Operator-only real integration. Credentials and all notebook data belong to a
/// disposable test account. The observer forwards real HTTP bytes without mocks.
@MainActor final class LiveReadingSessionTests: XCTestCase {
    struct Turn: Decodable { let question: String; let kind: String }
    struct Case: Decodable {
        let id: String; let profile: String; let mode: String; let question: String
        let expected: String; let expectation: String; let turns: [Turn]
        let cast: [String: String]?
    }
    struct Matrix: Decodable { let syntheticOnly: Bool; let profiles: [String: BirthProfile]; let cases: [Case] }
    struct Configuration: Decodable {
        let email: String; let password: String; let reportPath: String
        let matrixPath: String; let caseIDs: [String]
    }

    func testAuthenticatedReadingJourney() async throws {
        guard let path = ProcessInfo.processInfo.environment["SUJI_LIVE_READING_CONFIG"] else {
            throw XCTSkip("Requires the explicit disposable-account live test launcher")
        }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let matrix = try JSONDecoder().decode(Matrix.self, from: Data(contentsOf: URL(fileURLWithPath: config.matrixPath)))
        guard matrix.syntheticOnly else { throw EngineError.execution("Live fixtures must be explicitly synthetic") }
        let previousSession = try KeychainStore.read("supabase-session")
        try KeychainStore.write(nil, name: "supabase-session")
        defer { try? KeychainStore.write(previousSession, name: "supabase-session") }
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: nil)
        await store.accountSession.signIn(email: config.email, password: config.password)
        try XCTUnwrap(store.accountSession.user)
        XCTAssertTrue(store.isSignedIn)
        var results: [[String: Any]] = []
        LiveHTTPObserver.reset()
        for item in matrix.cases where config.caseIDs.contains(item.id) {
            let birth = try XCTUnwrap(matrix.profiles[item.profile])
            // Only the disposable account's in-memory notebook is changed.
            store.state.conversations = []
            try await store.updateBirth(birth)
            let dossier = try await store.ensureNatalDossier()
            for (turnIndex, turn) in ([Turn(question: item.question, kind: "independent")] + item.turns).enumerated() {
                let start = LiveHTTPObserver.exchanges.count
                let oldReceipts = store.state.conversations.last(where: { $0.role == "user" })?.toolReceipts
                let oldCount = store.state.conversations.count
                let session = ChatSession(makeClient: { store in
                    let backend = try XCTUnwrap(AccountSession.configuration(in: .main))
                    let user = try XCTUnwrap(store.accountSession.user?.id)
                    let token = try await store.accountSession.aiAccessToken(for: user)
                    let transport = URLSessionConfiguration.ephemeral
                    transport.protocolClasses = [LiveHTTPObserver.self]
                    return ChatClient(configuration: try ManagedAI.configuration(supabase: backend), credential: token, session: URLSession(configuration: transport))
                })
                session.send(turn.question, mode: item.mode, store: store, appendUser: turn.kind != "retry")
                let deadline = Date().addingTimeInterval(300)
                var confirmationFailure: String?
                while session.working && Date() < deadline {
                    if let pending = session.castConfirmation.pending {
                        if let input = item.cast {
                            let drafts = pending.drafts.map { proposed in
                                var edited = proposed
                                edited.question = item.question
                                edited.subject = input["subject"]!; edited.questionType = input["questionType"]!
                                edited.event = input["event"]!; edited.timeHorizon = input["timeHorizon"]!
                                return edited
                            }
                            session.castConfirmation.confirm(id: pending.id, drafts: drafts)
                            if let error = session.castConfirmation.validationFailure { confirmationFailure = error; session.stop() }
                        } else { confirmationFailure = "Unexpected cast requested for a non-cast scenario"; session.stop() }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let timedOut = session.working
                if timedOut { session.stop(); try await Task.sleep(for: .milliseconds(300)) }
                let source = try XCTUnwrap(store.state.conversations.last { $0.role == "user" })
                let answer = store.state.conversations.last { $0.role == "assistant" && $0.date >= source.date }?.text ?? ""
                let receipts = source.toolReceipts ?? []
                let restored = try AppStore(context: container.mainContext, scriptURL: script, userID: store.accountSession.user?.id)
                let replayOK = restored.state.conversations.last?.text == store.state.conversations.last?.text
                    && restored.state.conversations.last(where: { $0.role == "user" })?.toolReceipts == source.toolReceipts
                let trace = Array(LiveHTTPObserver.exchanges.dropFirst(start))
                let result: [String: Any] = [
                    "id": item.id, "turn": turnIndex, "kind": turn.kind, "profile": item.profile,
                    "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth)),
                    "mode": item.mode, "question": turn.question, "expected": item.expected, "expectation": item.expectation,
                    "answer": answer, "failure": session.failure as Any? ?? NSNull(),
                    "confirmationFailure": confirmationFailure as Any? ?? NSNull(), "timedOut": timedOut,
                    "receipts": try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipts)),
                    "context": try JSONSerialization.jsonObject(with: JSONEncoder().encode(source.toolContext), options: [.fragmentsAllowed]),
                    "confirmations": try JSONSerialization.jsonObject(with: JSONEncoder().encode(source.confirmedCastQuestions), options: [.fragmentsAllowed]),
                    "dossierReused": store.natalDossier?.createdAt == dossier.createdAt, "archiveReplayOK": replayOK,
                    "retryPreservedReceipts": turn.kind == "retry" ? oldReceipts == source.toolReceipts : true,
                    "retryDidNotAppend": turn.kind == "retry" ? oldCount == store.state.conversations.count : true,
                    "exchanges": trace,
                    "executionOK": session.failure == nil && !answer.isEmpty && !timedOut && confirmationFailure == nil && replayOK,
                ]
                results.append(result)
                let report: [String: Any] = ["scope": "Production native ChatSession + engine + verifier; real deployed Supabase/DeepSeek; synthetic profiles; HTTP observer forwards bytes without substituting responses. executionOK is not semantic acceptance.", "promptVersion": ReadingPrompt.version, "results": results, "modelRequestCount": LiveHTTPObserver.exchanges.count]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
                    .write(to: URL(fileURLWithPath: config.reportPath), options: .atomic)
                print("LIVE_CASE \(item.id) turn=\(turnIndex) receipts=\(receipts.count) requests=\(trace.count) failure=\(session.failure ?? "none")")
                XCTAssertTrue(replayOK, item.id)
                XCTAssertFalse(timedOut, item.id)
                // Continue the matrix after a failed case; the report preserves
                // the error, while XCTest still exits nonzero for failed journeys.
                XCTAssertNil(session.failure, item.id)
                XCTAssertNil(confirmationFailure, item.id)
                XCTAssertFalse(answer.isEmpty, item.id)
            }
        }
    }
}

/// Transparent, test-bundle-only observer. Never records authorization headers.
/// A minimum 6.2 seconds between actual calls keeps this account below 12/minute;
/// 100 total calls per disposable batch leaves room below the existing daily cap.
final class LiveHTTPObserver: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var recorded: [[String: Any]] = []
    private static var nextRequest = Date.distantPast
    private static var count = 0
    private static var budget = 100
    private static var failNext = false
    private static let forwardingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = []
        return URLSession(configuration: config)
    }()
    private var forwardingTask: Task<Void, Never>?
    static var exchanges: [[String: Any]] { lock.withLock { recorded } }
    static func reset(maxRequests: Int = 100) { lock.withLock { recorded = []; nextRequest = .distantPast; count = 0; budget = maxRequests; failNext = false } }
    static func interruptNextRequest() { lock.withLock { failNext = true } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.path.contains("suji-chat") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        forwardingTask = Task {
            var trace: [String: Any] = [:]
            do {
                var outbound = request
                var data = request.httpBody ?? Data()
                if data.isEmpty, let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var buffer = [UInt8](repeating: 0, count: 8192)
                    while stream.hasBytesAvailable {
                        let n = stream.read(&buffer, maxLength: buffer.count)
                        if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n))
                    }
                }
                outbound.httpBodyStream = nil; outbound.httpBody = data
                let interrupted = Self.lock.withLock { let value = Self.failNext; Self.failNext = false; return value }
                if interrupted { trace["injectedTransportInterruption"] = true; throw URLError(.notConnectedToInternet) }
                trace["request"] = try JSONSerialization.jsonObject(with: data)
                trace["endpoint"] = outbound.url?.absoluteString
                let slot: (Date, Int) = Self.lock.withLock {
                    let scheduled = max(Date(), Self.nextRequest)
                    Self.nextRequest = scheduled.addingTimeInterval(6.2); Self.count += 1
                    return (scheduled, Self.count)
                }
                guard slot.1 <= Self.lock.withLock({ Self.budget }) else { throw EngineError.execution("Live test request budget exhausted") }
                let delay = slot.0.timeIntervalSinceNow
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                trace["startedAt"] = ISO8601DateFormatter().string(from: Date())
                let (body, response) = try await Self.forwardingSession.data(for: outbound)
                trace["status"] = (response as? HTTPURLResponse)?.statusCode
                trace["response"] = String(decoding: body, as: UTF8.self)
                Self.lock.withLock { Self.recorded.append(trace) }
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                trace["error"] = error.localizedDescription
                Self.lock.withLock { Self.recorded.append(trace) }
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
    override func stopLoading() { forwardingTask?.cancel() }
}
