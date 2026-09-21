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
    public var context: ToolContext?

    public init(
        callID: String,
        name: String,
        arguments: JSONValue,
        output: String,
        evidence: [String] = [],
        createdAt: Date = Date(),
        context: ToolContext? = nil
    ) {
        self.callID = callID
        self.name = name
        self.arguments = arguments
        self.output = output
        self.evidence = evidence
        self.createdAt = createdAt
        self.context = context
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
    case invalidCallID(String)
    case staleContext

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
        case .staleContext:
            return "出生资料或排盘规则已更新。原来的盘已保留，请发起新提问以使用当前资料。"
        case .invalidCallID:
            return "模型返回了重复或无效的工具编号，请重试。"
        }
    }
}

public struct ToolOrchestrator {
    /// Shared with replay: a successfully delivered round must remain available
    /// on retry. This is independent of the conversational text budget.
    static let outputByteLimit = 60_000
    public static let allowedToolNames: Set<String> = [
        "get_domain",
        "get_bazi_star",
        "list_shensha",
        "get_timing",
        "get_today_context",
        "get_ziwei_palace",
        "get_ziwei_timing",
        "get_natal_astronomy",
        "cast_liuyao",
        "setup_qimen",
    ]

    public typealias Complete = ([ChatMessage], [ChatToolDefinition]) async throws -> ChatCompletionResult
    public typealias Execute = (ChatToolCall) async throws -> ToolExecutionResult
    public typealias PrepareCasts = ([ChatToolCall]) async throws -> [ConfirmedCastQuestion]
    public typealias PersistConfirmations = ([ConfirmedCastQuestion]) async throws -> Void
    public typealias PersistReceipt = (ToolReceipt) async throws -> Void

    private let complete: Complete
    private let execute: Execute
    private let persistReceipt: PersistReceipt
    private let prepareCasts: PrepareCasts?
    private let persistConfirmations: PersistConfirmations
    private let maxRounds: Int
    private let maxCalls: Int

    public init(
        maxRounds: Int = 5,
        maxCalls: Int = 8,
        complete: @escaping Complete,
        execute: @escaping Execute,
        persistReceipt: @escaping PersistReceipt = { _ in },
        prepareCasts: PrepareCasts? = nil,
        persistConfirmations: @escaping PersistConfirmations = { _ in }
    ) {
        precondition(maxRounds > 0 && maxCalls > 0)
        self.maxRounds = maxRounds
        self.maxCalls = maxCalls
        self.complete = complete
        self.execute = execute
        self.persistReceipt = persistReceipt
        self.prepareCasts = prepareCasts
        self.persistConfirmations = persistConfirmations
    }

