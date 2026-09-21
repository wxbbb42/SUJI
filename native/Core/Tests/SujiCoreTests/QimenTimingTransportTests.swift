import XCTest
@testable import SujiCore

final class QimenTimingTransportTests: XCTestCase {
    private let now = "2004-05-09T04:00:00Z"
    private func fixture(escapedEvent:Bool=false,instant:String?=nil,focus:String="self",unit:String="day") async throws -> (JSONValue,ToolReceipt,ToolContext) {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let reference=instant ?? now
        let event=escapedEvent ? "事"+String(repeating:"\u{1}",count:199):String(repeating:"事",count:200),question=String(repeating:"问",count:1600)
        let arguments:JSONValue=["question":.string(question),"questionType":"career","subject":"self","event":.string(event),"timeHorizon":"far",
            "timingRequest":["focus":.string(focus),"event":.string(event),"timeUnit":.string(unit),"window":["end":"2100-12-31T23:59:59+08:00","maxCandidates":256]]]
        let request:JSONValue=["command":"tool","name":"setup_qimen","arguments":arguments,"now":.string(reference)]
        let data=try await bridge.request(ReadingVerificationEvidence.encoded(request))
        let envelope=try JSONDecoder().decode(JSONValue.self,from:data)
        let result=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:result) else { throw EngineError.execution("Missing revision") }
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:reference)!,mode:"起卦")
        return (result,ToolReceipt(callID:String(repeating:"q",count:200),name:"setup_qimen",arguments:arguments,output:ReadingVerificationEvidence.encoded(result),context:context),context)
    }

    func testMaximumPeriodVoidCalendarKeepsEveryDateWithinWireBudget() async throws {
        let (original,receipt,context)=try await fixture()
        guard case let .array(dates)=ReadingVerificationEvidence.pointer("/timing/dates",in:original) else { return XCTFail("Missing dates") }
        XCTAssertEqual(dates.count,172)
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/timing/searchPolicy/reason",in:original),"period-limit")
        let packed=try CastReceiptStorage.encode(receipt.output)
        XCTAssertEqual(try CastReceiptStorage.expanded(packed),original)
        var saved=receipt;saved.output=packed
        let report=try XCTUnwrap(QimenReferenceReading.render(receipts:[saved],context:context))
        XCTAssertTrue(report.text.contains("条件候选"))
        let prefix=[ChatMessage.assistantToolCalls([saved.call])]
        let output=NatalEvidenceProjection.output(packed,name:saved.name,delivered:prefix,callID:saved.callID)
        print("Qimen max timing raw \(receipt.output.utf16.count)/\(receipt.output.utf8.count), stored \(packed.utf16.count)/\(packed.utf8.count), wire \(output.utf16.count)/\(output.utf8.count)")
        XCTAssertLessThanOrEqual(packed.utf8.count,60_000)
        XCTAssertLessThanOrEqual(output.utf16.count,32_000)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(saved,in:prefix+[.toolResult(.init(callID:saved.callID,output:output))]))
        let facts=ReadingVerificationEvidence.facts(prefix+[.toolResult(.init(callID:saved.callID,output:output))])
        XCTAssertTrue(facts.contains { $0.pointer == "/timing/dates/171/startsAt" })
        let argumentsData=try JSONEncoder().encode(saved.arguments)
        XCTAssertLessThanOrEqual(argumentsData.count,8_000)
    }
    func testLargerChartAcrossEveryUnitKeepsFullCandidateArrays() async throws {
        // Largest raw chart among a 720-clock / four-focus representative capacity probe.
        for unit in ["year","month","day","hour"] {
            let (original,receipt,context)=try await fixture(escapedEvent:true,instant:"2004-07-02T08:00:00Z",focus:"relationship",unit:unit)
            let stored=try CastReceiptStorage.encode(receipt.output)
            XCTAssertEqual(try CastReceiptStorage.expanded(stored),original)
            var saved=receipt;saved.output=stored
            XCTAssertNotNil(QimenReferenceReading.render(receipts:[saved],context:context),unit)
            let wire=NatalEvidenceProjection.output(stored,name:saved.name,delivered:[.assistantToolCalls([saved.call])],callID:saved.callID)
            XCTAssertLessThanOrEqual(wire.utf16.count,32_000,unit)
            XCTAssertLessThanOrEqual(stored.utf8.count,60_000,unit)
            print("Qimen larger \(unit) wire \(wire.utf16.count)/\(wire.utf8.count)")
        }
    }

    func testPackedMaximumCalendarReassessesThroughJSCAndNativeSupplement() async throws {
        let (original,receipt,context)=try await fixture()
        var saved=receipt;saved.output=try CastReceiptStorage.encode(receipt.output)
        var source=ConversationEntry(role:"user",text:"核对原盘条件日期")
        source.date=context.referenceDate;source.toolContext=context;source.analysisMode=context.mode;source.toolReceipts=[saved]
        let link=try CastSupplement.select(entryID:source.id,callID:saved.callID,entries:[source],context:context)
        var user=ConversationEntry(role:"user",text:"补充应期范围");user.toolContext=context;user.castSupplement=link
        var draft=try CastQuestionDraft(call:.init(id:"packed-supplement",name:"setup_qimen",arguments:link.arguments))
        draft.timingEnabled=true;draft.timingFocus="self";draft.timingUnit="day";draft.timingEndDate="2100-12-31"
        let confirmation=try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let request:JSONValue=["command":"reassess-question","name":"setup_qimen","sourceCallID":.string(saved.callID),"original":try JSONDecoder().decode(JSONValue.self,from:Data(saved.output.utf8)),"arguments":confirmation.call.arguments]
        let envelope=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(request)))
        let revised=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        let amended=ToolReceipt(callID:confirmation.call.id,name:link.derivedName,arguments:confirmation.call.arguments,output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(revised)),context:context)
        user.confirmedCastQuestions=[confirmation];user.toolReceipts=[amended]
        let restored=try JSONDecoder().decode([ConversationEntry].self,from:JSONEncoder().encode([source,user]))
        let restoredLink=try XCTUnwrap(restored[1].castSupplement)
        let text=try restoredLink.render(receipt:amended,confirmation:confirmation,userID:user.id,entries:restored,context:context)
        XCTAssertTrue(text.contains("沿用原盘"));XCTAssertTrue(text.contains("条件候选"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/palaces",in:original),ReadingVerificationEvidence.pointer("/palaces",in:revised))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/setupTime",in:original),ReadingVerificationEvidence.pointer("/setupTime",in:revised))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/timing/dates/0",in:original),ReadingVerificationEvidence.pointer("/timing/dates/0",in:revised))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/timing/searchPolicy/maxCandidates",in:revised),32)
        XCTAssertEqual(try CastReceiptStorage.expanded(restoredLink.original.output),original)
    }

    func testCalendarGridPreservesClippedMillisecondsAndUnknownFields() throws {
        var original:JSONValue=["unknownFutureField":["false":false,"null":.null,"ordered":[3,1,2]],"timing":["dates":[
            ["unit":"hour","ganZhi":"甲子","branch":"子","startsAt":"2004-06-03T15:00:00.001Z","endsAt":"2004-06-03T17:00:00.003Z","eligibleStart":"2004-06-03T15:12:34.567Z","eligibleEnd":"2004-06-03T17:00:00.003Z","triggerIds":["void-fill","other"],"firstWindow":true],
            ["unit":"hour","ganZhi":"乙丑","branch":"丑","startsAt":"2004-06-03T17:00:00.003Z","endsAt":"2004-06-03T19:00:00.002Z","eligibleStart":"2004-06-03T17:00:00.003Z","eligibleEnd":"2004-06-03T18:23:45.678Z","triggerIds":["void-clash"],"firstWindow":false]
        ]]]
        if case var .object(root)=original,case var .object(timing)=root["timing"],case let .array(dates)=timing["dates"] {
            timing["dates"] = .array(Array(repeating:dates,count:8).flatMap{$0});root["timing"] = .object(timing);original = .object(root)
        }
        let packed=QimenTimingTransport.encode(ReadingVerificationEvidence.encoded(original))
        let decoded=try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))
        XCTAssertEqual(QimenTimingTransport.expand(decoded),original)
        XCTAssertEqual(QimenTimingTransport.encode(packed),packed)
        for step in [JSONValue.integer(0),.integer(Int64.max),.double(0.5)] {
            guard case var .object(root)=decoded,case var .object(metadata)=root["qimenTimingDateRows"],case var .object(grid)=metadata["timestamps"] else {return XCTFail("Expected exact timestamp grid")}
            grid["stepMilliseconds"]=step;metadata["timestamps"] = .object(grid);root["qimenTimingDateRows"] = .object(metadata)
            XCTAssertNil(QimenTimingTransport.expand(.object(root)))
        }
    }

    func testCalendarDictionaryRejectsDamageAndPreservesAllEvidence() async throws {
        let (original,receipt,_)=try await fixture()
        let packed=QimenTimingTransport.encode(receipt.output)
        let value=try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))
        XCTAssertEqual(QimenTimingTransport.expand(value),original)
        let object=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(packed.utf8)) as? [String:Any])
        for kind in 0..<9 {
            var root=object,m=root["qimenTimingDateRows"] as! [String:Any],timing=root["timing"] as! [String:Any],dates=timing["dates"] as! [[Any]]
            switch kind {
            case 0:root.removeValue(forKey:"qimenTimingDateRows")
            case 1:m["version"]=2
            case 2:var grid=m["timestamps"] as! [String:Any];grid["offsets"]=(grid["offsets"] as! [Int])+[9999];m["timestamps"]=grid
            case 3:dates[0][3] = -1
            case 4:dates[0][7] = 999
            case 5:dates[0][3] = 0.5
            case 6:dates[0].append(false)
            case 7:m["triggerSets"]=(m["triggerSets"] as! [[String]])+[["unused"]]
            default:dates[0][8]="false"
            }
            if kind != 0 {root["qimenTimingDateRows"]=m}
            timing["dates"]=dates;root["timing"]=timing
            let changed=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:root))
            XCTAssertNil(QimenTimingTransport.expand(changed),"mutation \(kind)")
        }
    }

    func testPairedActualChartsPersistReplayAndVerifyUnderExistingBudgets() async throws {
        let (_,qimen,context)=try await fixture(escapedEvent:true)
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:directory)}
        let script=try String(contentsOf:native.appendingPathComponent("Resources/mingli.js"),encoding:.utf8)
        let seeded=directory.appendingPathComponent("engine.js")
        let draws=[6,6,6,6,9,9].flatMap { Array(repeating:$0==6 ? 0.0:0.75,count:3) }
        try (script+"\nlet coinCalls=0;const draws="+ReadingVerificationEvidence.encoded(draws)+";Math.random=()=>draws[coinCalls++];").write(to:seeded,atomically:true,encoding:.utf8)
        let bridge=try MingliBridge(scriptURL:seeded)
        guard case var .object(liuArgs)=qimen.arguments else {return XCTFail("arguments")}
        liuArgs.removeValue(forKey:"timingRequest");liuArgs["questionType"]="parents";liuArgs["subject"]="parent"
        let liuCall=ChatToolCall(id:String(repeating:"l",count:200),name:"cast_liuyao",arguments:.object(liuArgs))
        let request:JSONValue=["command":"tool","name":"cast_liuyao","arguments":liuCall.arguments,"now":.string(now)]
        let data=try await bridge.request(ReadingVerificationEvidence.encoded(request)),envelope=try JSONDecoder().decode(JSONValue.self,from:data)
        let liuResult=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        let calls=[liuCall,qimen.call],outputs=[liuCall.id:ReadingVerificationEvidence.encoded(liuResult),qimen.callID:qimen.output]
        let definitions=calls.map {ChatToolDefinition(name:$0.name,description:$0.name,parameters:["type":"object","properties":[:]])}
        for call in calls {
            let raw=outputs[call.id]!,stored=try CastReceiptStorage.encode(raw)
            let saved=ToolReceipt(callID:call.id,name:call.name,arguments:call.arguments,output:stored,context:context)
            let prefix=CastSourceDirectory.message(receipt:saved).map{[$0]} ?? []
            let wire=NatalEvidenceProjection.output(stored,name:call.name,delivered:prefix+[.assistantToolCalls(calls)],callID:call.id)
            print("Qimen pair component \(call.name) raw \(raw.utf16.count)/\(raw.utf8.count), stored \(stored.utf16.count)/\(stored.utf8.count), wire \(wire.utf16.count)/\(wire.utf8.count), args \(try JSONEncoder().encode(call.arguments).count)")
            XCTAssertLessThanOrEqual(try JSONEncoder().encode(call.arguments).count,8_000)
        }
        let originalQuestion=String(repeating:"问",count:8000)
        let history=[ChatMessage(role:.user,content:originalQuestion)]
        var round=0
        let orchestrator=ToolOrchestrator(complete:{_,_ in round += 1;return round==1 ? .toolCalls(calls):.text("ready")},execute:{call in .init(output:outputs[call.id]!,evidence:[call.id])})
        let result=try await orchestrator.run(history:history,definitions:definitions,context:context)
        XCTAssertEqual(result.receipts.count,2)
        let messages=result.messages.filter{$0.role == .tool},sizes=messages.map{$0.content!.utf8.count}
        print("Qimen timing paired wire \(sizes), UTF16 \(messages.map{$0.content!.utf16.count})")
        XCTAssertEqual(messages.count,2)
        XCTAssertLessThanOrEqual(sizes.reduce(0,+),60_000)
        for (index,message) in result.messages.enumerated() where message.role == .tool {
            let call=try XCTUnwrap(calls.first{$0.id==message.toolCallID})
            let decoded=try XCTUnwrap(ToolOutputWire.decode(message,history:Array(result.messages.prefix(index))))
            guard case var .object(root)=decoded else { return XCTFail("Decoded chart must be an object") }
            if let reference=root.removeValue(forKey:"questionFromArguments") {
                XCTAssertEqual(ReadingVerificationEvidence.pointer("/toolCallID",in:reference),.string(call.id))
                XCTAssertEqual(ReadingVerificationEvidence.pointer("/pointer",in:reference),"/question")
                root["question"]=ReadingVerificationEvidence.pointer("/question",in:call.arguments)
            }
            XCTAssertEqual(JSONValue.object(root),try JSONDecoder().decode(JSONValue.self,from:Data(outputs[call.id]!.utf8)),"Every chart field and candidate survives contextual wire decoding")
        }
        for receipt in result.receipts {
            XCTAssertEqual(try CastReceiptStorage.expanded(receipt.output),try JSONDecoder().decode(JSONValue.self,from:Data(outputs[receipt.callID]!.utf8)))
            XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:result.messages))
        }
        var entry=ConversationEntry(role:"user",text:originalQuestion);entry.toolReceipts=result.receipts
        let restored=try JSONDecoder().decode(ConversationEntry.self,from:JSONEncoder().encode(entry))
        let replay=ReadingPrompt.history(from:[restored],currentUserID:restored.id,context:context)
        XCTAssertTrue(replay.filter{$0.role == .tool}.map(\.content)==messages.map(\.content),"Replay retains the same delivered outputs")
        let retry=ToolOrchestrator(complete:{_,_ in .text("ready")},execute:{_ in XCTFail("No recast");return .init(output:"{}")})
        let retried=try await retry.run(history:replay,definitions:definitions,cachedReceipts:result.receipts,context:context)
        XCTAssertEqual(retried.evidence,calls.map(\.id))
        let review=ReadingVerifier.messages(draft:"以下仅为条件候选，事件结果未定。",history:result.messages,question:originalQuestion)
        let total=review.reduce(0){$0+($1.content?.utf16.count ?? 0)+($1.toolCalls ?? []).reduce(0){$0+ReadingVerificationEvidence.encoded($1.arguments).utf16.count}}
        print("Qimen timing paired verifier \(total) UTF16, \(try JSONEncoder().encode(review).count) bytes")
        let reviewSizes=review.enumerated().map { "\($0.offset):\($0.element.role.rawValue):\($0.element.content?.utf16.count ?? 0)" }
        print("Qimen timing verifier messages \(reviewSizes)")
        XCTAssertLessThanOrEqual(total,120_000);XCTAssertLessThan(try JSONEncoder().encode(review).count+1024,262_144)
        for message in review {XCTAssertLessThanOrEqual(message.content?.utf16.count ?? 0,32_000)}
    }

}
