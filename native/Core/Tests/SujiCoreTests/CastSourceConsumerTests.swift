import XCTest
@testable import SujiCore

/// A real, complete all-moving chart exercises the directory threshold and the
/// same storage/layout codecs used by live casting, save, and replay.
enum CastSourceTestFixture {
    static func make() throws -> (root:JSONValue, receipt:ToolReceipt, directory:ChatMessage, prefix:[ChatMessage], tool:ChatMessage) {
        let folder=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Engine/validation/research-divination/efficacy-2026-09-21/swift-fixtures.json")
        let fixture=try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:folder))
        guard case let .array(rows)=fixture,
              let row=rows.first(where:{ReadingVerificationEvidence.pointer("/name",in:$0) == "all-moving"}),
              let root=ReadingVerificationEvidence.pointer("/reading",in:row) else {throw EngineError.execution("Missing all-moving source fixture")}
        let raw=ReadingVerificationEvidence.encoded(root)
        let context=try ToolContext(birth:nil,engineRevision:"directory-consumer-test",referenceDate:Date(timeIntervalSince1970:1_789_792_000),mode:"起卦")
        let receipt=ToolReceipt(callID:"source-cast",name:"cast_liuyao",arguments:[:],output:try CastReceiptStorage.encode(raw),context:context)
        let directory=try XCTUnwrap(CastSourceDirectory.message(receipt:receipt))
        let prefix:[ChatMessage]=[.init(role:.user,content:"核对完整原盘依据"),directory,.assistantToolCalls([receipt.call])]
        let output=NatalEvidenceProjection.output(receipt.output,name:receipt.name,delivered:prefix,callID:receipt.callID)
        return (root,receipt,directory,prefix,.toolResult(.init(callID:receipt.callID,output:output)))
    }
}

final class CastSourceConsumerTests:XCTestCase {
    func testSharedDirectoryRestoresLegacyFormAndRejectsBrokenDictionary() throws {
        let f=try CastSourceTestFixture.make()
        let raw=try JSONDecoder().decode(JSONValue.self,from:Data(f.directory.content!.dropFirst(CastSourceDirectory.prefix.count).utf8))
        XCTAssertNotNil(ReadingVerificationEvidence.pointer("/sharedValueRows",in:raw))
        let restored=try XCTUnwrap(JSONValueTransport.expand(raw))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/ruleSources",in:restored),ReadingVerificationEvidence.pointer("/ruleSources",in:f.root))
        var legacy=f.directory;legacy.content=CastSourceDirectory.prefix+ReadingVerificationEvidence.encoded(restored)
        XCTAssertEqual(ToolOutputWire.decode(f.tool,history:[legacy,.assistantToolCalls([f.receipt.call])]),f.root)
        guard case var .object(broken)=raw else{return XCTFail()}
        broken.removeValue(forKey:"sharedValueRows")
        var damaged=f.directory;damaged.content=CastSourceDirectory.prefix+ReadingVerificationEvidence.encoded(JSONValue.object(broken))
        XCTAssertNil(ToolOutputWire.decode(f.tool,history:[damaged,.assistantToolCalls([f.receipt.call])]))
    }

