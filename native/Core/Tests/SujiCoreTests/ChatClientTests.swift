import Foundation
import XCTest
@testable import SujiCore

final class ChatClientTests: XCTestCase {
    func testManagedBackendUsesSupabaseSessionAndFixedRoute() async throws {
        let captured = LockedBox<URLRequest?>(nil)
        StubURLProtocol.handler = { request in
            captured.value = request
            return .json(status: 200, body: #"{"choices":[{"message":{"role":"assistant","content":"你好"}}]}"#)
        }
        let configuration = try ManagedAI.configuration(supabase: SupabaseConfiguration(
            url: URL(string: "https://project.supabase.co")!, anonKey: "public-key"
        ))
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        let client = ChatClient(configuration: configuration, credential: "user-session", session: URLSession(configuration: sessionConfiguration))
        _ = try await client.complete(messages: [ChatMessage(role: .user, content: "你好")])
        let request = try XCTUnwrap(captured.value)
        XCTAssertEqual(request.url?.absoluteString, "https://project.supabase.co/functions/v1/suji-chat/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user-session")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "public-key")
        XCTAssertEqual(try requestJSONObject(request)["model"] as? String, "deepseek-flash")
    }

    func testManagedBackendRejectsInsecureOrCredentialBearingURLs() {
        for url in ["http://project.test", "https://user:password@project.test", "https://project.test?token=x"] {
            XCTAssertThrowsError(try ManagedAI.configuration(supabase: SupabaseConfiguration(url: URL(string: url)!, anonKey: "public")))
        }
        XCTAssertTrue(ChatClientError.httpStatus(status: 429, body: #"{"error":{"code":"daily_limit"}}"#).localizedDescription.contains("明天"))
        XCTAssertTrue(ChatClientError.httpStatus(status: 429, body: "{}").localizedDescription.contains("一分钟"))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        StubURLProtocol.onStop = nil
        super.tearDown()
    }

    func testChatCompletionsPayloadPreservesHistoryToolCallIDsAndDefinitions() async throws {
        let captured = LockedBox<URLRequest?>(nil)
        StubURLProtocol.handler = { request in
            captured.value = request
            return .json(
                status: 200,
                body: #"{"choices":[{"message":{"role":"assistant","content":"整合后的回答"}}]}"#
            )
        }
        let client = makeClient(
            url: "https://example.test/v1",
            credential: "secret"
        )
        let call = ChatToolCall(id: "call-42", name: "get_today_context", arguments: ["day": "2026-09-19"])
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "system"),
            ChatMessage(role: .user, content: "上一问"),
            .assistantToolCalls([call]),
            .toolResult(ChatToolResult(callID: "call-42", output: #"{"solarTerm":"白露"}"#)),
            ChatMessage(role: .user, content: "那今天呢？"),
        ]
        let tool = ChatToolDefinition(
            name: "get_today_context",
            description: "今日上下文",
            parameters: [
                "type": "object",
                "properties": ["day": ["type": "string"]],
                "required": ["day"],
            ]
        )

        let result = try await client.complete(messages: messages, tools: [tool])

        XCTAssertEqual(result, .text("整合后的回答"))
        let request = try XCTUnwrap(captured.value)
        XCTAssertEqual(request.url?.absoluteString, "https://example.test/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        let body = try requestJSONObject(request)
        XCTAssertEqual(body["model"] as? String, "test-model")
        XCTAssertEqual(body["stream"] as? Bool, false)
        let sentMessages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(sentMessages.count, 5)
        let assistantCalls = try XCTUnwrap(sentMessages[2]["tool_calls"] as? [[String: Any]])
        XCTAssertEqual(assistantCalls[0]["id"] as? String, "call-42")
        let function = try XCTUnwrap(assistantCalls[0]["function"] as? [String: Any])
        XCTAssertEqual(function["name"] as? String, "get_today_context")
        XCTAssertEqual(sentMessages[3]["tool_call_id"] as? String, "call-42")
        XCTAssertEqual(sentMessages[4]["content"] as? String, "那今天呢？")
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        let sentDefinition = try XCTUnwrap(tools[0]["function"] as? [String: Any])
        XCTAssertEqual(sentDefinition["name"] as? String, "get_today_context")
    }

    func testChatCompletionsReturnsToolCallsWithoutLosingIDOrArguments() async throws {
        StubURLProtocol.handler = { _ in
            .json(
                status: 200,
                body: #"{"choices":[{"message":{"tool_calls":[{"id":"abc","type":"function","function":{"name":"cast_liuyao","arguments":"{\"seed\":7}"}}]}}]}"#
            )
        }

        let result = try await makeClient(url: "https://example.test/v1", credential: "key")
            .complete(messages: [ChatMessage(role: .user, content: "起卦")], tools: [])

        XCTAssertEqual(
            result,
            .toolCalls([ChatToolCall(id: "abc", name: "cast_liuyao", arguments: ["seed": 7])])
        )
    }

    func testResponsesAzurePayloadUsesAPIKeyAndPairedFunctionItems() async throws {
        let captured = LockedBox<URLRequest?>(nil)
        StubURLProtocol.handler = { request in
            captured.value = request
            return .json(
                status: 200,
                body: #"{"output":[{"type":"function_call","call_id":"next-9","name":"get_timing","arguments":"{\"year\":2027}"}]}"#
            )
        }
        let url = "https://suji.services.ai.azure.com/openai/v1/responses?api-version=2025-04-01-preview"
        let previous = ChatToolCall(id: "prior-1", name: "get_bazi_star", arguments: ["star": "正官"])
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "system"),
            ChatMessage(role: .user, content: "看事业"),
            .assistantToolCalls([previous]),
            .toolResult(ChatToolResult(callID: "prior-1", output: #"{"strength":"strong"}"#)),
        ]

        let result = try await makeClient(url: url, credential: "azure-secret")
            .complete(
                messages: messages,
                tools: [ChatToolDefinition(name: "get_timing", description: "流年", parameters: ["type": "object"])]
            )

        XCTAssertEqual(result, .toolCalls([ChatToolCall(id: "next-9", name: "get_timing", arguments: ["year": 2027])]))
        let request = try XCTUnwrap(captured.value)
        XCTAssertEqual(request.url?.absoluteString, url)
        XCTAssertEqual(request.value(forHTTPHeaderField: "api-key"), "azure-secret")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try requestJSONObject(request)
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        XCTAssertEqual(input[2]["type"] as? String, "function_call")
        XCTAssertEqual(input[2]["call_id"] as? String, "prior-1")
        XCTAssertEqual(input[3]["type"] as? String, "function_call_output")
        XCTAssertEqual(input[3]["call_id"] as? String, "prior-1")
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools[0]["name"] as? String, "get_timing")
        XCTAssertNil(tools[0]["function"])
    }

    func testBothProviderAPIsPreserveExactSourceDirectoryBeforeItsToolCall() async throws {
        let fixture=try CastSourceTestFixture.make()
        for api in [ChatAPIStyle.chatCompletions,.responses] {
            let captured=LockedBox<URLRequest?>(nil)
            StubURLProtocol.handler={request in
                captured.value=request
                return .json(status:200,body:api == .responses
                    ? #"{"output":[{"type":"message","content":[{"type":"output_text","text":"已核对"}]}]}"#
                    : #"{"choices":[{"message":{"role":"assistant","content":"已核对"}}]}"#)
            }
            let messages=fixture.prefix+[fixture.tool]
            _ = try await makeClient(url:"https://example.test/v1",credential:"key",api:api).complete(messages:messages)
            let body=try requestJSONObject(XCTUnwrap(captured.value))
            let sent=try XCTUnwrap(body[api == .responses ? "input" : "messages"] as? [[String:Any]])
            XCTAssertEqual(sent.count,4)
            XCTAssertEqual(sent[1]["role"] as? String,"system")
            if api == .responses {
                let content=try XCTUnwrap(sent[1]["content"] as? [[String:Any]])
                XCTAssertEqual(content.first?["text"] as? String,fixture.directory.content)
                XCTAssertEqual(sent[2]["call_id"] as? String,fixture.receipt.callID)
                XCTAssertEqual(sent[3]["output"] as? String,fixture.tool.content)
            } else {
                XCTAssertEqual(sent[1]["content"] as? String,fixture.directory.content)
                XCTAssertNotNil(sent[2]["tool_calls"])
                XCTAssertEqual(sent[3]["content"] as? String,fixture.tool.content)
            }
        }
    }

    func testBothProviderAPIsRejectDetachedDirectoryReferenceBeforeNetwork() async throws {
        let fixture=try CastSourceTestFixture.make()
        let count=LockedBox(0)
        StubURLProtocol.handler={_ in
            count.value += 1
            return .json(status:200,body:#"{"choices":[{"message":{"content":"unexpected"}}]}"#)
        }
        for api in [ChatAPIStyle.chatCompletions,.responses] {
            let client=makeClient(url:"https://example.test/v1",credential:"key",api:api)
            let detached=[ChatMessage.assistantToolCalls([fixture.receipt.call]),fixture.tool]
            do { _ = try await client.complete(messages:detached);XCTFail("Missing directory must fail before complete") }
            catch { guard case .invalidConfiguration = error as? ChatClientError else {return XCTFail("Unexpected error: \(error)")} }
            do { for try await _ in client.streamText(messages:detached) {};XCTFail("Missing directory must fail before streaming") }
            catch { guard case .invalidConfiguration = error as? ChatClientError else {return XCTFail("Unexpected error: \(error)")} }
        }
        XCTAssertEqual(count.value,0)
    }

    func testStreamingChatCompletionsEmitsDeltasAcrossArbitraryByteChunks() async throws {
        let streamBytes = Data((
            "data: {\"choices\":[{\"delta\":{\"content\":\"春\"}}]}\r\n\r\n" +
            "data: {\"choices\":[{\"delta\":{\"content\":\"风\"},\"finish_reason\":null}]}\n\n" +
            "data: [DONE]\n\n"
        ).utf8)
        let scalarBoundary = try XCTUnwrap(streamBytes.firstIndex(of: 0xE6)) + 1
        let firstChunk = Data(streamBytes.prefix(scalarBoundary))
        let secondChunk = Data(streamBytes[scalarBoundary..<(scalarBoundary + 1)])
        let thirdChunk = Data(streamBytes.suffix(from: scalarBoundary + 1))
        StubURLProtocol.handler = { _ in
            .eventStream(status: 200, chunks: [firstChunk, secondChunk, thirdChunk])
        }

        var deltas: [String] = []
        for try await delta in makeClient(url: "https://example.test/v1", credential: "key")
            .streamText(messages: [ChatMessage(role: .user, content: "写两个字")]) {
            deltas.append(delta)
        }

        XCTAssertEqual(deltas, ["春", "风"])
    }

    func testSuccessTerminalFinishesWithoutWaitingForTransportClose() async throws {
        let stopped = expectation(description: "terminal cancels transport")
        StubURLProtocol.handler = { _ in
            .response(
                status: 200,
                headers: ["Content-Type": "text/event-stream"],
                chunks: [Data("data: {\"choices\":[{\"delta\":{\"content\":\"完成\"}}]}\n\ndata: [DONE]\n\n".utf8)],
                finish: false
            )
        }
        StubURLProtocol.onStop = { stopped.fulfill() }
        let finished = expectation(description: "consumer finishes")
        let result = LockedBox<Result<[String], Error>?>(nil)
        let client = makeClient(url: "https://terminal.test/v1", credential: "key")
        let consumer = Task {
            do {
                var values: [String] = []
                for try await delta in client.streamText(messages: [ChatMessage(role: .user, content: "hello")]) {
                    values.append(delta)
                }
                result.value = .success(values)
            } catch { result.value = .failure(error) }
            finished.fulfill()
        }
        defer { consumer.cancel() }

        await fulfillment(of: [finished, stopped], timeout: 2)
        XCTAssertEqual(try result.value?.get(), ["完成"])
    }

    func testEventsAfterSuccessTerminalAreIgnored() async throws {
        StubURLProtocol.handler = { _ in
            .eventStream(status: 200, chunks: [Data((
                "data: {\"choices\":[{\"delta\":{\"content\":\"完成\"}}]}\n\n" +
                "data: [DONE]\n\n" +
                "event: error\n" +
                "data: {\"error\":{\"message\":\"must be ignored\"}}\n\n"
            ).utf8)])
        }
        var deltas: [String] = []

        for try await delta in makeClient(url: "https://terminal.test/v1", credential: "key")
            .streamText(messages: [ChatMessage(role: .user, content: "hello")]) {
            deltas.append(delta)
        }

        XCTAssertEqual(deltas, ["完成"])
    }

    func testResponsesFailureEventThrowsServerErrorAfterPreservingEarlierDelta() async throws {
        StubURLProtocol.handler = { _ in
            .eventStream(
                status: 200,
                chunks: [Data((
                    "event: response.output_text.delta\n" +
                    "data: {\"type\":\"response.output_text.delta\",\"delta\":\"已收到\"}\n\n" +
                    "event: response.failed\n" +
                    "data: {\"type\":\"response.failed\",\"response\":{\"error\":{\"message\":\"quota exhausted\"}}}\n\n"
                ).utf8)]
            )
        }
        var deltas: [String] = []

        do {
            for try await delta in makeClient(url: "https://example.test/v1/responses", credential: "key")
                .streamText(messages: [ChatMessage(role: .user, content: "hello")]) {
                deltas.append(delta)
            }
            XCTFail("Expected the terminal failure to throw")
        } catch {
            XCTAssertEqual(error as? ChatClientError, .server("quota exhausted"))
        }
        XCTAssertEqual(deltas, ["已收到"])
    }

    func testStreamEndingWithoutDoneOrFinishThrowsIncompleteStream() async throws {
        StubURLProtocol.handler = { _ in
            .eventStream(status: 200, chunks: [Data("data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n".utf8)])
        }

        do {
            for try await _ in makeClient(url: "https://example.test/v1", credential: "key")
                .streamText(messages: [ChatMessage(role: .user, content: "hello")]) {}
            XCTFail("Expected an incomplete stream error")
        } catch {
            XCTAssertEqual(error as? ChatClientError, .incompleteStream)
        }
    }

    func testMissingCredentialFailsBeforeStartingARequestButNoneAuthIsAllowed() async throws {
        let requests = LockedBox(0)
        StubURLProtocol.handler = { _ in
            requests.value += 1
            return .json(status: 200, body: #"{"choices":[{"message":{"content":"ok"}}]}"#)
        }
        let configuration = ChatProviderConfiguration(
            baseURL: URL(string: "https://local.test/v1")!,
            model: "local",
            authentication: .automatic
        )

        do {
            _ = try await ChatClient(configuration: configuration, credential: nil, session: makeSession())
                .complete(messages: [ChatMessage(role: .user, content: "hello")])
            XCTFail("Expected missing credential")
        } catch {
            XCTAssertEqual(error as? ChatClientError, .missingCredential)
        }
        XCTAssertEqual(requests.value, 0)

        var noAuthConfiguration = configuration
        noAuthConfiguration.authentication = .none
        let result = try await ChatClient(configuration: noAuthConfiguration, credential: nil, session: makeSession())
            .complete(messages: [ChatMessage(role: .user, content: "hello")])
        XCTAssertEqual(result, .text("ok"))
        XCTAssertEqual(requests.value, 1)
    }

    func testInvalidConfigurationFailsBeforeStartingARequest() async throws {
        let requests = LockedBox(0)
        StubURLProtocol.handler = { _ in
            requests.value += 1
            return .json(status: 200, body: #"{"choices":[{"message":{"content":"unexpected"}}]}"#)
        }
        let client = ChatClient(
            configuration: ChatProviderConfiguration(
                baseURL: URL(string: "relative/path")!,
                model: "test-model",
                authentication: .none
            ),
            credential: nil,
            session: makeSession()
        )

        do {
            _ = try await client.complete(messages: [ChatMessage(role: .user, content: "hello")])
            XCTFail("Expected invalid configuration")
        } catch {
            XCTAssertEqual(
                error as? ChatClientError,
                .invalidConfiguration("Base URL must be an absolute HTTP(S) URL")
            )
        }
        XCTAssertEqual(requests.value, 0)
    }

    func testHTTPAuthenticationAndServiceErrorsAreDistinct() async throws {
        StubURLProtocol.handler = { request in
            if request.url?.host == "auth.test" {
                return .json(status: 401, body: #"{"error":{"message":"bad key"}}"#)
            }
            return .json(status: 503, body: "maintenance")
        }

        do {
            _ = try await makeClient(url: "https://auth.test/v1", credential: "bad")
                .complete(messages: [ChatMessage(role: .user, content: "hello")])
            XCTFail("Expected authentication error")
        } catch {
            XCTAssertEqual(error as? ChatClientError, .authentication(status: 401, body: #"{"error":{"message":"bad key"}}"#))
        }

        do {
            for try await _ in makeClient(url: "https://service.test/v1", credential: "key")
                .streamText(messages: [ChatMessage(role: .user, content: "hello")]) {}
            XCTFail("Expected service error")
        } catch {
            XCTAssertEqual(error as? ChatClientError, .httpStatus(status: 503, body: "maintenance"))
        }
    }

    func testLocalizedErrorsDistinguishRecoveryActionsWithoutEchoingServerDetails() {
        let authentication = ChatClientError.authentication(status: 401, body: "secret upstream response")
        let service = ChatClientError.httpStatus(status: 503, body: "private maintenance detail")
        let transport = ChatClientError.transport("socket diagnostics")
        let incomplete = ChatClientError.incompleteStream

        XCTAssertTrue(authentication.localizedDescription.contains("身份验证"))
        XCTAssertTrue(authentication.localizedDescription.contains("重新登录"))
        XCTAssertTrue(service.localizedDescription.contains("503"))
        XCTAssertTrue(service.localizedDescription.contains("稍后重试"))
        XCTAssertTrue(transport.localizedDescription.contains("网络"))
        XCTAssertTrue(incomplete.localizedDescription.contains("重试"))

        XCTAssertNotEqual(authentication.localizedDescription, service.localizedDescription)
        XCTAssertNotEqual(service.localizedDescription, transport.localizedDescription)
        XCTAssertNotEqual(transport.localizedDescription, incomplete.localizedDescription)
        XCTAssertFalse(authentication.localizedDescription.contains("secret upstream response"))
        XCTAssertFalse(service.localizedDescription.contains("private maintenance detail"))
        XCTAssertFalse(authentication.localizedDescription.contains("ChatClientError"))
    }

    func testCancellingConsumerCancelsUnderlyingURLSessionLoad() async throws {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request cancelled")
        StubURLProtocol.handler = { _ in
            started.fulfill()
            return .pending
        }
        StubURLProtocol.onStop = { stopped.fulfill() }
        let client = makeClient(url: "https://cancel.test/v1", credential: "key")
        let consumer = Task {
            do {
                for try await _ in client.streamText(messages: [ChatMessage(role: .user, content: "hello")]) {}
                return nil as ChatClientError?
            } catch {
                return error as? ChatClientError
            }
        }

        await fulfillment(of: [started], timeout: 2)
        consumer.cancel()
        await fulfillment(of: [stopped], timeout: 2)
        _ = await consumer.value
        XCTAssertTrue(consumer.isCancelled)
    }

    private func makeClient(
        url: String,
        credential: String?,
        api: ChatAPIStyle = .automatic,
        authentication: ChatAuthenticationStyle = .automatic
    ) -> ChatClient {
        ChatClient(
            configuration: ChatProviderConfiguration(
                baseURL: URL(string: url)!,
                model: "test-model",
                api: api,
                authentication: authentication
            ),
            credential: credential,
            session: makeSession()
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func requestJSONObject(_ request: URLRequest) throws -> [String: Any] {
        let data: Data
        if let body = request.httpBody {
            data = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var output = Data()
            var bytes = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                output.append(bytes, count: count)
            }
            data = output
        } else {
            throw XCTSkip("URLProtocol did not expose the request body")
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class LockedBox<Value> {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) { storage = value }

    var value: Value {
        get { lock.withLock { storage } }
        set { lock.withLock { storage = newValue } }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Reply {
        case response(status: Int, headers: [String: String], chunks: [Data], finish: Bool)
        case pending

        static func json(status: Int, body: String) -> Reply {
            .response(status: status, headers: ["Content-Type": "application/json"], chunks: [Data(body.utf8)], finish: true)
        }

        static func eventStream(status: Int, chunks: [Data]) -> Reply {
            .response(status: status, headers: ["Content-Type": "text/event-stream"], chunks: chunks, finish: true)
        }
    }

    static var handler: ((URLRequest) throws -> Reply)?
    static var onStop: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let reply = try Self.handler?(request) else {
                throw URLError(.unsupportedURL)
            }
            switch reply {
            case .pending:
                break
            case let .response(status, headers, chunks, finish):
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                for chunk in chunks {
                    client?.urlProtocol(self, didLoad: chunk)
                }
                if finish { client?.urlProtocolDidFinishLoading(self) }
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        Self.onStop?()
    }
}
