import XCTest
@testable import SujiCore

final class CastSourcePackingTests:XCTestCase {
    func testSourceDirectoryCannotDisablePackingForFortyMonthlyCandidates() async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let event="事"+String(repeating:"\u{1}",count:199),question=String(repeating:"问",count:1600)
        let arguments:JSONValue=["question":.string(question),"questionType":"career","subject":"self","event":.string(event),"timeHorizon":"far",
            "timingRequest":["focus":"relationship","event":.string(event),"timeUnit":"month","window":["end":"2100-12-31T23:59:59+08:00","maxCandidates":256]]]
        let request:JSONValue=["command":"tool","name":"setup_qimen","arguments":arguments,"now":"2004-07-02T08:00:00Z"]
        let envelope=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(request)))
        let original=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .array(dates)=ReadingVerificationEvidence.pointer("/timing/dates",in:original) else {return XCTFail("Missing calendar")}
        XCTAssertEqual(dates.count,40)
        let raw=ReadingVerificationEvidence.encoded(original)
        let receipt=ToolReceipt(callID:String(repeating:"b",count:200),name:"setup_qimen",arguments:arguments,output:try CastReceiptStorage.encode(raw))
        let directory=try XCTUnwrap(CastSourceDirectory.message(receipt:receipt))
        let prefix:[ChatMessage]=[directory,.assistantToolCalls([receipt.call])]
        guard case var .object(shared)=CastSourceDirectory.project(original,name:receipt.name,history:prefix,callID:receipt.callID) else {return XCTFail("Missing chart")}
        shared.removeValue(forKey:"question")
        shared["questionFromArguments"]=["toolCallID":.string(receipt.callID),"pointer":"/question"]
        XCTAssertGreaterThan(raw.utf16.count,28_000)
        XCTAssertLessThan(ReadingVerificationEvidence.encoded(JSONValue.object(shared)).utf16.count,28_000)

        let wire=NatalEvidenceProjection.output(receipt.output,name:receipt.name,delivered:prefix,callID:receipt.callID)
        // The full paired review has only 3,044 units to recover from this
        // component; 24,000 leaves room under the existing 120,000 total cap.
        XCTAssertLessThanOrEqual(wire.utf16.count,24_000)
        guard case var .object(restored)=try XCTUnwrap(ToolOutputWire.decode(wire,name:receipt.name,history:prefix,callID:receipt.callID)) else {return XCTFail("Missing restored chart")}
        let reference=try XCTUnwrap(restored.removeValue(forKey:"questionFromArguments"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/toolCallID",in:reference),.string(receipt.callID))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/pointer",in:reference),"/question")
        restored["question"]=ReadingVerificationEvidence.pointer("/question",in:arguments)
        XCTAssertEqual(JSONValue.object(restored),original)
    }
}