    func testActualDirectoryPreservesExactSourceFactsFallbackAndVerifier() throws {
        let f=try CastSourceTestFixture.make(),history=f.prefix+[f.tool]
        XCTAssertTrue(try XCTUnwrap(f.tool.content).contains("ruleSourcesFromDirectory"))
        XCTAssertThrowsError(try CastReceiptStorage.expanded(f.tool.content!))
        XCTAssertNil(ToolOutputWire.decode(f.tool.content!))
        XCTAssertEqual(ToolOutputWire.decode(f.tool,history:f.prefix),f.root)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(f.receipt,in:history))
        let inline:[ChatMessage]=[.assistantToolCalls([f.receipt.call]),.toolResult(.init(callID:f.receipt.callID,output:ReadingVerificationEvidence.encoded(f.root)))]
        let facts=ReadingVerificationEvidence.facts(history)
        XCTAssertFalse(facts.isEmpty)
        XCTAssertTrue(facts.contains{$0.pointer.hasSuffix("/quote")})
        XCTAssertTrue(facts.contains{$0.pointer.hasSuffix("/sha256")})
        XCTAssertEqual(facts.map{$0.pointer},ReadingVerificationEvidence.facts(inline).map{$0.pointer})
        XCTAssertEqual(facts.map{$0.value},ReadingVerificationEvidence.facts(inline).map{$0.value})
        XCTAssertEqual(ReadingFallback.reply(history:history),ReadingFallback.reply(history:inline))
        let verifier=ReadingVerifier.messages(draft:"保留已取得的盘面事实。",history:history,question:"核对完整原盘依据")
        XCTAssertEqual(verifier.filter(CastSourceDirectory.isDirectory),[f.directory])
        XCTAssertNoThrow(try ToolOutputWire.validateSourceReferences(verifier))
        let index=try XCTUnwrap(verifier.firstIndex(of:f.tool))
        XCTAssertEqual(ToolOutputWire.decode(f.tool,history:Array(verifier.prefix(index))),f.root)
    }

    func testMissingDamagedAmbiguousStaleAndForwardDirectoriesFailClosed() throws {
        let f=try CastSourceTestFixture.make(),call=ChatMessage.assistantToolCalls([f.receipt.call])
        var damaged=f.directory
        damaged.content=damaged.content!.replacingOccurrences(of:"\"sha256\":\"",with:"\"sha256\":\"tampered-")
        var alteredSources=f.directory
        let metadata=try JSONDecoder().decode(JSONValue.self,from:Data(f.directory.content!.dropFirst(CastSourceDirectory.prefix.count).utf8))
        guard case var .object(fields)=metadata,case var .array(sources)=fields["ruleSources"] else {return XCTFail("Invalid test directory")}
        sources.append(["id":"injected-source","quote":"并非原始来源"])
        fields["ruleSources"] = .array(sources)
        alteredSources.content=CastSourceDirectory.prefix+ReadingVerificationEvidence.encoded(JSONValue.object(fields))
        var wrongRole=f.directory;wrongRole.role = .user
        var wrongCall=f.receipt.call;wrongCall.name="setup_qimen"
        let cases:[[ChatMessage]]=[
            [call,f.tool],
            [damaged,call,f.tool],
            [alteredSources,call,f.tool],
            [f.directory,f.directory,call,f.tool],
            [f.directory,.init(role:.user,content:"另一轮问题"),call,f.tool],
            [call,f.tool,f.directory],
            [call,f.directory,f.tool],
            [wrongRole,call,f.tool],
            [f.directory,.assistantToolCalls([wrongCall]),f.tool],
            [f.directory,call,call,f.tool],
            [f.directory,.init(role:.system,content:nil,toolCalls:[f.receipt.call]),f.tool]
        ]
        for (number,history) in cases.enumerated() {
            XCTAssertTrue(ReadingVerificationEvidence.facts(history).isEmpty,"case \(number)")
            XCTAssertTrue(ReadingFallback.reply(history:history).contains("尚未取得可用"),"case \(number)")
            XCTAssertFalse(NatalEvidenceProjection.wasDelivered(f.receipt,in:history),"case \(number)")
            XCTAssertThrowsError(try ToolOutputWire.validateSourceReferences(history),"case \(number)")
        }
    }

    func testInlineAndReferencedSourcesCannotCoexist() throws {
        let f=try CastSourceTestFixture.make()
        var wire=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(f.tool.content!.utf8)) as? [String:Any])
        wire["ruleSources"]=[]
        let raw=String(decoding:try JSONSerialization.data(withJSONObject:wire),as:UTF8.self)
        let tool=ChatMessage.toolResult(.init(callID:f.receipt.callID,output:raw))
        XCTAssertNil(ToolOutputWire.decode(tool,history:f.prefix))
        XCTAssertTrue(ReadingVerificationEvidence.facts(f.prefix+[tool]).isEmpty)
        XCTAssertThrowsError(try ToolOutputWire.validateSourceReferences(f.prefix+[tool]))
    }

    func testWireOnlyPayloadCannotAuthenticateAsASavedReceiptByByteEquality() throws {
        let f=try CastSourceTestFixture.make()
        var invalid=f.receipt;invalid.output=f.tool.content!
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(invalid,in:[f.tool]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(invalid,in:f.prefix+[f.tool]))
    }

    func testVerifierCannotRebindAnOlderDirectoryWhenItRemovesConversationText() throws {
        let f=try CastSourceTestFixture.make()
        let stale:[ChatMessage]=[f.directory,.init(role:.user,content:"另一轮问题"),.assistantToolCalls([f.receipt.call]),f.tool]
        XCTAssertTrue(ReadingVerificationEvidence.facts(stale).isEmpty)
        let review=ReadingVerifier.messages(draft:"保留已取得的盘面事实。",history:stale,question:"另一轮问题")
        XCTAssertEqual(Array(review.dropFirst()),stale,"Preserve the user boundary so the stale reference remains invalid")
        XCTAssertTrue(ReadingVerificationEvidence.facts(review).isEmpty)
        XCTAssertThrowsError(try ToolOutputWire.validateSourceReferences(review))
    }

    func testInvalidDirectoryRejectsReviewBeforeAnyCompletionClosureCanAcceptIt() async throws {
        let f=try CastSourceTestFixture.make()
        let stale:[ChatMessage]=[f.directory,.init(role:.user,content:"另一轮问题"),.assistantToolCalls([f.receipt.call]),f.tool]
        do {
            _ = try await ReadingVerifier.verify(draft:"已取得完整盘面。",history:stale,question:"另一轮问题",complete:{_ in
                XCTFail("No provider or custom completion may accept detached sources")
                return .text(#"{"protocolVersion":"suji-verification-2","accepted":true,"reviewedSentences":[1],"issues":[]}"#)
            })
            XCTFail("Invalid source directory must reject verification")
        } catch let error as ReadingVerifier.Rejected {
            XCTAssertEqual(error.reason,"invalid_source_directory")
        }
    }

    func testSavedReceiptRebuildsDirectoryForReplayAndNewRetryCallID() throws {
        let f=try CastSourceTestFixture.make()
        let restored=try JSONDecoder().decode(ToolReceipt.self,from:JSONEncoder().encode(f.receipt))
        XCTAssertEqual(try CastReceiptStorage.expanded(restored.output),f.root)
        var entry=ConversationEntry(role:"user",text:"核对完整原盘依据")
        entry.toolReceipts=[restored]
        let replay=ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:restored.context)
        let index=try XCTUnwrap(replay.firstIndex{$0.role == .tool})
        XCTAssertEqual(replay.filter(CastSourceDirectory.isDirectory),[f.directory])
        XCTAssertEqual(ToolOutputWire.decode(replay[index],history:Array(replay.prefix(index))),f.root)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(restored,in:replay))
        let retryID="source-cast-retry",retryCall=ChatToolCall(id:retryID,name:restored.name,arguments:restored.arguments)
        let retryDirectory=try XCTUnwrap(CastSourceDirectory.message(receipt:restored,callID:retryID))
        let prefix:[ChatMessage]=[.init(role:.user,content:"重试"),retryDirectory,.assistantToolCalls([retryCall])]
        let output=NatalEvidenceProjection.output(restored.output,name:restored.name,delivered:prefix,callID:retryID)
        XCTAssertEqual(ToolOutputWire.decode(output,name:restored.name,history:prefix,callID:retryID),f.root)
        XCTAssertNil(ToolOutputWire.decode(output,name:restored.name,history:f.prefix,callID:retryID))
    }
}
