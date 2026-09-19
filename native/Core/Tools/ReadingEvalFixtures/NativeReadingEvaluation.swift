import Foundation
import CryptoKit
import SujiCore

/// Opt-in synthetic live exercise of shipping Swift components, including SSE.
/// The loopback proxy uses the real backend handler; auth/quota are synthetic.
enum NativeReadingEvaluation {
    struct Configuration: Decodable {
        let proxyURL: URL
        let proxyToken: String
        let bundlePath: String
        let cases: [Case]
    }
    struct Case: Decodable {
        let id: String
        let question: String
        let noBirth: Bool?
        let mode: String?
        let failure: Bool?
        let fixedLineValues: [Int]?
        let followups: [String]?
    }

    static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value), options: [.fragmentsAllowed])
    }
    static func json(_ value: Any) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed]), as: UTF8.self)
    }
    static func run() async throws {
        guard let flag = CommandLine.arguments.firstIndex(of: "--live-native"), CommandLine.arguments.count == flag + 3 else {
            throw EngineError.execution("Usage: --live-native private-config.json new-report.json")
        }
        let config = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[flag + 1])))
        let output = URL(fileURLWithPath: CommandLine.arguments[flag + 2])
        guard config.proxyURL.host == "127.0.0.1", (1...11).contains(config.cases.count), !FileManager.default.fileExists(atPath: output.path) else {
            throw EngineError.execution("Require loopback proxy, 1–11 synthetic cases and a new output file")
        }
        let bundle = URL(fileURLWithPath: config.bundlePath)
        let bridge = try MingliBridge(scriptURL: bundle)
        let metadata = try JSONSerialization.jsonObject(with: await bridge.request(#"{"command":"metadata"}"#)) as! [String: Any]
        let definitions = try await bridge.request(#"{"command":"tools"}"#)
        let baseNow = ISO8601DateFormatter().date(from: "2024-02-04T04:00:00Z")!
        let client = ChatClient(configuration: .init(baseURL: config.proxyURL, model: "deepseek-flash", api: .chatCompletions, authentication: .bearer), credential: config.proxyToken)
        var records: [[String: Any]] = []
        let reportBase: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()), "promptVersion": ReadingPrompt.version,
            "claimProtocolVersion": BaziFrameworkReading.protocolVersion,
            "scope": "Live synthetic Swift ChatClient, MingliBridge, ToolOrchestrator and backend handler. Framework comparisons use a local claim compiler plus model ordering; other cases use SSE writing and ReadingVerifier. Loopback auth/quota are mocked; not deployed Supabase authentication or SwiftUI integration.",
            "engine": metadata, "bundleSHA256": SHA256.hash(data: try Data(contentsOf: bundle)).map { String(format: "%02x", $0) }.joined(),
            "executableSHA256": SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))).map { String(format: "%02x", $0) }.joined(),
        ]
        for item in config.cases {
            var caseBridge = bridge
            var fixture: [String: Any] = [:]
            if let values = item.fixedLineValues {
                guard values.count == 6, values.allSatisfy({ (6...9).contains($0) }), item.mode == "起卦" else {
                    throw EngineError.execution("Invalid synthetic coin fixture")
                }
                let draws = values.flatMap { value in (0..<3).map { $0 < value - 6 ? 0.75 : 0.25 } }
                let prelude = "// Evaluation-only synthetic coin source. Never bundled into the App.\n(() => { const draws = \(try json(draws)); let index = 0; Math.random = () => { if (index >= draws.length) throw new Error('Synthetic coin fixture exhausted'); return draws[index++]; }; })();\n"
                let script = Data(prelude.utf8) + (try Data(contentsOf: bundle))
                let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("suji-eval-coins-\(UUID().uuidString).js")
                try script.write(to: temporary, options: .atomic)
                defer { try? FileManager.default.removeItem(at: temporary) }
                caseBridge = try MingliBridge(scriptURL: temporary)
                fixture = ["kind": "evaluation-only Math.random substitution", "lineValues": values, "coinDraws": draws,
                           "effectiveBundleSHA256": SHA256.hash(data: script).map { String(format: "%02x", $0) }.joined()]
            }
            let mode = item.mode ?? "命理"
            let birth: BirthProfile? = item.noBirth == true ? nil : .init(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
            var conversation: [ConversationEntry] = []
            for (turnIndex, question) in ([item.question] + (item.followups ?? [])).enumerated() {
                guard turnIndex < 6 else { throw EngineError.execution("At most six synthetic turns per case") }
                let now = baseNow.addingTimeInterval(Double(turnIndex * 60))
                var userEntry = ConversationEntry(role: "user", text: question)
                userEntry.date = now
                userEntry.analysisMode = mode
                conversation.append(userEntry)
                var readingDocument: ReadingDocument?
                let context = try ToolContext(birth: birth, engineRevision: metadata["engineRevision"] as! String, referenceDate: now, mode: mode)
                let focus = BaziReadingRequest.resolve(question: question, mode: mode, entries: conversation, currentUserID: userEntry.id, context: context)
                let instruction = ReadingPrompt.instruction(tone: "温暖", mode: mode, referenceDate: now, hasBirth: birth != nil)
                var exchanges: [[String: Any]] = []
                var receipts: [ToolReceipt] = []
                var record: [String: Any] = ["id": turnIndex == 0 ? item.id : "\(item.id)-turn\(turnIndex + 1)", "question": question, "turnIndex": turnIndex, "mode": mode, "birth": try object(birth), "context": try object(context)]
                if !fixture.isEmpty { record["fixture"] = fixture }
                if item.failure == true { record["injectedFailure"] = "synthetic_engine_failure" }
                func complete(_ messages: [ChatMessage], tools: [ChatToolDefinition] = [], phase: String) async throws -> ChatCompletionResult {
                    let result = try await client.complete(messages: messages, tools: tools)
                    let response: Any
                    switch result {
                    case let .text(text): response = ["text": text]
                    case let .toolCalls(calls): response = ["toolCalls": try object(calls)]
                    }
                    exchanges.append(["phase": phase, "messages": try object(messages), "tools": try object(tools), "response": response])
                    return result
                }
                do {
                    let available = try ReadingIntent.definitions(from: definitions, mode: mode, question: question, hasBirth: birth != nil)
                    let orchestrator = ToolOrchestrator(complete: { messages, tools in
                        if focus != nil {
                            let planned = BaziFrameworkReading.plan(callID: "bazi-" + userEntry.id.uuidString, history: messages, context: context, hasBirth: birth != nil)
                            let response: Any
                            switch planned {
                            case let .text(text): response = ["text": text]
                            case let .toolCalls(calls): response = ["toolCalls": try object(calls)]
                            }
                            exchanges.append(["phase": "local-plan", "messages": try object(messages), "response": response])
                            return planned
                        }
                        return try await complete(messages, tools: tools, phase: "planner")
                    }, execute: { call in
                        if item.failure == true { throw EngineError.execution("synthetic_engine_failure") }
                        var request: [String: Any] = ["command": "tool", "name": call.name, "id": call.id, "arguments": try object(call.arguments), "now": ISO8601DateFormatter().string(from: now)]
                        if let birth { request["birth"] = try object(birth) }
                        let raw = try await caseBridge.request(json(request))
                        try EngineContract.validate(raw, command: "tool")
                        let result = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
                        return ToolExecutionResult(output: try json(result["result"]!), evidence: result["evidence"] as? [String] ?? [])
                    }, persistReceipt: { receipt in receipts.append(receipt) })
                    let result = try await orchestrator.run(history: [.init(role: .system, content: instruction + "\n" + ReadingPrompt.plannerInstruction(question: question, mode: mode, focus: focus))] + ReadingPrompt.history(from: conversation, currentUserID: userEntry.id, context: context), definitions: available, context: context)
                    var history = result.messages
                    if result.reachedRoundLimit { history.append(.init(role: .user, content: "已达到工具轮次上限，请说明现有依据的限度，不要继续起盘。")) }
                    history[0].content = instruction + "\n" + ReadingPrompt.writer
                    if result.evidence.isEmpty { history[0].content! += "\n本次没有取得新的计算证据；只能提供一般建议，不能声称已完成命盘解读。" }
                    record["writerHistory"] = try object(history)
                    if let focus {
                        record["focus"] = focus.rawValue
                        record["executionPath"] = "typed-claims"
                        if let catalog = BaziFrameworkReading.catalog(receipts: result.receipts, context: context) {
                            record["claimCatalog"] = try object(catalog)
                            let answer = try await BaziFrameworkReading.compose(catalog: catalog, question: question, focus: focus) { messages in
                                try await complete(messages, phase: "claim-selection")
                            }
                            readingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: userEntry.id, focus: focus)
                            record["readingDocument"] = try object(readingDocument)
                            record["claimAnswer"] = try object(answer)
                            record["answer"] = answer.text
                            record["status"] = "locally-rendered-claims"
                        } else {
                            record["answer"] = BaziFrameworkReading.unavailableReply(hasBirth: birth != nil, focus: focus)
                            record["status"] = "claims-unavailable"
                        }
                    } else {
                        record["executionPath"] = "verified-prose"
                        var draft = ""
                        var deltas = 0
                        for try await delta in client.streamText(messages: history) { draft += delta; deltas += 1 }
                        record["draft"] = draft
                        record["streamDeltas"] = deltas
                        record["writerHistory"] = try object(history)
                        do {
                            record["answer"] = try await ReadingVerifier.verify(draft: draft, history: history, question: question) { messages in
                                try await complete(messages, phase: messages.first?.content == ReadingVerifier.instruction ? "verifier" : "revision")
                            }
                            record["status"] = "accepted"
                        } catch let error as ReadingVerifier.Rejected {
                            record["status"] = "fact-fallback"
                            record["rejectionReason"] = error.reason
                            record["answer"] = ReadingFallback.reply(history: history)
                        }
                    }
                } catch {
                    record["status"] = "error"
                    record["error"] = error.localizedDescription
                }
                userEntry.toolContext = context
                userEntry.toolReceipts = receipts
                conversation[conversation.count - 1] = userEntry
                if let text = record["answer"] as? String {
                    var reply = ConversationEntry(role: "assistant", text: text)
                    reply.readingDocument = readingDocument
                    conversation.append(reply)
                }
                record["exchanges"] = exchanges
                record["receipts"] = try object(receipts)
                records.append(record)
                var report = reportBase; report["cases"] = records
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output, options: .atomic)
                print("\(record["id"]!): \(record["status"] ?? "unknown"), \(receipts.count) preserved receipts")
            }
        }
    }
}
