import Foundation

public struct ToolExecutionResult: Sendable, Equatable {
    public var output: String
    public var evidence: [String]

    public init(output: String, evidence: [String] = []) {
        self.output = output
        self.evidence = evidence
    }
}

public struct ToolReceipt: Codable, Sendable, Equatable {
    public var callID: String
    public var name: String
    public var arguments: JSONValue
    public var output: String
    public var evidence: [String]
    public var createdAt: Date

    public init(
        callID: String,
        name: String,
        arguments: JSONValue,
        output: String,
        evidence: [String] = [],
        createdAt: Date = Date()
    ) {
        self.callID = callID
        self.name = name
        self.arguments = arguments
        self.output = output
        self.evidence = evidence
        self.createdAt = createdAt
    }

    public var call: ChatToolCall {
        ChatToolCall(id: callID, name: name, arguments: arguments)
    }
}

public struct ToolOrchestrationResult: Sendable, Equatable {
    public var messages: [ChatMessage]
    public var receipts: [ToolReceipt]
    public var evidence: [String]
    public var reachedRoundLimit: Bool

    public init(
        messages: [ChatMessage],
        receipts: [ToolReceipt],
        evidence: [String],
        reachedRoundLimit: Bool
    ) {
        self.messages = messages
        self.receipts = receipts
        self.evidence = evidence
        self.reachedRoundLimit = reachedRoundLimit
    }
}

public enum ToolOrchestratorError: LocalizedError, Sendable, Equatable {
    case unknownTool(String)
    case invalidArguments(tool: String, reason: String)
    case tooManyCalls(limit: Int)
    case emptyToolCallRound

    public var errorDescription: String? {
        switch self {
        case let .unknownTool(name):
            return "模型请求了不支持的工具：\(name)"
        case let .invalidArguments(tool, reason):
            return "工具 \(tool) 的参数无效：\(reason)"
        case let .tooManyCalls(limit):
            return "这次推演请求了过多工具（最多 \(limit) 次），请缩小问题后再试。"
        case .emptyToolCallRound:
            return "模型返回了空的工具请求。"
        }
    }
}

public struct ToolOrchestrator {
    public static let allowedToolNames: Set<String> = [
        "get_domain",
        "get_bazi_star",
        "list_shensha",
        "get_timing",
        "get_today_context",
        "get_ziwei_palace",
        "cast_liuyao",
        "setup_qimen",
    ]

    public typealias Complete = ([ChatMessage], [ChatToolDefinition]) async throws -> ChatCompletionResult
    public typealias Execute = (ChatToolCall) async throws -> ToolExecutionResult
    public typealias PersistReceipt = (ToolReceipt) async throws -> Void

    private let complete: Complete
    private let execute: Execute
    private let persistReceipt: PersistReceipt
    private let maxRounds: Int
    private let maxCalls: Int

    public init(
        maxRounds: Int = 5,
        maxCalls: Int = 8,
        complete: @escaping Complete,
        execute: @escaping Execute,
        persistReceipt: @escaping PersistReceipt = { _ in }
    ) {
        precondition(maxRounds > 0 && maxCalls > 0)
        self.maxRounds = maxRounds
        self.maxCalls = maxCalls
        self.complete = complete
        self.execute = execute
        self.persistReceipt = persistReceipt
    }

