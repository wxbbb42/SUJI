import Foundation
import XCTest
@testable import SujiCore

final class BaziFrameworkIntegrationTests: XCTestCase {
    func testActualEngineFollowupsAcquireOneCurrentReceiptEachWithoutModelPlanning() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let metadata = try JSONDecoder().decode(JSONValue.self, from: await bridge.request(#"{"command":"metadata"}"#))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/engineRevision", in: metadata) else { return XCTFail("Missing engine revision") }
        let definitions = try await bridge.request(#"{"command":"tools"}"#)
        let birth = BirthProfile(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
        var entries: [ConversationEntry] = []
        let turns: [(String, ReadingDocument.Focus)] = [("扶抑用神和格局用神为什么不同？", .comparison), ("简单说，我到底用哪个？", .overview), ("那是不是偏印格已成？", .pattern), ("土克水，也是在耗水吗？", .relations), ("调候又怎么看？", .climate), ("简单说", .climate)]
        for (index, turn) in turns.enumerated() {
            let now = Date(timeIntervalSince1970: 1_706_976_000 + Double(index * 60))
            let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: now, mode: "命理")
            var user = ConversationEntry(role: "user", text: turn.0)
            user.date = now; user.analysisMode = "命理"; entries.append(user)
            let focus = try XCTUnwrap(BaziReadingRequest.resolve(question: turn.0, mode: "命理", entries: entries, currentUserID: user.id, context: context))
            XCTAssertEqual(focus, turn.1)
            var executions = 0
            var saved: [ToolReceipt] = []
            let callID = "bazi-" + user.id.uuidString
            let orchestrator = ToolOrchestrator(complete: { history, _ in
                BaziFrameworkReading.plan(callID: callID, history: history, context: context, hasBirth: true)
            }, execute: { call in
                executions += 1
                let request: [String: Any] = ["command": "tool", "name": call.name, "id": call.id, "arguments": try JSONSerialization.jsonObject(with: JSONEncoder().encode(call.arguments)), "now": ISO8601DateFormatter().string(from: now), "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))]
                let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
                try EngineContract.validate(raw, command: "tool")
                let response = try JSONDecoder().decode(JSONValue.self, from: raw)
                let output = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: response))
                return ToolExecutionResult(output: ReadingVerificationEvidence.encoded(output))
            }, persistReceipt: { saved.append($0) })
            let history = ReadingPrompt.history(from: entries, currentUserID: user.id, context: context)
            XCTAssertFalse(history.contains { $0.role == .tool })
            let available = try ReadingIntent.definitions(from: definitions, mode: "命理", question: turn.0, hasBirth: true)
            let result = try await orchestrator.run(history: history, definitions: available, context: context)
            XCTAssertEqual(executions, 1); XCTAssertEqual(saved.count, 1)
            XCTAssertEqual(saved.first?.context, context)
            let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: result.receipts, context: context))
            let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: focus)
            user.toolContext = context; user.toolReceipts = saved; entries[entries.count - 1] = user
            var reply = ConversationEntry(role: "assistant", text: answer.text)
            reply.readingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: user.id, focus: focus)
            XCTAssertTrue(reply.readingDocument!.isValid)
            entries.append(reply)
        }
    }

    func testCurrentEngineAcrossTwelveBirthMonthsCompilesSourceBoundClaims() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let metadata = try JSONDecoder().decode(JSONValue.self, from: await bridge.request(#"{"command":"metadata"}"#))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/engineRevision", in: metadata) else { return XCTFail("Missing engine revision") }
        let now = Date(timeIntervalSince1970: 1_706_976_000)
        for month in 1...12 {
            let birth = BirthProfile(year: 1990, month: month, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
            let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: now, mode: "命理")
            let request: [String: Any] = ["command": "tool", "name": "get_domain", "id": "month-\(month)", "arguments": ["domain": "事业"], "now": ISO8601DateFormatter().string(from: now), "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))]
            let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            try EngineContract.validate(raw, command: "tool")
            let response = try JSONDecoder().decode(JSONValue.self, from: raw)
            let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: response))
            let receipt = ToolReceipt(callID: "month-\(month)", name: "get_domain", arguments: ["domain": "事业"], output: ReadingVerificationEvidence.encoded(result), context: context)
            let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: context), "Month \(month)")
            let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog)
            XCTAssertTrue(answer.text.contains("候选"))
            XCTAssertTrue(answer.text.contains("工程启发式"))
            XCTAssertTrue(answer.text.contains("不能证明两套计算都正确"))
            for claim in catalog.claims {
                XCTAssertFalse(claim.evidence.isEmpty, claim.id)
                for field in claim.evidence {
                    XCTAssertEqual(field.toolCallID, receipt.callID)
                    XCTAssertEqual(ReadingVerificationEvidence.pointer(field.pointer, in: result), field.value)
                }
            }
            // The actual backend accepts a maximum 32,000 UTF-16 code units per message.
            XCTAssertTrue(BaziFrameworkReading.selectionMessages(catalog: catalog, question: "扶抑用神与格局用神为什么不同").allSatisfy { ($0.content?.utf16.count ?? 0) <= 32_000 })
        }
    }
}
