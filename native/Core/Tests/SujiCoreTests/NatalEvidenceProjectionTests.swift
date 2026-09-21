import XCTest
@testable import SujiCore

final class NatalEvidenceProjectionTests: XCTestCase {
    private let definition = ChatToolDefinition(name:"get_domain", description:"domain", parameters:["type":"object","properties":["domain":["type":"string"]],"required":["domain"]])

    func testLongCastQuestionReferencesOnlyItsExactCallArgument() throws {
        let question=String(repeating:"保留原问题，不改变盘面。",count:120)
        for name in ["cast_liuyao","setup_qimen"] {
            let full=ReadingVerificationEvidence.encoded(JSONValue.object(["question":.string(question),"lines":[],"questionContext":["event":"核对"]]))
            let call=ChatToolCall(id:"cast",name:name,arguments:["question":.string(question)])
            let before=[ChatMessage.assistantToolCalls([call])]
            let projected=NatalEvidenceProjection.output(full,name:name,delivered:before)
            let root=try JSONDecoder().decode(JSONValue.self,from:Data(projected.utf8))
            XCTAssertNil(ReadingVerificationEvidence.pointer("/question",in:root))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/questionFromArguments/toolCallID",in:root),"cast")
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/questionFromArguments/pointer",in:root),"/question")
            let receipt=ToolReceipt(callID:"cast",name:name,arguments:call.arguments,output:full,evidence:["cast"])
            let result=ChatMessage.toolResult(.init(callID:"cast",output:projected))
            XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:before+[result]))
            XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[result]))
            let wrong=ChatMessage.assistantToolCalls([.init(id:"cast",name:name,arguments:["question":"另一件事"])])
            XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[wrong,result]))
            XCTAssertEqual(NatalEvidenceProjection.output(full,name:name,delivered:[wrong]),full)
            XCTAssertEqual(NatalEvidenceProjection.output(full,name:name,delivered:[]),full)
            // A different call, even with identical words, cannot authenticate this receipt.
            let other=ChatMessage.assistantToolCalls([.init(id:"other",name:name,arguments:call.arguments)])
            XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[other,result]))
        }
    }

    func testStandalonePalaceReferencesKeepIdentityOriginalSourceAndCompleteReceipts() throws {
        let stars: JSONValue = [["name":"天同","detail":.string(String(repeating:"source",count:80))]]
        let method: JSONValue = ["algorithm":.string(String(repeating:"selected",count:60))]
        let palace: JSONValue = ["palace":"夫妻宫","starDetails":stars,"method":method]
        let full = ReadingVerificationEvidence.encoded(JSONValue.object(["palace":"夫妻宫","starDetails":stars,"method":method,"palaceFlights":["scope":"natal-palace-stem","outgoing":[["sourcePalace":"夫妻宫","targetPalace":"父母宫"]]]]))
        for sourceObject: JSONValue in [["ziwei":palace],["ziwei":["palace":"官禄宫","relatedPalaces":[palace]]]] {
        let source = ReadingVerificationEvidence.encoded(sourceObject)
        let calls = ChatMessage.assistantToolCalls([.init(id:"a",name:"get_domain",arguments:[:]),.init(id:"b",name:"get_ziwei_palace",arguments:[:]),.init(id:"c",name:"get_ziwei_palace",arguments:[:])])
        let earlier = [calls,ChatMessage.toolResult(.init(callID:"a",output:source))]
        let projected = NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:earlier)
        let value = try JSONDecoder().decode(JSONValue.self,from:Data(projected.utf8))
        let original = try JSONDecoder().decode(JSONValue.self,from:Data(full.utf8))
        XCTAssertNil(ReadingVerificationEvidence.pointer("/starDetails",in:value))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/palaceFlights",in:value),ReadingVerificationEvidence.pointer("/palaceFlights",in:original))
        let repeated = NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:earlier+[.toolResult(.init(callID:"b",output:projected))])
        let repeatedValue = try JSONDecoder().decode(JSONValue.self,from:Data(repeated.utf8))
        // The second receipt may retain a concrete method even though its star
        // details are references. Sharing that concrete method is not a chain.
        guard case let .array(repeatedRefs) = ReadingVerificationEvidence.pointer("/reusedFacts",in:repeatedValue) else { return XCTFail("Missing repeated references") }
        for ref in repeatedRefs {
            guard case let .string(id) = ReadingVerificationEvidence.pointer("/toolCallID",in:ref),case let .string(path) = ReadingVerificationEvidence.pointer("/path",in:ref),case let .string(pointer) = ReadingVerificationEvidence.pointer("/pointer",in:ref) else { return XCTFail("Missing repeated identity") }
            let sourceValue = id == "a" ? sourceObject : value
            XCTAssertTrue(["a","b"].contains(id))
            if path == "/starDetails" { XCTAssertEqual(id,"a") }
            XCTAssertEqual(ReadingVerificationEvidence.pointer(pointer,in:sourceValue),ReadingVerificationEvidence.pointer(path,in:original))
        }
        guard case let .array(refs) = ReadingVerificationEvidence.pointer("/reusedFacts",in:value) else { return XCTFail("Missing explicit references") }
        for ref in refs {
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/toolCallID",in:ref),"a")
            guard case let .string(path) = ReadingVerificationEvidence.pointer("/path",in:ref),case let .string(pointer) = ReadingVerificationEvidence.pointer("/pointer",in:ref) else { return XCTFail("Missing pointer") }
            let sourceValue = try JSONDecoder().decode(JSONValue.self,from:Data(source.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer(pointer,in:sourceValue),ReadingVerificationEvidence.pointer(path,in:original))
        }
        let wrongPalace = source.replacingOccurrences(of:"夫妻宫",with:"父母宫")
        let wrongProjection = NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:[calls,.toolResult(.init(callID:"a",output:wrongPalace))])
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/starDetails",in:try JSONDecoder().decode(JSONValue.self,from:Data(wrongProjection.utf8))),stars)
        XCTAssertEqual(NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:[calls]),full)
        let context = try ToolContext(birth:nil,engineRevision:"fixture",referenceDate:Date(),mode:"命理")
        let receipt = ToolReceipt(callID:"b",name:"get_ziwei_palace",arguments:[:],output:full,context:context)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:earlier+[.toolResult(.init(callID:"b",output:projected))]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[calls,.toolResult(.init(callID:"b",output:projected))]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[calls,.toolResult(.init(callID:"a",output:wrongPalace)),.toolResult(.init(callID:"b",output:projected))]))
        }
    }

    func testRelatedPalaceFieldsShareOnlyConcreteSamePalaceValuesAcrossReorderedArrays() throws {
        let stars:JSONValue = [["name":"天同","sihua":[.string(String(repeating:"化禄",count:150))]]]
        let primary:JSONValue = ["palace":"夫妻宫","starDetails":stars]
        let other:JSONValue = ["palace":"父母宫","starDetails":stars]
        let source:JSONValue = ["ziwei":["palace":"官禄宫","relatedPalaces":[other,primary]]]
        let full:JSONValue = ["palace":"命宫","relatedPalaces":[primary,other]]
        let calls = ChatMessage.assistantToolCalls([.init(id:"a",name:"get_domain",arguments:[:]),.init(id:"b",name:"get_ziwei_palace",arguments:[:])])
        let sourceText = ReadingVerificationEvidence.encoded(source),fullText = ReadingVerificationEvidence.encoded(full)
        let earlier = [calls,ChatMessage.toolResult(.init(callID:"a",output:sourceText))]
        let projected = NatalEvidenceProjection.output(fullText,name:"get_ziwei_palace",delivered:earlier)
        let value = try JSONDecoder().decode(JSONValue.self,from:Data(projected.utf8))
        XCTAssertNil(ReadingVerificationEvidence.pointer("/relatedPalaces/0/starDetails",in:value))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/relatedPalaces/0/palace",in:value),"夫妻宫")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/reusedFacts/0/pointer",in:value),"/ziwei/relatedPalaces/1/starDetails")
        let context = try ToolContext(birth:nil,engineRevision:"fixture",referenceDate:Date(),mode:"命理")
        let receipt = ToolReceipt(callID:"b",name:"get_ziwei_palace",arguments:[:],output:fullText,context:context)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:earlier+[.toolResult(.init(callID:"b",output:projected))]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[calls,.toolResult(.init(callID:"b",output:projected))]))
        let wrong = sourceText.replacingOccurrences(of:"夫妻宫",with:"福德宫")
        let wrongValue = try JSONDecoder().decode(JSONValue.self,from:Data(NatalEvidenceProjection.output(fullText,name:"get_ziwei_palace",delivered:[calls,.toolResult(.init(callID:"a",output:wrong))]).utf8))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/relatedPalaces/0/starDetails",in:wrongValue),stars)
        let sharedAgain = NatalEvidenceProjection.output(fullText,name:"get_ziwei_palace",delivered:earlier+[.toolResult(.init(callID:"b",output:projected))])
        XCTAssertEqual(sharedAgain,projected)
    }

    func testSourceReferencesRequireSameSourceVersionAndIndex() throws {
        let reference:JSONValue = [["url":"https://source.invalid","quote":.string(String(repeating:"source",count:100))]]
        let rule:JSONValue = ["id":"selected-rule","version":"1","references":reference]
        let source:JSONValue = ["ziwei":["ruleSources":[rule]]]
        let full = ReadingVerificationEvidence.encoded(JSONValue.object(["ruleSources":[rule,["id":"extra","version":"1"]]]))
        let calls = ChatMessage.assistantToolCalls([.init(id:"a",name:"get_domain",arguments:[:])])
        func projected(_ earlier:JSONValue) throws -> JSONValue {
            let text = NatalEvidenceProjection.output(full,name:"get_ziwei_palace",delivered:[calls,.toolResult(.init(callID:"a",output:ReadingVerificationEvidence.encoded(earlier)))])
            return try JSONDecoder().decode(JSONValue.self,from:Data(text.utf8))
        }
        let value = try projected(source)
        XCTAssertNil(ReadingVerificationEvidence.pointer("/ruleSources/0/references",in:value))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/ruleSources/0/id",in:value),"selected-rule")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/reusedFacts/0/pointer",in:value),"/ziwei/ruleSources/0/references")
        for wrong:JSONValue in [
            ["ziwei":["ruleSources":[["id":"other","version":"1","references":reference]]]],
            ["ziwei":["ruleSources":[["id":"selected-rule","version":"2","references":reference]]]],
            ["ziwei":["ruleSources":[["id":"other"],rule]]],
        ] {
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/ruleSources/0/references",in:try projected(wrong)),reference)
        }
    }

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
            let rawRoot = try JSONDecoder().decode(JSONValue.self,from:Data(message.content!.utf8))
            let root = try XCTUnwrap(LiuyaoConditionTransport.expand(XCTUnwrap(JSONValueTransport.expand(rawRoot))))
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
