import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class ChatClient: @unchecked Sendable {
    public let configuration: ChatProviderConfiguration
    private let credential: String?
    private let session: URLSession

    public init(
        configuration: ChatProviderConfiguration,
        credential: String?,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.credential = credential
        self.session = session
    }

    public func complete(
        messages: [ChatMessage],
        tools: [ChatToolDefinition] = []
    ) async throws -> ChatCompletionResult {
        do {
            let api = resolvedAPI
            let request = try makeRequest(
                body: try requestBody(messages: messages, tools: tools, stream: false, api: api),
                api: api
            )
            let (data, response) = try await session.data(for: request)
            try validate(response: response, body: data)
            return try parseCompletion(data, api: api)
        } catch {
            throw map(error)
        }
    }

    /// Streams text deltas. Cancelling the consuming task cancels its URLSession
    /// request; a server stream that closes without DONE/finish is an error.
    public func streamText(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.runStream(messages: messages, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: self.map(error))
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private var resolvedAPI: ChatAPIStyle {
        if configuration.api != .automatic { return configuration.api }
        let path = configuration.baseURL.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.hasSuffix("responses") ? .responses : .chatCompletions
    }

    private var resolvedAuthentication: ChatAuthenticationStyle {
        if configuration.authentication != .automatic { return configuration.authentication }
        let host = configuration.baseURL.host?.lowercased() ?? ""
        return host == "azure.com" || host.hasSuffix(".azure.com") ? .apiKey : .bearer
    }

    private func makeRequest(body: JSONValue, api: ChatAPIStyle) throws -> URLRequest {
        let url = try endpoint(for: api)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream, application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 95
        if let publicAPIKey = configuration.publicAPIKey {
            request.setValue(publicAPIKey, forHTTPHeaderField: "apikey")
        }

        switch resolvedAuthentication {
        case .none:
            break
        case .bearer, .apiKey, .automatic:
            guard let credential, !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ChatClientError.missingCredential
            }
            if resolvedAuthentication == .apiKey {
                request.setValue(credential, forHTTPHeaderField: "api-key")
            } else {
                request.setValue("Bearer \(credential)", forHTTPHeaderField: "Authorization")
            }
        }
        request.httpBody = try encode(body)
        return request
    }

    private func endpoint(for api: ChatAPIStyle) throws -> URL {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatClientError.invalidConfiguration("Model must not be empty")
        }
        guard let scheme = configuration.baseURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              configuration.baseURL.host != nil else {
            throw ChatClientError.invalidConfiguration("Base URL must be an absolute HTTP(S) URL")
        }
        switch api {
        case .responses:
            return configuration.baseURL
        case .chatCompletions, .automatic:
            let trimmedPath = configuration.baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if trimmedPath.lowercased().hasSuffix("chat/completions") {
                return configuration.baseURL
            }
            guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
                throw ChatClientError.invalidConfiguration("Invalid base URL")
            }
            let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
            components.path = basePath + "/chat/completions"
            guard let url = components.url else {
                throw ChatClientError.invalidConfiguration("Could not construct chat/completions URL")
            }
            return url
        }
    }

    private func requestBody(
        messages: [ChatMessage],
        tools: [ChatToolDefinition],
        stream: Bool,
        api: ChatAPIStyle
    ) throws -> JSONValue {
        switch api {
        case .chatCompletions, .automatic:
            var object: [String: JSONValue] = [
                "model": .string(configuration.model),
                "stream": .bool(stream),
                "messages": .array(try messages.map(chatCompletionsMessage)),
            ]
            if !tools.isEmpty {
                object["tools"] = .array(tools.map(chatCompletionsTool))
                object["tool_choice"] = .string("auto")
            }
            return .object(object)
        case .responses:
            var object: [String: JSONValue] = [
                "model": .string(configuration.model),
                "stream": .bool(stream),
                "input": .array(try messages.flatMap(responsesInput)),
            ]
            if !tools.isEmpty {
                object["tools"] = .array(tools.map(responsesTool))
                object["tool_choice"] = .string("auto")
            }
            return .object(object)
        }
    }

    private func chatCompletionsMessage(_ message: ChatMessage) throws -> JSONValue {
        var object: [String: JSONValue] = ["role": .string(message.role.rawValue)]
        object["content"] = message.content.map(JSONValue.string) ?? .null
        if let callID = message.toolCallID { object["tool_call_id"] = .string(callID) }
        if let calls = message.toolCalls {
            object["tool_calls"] = .array(try calls.map { call in
                .object([
                    "id": .string(call.id),
                    "type": .string("function"),
                    "function": .object([
                        "name": .string(call.name),
                        "arguments": .string(try jsonString(call.arguments)),
                    ]),
                ])
            })
        }
        return .object(object)
    }

    private func responsesInput(_ message: ChatMessage) throws -> [JSONValue] {
        switch message.role {
        case .system, .user:
            return [.object([
                "type": .string("message"),
                "role": .string(message.role.rawValue),
                "content": .array([.object([
                    "type": .string("input_text"),
                    "text": .string(message.content ?? ""),
                ])]),
            ])]
        case .assistant:
            var items: [JSONValue] = try (message.toolCalls ?? []).map { call in
                .object([
                    "type": .string("function_call"),
                    "call_id": .string(call.id),
                    "name": .string(call.name),
                    "arguments": .string(try jsonString(call.arguments)),
                ])
            }
            if let content = message.content {
                items.append(.object([
                    "type": .string("message"),
                    "role": .string("assistant"),
                    "content": .array([.object([
                        "type": .string("output_text"),
                        "text": .string(content),
                    ])]),
                ]))
            }
            return items
        case .tool:
            guard let callID = message.toolCallID, !callID.isEmpty else {
                throw ChatClientError.invalidConfiguration("A tool message requires toolCallID")
            }
            return [.object([
                "type": .string("function_call_output"),
                "call_id": .string(callID),
                "output": .string(message.content ?? ""),
            ])]
        }
    }

    private func chatCompletionsTool(_ tool: ChatToolDefinition) -> JSONValue {
        .object([
            "type": .string("function"),
            "function": .object([
                "name": .string(tool.name),
                "description": .string(tool.description),
                "parameters": tool.parameters,
            ]),
        ])
    }

    private func responsesTool(_ tool: ChatToolDefinition) -> JSONValue {
        .object([
            "type": .string("function"),
            "name": .string(tool.name),
            "description": .string(tool.description),
            "parameters": tool.parameters,
        ])
    }

    private func jsonString(_ value: JSONValue) throws -> String {
        let data = try encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw ChatClientError.malformedResponse("Could not encode tool arguments")
        }
        return string
    }

    private func validate(response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ChatClientError.malformedResponse("The server did not return an HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: body, encoding: .utf8) ?? "<non-UTF8 response>"
            if http.statusCode == 401 || http.statusCode == 403 {
                throw ChatClientError.authentication(status: http.statusCode, body: text)
            }
            throw ChatClientError.httpStatus(status: http.statusCode, body: text)
        }
    }

    private func parseCompletion(_ data: Data, api: ChatAPIStyle) throws -> ChatCompletionResult {
        let root: JSONValue
        do { root = try decode(data) }
        catch { throw ChatClientError.malformedResponse("Invalid JSON response: \(error.localizedDescription)") }

        if let error = serverError(in: root) { throw ChatClientError.server(error) }
        switch api {
        case .chatCompletions, .automatic:
            guard let message = root["choices"]?.arrayValue?.first?["message"] else {
                throw ChatClientError.malformedResponse("Missing choices[0].message")
            }
            if let calls = message["tool_calls"]?.arrayValue, !calls.isEmpty {
                return .toolCalls(try calls.map(parseChatToolCall))
            }
            guard let content = message["content"]?.stringValue else {
                throw ChatClientError.malformedResponse("Message contains neither text nor tool calls")
            }
            return .text(content)
        case .responses:
            let output = root["output"]?.arrayValue ?? []
            let calls = try output.filter { $0["type"]?.stringValue == "function_call" }.map(parseResponsesToolCall)
            if !calls.isEmpty { return .toolCalls(calls) }

            var text = ""
            var foundText = false
            for item in output where item["type"]?.stringValue == "message" {
                for content in item["content"]?.arrayValue ?? [] where content["type"]?.stringValue == "output_text" {
                    guard let part = content["text"]?.stringValue else {
                        throw ChatClientError.malformedResponse("output_text is missing text")
                    }
                    foundText = true
                    text += part
                }
            }
            if let direct = root["output_text"]?.stringValue {
                foundText = true
                text += direct
            }
            guard foundText else {
                throw ChatClientError.malformedResponse("Response contains neither text nor tool calls")
            }
            return .text(text)
        }
    }

    private func parseChatToolCall(_ value: JSONValue) throws -> ChatToolCall {
        guard let id = value["id"]?.stringValue,
              let name = value["function"]?["name"]?.stringValue,
              let arguments = value["function"]?["arguments"]?.stringValue else {
            throw ChatClientError.malformedResponse("Malformed chat-completions tool call")
        }
        return ChatToolCall(id: id, name: name, arguments: try decodeArguments(arguments))
    }

    private func parseResponsesToolCall(_ value: JSONValue) throws -> ChatToolCall {
        guard let id = value["call_id"]?.stringValue,
              let name = value["name"]?.stringValue,
              let arguments = value["arguments"]?.stringValue else {
            throw ChatClientError.malformedResponse("Malformed Responses API function call")
        }
        return ChatToolCall(id: id, name: name, arguments: try decodeArguments(arguments))
    }

    private func decodeArguments(_ string: String) throws -> JSONValue {
        guard let data = string.data(using: .utf8) else {
            throw ChatClientError.malformedResponse("Tool arguments are not UTF-8")
        }
        do { return try decode(data) }
        catch { throw ChatClientError.malformedResponse("Tool arguments are not valid JSON") }
    }

    private func runStream(
        messages: [ChatMessage],
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        try Task.checkCancellation()
        let api = resolvedAPI
        let request = try makeRequest(
            body: try requestBody(messages: messages, tools: [], stream: true, api: api),
            api: api
        )
        let (bytes, response) = try await session.bytes(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ChatClientError.malformedResponse("The server did not return an HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte) }
            try validate(response: response, body: body)
            return
        }

        var parser = SSEParser()
        for try await byte in bytes {
            try Task.checkCancellation()
            for event in try parser.feed(Data([byte])) {
                if try process(event: event, api: api, continuation: continuation) {
                    // Finishing the stream triggers onTermination, which cancels this
                    // producer task and therefore the still-open URLSession transport.
                    // Return before parsing any bytes a proxy sends after success.
                    continuation.finish()
                    return
                }
            }
        }
        for event in try parser.finish() {
            if try process(event: event, api: api, continuation: continuation) {
                continuation.finish()
                return
            }
        }
        throw ChatClientError.incompleteStream
    }

    /// Returns true when the event is a successful terminal event.
    private func process(
        event: SSEEvent,
        api: ChatAPIStyle,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) throws -> Bool {
        if event.data.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" { return true }
        if event.event == "error" { throw ChatClientError.server(message(fromErrorData: event.data)) }

        guard let data = event.data.data(using: .utf8) else {
            throw ChatClientError.malformedResponse("SSE data is not UTF-8")
        }
        let value: JSONValue
        do { value = try decode(data) }
        catch { throw ChatClientError.malformedResponse("Invalid SSE JSON: \(event.data)") }
        if let error = serverError(in: value) { throw ChatClientError.server(error) }

        switch api {
        case .chatCompletions, .automatic:
            guard let choice = value["choices"]?.arrayValue?.first else {
                throw ChatClientError.malformedResponse("Streaming response is missing choices[0]")
            }
            if let delta = choice["delta"]?["content"]?.stringValue, !delta.isEmpty {
                continuation.yield(delta)
            }
            if let finish = choice["finish_reason"], finish != .null { return true }
            return false
        case .responses:
            let type = value["type"]?.stringValue ?? event.event
            switch type {
            case "response.output_text.delta":
                guard let delta = value["delta"]?.stringValue else {
                    throw ChatClientError.malformedResponse("Responses delta is missing text")
                }
                if !delta.isEmpty { continuation.yield(delta) }
                return false
            case "response.completed":
                return true
            case "response.failed", "response.incomplete", "error":
                throw ChatClientError.server(serverError(in: value) ?? "The model response failed")
            default:
                return false
            }
        }
    }

    private func message(fromErrorData string: String) -> String {
        guard let data = string.data(using: .utf8),
              let value = try? decode(data) else { return string }
        return serverError(in: value) ?? string
    }

    private func encode(_ value: JSONValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func decode(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func serverError(in value: JSONValue) -> String? {
        guard let error = value["error"] else {
            if let response = value["response"] { return serverError(in: response) }
            return nil
        }
        if let message = error["message"]?.stringValue { return message }
        if let message = error.stringValue { return message }
        return "The server returned an error"
    }

    private func map(_ error: Error) -> ChatClientError {
        if let error = error as? ChatClientError { return error }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError {
            return error.code == .cancelled ? .cancelled : .transport(error.localizedDescription)
        }
        if error is SSEParserError || error is DecodingError {
            return .malformedResponse(error.localizedDescription)
        }
        return .transport(error.localizedDescription)
    }
}

private extension JSONValue {
    subscript(_ key: String) -> JSONValue? {
        guard case let .object(object) = self else { return nil }
        return object[key]
    }

    var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}
