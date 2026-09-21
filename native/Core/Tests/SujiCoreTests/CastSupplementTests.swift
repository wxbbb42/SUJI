import XCTest
@testable import SujiCore

final class CastSupplementTests: XCTestCase {
    private func fixture(_ name: String) async throws -> (MingliBridge, ConversationEntry, ToolContext) {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let args: JSONValue = ["question":"核对自身情况","questionType":"health","subject":"self","event":"身体情况","timeHorizon":"near"]
        let data = try await bridge.request(ReadingVerificationEvidence.encoded(["command":.string("tool"),"name":.string(name),"arguments":args,"now":.string("2024-02-04T04:00:00Z")] as [String:JSONValue]))
        let root = try JSONDecoder().decode(JSONValue.self,from:data)
        let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:root))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:result) else { throw EngineError.execution("revision") }
        let context = try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦")
        var user = ConversationEntry(role:"user",text:"核对自身情况")
        user.date = context.referenceDate; user.toolContext = context; user.analysisMode = context.mode
        user.toolReceipts = [.init(callID:"original",name:name,arguments:args,output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(result)),context:context)]
        return (bridge,user,context)
    }
    private func derived(_ bridge:MingliBridge, _ supplement:CastSupplement, _ user:ConversationEntry, _ context:ToolContext) async throws -> (ConfirmedCastQuestion,ToolReceipt) {
        var draft = try CastQuestionDraft(call:.init(id:"supplement",name:supplement.original.name,arguments:supplement.arguments))
        draft.subject = "parent"; draft.event = "父亲的情况"; draft.question = "补充：问父亲"; draft.timeHorizon = "far"
        let confirmation = try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
        let original = try JSONDecoder().decode(JSONValue.self,from:Data(supplement.original.output.utf8))
        let raw = try await bridge.request(ReadingVerificationEvidence.encoded(["command":.string("reassess-question"),"name":.string(supplement.original.name),"sourceCallID":.string(supplement.original.callID),"original":original,"arguments":confirmation.call.arguments] as [String:JSONValue]))
        let envelope = try JSONDecoder().decode(JSONValue.self,from:raw)
        let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        return (confirmation,.init(callID:confirmation.call.id,name:supplement.derivedName,arguments:confirmation.call.arguments,output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(result)),context:context))
    }
    func testBothMethodsSupplementOriginalAndRetainSourceAcrossFurtherSupplements() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (bridge,original,context) = try await fixture(name)
            let link = try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
            var user = ConversationEntry(role:"user",text:"补充原占问");user.toolContext=context;user.castSupplement=link
            let (confirmation,receipt) = try await derived(bridge,link,user,context)
            user.confirmedCastQuestions=[confirmation];user.toolReceipts=[receipt]
            let report = try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[original,user],context:context)
            XCTAssertTrue(report.contains("沿用原盘"));XCTAssertTrue(report.contains("补充：问父亲"))
            let next = try CastSupplement.select(entryID:user.id,callID:receipt.callID,entries:[original,user],context:context)
            XCTAssertEqual(next.sourceUserID,original.id);XCTAssertEqual(next.original,link.original);XCTAssertEqual(next.arguments,receipt.arguments)
            let decoded = try JSONDecoder().decode(ConversationEntry.self,from:JSONEncoder().encode(user))
            XCTAssertEqual(decoded.castSupplement,link)
        }
    }
    func testSourceMustExistUnambiguouslyEarlierInSameHistoryAndMatchSnapshot() async throws {
        let (_,original,context)=try await fixture("cast_liuyao")
        let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
        var user=ConversationEntry(role:"user",text:"补充");user.toolContext=context;user.castSupplement=link
        try link.validate(userID:user.id,entries:[original,user],context:context)
        XCTAssertThrowsError(try link.validate(userID:user.id,entries:[user],context:context))
        XCTAssertThrowsError(try link.validate(userID:user.id,entries:[user,original],context:context))
        XCTAssertThrowsError(try link.validate(userID:user.id,entries:[original,original,user],context:context))
        var altered=original;altered.toolReceipts![0].output="{}"
        XCTAssertThrowsError(try link.validate(userID:user.id,entries:[altered,user],context:context))
        let stale=try ToolContext(birth:nil,engineRevision:"stale",referenceDate:context.referenceDate,mode:context.mode)
        XCTAssertThrowsError(try link.validate(userID:user.id,entries:[original,user],context:stale))
    }
    func testOriginalProvenanceCannotDisagreeWithOriginalChartTimeOrCalendarPolicy() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (_,original,context)=try await fixture(name)
            for field in ["referenceDate","calendarPolicy"] {
                var source=original
                var root=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(source.toolReceipts![0].output)) as? [String:Any])
                var provenance=root["provenance"] as! [String:Any]
                if field == "referenceDate" { provenance[field]="2025-01-01T00:00:00.000Z" }
                else { provenance[field]=["version":"old","timezone":"UTC-08:00"] }
                root["provenance"]=provenance
                source.toolReceipts![0].output=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self)
                XCTAssertThrowsError(try CastSupplement.select(entryID:source.id,callID:"original",entries:[source],context:context))
            }
        }
    }

    func testOldQuestionDependentFieldsCannotMasqueradeAsAcceptedSupplement() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (bridge,original,context)=try await fixture(name)
            let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
            var user=ConversationEntry(role:"user",text:"补充");user.toolContext=context;user.castSupplement=link
            let (confirmation,receipt)=try await derived(bridge,link,user,context)
            var changed=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(receipt.output)) as? [String:Any])
            let source=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(link.original.output)) as? [String:Any])
            for key in ["yongShen","yingQi"] + (name == "cast_liuyao" ? ["roleRelations"] : []) { changed[key]=source[key] }
            var bad=receipt;bad.output=String(decoding:try JSONSerialization.data(withJSONObject:changed),as:UTF8.self)
            XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context))
        }
    }

    func testDerivedRecordRejectsImmutableChangesWrongArgumentsAndIdentity() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (bridge,original,context)=try await fixture(name)
            let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
            var user=ConversationEntry(role:"user",text:"补充");user.toolContext=context;user.castSupplement=link
            let (confirmation,receipt)=try await derived(bridge,link,user,context)
            let root=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(receipt.output)) as? [String:Any])
            for key in root.keys where !["question","questionType","questionContext","yongShen","yingQi","questionRevision","roleRelations","efficacy","timing"].contains(key) {
                var bad=receipt;var object=root;object.removeValue(forKey:key);bad.output=String(decoding:try JSONSerialization.data(withJSONObject:object),as:UTF8.self)
                XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context),key)
            }
            var bad=receipt;bad.arguments=original.toolReceipts![0].arguments
            XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context))
            bad=receipt;bad.callID="wrong"
            XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context))
            bad=receipt;bad.name=name
            XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context))
            var object=root;object["questionRevision"]=["algorithm":"suji-cast-question-revision-1","sourceToolName":name,"sourceCallID":"wrong"]
            bad=receipt;bad.output=String(decoding:try JSONSerialization.data(withJSONObject:object),as:UTF8.self)
            XCTAssertThrowsError(try link.render(receipt:bad,confirmation:confirmation,userID:user.id,entries:[original,user],context:context))
        }
    }
}
