import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class CastQuestionConfirmationTests: XCTestCase {
    private let call = ChatToolCall(id: "f4-omission", name: "setup_qimen", arguments: ["question": "我自己近期能否签下新办公室租约", "questionType": "event", "subject": "self", "timeHorizon": "near"])
    private func context() throws -> ToolContext {
        try ToolContext(birth: nil, engineRevision: "f6-native", referenceDate: Date(timeIntervalSince1970: 1789880000), mode: "起卦")
    }
    private func waitForPending(_ gate: CastQuestionConfirmation) async throws -> CastQuestionConfirmation.Request {
        for _ in 0..<500 {
            if let request = gate.pending { return request }
            try await Task.sleep(for: .milliseconds(2))
        }
        throw EngineError.execution("Confirmation did not appear")
    }

    private func waitUntilIdle(_ session: ChatSession) async throws {
        for _ in 0..<1000 {
            if !session.working { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw EngineError.execution("Chat did not finish")
    }

    private func makeClient() -> ChatClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CastPlannerProtocol.self]
        return ChatClient(configuration: .init(baseURL: URL(string: "https://cast-fixture.invalid/v1")!, model: "synthetic", api: .chatCompletions, authentication: .none), credential: nil, session: URLSession(configuration: config))
    }

    func testActualChatPersistsBeforeCastAndRestoredRetryReusesOriginalReceipt() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: "f6-synthetic")
        let session = ChatSession(makeClient: { _ in self.makeClient() })
        session.send("请用奇门问我自己近期能否签下新办公室租约，先只核对日干、时干、事项参考的盘面依据。", mode: "起卦", store: store)
        let request = try await waitForPending(session.castConfirmation)
        XCTAssertTrue(store.state.conversations[0].toolReceipts?.isEmpty ?? true)
        XCTAssertNil(store.state.conversations[0].confirmedCastQuestions)
        var drafts = request.drafts; drafts[0].event = "签下新办公室租约"
        session.castConfirmation.confirm(id: request.id, drafts: drafts)
        try await waitUntilIdle(session)
        XCTAssertNil(session.failure)
        let source = try XCTUnwrap(store.state.conversations.first)
        XCTAssertEqual(source.confirmedCastQuestions?.count, 1)
        let receipt = try XCTUnwrap(source.toolReceipts?.first)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(receipt.output.utf8)) as? [String: Any])
        XCTAssertEqual((raw["questionContext"] as? [String: Any])?["event"] as? String, "签下新办公室租约")
        XCTAssertEqual(source.confirmedCastQuestions?.first?.context.referenceDate, source.date)
        let restored = try AppStore(context: container.mainContext, scriptURL: script, userID: "f6-synthetic")
        XCTAssertEqual(restored.state.conversations.first?.confirmedCastQuestions, source.confirmedCastQuestions)
        let retry = ChatSession(makeClient: { _ in self.makeClient() })
        retry.send(source.text, mode: "命理", store: restored, appendUser: false)
        try await waitUntilIdle(retry)
        XCTAssertNil(retry.failure)
        XCTAssertNil(retry.castConfirmation.pending)
        XCTAssertEqual(restored.state.conversations.first?.toolReceipts, source.toolReceipts)
        XCTAssertEqual(restored.state.conversations.first?.confirmedCastQuestions, source.confirmedCastQuestions)
    }

    func testReferenceOnlyLiuyaoFirstReadingAndPersistedRetryKeepScope() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: "reference-only-liuyao")
        let session = ChatSession(makeClient: { _ in self.makeClient() })
        session.send("请用六爻核对我自己的身体情况", mode: "起卦", store: store)
        let request = try await waitForPending(session.castConfirmation)
        var drafts = request.drafts
        XCTAssertEqual(drafts[0].proposedCall.name, "cast_liuyao")
        drafts[0].questionType = "health"; drafts[0].subject = "self"
        drafts[0].event = "我自己的身体情况"; drafts[0].referenceOnly = true
        session.castConfirmation.confirm(id: request.id, drafts: drafts)
        try await waitUntilIdle(session)
        XCTAssertNil(session.failure)
        let source = try XCTUnwrap(store.state.conversations.first)
        XCTAssertEqual(source.confirmedCastQuestions?.first?.referenceOnly, true)
        let text = try XCTUnwrap(store.state.conversations.last?.text)
        XCTAssertFalse(text.contains("事件方向（")); XCTAssertFalse(text.contains("事件候选"))
        let receipt = try XCTUnwrap(source.toolReceipts?.first)
        let chart = try CastReceiptStorage.expanded(receipt.output)
        if case let .object(root) = chart { XCTAssertNotNil(root["eventAssessment"]) } else { XCTFail("Missing complete receipt") }
        let restored = try AppStore(context: container.mainContext, scriptURL: script, userID: "reference-only-liuyao")
        let retry = ChatSession(makeClient: { _ in self.makeClient() })
        retry.send(source.text, mode: "起卦", store: restored, appendUser: false)
        try await waitUntilIdle(retry)
        XCTAssertNil(retry.failure)
        XCTAssertEqual(restored.state.conversations.first?.toolReceipts, source.toolReceipts)
        XCTAssertEqual(restored.state.conversations.last?.text, text)
    }

    func testActualChatStopAndAccountChangeCannotConfirmOrCalculate() async throws {
        for changeAccount in [false, true] {
            let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let store = try AppStore(context: container.mainContext, scriptURL: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), userID: "f6-synthetic")
            let session = ChatSession(makeClient: { _ in self.makeClient() })
            session.send("请用奇门只核对盘面", mode: "起卦", store: store)
            let request = try await waitForPending(session.castConfirmation)
            if changeAccount { try await store.switchAccount(from: "f6-synthetic", to: "other") }
            else { session.stop() }
            var drafts = request.drafts; drafts[0].event = "不应进入盘面"
            session.castConfirmation.confirm(id: request.id, drafts: drafts)
            try await waitUntilIdle(session)
            if changeAccount { try await store.switchAccount(from: "other", to: "f6-synthetic") }
            XCTAssertTrue(store.state.conversations[0].toolReceipts?.isEmpty ?? true)
            XCTAssertNil(store.state.conversations[0].confirmedCastQuestions)
        }
    }

    func testMissingEventKeepsWaitingUntilEditedConfirmation() async throws {
        let gate = CastQuestionConfirmation()
        let userID = UUID(), context = try context()
        var returned = false
        let task = Task { let result = try await gate.request(calls: [call], originalQuestion: "原始提问", userID: userID, context: context, checkScope: {}); returned = true; return result }
        let request = try await waitForPending(gate)
        gate.confirm(id: request.id, drafts: request.drafts)
        XCTAssertNotNil(gate.validationFailure)
        XCTAssertNotNil(gate.pending)
        XCTAssertFalse(returned)
        var drafts = request.drafts; drafts[0].event = "签下新办公室租约"
        gate.confirm(id: request.id, drafts: drafts)
        let result = try await task.value
        XCTAssertNil(gate.pending)
        XCTAssertEqual(result.first?.call.arguments, ["question": "我自己近期能否签下新办公室租约", "questionType": "event", "subject": "self", "timeHorizon": "near", "event": "签下新办公室租约"])
        XCTAssertEqual(result.first?.userID, userID)
        XCTAssertEqual(result.first?.context.referenceDate, context.referenceDate)
        // A second tap cannot resume the continuation again.
        gate.confirm(id: request.id, drafts: drafts)
    }

    func testTaskCancellationReleasesWaitAndStaleSheetCannotConfirmNextRequest() async throws {
        let gate = CastQuestionConfirmation(), context = try context()
        let first = Task { try await gate.request(calls: [call], originalQuestion: "first", userID: UUID(), context: context, checkScope: {}) }
        let previous = try await waitForPending(gate)
        first.cancel()
        do { _ = try await first.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(gate.pending)
        let second = Task { try await gate.request(calls: [call], originalQuestion: "second", userID: UUID(), context: context, checkScope: {}) }
        let current = try await waitForPending(gate)
        var oldDrafts = previous.drafts; oldDrafts[0].event = "不应被接受"
        gate.confirm(id: previous.id, drafts: oldDrafts)
        gate.cancel(id: previous.id)
        XCTAssertEqual(gate.pending?.id, current.id)
        gate.cancel(id: current.id)
        do { _ = try await second.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testScopeChangeRejectsEvenBeforeViewObservationCancels() async throws {
        let gate = CastQuestionConfirmation(), context = try context()
        var scopeMatches = true
        let task = Task { try await gate.request(calls: [call], originalQuestion: "scope", userID: UUID(), context: context, checkScope: { if !scopeMatches { throw CancellationError() } }) }
        let request = try await waitForPending(gate)
        scopeMatches = false
        var drafts = request.drafts; drafts[0].event = "签约"
        gate.confirm(id: request.id, drafts: drafts)
        do { _ = try await task.value; XCTFail() } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(gate.pending)
    }

    func testReferenceOnlyExplicitlyAllowsMissingEventAndUnknownScope() async throws {
        let gate = CastQuestionConfirmation(), context = try context()
        let task = Task { try await gate.request(calls: [ChatToolCall(id: "reference", name: "cast_liuyao", arguments: ["question": "核对盘面"])], originalQuestion: "核对盘面", userID: UUID(), context: context, checkScope: {}) }
        let request = try await waitForPending(gate)
        var drafts = request.drafts; drafts[0].referenceOnly = true
        gate.confirm(id: request.id, drafts: drafts)
        let result = try await task.value
        XCTAssertEqual(result.first?.referenceOnly, true)
        XCTAssertEqual(result.first?.call.arguments, ["question": "核对盘面", "questionType": "general", "subject": "unknown", "timeHorizon": "unspecified"])
    }
}

private final class CastPlannerProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "cast-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)) }
            }
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let hasResult = (body["messages"] as? [[String: Any]] ?? []).contains { $0["role"] as? String == "tool" }
            let definitions = body["tools"] as? [[String: Any]] ?? []
            let liuyao = definitions.contains { ($0["function"] as? [String: Any])?["name"] as? String == "cast_liuyao" }
            let plannedName = liuyao ? "cast_liuyao" : "setup_qimen"
            let message: [String: Any] = hasResult ? ["role": "assistant", "content": "工具结果已读取"] : ["role": "assistant", "tool_calls": [["id": "call_00_38IbWgAki7a6Um1N8aoe8763", "type": "function", "function": ["name": plannedName, "arguments": "{\"question\":\"我自己近期能否签下新办公室租约\",\"questionType\":\"event\",\"subject\":\"self\",\"timeHorizon\":\"near\"}"]]]]
            let response = try JSONSerialization.data(withJSONObject: ["choices": [["message": message, "finish_reason": hasResult ? "stop" : "tool_calls"]]])
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
