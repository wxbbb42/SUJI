import XCTest
@testable import SujiCore

final class QimenTimingPreparationTests:XCTestCase {
    private let now="2004-05-29T04:00:00Z"
    private func draft()throws->CastQuestionDraft {
        try CastQuestionDraft(call:.init(id:"qimen-timing-confirmed",name:"setup_qimen",arguments:["question":"工作事项何时变化","questionType":"career","subject":"self","event":"工作事项","timeHorizon":"near"]))
    }
    func testTimingIsOffByDefaultAndNeedsExplicitFields()throws {
        var d=try draft()
        XCTAssertFalse(d.timingEnabled)
        XCTAssertNil(ReadingVerificationEvidence.pointer("/timingRequest",in:try d.validatedCall().arguments))
        d.timingEnabled=true
        XCTAssertThrowsError(try d.validatedCall())
        d.timingFocus="employment";d.timingUnit="day";d.timingEndDate="2004-06-05"
        XCTAssertNotNil(ReadingVerificationEvidence.pointer("/timingRequest",in:try d.validatedCall().arguments))
        d.referenceOnly=true
        XCTAssertNil(ReadingVerificationEvidence.pointer("/timingRequest",in:try d.validatedCall().arguments))
    }
    func testConfirmationRoundTripDispatchAndReferenceOnlyRemoval()async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let metadata=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(#"{"command":"metadata"}"#))
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/engineRevision",in:metadata) else { return XCTFail() }
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        var d=try draft();d.timingEnabled=true;d.timingFocus="employment";d.timingUnit="day";d.timingEndDate="2004-06-05"
        let id=UUID(),confirmed=try ConfirmedCastQuestion(draft:d,userID:id,context:context)
        let restored=try JSONDecoder().decode(ConfirmedCastQuestion.self,from:JSONEncoder().encode(confirmed))
        try restored.validate(userID:id,context:context)
        XCTAssertEqual(restored.call,confirmed.call)
        let input:JSONValue=["command":"tool","name":"setup_qimen","arguments":restored.call.arguments,"now":.string(now)]
        let envelope=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(input)))
        let result=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/timing/dates/0/ganZhi",in:result),"甲寅")
        XCTAssertNotNil(QimenTimingEvidence.read(root:result))
        d.timingEndDate="2004-05-28"
        XCTAssertThrowsError(try ConfirmedCastQuestion(draft:d,userID:id,context:context))
        d.referenceOnly=true
        XCTAssertNoThrow(try ConfirmedCastQuestion(draft:d,userID:id,context:context))
    }
    func testRejectsImplicitOrInvalidFocusDateAndUnit()throws {
        var d=try draft();d.timingEnabled=true;d.timingFocus="employment";d.timingUnit="day";d.timingEndDate="2004-06-05"
        for field in 0..<6 {
            var invalid=d
            switch field {
            case 0:invalid.timingFocus="wealth"
            case 1:invalid.timingUnit="near"
            case 2:invalid.timingEndDate="2004-02-30"
            case 3:invalid.timingEndDate="2101-01-01"
            case 4:invalid.timingFocus="self";invalid.subject="parent"
            default:invalid.timingEndDate=""
            }
            XCTAssertThrowsError(try invalid.validatedCall(),"mutation \(field)")
        }
    }
    func testSupplementConfirmationKeepsOriginalPlateAndRendersAddedTiming()async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let originalCall=try draft().validatedCall()
        let input:JSONValue=["command":"tool","name":"setup_qimen","arguments":originalCall.arguments,"now":.string(now)]
        let envelope=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(input)))
        let result=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:result) else { return XCTFail() }
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        var source=ConversationEntry(role:"user",text:"工作事项何时变化")
        source.date=context.referenceDate;source.toolContext=context;source.analysisMode=context.mode
        source.toolReceipts=[.init(callID:"original",name:"setup_qimen",arguments:originalCall.arguments,output:ReadingVerificationEvidence.encoded(result),context:context)]
        let link=try CastSupplement.select(entryID:source.id,callID:"original",entries:[source],context:context)
        var user=ConversationEntry(role:"user",text:"补充应期范围");user.toolContext=context;user.castSupplement=link
        var d=try CastQuestionDraft(call:.init(id:"supplement",name:"setup_qimen",arguments:link.arguments))
        d.timingEnabled=true;d.timingFocus="employment";d.timingUnit="day";d.timingEndDate="2004-06-05"
        let confirmation=try ConfirmedCastQuestion(draft:d,userID:user.id,context:context)
        let request:JSONValue=["command":"reassess-question","name":"setup_qimen","sourceCallID":"original","original":result,"arguments":confirmation.call.arguments]
        let revisedEnvelope=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(request)))
        let revised=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:revisedEnvelope))
        let receipt=ToolReceipt(callID:confirmation.call.id,name:link.derivedName,arguments:confirmation.call.arguments,output:ReadingVerificationEvidence.encoded(revised),context:context)
        user.confirmedCastQuestions=[confirmation];user.toolReceipts=[receipt]
        let text=try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[source,user],context:context)
        XCTAssertTrue(text.contains("沿用原盘"));XCTAssertTrue(text.contains("条件候选"));XCTAssertTrue(text.contains("甲寅"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/palaces",in:result),ReadingVerificationEvidence.pointer("/palaces",in:revised))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/setupTime",in:result),ReadingVerificationEvidence.pointer("/setupTime",in:revised))
        XCTAssertNil(ReadingVerificationEvidence.pointer("/timing",in:result))
    }
}
