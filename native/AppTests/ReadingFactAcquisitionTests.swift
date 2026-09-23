import XCTest
import SwiftData
import SujiCore
@testable import Suji

/// Regression for the observed planner-prose/no-receipt failure. This deliberately
/// fails the writer transport; it tests acquisition, not a mocked successful reading.
@MainActor final class ReadingFactAcquisitionTests: XCTestCase {
    func testSkippedPlannerAcquiresRealEngineFactsBeforeWriterAndPersistsForRetry() async throws {
        let container = try ModelContainer(for: SavedState.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let script = try XCTUnwrap(Bundle.main.url(forResource: "mingli", withExtension: "js"))
        let store = try AppStore(context: container.mainContext, scriptURL: script, userID: "synthetic-acquisition")
        store.state.birth = .init(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成测试", longitude: 120)
        try store.saveThrowing()
        func client() -> ChatClient {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [SkippedPlannerProtocol.self]
            return ChatClient(configuration: .init(baseURL: URL(string: "https://acquisition-fixture.invalid")!, model: "regression", authentication: .none), credential: nil, session: URLSession(configuration: config))
        }
        let session = ChatSession(makeClient: { _ in client() })
        session.send("我的财运怎么样", mode: "命理", store: store)
        while session.working { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertNotNil(session.failure, "Writer deliberately fails; no fake successful model result")
        let source = try XCTUnwrap(store.state.conversations.first)
        XCTAssertEqual(source.toolReceipts?.map(\.name), ["get_domain"])
        XCTAssertEqual(source.toolReceipts?.first?.arguments, ["domain": "财富"])
        let document = try Document(receiptOutput: XCTUnwrap(source.toolReceipts?.first?.output))
        XCTAssertEqual(document["bazi"]["pillars"]["month"]["ganZhi"]["gan"].text, "甲")
        let restored = try AppStore(context: container.mainContext, scriptURL: script, userID: "synthetic-acquisition")
        XCTAssertEqual(restored.state.conversations.first?.toolReceipts, source.toolReceipts)
        session.send(source.text, mode: "命理", store: restored, appendUser: false)
        while session.working { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(restored.state.conversations.first?.toolReceipts, source.toolReceipts, "Retry must keep the original receipt")
    }
}

private final class SkippedPlannerProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "acquisition-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 8192)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }; data.append(contentsOf: buffer.prefix(n))
            }
        }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let stream = object?["stream"] as? Bool == true
        let body = stream ? #"{"error":{"message":"deliberate writer failure"}}"# : #"{"choices":[{"message":{"content":"可以继续解释。"}}]}"#
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: stream ? 503 : 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