    public func run(
        history: [ChatMessage],
        definitions: [ChatToolDefinition],
        cachedReceipts: [ToolReceipt] = []
    ) async throws -> ToolOrchestrationResult {
        var definitionsByName: [String: ChatToolDefinition] = [:]
        for definition in definitions where Self.allowedToolNames.contains(definition.name) {
            definitionsByName[definition.name] = definition
        }
        let availableDefinitions = definitionsByName.values.sorted { $0.name < $1.name }

        var messages = history
        var receipts: [ToolReceipt] = []
        var evidence: [String] = []
        var totalCalls = 0
        var cachedCast = cachedReceipts.last { $0.name == "cast_liuyao" }

        for _ in 0 ..< maxRounds {
            try Task.checkCancellation()
            let completion = try await complete(messages, availableDefinitions)
            switch completion {
            case let .text(text):
                messages.append(ChatMessage(role: .assistant, content: text))
                return ToolOrchestrationResult(
                    messages: messages,
                    receipts: receipts,
                    evidence: Self.unique(evidence),
                    reachedRoundLimit: false
                )

            case let .toolCalls(calls):
                guard !calls.isEmpty else { throw ToolOrchestratorError.emptyToolCallRound }
                guard totalCalls + calls.count <= maxCalls else {
                    throw ToolOrchestratorError.tooManyCalls(limit: maxCalls)
                }
                totalCalls += calls.count
                messages.append(.assistantToolCalls(calls))

                for call in calls {
                    try Task.checkCancellation()
                    guard Self.allowedToolNames.contains(call.name),
                          let definition = definitionsByName[call.name] else {
                        throw ToolOrchestratorError.unknownTool(call.name)
                    }
                    do {
                        try Self.validate(call.arguments, against: definition.parameters, path: "arguments")
                    } catch {
                        throw ToolOrchestratorError.invalidArguments(
                            tool: call.name,
                            reason: error.localizedDescription
                        )
                    }

                    let receipt: ToolReceipt
                    let shouldPersist: Bool
                    if call.name == "cast_liuyao", let cachedCast {
                        receipt = ToolReceipt(
                            callID: call.id,
                            name: call.name,
                            arguments: call.arguments,
                            output: cachedCast.output,
                            evidence: cachedCast.evidence,
                            createdAt: cachedCast.createdAt
                        )
                        shouldPersist = false
                    } else {
                        do {
                            let result = try await execute(call)
                            receipt = ToolReceipt(
                                callID: call.id,
                                name: call.name,
                                arguments: call.arguments,
                                output: result.output,
                                evidence: result.evidence
                            )
                            shouldPersist = true
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            messages.append(.toolResult(ChatToolResult(
                                callID: call.id,
                                output: Self.errorOutput(error)
                            )))
                            continue
                        }
                    }

                    if shouldPersist {
                        try await persistReceipt(receipt)
                        if receipt.name == "cast_liuyao" { cachedCast = receipt }
                    }
                    receipts.append(receipt)
                    evidence.append(contentsOf: receipt.evidence)
                    messages.append(.toolResult(ChatToolResult(callID: call.id, output: receipt.output)))
                }
            }
        }

        return ToolOrchestrationResult(
            messages: messages,
            receipts: receipts,
            evidence: Self.unique(evidence),
            reachedRoundLimit: true
        )
    }

    private static func validate(_ value: JSONValue, against schema: JSONValue, path: String) throws {
        guard case let .object(schemaObject) = schema else { return }

        if let typeValue = schemaObject["type"], case let .string(type) = typeValue,
           !matches(value, type: type) {
            throw SchemaValidationError(reason: "\(path) 应为 \(type)")
        }

        if let allowed = schemaObject["enum"], case let .array(values) = allowed,
           !values.contains(value) {
            throw SchemaValidationError(reason: "\(path) 不在允许值中")
        }

        if case let .object(object) = value {
            if let requiredValue = schemaObject["required"], case let .array(required) = requiredValue {
                for item in required {
                    guard case let .string(key) = item else { continue }
                    guard let requiredValue = object[key], requiredValue != .null else {
                        throw SchemaValidationError(reason: "缺少必填参数 \(path).\(key)")
                    }
                }
            }
            if let propertiesValue = schemaObject["properties"], case let .object(properties) = propertiesValue {
                for (key, childSchema) in properties {
                    guard let child = object[key] else { continue }
                    try validate(child, against: childSchema, path: "\(path).\(key)")
                }
            }
        }

        if case let .array(array) = value, let itemSchema = schemaObject["items"] {
            for (index, item) in array.enumerated() {
                try validate(item, against: itemSchema, path: "\(path)[\(index)]")
            }
        }
    }

    private static func matches(_ value: JSONValue, type: String) -> Bool {
        switch (type, value) {
        case ("object", .object), ("array", .array), ("string", .string),
             ("integer", .integer), ("number", .integer), ("number", .double),
             ("boolean", .bool), ("null", .null):
            return true
        default:
            return false
        }
    }

    private static func errorOutput(_ error: Error) -> String {
        let value: JSONValue = ["error": .string(error.localizedDescription)]
        let data = (try? JSONEncoder().encode(value)) ?? Data(#"{"error":"工具未能完成"}"#.utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}

private struct SchemaValidationError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
