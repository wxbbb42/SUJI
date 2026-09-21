import XCTest
@testable import SujiCore

final class CastReceiptStorageTests:XCTestCase {
    private var folder:URL {URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Engine/validation/research-divination/efficacy-2026-09-21")}
    private func fixtures()throws->[(String,JSONValue)] {
        guard case let .array(rows)=try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:folder.appendingPathComponent("swift-fixtures.json"))) else{throw EngineError.execution("fixture")}
        return try rows.map{r in guard case let .string(name)=ReadingVerificationEvidence.pointer("/name",in:r),let reading=ReadingVerificationEvidence.pointer("/reading",in:r) else{throw EngineError.execution("row")};return (name,reading)}
    }
    private func receipt(_ root:JSONValue,_ output:String,_ id:String="saved")throws->ToolReceipt {
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root),case let .string(stamp)=ReadingVerificationEvidence.pointer("/castTime",in:root) else{throw EngineError.execution("provenance")}
        let iso=ISO8601DateFormatter();iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let date=iso.date(from:stamp) ?? ISO8601DateFormatter().date(from:stamp)!
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:date,mode:"起卦")
        return .init(callID:id,name:"cast_liuyao",arguments:["question":"原文规则核对","questionType":"health","subject":"self","event":"原文规则核对","timeHorizon":"near"],output:output,context:context)
    }
    func testCompleteStorageRoundtripRenderingAndFactLedger()throws {
        var vectors=[JSONValue]()
        for (name,root) in try fixtures() {
            let raw=ReadingVerificationEvidence.encoded(root),packed=try CastReceiptStorage.encode(raw)
            XCTAssertLessThan(packed.utf8.count,60_000,name)
            XCTAssertEqual(try CastReceiptStorage.expanded(packed),root,name)
            XCTAssertEqual(try CastReceiptStorage.encode(packed),packed,"retry bytes")
            let stored=try receipt(root,packed)
            let restored=try JSONDecoder().decode(ToolReceipt.self,from:JSONEncoder().encode(stored))
            XCTAssertEqual(restored,stored)
            let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[restored],context:restored.context!),name)
            for section in report.sections {for evidence in section.evidence {XCTAssertEqual(evidence.value,ReadingVerificationEvidence.pointer(evidence.pointer,in:root),name+evidence.pointer)}}
            func facts(_ output:String)->[String:JSONValue] {
                let history:[ChatMessage]=[.assistantToolCalls([.init(id:"saved",name:"cast_liuyao",arguments:stored.arguments)]),.toolResult(.init(callID:"saved",output:output))]
                return Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(history).map{($0.pointer,$0.value)})
            }
            XCTAssertEqual(facts(raw),facts(packed),name)
            if ["rootless","strong-tomb","all-moving"].contains(name) {vectors.append(.object(["name":.string(name),"packed":.string(packed)]))}
        }
        if let path=ProcessInfo.processInfo.environment["SUJI_RECEIPT_LAYOUT_VECTORS"] {try JSONEncoder().encode(JSONValue.array(vectors)).write(to:URL(fileURLWithPath:path))}
    }
    func testOrchestratorPersistsPackedThenReusesIdenticalBytesWithoutExecution() async throws {
        let root=try fixtures().first{$0.0=="all-moving"}!.1,raw=ReadingVerificationEvidence.encoded(root),base=try receipt(root,raw)
        let probe=StorageProbe()
        let definition=ChatToolDefinition(name:"cast_liuyao",description:"test",parameters:["type":"object","properties":["question":["type":"string"],"questionType":["type":"string"],"subject":["type":"string"],"event":["type":"string"],"timeHorizon":["type":"string"]],"required":["question"]])
        func run(_ id:String,_ cached:[ToolReceipt]) async throws->ToolOrchestrationResult {
            let orchestrator=ToolOrchestrator(complete:{messages,_ in
                messages.contains{$0.role == .tool} ? .text("done") : .toolCalls([.init(id:id,name:"cast_liuyao",arguments:base.arguments)])
            },execute:{_ in await probe.executed();return .init(output:raw,evidence:[])},persistReceipt:{r in await probe.saved(r)})
            return try await orchestrator.run(history:[],definitions:[definition],cachedReceipts:cached,context:base.context)
        }
        let first=try await run("first",[]),stored=try XCTUnwrap(first.receipts.first)
        XCTAssertNotEqual(stored.output,raw);XCTAssertEqual(try CastReceiptStorage.expanded(stored.output),root)
        let second=try await run("retry",[stored])
        XCTAssertEqual(second.receipts.first?.output,stored.output)
        let state=await probe.state();XCTAssertEqual(state.0,1);XCTAssertEqual(state.1,[stored])
        XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[stored],context:stored.context!))
    }
    func testComplete48PairedCapacityMatrix()throws {
        guard let path=ProcessInfo.processInfo.environment["SUJI_LIUYAO_CAPACITY_MATRIX"] else{throw XCTSkip("Set the existing paired-matrix artifact path for the integration capacity probe")}
        guard case let .array(matrix)=try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:URL(fileURLWithPath:path))) else{throw EngineError.execution("matrix")}
        var rows=0,maxBytes=0
        for item in matrix {
            guard case let .array(entries)=ReadingVerificationEvidence.pointer("/rows",in:item) else{throw EngineError.execution("matrix rows")}
            for entry in entries where ReadingVerificationEvidence.pointer("/name",in:entry)=="cast_liuyao" {
                let root=try XCTUnwrap(ReadingVerificationEvidence.pointer("/output",in:entry)),raw=ReadingVerificationEvidence.encoded(root),packed=try CastReceiptStorage.encode(raw)
                XCTAssertLessThanOrEqual(packed.utf8.count,60_000)
                XCTAssertLessThan(packed.utf8.count,64*1024)
                XCTAssertEqual(try CastReceiptStorage.expanded(packed),root)
                let r=try receipt(root,packed,"matrix-\(rows)")
                XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[r],context:r.context!),"matrix \(rows)")
                maxBytes=max(maxBytes,packed.utf8.count);rows += 1
            }
        }
        XCTAssertGreaterThanOrEqual(rows,48);XCTAssertEqual(rows,matrix.count)
        print("\(rows) paired liuyao receipt maximum: \(maxBytes) UTF8 bytes; complete semantic roundtrip")
    }
    func testMalformedStorageFailsClosedAndDoesNotBorrowQuestionFromOtherCalls()throws {
        let root=try fixtures()[0].1,packed=try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(root))
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(packed.utf8)) as? [String:Any])
        object.removeValue(forKey:"liuyaoObjectRows")
        let malformed=String(decoding:try JSONSerialization.data(withJSONObject:object),as:UTF8.self)
        XCTAssertThrowsError(try CastReceiptStorage.expanded(malformed));XCTAssertThrowsError(try CastReceiptStorage.encode(malformed))
        let r=try receipt(root,malformed);XCTAssertNil(LiuyaoReferenceReading.render(receipts:[r],context:r.context!))
        XCTAssertThrowsError(try CastReceiptStorage.expanded(#"{"questionFromArguments":{"toolCallID":"other"}}"#))
        XCTAssertThrowsError(try CastReceiptStorage.expanded(#"{"ruleSourcesFromDirectory":{"toolCallID":"other"}}"#))
    }
}

private actor StorageProbe {
    var calls=0;var receipts=[ToolReceipt]()
    func executed(){calls += 1}
    func saved(_ receipt:ToolReceipt){receipts.append(receipt)}
    func state()->(Int,[ToolReceipt]){(calls,receipts)}
}