    public func run(
        history: [ChatMessage],
        definitions: [ChatToolDefinition],
        cachedReceipts: [ToolReceipt] = [],
        context: ToolContext? = nil,
        questionID: UUID? = nil,
        confirmedQuestions: [ConfirmedCastQuestion] = []
    ) async throws -> ToolOrchestrationResult {
        if let context, cachedReceipts.contains(where: { $0.context != context }) {
            throw ToolOrchestratorError.staleContext
        }
        var definitionsByName: [String: ChatToolDefinition] = [:]
        for definition in definitions where Self.allowedToolNames.contains(definition.name) {
            definitionsByName[definition.name] = definition
        }
        let availableDefinitions = definitionsByName.values.sorted { $0.name < $1.name }

        var preparedArguments: [String: JSONValue] = [:]
        for confirmation in confirmedQuestions {
            guard let questionID, let context else { throw ToolOrchestratorError.staleContext }
            try confirmation.validate(userID: questionID, context: context)
            guard preparedArguments[confirmation.call.name] == nil else { throw ToolOrchestratorError.staleContext }
            preparedArguments[confirmation.call.name] = confirmation.call.arguments
        }
        // A saved confirmation must not silently rebind an already completed chart.
        for receipt in cachedReceipts {
            if let confirmed = preparedArguments[receipt.name], confirmed != receipt.arguments {
                throw ToolOrchestratorError.staleContext
            }
        }

        var messages = history
        for confirmation in confirmedQuestions where !messages.contains(confirmation.intentMessage) {
            messages.append(confirmation.intentMessage)
        }
        var receipts: [ToolReceipt] = []
        var evidence: [String] = cachedReceipts.filter { NatalEvidenceProjection.wasDelivered($0,in:history) }.flatMap(\.evidence)
        var totalCalls = 0
        var outputBytes = history.filter { $0.role == .tool }.reduce(0) { $0 + ($1.content?.utf8.count ?? 0) }
        var seenCallIDs = Set(history.flatMap { $0.toolCalls ?? [] }.map(\.id))
        var cachedCharts: [String: ToolReceipt] = [:]
        for receipt in cachedReceipts where Self.stableChartTools.contains(receipt.name) {
            cachedCharts[receipt.name] = receipt
        }

        for _ in 0 ..< maxRounds {
            try Task.checkCancellation()
            let completion = try await complete(messages, availableDefinitions)
            switch completion {
            case .text:
                // Planning prose is not calculation evidence. Only tool messages are
                // passed to the final writer, so it cannot inherit an ungrounded draft.
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
                // Validate the whole batch before any cast or persistence. An invalid
                // sibling call must not leave half of a user question executed.
                var batchIDs = Set<String>()
                for call in calls {
                    guard Self.validCallID(call.id), !seenCallIDs.contains(call.id),
                          batchIDs.insert(call.id).inserted else {
                        throw ToolOrchestratorError.invalidCallID(call.id)
                    }
                    guard Self.allowedToolNames.contains(call.name),
                          let definition = definitionsByName[call.name] else {
                        throw ToolOrchestratorError.unknownTool(call.name)
                    }
                    do {
                        try Self.validate(call.arguments, against: definition.parameters, path: "arguments")
                        try Self.validateToolSemantics(call)
                    } catch {
                        throw ToolOrchestratorError.invalidArguments(tool: call.name, reason: error.localizedDescription)
                    }
                }
                // Collect all new methods before executing any sibling tool. Aliases
                // share one confirmation and completed receipts always take priority.
                var newNames = Set<String>()
                let newCasts = calls.filter {
                    Self.stableChartTools.contains($0.name) && cachedCharts[$0.name] == nil &&
                    preparedArguments[$0.name] == nil && newNames.insert($0.name).inserted
                }
                if !newCasts.isEmpty, let prepareCasts {
                    guard let questionID, let context else { throw ToolOrchestratorError.staleContext }
                    let confirmations = try await prepareCasts(newCasts)
                    try Task.checkCancellation()
                    guard confirmations.count == newCasts.count else { throw SchemaValidationError(reason: "占问确认不完整") }
                    for (original, confirmation) in zip(newCasts, confirmations) {
                        try confirmation.validate(userID: questionID, context: context)
                        guard confirmation.proposedCall == original,
                              let definition = definitionsByName[original.name] else { throw SchemaValidationError(reason: "占问确认与原请求不一致") }
                        try Self.validate(confirmation.call.arguments, against: definition.parameters, path: "arguments")
                        try Self.validateToolSemantics(confirmation.call)
                    }
                    // Persistence errors abort before any calculation, including siblings.
                    try await persistConfirmations(confirmations)
                    try Task.checkCancellation()
                    for confirmation in confirmations {
                        preparedArguments[confirmation.call.name] = confirmation.call.arguments
                        messages.append(confirmation.intentMessage)
                    }
                }
                totalCalls += calls.count
                seenCallIDs.formUnion(batchIDs)
                // A retry references the original question and chart, not newly invented
                // model arguments. This preserves the provenance attached to the receipt.
                var chartArguments = preparedArguments
                for (name, receipt) in cachedCharts { chartArguments[name] = receipt.arguments }
                let effectiveCalls = calls.map { call in
                    guard Self.stableChartTools.contains(call.name) else { return call }
                    if let original = chartArguments[call.name] {
                        return ChatToolCall(id: call.id, name: call.name, arguments: original)
                    }
                    chartArguments[call.name] = call.arguments
                    return call
                }
                // Validate confirmed/cached effective arguments against today's schema.
                for call in effectiveCalls {
                    if let definition = definitionsByName[call.name] {
                        try Self.validate(call.arguments, against: definition.parameters, path: "arguments")
                        try Self.validateToolSemantics(call)
                    }
                }
                var callBatchIndex=messages.count
                messages.append(.assistantToolCalls(effectiveCalls))

                for call in effectiveCalls {
                    try Task.checkCancellation()
                    let receipt: ToolReceipt
                    let shouldPersist: Bool
                    if let cachedChart = cachedCharts[call.name] {
                        receipt = ToolReceipt(
                            callID: call.id,
                            name: call.name,
                            arguments: call.arguments,
                            output: cachedChart.output,
                            evidence: cachedChart.evidence,
                            createdAt: cachedChart.createdAt,
                            context: cachedChart.context
                        )
                        shouldPersist = false
                    } else {
                        do {
                            let result = try await execute(call)
                            guard result.output.utf8.count <= 1_000_000 else {
                                throw SchemaValidationError(reason: "工具结果过长，请缩小查询范围")
                            }
                            if Self.isFailureOutput(result.output) {
                                try Self.appendFailureOutput(result.output, callID: call.id, messages: &messages, outputBytes: &outputBytes)
                                continue
                            }
                            receipt = ToolReceipt(
                                callID: call.id,
                                name: call.name,
                                arguments: call.arguments,
                                output: Self.stableChartTools.contains(call.name) ? try CastReceiptStorage.encode(result.output) : result.output,
                                evidence: result.evidence,
                                context: context
                            )
                            shouldPersist = true
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            try Self.appendFailureOutput(Self.errorOutput(error), callID: call.id, messages: &messages, outputBytes: &outputBytes)
                            continue
                        }
                    }

                    // Save a completed calculation before applying MODEL context limits.
                    // Otherwise a large chart could be lost and recast by a retry.
                    if shouldPersist {
                        try await persistReceipt(receipt)
                        if Self.stableChartTools.contains(receipt.name) { cachedCharts[receipt.name] = receipt }
                    }
                    receipts.append(receipt)
                    if let directory=CastSourceDirectory.message(receipt:receipt,callID:call.id) {
                        messages.insert(directory,at:callBatchIndex)
                        callBatchIndex += 1
                    }
                    let modelOutput = NatalEvidenceProjection.output(receipt.output, name:receipt.name, delivered:Array(messages.dropFirst(history.count)),callID:call.id)
                    guard modelOutput.utf16.count <= 32_000, outputBytes + modelOutput.utf8.count <= Self.outputByteLimit else {
                        try Self.appendFailureOutput(Self.errorOutput(SchemaValidationError(reason: "盘面已保存，但本次模型依据容量不足；不要重新起盘，也不要编造未读取的细节")), callID: call.id, messages: &messages, outputBytes: &outputBytes)
                        continue
                    }
                    evidence.append(contentsOf: receipt.evidence)
                    outputBytes += modelOutput.utf8.count
                    messages.append(.toolResult(ChatToolResult(callID: call.id, output: modelOutput)))
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

    private static let stableChartTools: Set<String> = ["cast_liuyao", "setup_qimen"]

    private static func validCallID(_ id: String) -> Bool {
        !id.isEmpty && id.utf8.count <= 200 && id.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        }
    }

    private static func isFailureOutput(_ output: String) -> Bool {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: Data(output.utf8)),
              case let .object(object) = value, let error = object["error"] else { return false }
        return error != .null
    }

    private static func appendFailureOutput(_ output: String, callID: String, messages: inout [ChatMessage], outputBytes: inout Int) throws {
        let bounded = output.utf16.count <= 32_000 && outputBytes + output.utf8.count <= Self.outputByteLimit
            ? output
            : errorOutput(SchemaValidationError(reason: "工具错误信息过长或超出本次容量，未取得有效计算结果"))
        guard outputBytes + bounded.utf8.count <= Self.outputByteLimit else {
            throw SchemaValidationError(reason: "本次工具输出已达到容量上限；已计算的盘面保留，请缩小问题后重试")
        }
        outputBytes += bounded.utf8.count
        messages.append(.toolResult(ChatToolResult(callID: callID, output: bounded)))
    }

    private static func number(_ value: JSONValue?) -> Double? {
        switch value {
        case let .integer(value): return Double(value)
        case let .double(value): return value
        default: return nil
        }
    }

    private static func validateToolSemantics(_ call: ChatToolCall) throws {
        if case let .object(arguments) = call.arguments,
           case let .string(question) = arguments["question"],
           question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError(reason: "问题不能为空")
        }
        guard call.name == "get_timing", case let .object(args) = call.arguments else { return }
        if let yearRange = args["yearRange"] {
            guard args["scope"] == .string("liunian"), case let .array(values) = yearRange,
                  values.count == 2, let start = number(values.first), let end = number(values.last),
                  start.isFinite, end.isFinite, start.rounded() == start, end.rounded() == end,
                  start >= 1901, end <= 2100, start <= end, end - start <= 20 else {
                throw SchemaValidationError(reason: "流年区间须为 1901–2100 年内由早到晚的两个整数年份，最多跨 20 年")
            }
        }
        if let year = args["year"] {
            guard args["scope"] == .string("liuyue"), let value = number(year), value.isFinite,
                  value.rounded() == value, (1901...2100).contains(value) else {
                throw SchemaValidationError(reason: "流月年份须为 1901–2100 年内的整数，且仅用于 liuyue")
            }
        }
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

        if let numeric = number(value) {
            guard numeric.isFinite else { throw SchemaValidationError(reason: "\(path) 必须为有限数值") }
            if let minimum = number(schemaObject["minimum"]), numeric < minimum {
                throw SchemaValidationError(reason: "\(path) 小于允许的最小值")
            }
            if let maximum = number(schemaObject["maximum"]), numeric > maximum {
                throw SchemaValidationError(reason: "\(path) 大于允许的最大值")
            }
        }
        if case let .string(text) = value {
            let count = Double(text.unicodeScalars.count)
            if let minimum = number(schemaObject["minLength"]), count < minimum {
                throw SchemaValidationError(reason: "\(path) 文字过短")
            }
            if let maximum = number(schemaObject["maxLength"]), count > maximum {
                throw SchemaValidationError(reason: "\(path) 文字过长")
            }
        }
        if case let .array(items) = value {
            if let minimum = number(schemaObject["minItems"]), Double(items.count) < minimum {
                throw SchemaValidationError(reason: "\(path) 项目过少")
            }
            if let maximum = number(schemaObject["maxItems"]), Double(items.count) > maximum {
                throw SchemaValidationError(reason: "\(path) 项目过多")
            }
        }
        if case let .object(object) = value {
            if schemaObject["additionalProperties"] == .bool(false),
               case let .object(properties) = schemaObject["properties"],
               let unknown = object.keys.sorted().first(where: { properties[$0] == nil }) {
                throw SchemaValidationError(reason: "不支持的参数 \(path).\(unknown)")
            }
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
