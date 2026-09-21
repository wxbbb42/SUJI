import XCTest
import SwiftData
import SujiCore
@testable import Suji

@MainActor final class CastSupplementSessionTests: XCTestCase {
    private func wait(_ session:ChatSession, pending:Bool = false) async throws {
        for _ in 0..<1500 {
            if pending ? session.castConfirmation.pending != nil : !session.working { return }
            try await Task.sleep(for:.milliseconds(5))
        }
        throw EngineError.execution("Session timed out: \(session.failure ?? "none")")
    }
    private func fixture(_ name:String) async throws -> (ModelContainer,AppStore,ConversationEntry) {
        let container=try ModelContainer(for:SavedState.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true))
        let script=try XCTUnwrap(Bundle.main.url(forResource:"mingli",withExtension:"js"))
        let store=try AppStore(context:container.mainContext,scriptURL:script,userID:"supplement-test")
        let args:[String:Any]=["question":"核对自身情况","questionType":"health","subject":"self","event":"身体情况","timeHorizon":"near"]
        let result=try await store.request(["command":"tool","name":name,"id":"original","arguments":args,"now":"2024-02-04T04:00:00Z"])
        let context=try ToolContext(birth:nil,engineRevision:result["result"]["provenance"]["engineRevision"].text,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦")
        var entry=ConversationEntry(role:"user",text:"核对自身情况");entry.date=context.referenceDate;entry.toolContext=context;entry.analysisMode=context.mode
        let arguments=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:args))
        entry.toolReceipts=[.init(callID:"original",name:name,arguments:arguments,output:result["result"].json,context:context)]
        store.state.conversations=[entry];try store.saveThrowing()
        return(container,store,entry)
    }
    private func session() -> ChatSession { ChatSession(makeClient:{_ in XCTFail("Supplement must not use a model");throw EngineError.execution("forbidden")}) }

    func testSavedCompressedChartsRestoreAllCardFields() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (container,_,entry) = try await fixture(name)
            defer { withExtendedLifetime(container) {} }
            let receipt = try XCTUnwrap(entry.toolReceipts?.first)
            let packed = try CastReceiptStorage.encode(receipt.output)
            let card = try Document(receiptOutput: packed)
            let original = try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
            XCTAssertEqual(try JSONDecoder().decode(JSONValue.self,from:Data(card.json.utf8)),original)
            XCTAssertEqual(card["questionContext"]["event"].text,"身体情况","The preparation audit must read the same restored event as the saved chart")
            if name == "cast_liuyao" {
                XCTAssertFalse(card["benGua"]["name"].text.isEmpty)
                XCTAssertFalse(card["bianGua"]["upper"].text.isEmpty)
            } else {
                XCTAssertEqual(card["palaces"].array.count,9)
                XCTAssertTrue(card["palaces"].array.allSatisfy { (1...9).contains(Int($0["id"].number)) })
            }
        }
    }

    func testRealEngineSupplementPreservesOriginalAndRetryNeverExecutesEngine() async throws {
        for name in ["cast_liuyao","setup_qimen"] {
            let (container,store,original)=try await fixture(name)
            let session=session();session.supplement(entryID:original.id,callID:"original",store:store)
            try await wait(session,pending:true)
            let request=try XCTUnwrap(session.castConfirmation.pending)
            XCTAssertTrue(request.reusesOriginal)
            let user=try XCTUnwrap(store.state.conversations.last);XCTAssertNotEqual(user.id,original.id)
            XCTAssertEqual(user.castSupplement?.original,original.toolReceipts?.first)
            XCTAssertNil(user.confirmedCastQuestions)
            var drafts=request.drafts;drafts[0].question="补充父亲的情况";drafts[0].subject="parent";drafts[0].event="父亲的情况";drafts[0].timeHorizon="far"
            session.castConfirmation.confirm(id:request.id,drafts:drafts);try await wait(session)
            XCTAssertNil(session.failure)
            XCTAssertEqual(store.state.conversations[0].toolReceipts,original.toolReceipts)
            let revised=store.state.conversations[1]
            XCTAssertEqual(revised.confirmedCastQuestions?.first?.call.arguments,try drafts[0].validatedCall().arguments)
            XCTAssertEqual(revised.toolReceipts?.first?.name,name == "cast_liuyao" ? "reassess_liuyao":"reassess_qimen")
            XCTAssertTrue(store.state.conversations.last?.text.contains("沿用原盘") ?? false)
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:directory)}
            let script=directory.appendingPathComponent("engine.js")
            let bundled=try String(contentsOf:XCTUnwrap(Bundle.main.url(forResource:"mingli",withExtension:"js")),encoding:.utf8)
            try (bundled+"\nconst runOriginal=SujiNative.run;SujiNative={...SujiNative,run:(json,resolve,reject)=>JSON.parse(json).command==='metadata'?runOriginal(json,resolve,reject):reject('recalculation forbidden')};").write(to:script,atomically:true,encoding:.utf8)
            let restored=try AppStore(context:container.mainContext,scriptURL:script,userID:"supplement-test")
            do { _ = try await restored.request(["command":"calendar"]);XCTFail("Engine trap must be active") }
            catch { XCTAssertTrue(error.localizedDescription.contains("recalculation forbidden")) }
            let retry=self.session();retry.send(revised.text,mode:"命理",store:restored,appendUser:false);try await wait(retry)
            XCTAssertNil(retry.failure);XCTAssertNil(retry.castConfirmation.pending)
            XCTAssertEqual(restored.state.conversations[1].toolReceipts,revised.toolReceipts)
            XCTAssertEqual(restored.state.conversations.count,3)
        }
    }
    func testFailedReassessmentRestoresAcceptedInputsWithoutAnotherConfirmation() async throws {
        let (container,store,original)=try await fixture("setup_qimen")
        defer { withExtendedLifetime(container) {} }
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:directory)}
        let bundledURL=try XCTUnwrap(Bundle.main.url(forResource:"mingli",withExtension:"js"))
        let script=directory.appendingPathComponent("engine.js")
        let bundled=try String(contentsOf:bundledURL,encoding:.utf8)
        try (bundled+"\nconst runOriginal=SujiNative.run;SujiNative={...SujiNative,run:(json,resolve,reject)=>JSON.parse(json).command==='reassess-question'?reject('synthetic reassessment failure'):runOriginal(json,resolve,reject)};").write(to:script,atomically:true,encoding:.utf8)
        let failing=try AppStore(context:container.mainContext,scriptURL:script,userID:"supplement-test")
        let session=session();session.supplement(entryID:original.id,callID:"original",store:failing)
        try await wait(session,pending:true)
        let pending=try XCTUnwrap(session.castConfirmation.pending)
        var drafts=pending.drafts;drafts[0].subject="parent";drafts[0].event="父亲的情况"
        session.castConfirmation.confirm(id:pending.id,drafts:drafts);try await wait(session)
        XCTAssertTrue(session.failure?.contains("synthetic reassessment failure") ?? false)
        let accepted=try XCTUnwrap(failing.state.conversations.last?.confirmedCastQuestions)
        XCTAssertTrue(failing.state.conversations.last?.toolReceipts?.isEmpty ?? false)
        let restored=try AppStore(context:container.mainContext,scriptURL:bundledURL,userID:"supplement-test")
        let retry=self.session();retry.send("retry",mode:"倾诉",store:restored,appendUser:false);try await wait(retry)
        XCTAssertNil(retry.failure);XCTAssertNil(retry.castConfirmation.pending)
        XCTAssertEqual(restored.state.conversations[1].confirmedCastQuestions,accepted)
        XCTAssertEqual(restored.state.conversations[1].toolReceipts?.first?.arguments,accepted[0].call.arguments)
        XCTAssertEqual(restored.state.conversations[0].toolReceipts,store.state.conversations[0].toolReceipts)
    }

    func testAccountChangeImmediatelyAfterConfirmCannotSaveIntoCopiedNotebook() async throws {
        let (container,store,original)=try await fixture("setup_qimen")
        defer { withExtendedLifetime(container) {} }
        let session=session();session.supplement(entryID:original.id,callID:"original",store:store)
        try await wait(session,pending:true)
        let pending=try XCTUnwrap(session.castConfirmation.pending)
        let destination=try AppStore(context:container.mainContext,scriptURL:XCTUnwrap(Bundle.main.url(forResource:"mingli",withExtension:"js")),userID:"other")
        destination.state=store.state;try destination.saveThrowing()
        session.castConfirmation.confirm(id:pending.id,drafts:pending.drafts)
        try await store.switchAccount(from:"supplement-test",to:"other")
        try await wait(session)
        XCTAssertNil(store.state.conversations[1].confirmedCastQuestions)
        XCTAssertTrue(store.state.conversations[1].toolReceipts?.isEmpty ?? true)
        let restored=try AppStore(context:container.mainContext,scriptURL:XCTUnwrap(Bundle.main.url(forResource:"mingli",withExtension:"js")),userID:"other")
        XCTAssertNil(restored.state.conversations[1].confirmedCastQuestions)
    }

    func testCancelOrAccountChangeCannotApplyStaleSupplementConfirmation() async throws {
        for accountChange in [false,true] {
            let (container,store,original)=try await fixture("setup_qimen")
            defer { withExtendedLifetime(container) {} }
            let session=session();session.supplement(entryID:original.id,callID:"original",store:store)
            try await wait(session,pending:true)
            let pending=try XCTUnwrap(session.castConfirmation.pending)
            if accountChange {try await store.switchAccount(from:"supplement-test",to:"other")} else {session.stop()}
            session.castConfirmation.confirm(id:pending.id,drafts:pending.drafts);try await wait(session)
            if accountChange {try await store.switchAccount(from:"other",to:"supplement-test")}
            XCTAssertNil(store.state.conversations[1].confirmedCastQuestions)
            XCTAssertTrue(store.state.conversations[1].toolReceipts?.isEmpty ?? true)
            XCTAssertEqual(store.state.conversations[0].toolReceipts,original.toolReceipts)
        }
    }
}
