import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class TodayReadingSessionTests: XCTestCase {
    private func wait(_ session: ChatSession) async throws {
        for _ in 0..<2000 {
            if !session.working { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw EngineError.execution("Today reading timed out")
    }

    private func client() -> ChatClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TodayReadingProtocol.self]
        return ChatClient(configuration: .init(baseURL: URL(string: "https://today-fixture.invalid/v1")!, model: "synthetic", api: .chatCompletions, authentication: .none), credential: nil, session: URLSession(configuration: config))
    }

    private func fixture() throws -> (ModelContainer, AppStore) {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: "today-test")
        store.state.birth = BirthProfile(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成测试", longitude: 120)
        try store.saveThrowing()
        return (container, store)
    }

    func testExplicitTodayQuestionAcquiresFactsBeforeAnyModelRequest() async throws {
        for question in ["今天适合干什么", "What should I do today?"] {
            TodayReadingProtocol.reset()
            let (container, store) = try fixture()
            defer { withExtendedLifetime(container) {} }
            let session = ChatSession(makeClient: { _ in self.client() })
            session.send(question, mode: "命理", store: store)
            try await wait(session)
            XCTAssertNil(session.failure)
            let receipt = try XCTUnwrap(store.state.conversations.first?.toolReceipts?.first)
            XCTAssertEqual(receipt.name, "get_today_context")
            XCTAssertEqual(store.state.conversations.first?.toolReceipts?.count, 1)
            let output = try Document(receiptOutput: receipt.output)
            XCTAssertFalse(output["todayGanZhi"].text.isEmpty)
            XCTAssertTrue(store.state.conversations.last?.text.contains(output["todayGanZhi"].text) == true)
            let requests = TodayReadingProtocol.requests
            XCTAssertEqual(requests.count, 2, "Only writing and verification use the model")
            for request in requests { XCTAssertTrue((request["tools"] as? [Any] ?? []).isEmpty) }
            let messages = try XCTUnwrap(requests.first?["messages"] as? [[String: Any]])
            XCTAssertTrue(messages.contains { $0["role"] as? String == "tool" })
            XCTAssertTrue((messages.first?["content"] as? String)?.contains(ReadingPrompt.todayWriter) == true)
        }
    }

    func testInvalidReviewKeepsFactsAndRestoredRetryDoesNotRecalculate() async throws {
        TodayReadingProtocol.reset(reject: true)
        let (container, store) = try fixture()
        defer { withExtendedLifetime(container) {} }
        let session = ChatSession(makeClient: { _ in self.client() })
        session.send("今天适合干什么", mode: "命理", store: store)
        try await wait(session)
        XCTAssertTrue(session.failure?.contains("未完成核对") == true)
        let source = try XCTUnwrap(store.state.conversations.first)
        let receipt = try XCTUnwrap(source.toolReceipts?.first)
        let day = try Document(receiptOutput: receipt.output)["todayGanZhi"].text
        XCTAssertTrue(store.state.conversations.last?.text.contains(day + "日") == true)
        XCTAssertFalse(store.state.conversations.last?.text.contains("未能与盘面核对一致") == true)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("engine.js")
        let bundled = try String(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), encoding: .utf8)
        try (bundled + "\nconst todayRun=SujiNative.run;SujiNative={...SujiNative,run:(json,resolve,reject)=>JSON.parse(json).command==='tool'?reject('unexpected recalculation'):todayRun(json,resolve,reject)};").write(to: script, atomically: true, encoding: .utf8)
        let restored = try AppStore(context: container.mainContext, scriptURL: script, userID: "today-test")
        TodayReadingProtocol.reset()
        let retry = ChatSession(makeClient: { _ in self.client() })
        retry.send(source.text, mode: "命理", store: restored, appendUser: false)
        try await wait(retry)
        XCTAssertNil(retry.failure)
        XCTAssertEqual(restored.state.conversations.first?.toolReceipts, source.toolReceipts)
        XCTAssertEqual(restored.state.conversations.count, 2)
        XCTAssertTrue(restored.state.conversations.last?.text.contains(day) == true)
        XCTAssertEqual(TodayReadingProtocol.requests.count, 2)
    }

    func testFailedToolAndRejectedDraftDoNotClaimASavedChart() async throws {
        TodayReadingProtocol.reset(asksForBirth: true)
        let (container, original) = try fixture()
        defer { withExtendedLifetime(container) {} }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = directory.appendingPathComponent("engine.js")
        let bundled = try String(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js")), encoding: .utf8)
        try (bundled + "\nconst failureRun=SujiNative.run;SujiNative={...SujiNative,run:(json,resolve,reject)=>JSON.parse(json).command==='tool'?reject('synthetic tool failure'):failureRun(json,resolve,reject)};").write(to: script, atomically: true, encoding: .utf8)
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: "today-test")
        let session = ChatSession(makeClient: { _ in self.client() })
        session.send("今天适合干什么", mode: "命理", store: store)
        try await wait(session)
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(session.failure?.contains("已计算的盘面已保留") == true)
        XCTAssertTrue(store.state.conversations.first?.toolReceipts?.isEmpty == true)
        XCTAssertTrue(store.state.conversations.last?.text.contains("没有可用的计算结果") == true)
        XCTAssertTrue(store.state.conversations.last?.text.contains("无需重新填写") == true)
        XCTAssertEqual(store.state.birth, original.state.birth)
    }
}

private final class TodayReadingProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recorded: [[String: Any]] = []
    private static var rejectReview = false
    private static var asksForBirth = false
    static var requests: [[String: Any]] { lock.withLock { recorded } }
    static func reset(reject: Bool = false, asksForBirth: Bool = false) {
        lock.withLock { recorded = []; rejectReview = reject; Self.asksForBirth = asksForBirth }
    }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "today-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
            }
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let reject = Self.lock.withLock { Self.recorded.append(body); return Self.rejectReview }
            let asksForBirth = Self.lock.withLock { Self.asksForBirth }
            let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
            let response: Data
            let mime: String
            if body["stream"] as? Bool == true {
                let text: String
                if asksForBirth {
                    text = "请补充出生日期和时间。"
                } else {
                    let raw = try XCTUnwrap(messages.last(where: { $0["role"] as? String == "tool" })?["content"] as? String)
                    let value = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
                    let day = try XCTUnwrap(value["todayGanZhi"] as? String)
                    text = "今日是\(day)日。可以按自己的安排选一件小事开始。"
                }
                let delta = try JSONSerialization.data(withJSONObject: ["choices": [["delta": ["content": text]]]])
                response = Data(("data: " + String(decoding: delta, as: UTF8.self) + "\n\ndata: [DONE]\n\n").utf8)
                mime = "text/event-stream"
            } else {
                let text = asksForBirth ? "请补充出生日期和时间。" : reject ? "invalid verification response" : #"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1,2],"issues":[]}"#
                response = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["role": "assistant", "content": text], "finish_reason": "stop"]]])
                mime = "application/json"
            }
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": mime])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
