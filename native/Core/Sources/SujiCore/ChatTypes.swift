import Foundation

public enum JSONValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case integer(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .integer(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        }
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) { self = .integer(value) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

public enum ChatAPIStyle: String, Codable, Sendable, Equatable {
    case automatic
    case chatCompletions
    case responses
}

public enum ChatAuthenticationStyle: String, Codable, Sendable, Equatable {
    case automatic
    case bearer
    case apiKey
    case none
}

/// Non-secret provider settings. The credential remains in the app's Keychain
/// and is supplied separately when constructing a `ChatClient`.
public struct ChatProviderConfiguration: Codable, Sendable, Equatable {
    public var baseURL: URL
    public var model: String
    public var api: ChatAPIStyle
    public var authentication: ChatAuthenticationStyle

    public init(
        baseURL: URL,
        model: String,
        api: ChatAPIStyle = .automatic,
        authentication: ChatAuthenticationStyle = .automatic
    ) {
        self.baseURL = baseURL
        self.model = model
        self.api = api
        self.authentication = authentication
    }
}

public enum ChatRole: String, Codable, Sendable, Equatable {
    case system
    case user
    case assistant
    case tool
}

public struct ChatToolCall: Codable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var arguments: JSONValue

    public init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ChatToolResult: Codable, Sendable, Equatable {
    public var callID: String
    public var output: String

    public init(callID: String, output: String) {
        self.callID = callID
        self.output = output
    }
}

public struct ChatToolDefinition: Codable, Sendable, Equatable {
    public var name: String
    public var description: String
    public var parameters: JSONValue

    public init(name: String, description: String, parameters: JSONValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct ChatMessage: Codable, Sendable, Equatable {
    public var role: ChatRole
    public var content: String?
    public var toolCallID: String?
    public var toolCalls: [ChatToolCall]?

    public init(
        role: ChatRole,
        content: String?,
        toolCallID: String? = nil,
        toolCalls: [ChatToolCall]? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCallID = toolCallID
        self.toolCalls = toolCalls
    }

    public static func assistantToolCalls(_ calls: [ChatToolCall], content: String? = nil) -> ChatMessage {
        ChatMessage(role: .assistant, content: content, toolCalls: calls)
    }

    public static func toolResult(_ result: ChatToolResult) -> ChatMessage {
        ChatMessage(role: .tool, content: result.output, toolCallID: result.callID)
    }
}

public enum ChatCompletionResult: Sendable, Equatable {
    case text(String)
    case toolCalls([ChatToolCall])
}

public enum ChatClientError: LocalizedError, Sendable, Equatable {
    case missingCredential
    case invalidConfiguration(String)
    case authentication(status: Int, body: String)
    case httpStatus(status: Int, body: String)
    case cancelled
    case transport(String)
    case malformedResponse(String)
    case server(String)
    case incompleteStream

    public var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "尚未设置 AI 服务凭据。请在设置中填写 API Key 后重试。"
        case .invalidConfiguration:
            return "AI 服务配置无效。请检查服务地址和模型设置。"
        case let .authentication(status, _):
            return "AI 服务身份验证失败（HTTP \(status)）。请检查 API Key 或账户权限。"
        case let .httpStatus(status, _):
            return "AI 服务暂时不可用（HTTP \(status)）。请稍后重试。"
        case .cancelled:
            return "已停止本次回答。"
        case .transport:
            return "无法连接 AI 服务。请检查网络后重试。"
        case .malformedResponse:
            return "AI 服务返回的数据无法解析。请稍后重试或检查服务配置。"
        case .server:
            return "AI 服务未能完成请求。请稍后重试。"
        case .incompleteStream:
            return "AI 回答在传输完成前中断。请点“重试”继续。"
        }
    }
}
