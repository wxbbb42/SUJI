import XCTest
@testable import SujiCore

final class NatalEvidenceProjectionTests: XCTestCase {
    private let definition = ChatToolDefinition(name:"get_domain", description:"domain", parameters:["type":"object","properties":["domain":["type":"string"]],"required":["domain"]])

    func testProjectionRequiresEqualDeliveredValuesAndNeverBuildsReferenceChains() throws {
        let full = ReadingVerificationEvidence.encoded(JSONValue.object(["bazi":.object(["pillars":.string(String(repeating:"A",count:400))]),"domain":.string("事业")]))
        let call = ChatMessage.assistantToolCalls([.init(id:"a",name:"get_domain",arguments:[:]),.init(id:"b",name:"get_domain",arguments:[:])])
        let delivered = [call,ChatMessage.toolResult(.init(callID:"a",output:full))]
        let second = NatalEvidenceProjection.output(full,name:"get_domain",delivered:delivered)
        let third = NatalEvidenceProjection.output(full,name:"get_domain",delivered:delivered + [.toolResult(.init(callID:"b",output:second))])
        for raw in [second,third] {
            let root = try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/reusedFacts/0/toolCallID",in:root),.string("a"))
        }
        let changed = full.replacingOccurrences(of:String(repeating:"A",count:400),with:String(repeating:"B",count:400))
        XCTAssertEqual(NatalEvidenceProjection.output(changed,name:"get_domain",delivered:delivered),changed)
        XCTAssertEqual(NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:delivered),full)
        XCTAssertEqual(NatalEvidenceProjection.output(full,name:"get_domain",delivered:[call,.toolResult(.init(callID:"a",output:#"{"error":"too large"}"#))]),full)
        // A receipt not in delivered messages cannot become a reference source.
        XCTAssertEqual(NatalEvidenceProjection.output(full,name:"get_domain",delivered:[call]),full)
    }

    func testEarlierHistoryAndBudgetRejectedOutputsCannotBecomeReferenceSources() async throws {
        let full = ReadingVerificationEvidence.encoded(JSONValue.object(["bazi":.object(["pillars":.string(String(repeating:"A",count:400))]),"domain":.string("事业")]))
        let earlier: [ChatMessage] = [.assistantToolCalls([.init(id:"old",name:"get_domain",arguments:["domain":"事业"])]),.toolResult(.init(callID:"old",output:full))]
        var round = 0
        let calls: [ChatToolCall] = [.init(id:"oversized",name:"get_domain",arguments:["domain":"事业"]),.init(id:"new",name:"get_domain",arguments:["domain":"事业"])]
        let oversized = String(full.dropLast()) + ",\"extra\":\"" + String(repeating:"X",count:32_000) + "\"}"
        let orchestrator = ToolOrchestrator(complete:{ _,_ in round += 1; return round == 1 ? .toolCalls(calls) : .text("ready") },execute:{ call in .init(output:call.id == "oversized" ? oversized : full) })
        let result = try await orchestrator.run(history:earlier,definitions:[definition])
        XCTAssertTrue(result.messages.first { $0.toolCallID == "oversized" }?.content?.contains("盘面已保存") == true)
        XCTAssertEqual(result.messages.first { $0.toolCallID == "new" }?.content,full)
        XCTAssertEqual(result.receipts.first?.output,oversized)
    }

    func testFourRealDomainsPreserveFullReceiptsAndDeliverEveryPalaceWithResolvableReferences() async throws {
        for birth: [String:Any] in [
            ["year":1990,"month":8,"day":16,"hour":14,"minute":30,"gender":"男","longitude":120],
            ["year":1991,"month":2,"day":14,"hour":13,"minute":30,"gender":"男","longitude":120],
            ["year":2010,"month":9,"day":6,"hour":8,"minute":30,"gender":"女","longitude":120],
            ["year":1994,"month":5,"day":17,"hour":16,"minute":30,"gender":"女","longitude":120],
        ] { try await assertFourDomains(birth:birth) }
    }

    private func assertFourDomains(birth: [String:Any]) async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        var outputs: [String:String] = [:]
        let domains = ["事业","婚姻","财富","迁移"]
        let calls = domains.enumerated().map { ChatToolCall(id:"call_" + String(repeating:"a",count:23) + String($0.offset), name:"get_domain", arguments:["domain":.string($0.element)]) }
        for (index, domain) in domains.enumerated() {
            let request: [String:Any] = ["command":"tool","name":"get_domain","birth":birth,"now":"2026-09-20T04:00:00Z","arguments":["domain":domain]]
            let data = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:request),as:UTF8.self))
            let envelope = try JSONDecoder().decode(JSONValue.self,from:data)
            outputs[calls[index].id] = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope)))
        }
        var round = 0
        var persisted: [ToolReceipt] = []
        let context = try ToolContext(birth:nil,engineRevision:"fixture",referenceDate:Date(timeIntervalSince1970:1_789_920_000),mode:"命理")
        let orchestrator = ToolOrchestrator(complete:{ _,_ in round += 1; return round == 1 ? .toolCalls(calls) : .text("ready") },execute:{ call in .init(output:outputs[call.id]!,evidence:[call.id]) },persistReceipt:{ persisted.append($0) })
        let result = try await orchestrator.run(history:[], definitions:[definition],context:context)
        XCTAssertEqual(result.receipts.map(\.output), calls.map { outputs[$0.id]! })
        XCTAssertEqual(persisted, result.receipts)
        let messages = result.messages.filter { $0.role == .tool }
        XCTAssertEqual(messages.count,4)
        var delivered: [String:JSONValue] = [:]
        var references = 0
        for message in messages {
            let id = try XCTUnwrap(message.toolCallID)
            let root = try JSONDecoder().decode(JSONValue.self,from:Data(message.content!.utf8))
            XCTAssertNil(ReadingVerificationEvidence.pointer("/error",in:root),message.content!)
            XCTAssertNotNil(ReadingVerificationEvidence.pointer("/ziwei/palace",in:root))
            let full = try JSONDecoder().decode(JSONValue.self,from:Data(outputs[id]!.utf8))
            if case let .array(refs) = ReadingVerificationEvidence.pointer("/reusedFacts",in:root) {
                for ref in refs {
                    guard case let .string(sourceID) = ReadingVerificationEvidence.pointer("/toolCallID",in:ref),
                          case let .string(sourcePointer) = ReadingVerificationEvidence.pointer("/pointer",in:ref),
                          case let .string(path) = ReadingVerificationEvidence.pointer("/path",in:ref) else { return XCTFail("Missing reference identity") }
                    let source = try XCTUnwrap(delivered[sourceID])
                    let value = try XCTUnwrap(ReadingVerificationEvidence.pointer(sourcePointer,in:source))
                    XCTAssertEqual(value,ReadingVerificationEvidence.pointer(path,in:full))
                    XCTAssertNil(ReadingVerificationEvidence.pointer(path,in:root))
                    references += 1
                }
            }
            delivered[id] = root
        }
        XCTAssertGreaterThan(references,0)
        let bytes = messages.reduce(0) { $0 + ($1.content?.utf8.count ?? 0) }
        XCTAssertLessThanOrEqual(bytes,60_000)
        let facts = ReadingVerificationEvidence.facts(result.messages)
        XCTAssertTrue(facts.contains { $0.toolCallID == calls[0].id && $0.factKey == "bazi.day.gan" })
        let review = ReadingVerifier.messages(draft:"仅核对各宫事实", history:result.messages, question:"比较四个领域")
        XCTAssertLessThanOrEqual(review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) },120_000)
        XCTAssertLessThanOrEqual(review.count,120)
        let body = try JSONEncoder().encode(review)
        XCTAssertLessThan(body.count + 1024,262_144)
        print("Four-domain delivery: \(bytes) UTF-8 bytes, review \(body.count) bytes")
        var entry = ConversationEntry(role:"user",text:"比较四个领域")
        entry.toolReceipts = result.receipts
        let restored = ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
        let restoredTools = restored.filter { $0.role == .tool }
        XCTAssertEqual(restoredTools.map(\.toolCallID),messages.map(\.toolCallID))
        for (replayed,original) in zip(restoredTools,messages) { XCTAssertEqual(replayed.content,original.content) }
        let retry = ToolOrchestrator(complete:{ _,_ in .text("ready") },execute:{ _ in XCTFail("No recalculation"); return .init(output:"{}") })
        let retried = try await retry.run(history:restored,definitions:[definition],cachedReceipts:result.receipts,context:context)
        XCTAssertEqual(retried.evidence,calls.map(\.id))
    }
}
