import Foundation
import XCTest
@testable import SujiCore

final class ReadingDocumentTests: XCTestCase {
    private struct Fixture {
        let context: ToolContext
        let receipts: [ToolReceipt]
        let catalog: BaziFrameworkReading.Catalog
        var source: ConversationEntry
        var reply: ConversationEntry
        var next: ConversationEntry
        var entries: [ConversationEntry] { [source, reply, next] }
    }

    private func fixture(focus: ReadingDocument.Focus = .comparison) throws -> Fixture {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/native-round6-results.json"))) as! [String: Any]
        let record = (report["cases"] as! [[String: Any]])[0]
        let context = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: record["context"]!))
        let receipts = try JSONDecoder().decode([ToolReceipt].self, from: JSONSerialization.data(withJSONObject: record["receipts"]!))
        let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: receipts, context: context))
        var source = ConversationEntry(role: "user", text: "结合我的命盘，扶抑用神和格局用神为什么不同？")
        source.toolContext = context
        source.toolReceipts = receipts
        source.analysisMode = context.mode
        let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: focus)
        var reply = ConversationEntry(role: "assistant", text: answer.text)
        reply.readingDocument = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: source.id, focus: focus)
        return Fixture(context: context, receipts: receipts, catalog: catalog, source: source, reply: reply, next: .init(role: "user", text: "简单说"))
    }

    private func resolve(_ question: String, _ f: Fixture, context: ToolContext? = nil, entries: [ConversationEntry]? = nil, mode: String = "命理") -> ReadingDocument.Focus? {
        BaziReadingRequest.resolve(question: question, mode: mode, entries: entries ?? f.entries, currentUserID: f.next.id, context: context ?? f.context)
    }

    private func alteredDocument(_ document: ReadingDocument, edit: (inout [String: Any]) -> Void) throws -> ReadingDocument {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as! [String: Any]
        edit(&object)
        return try JSONDecoder().decode(ReadingDocument.self, from: JSONSerialization.data(withJSONObject: object))
    }

    func testFocusedAnswersCannotLoseQualificationsOrSelectAnotherTopic() throws {
        let f = try fixture()
        for focus in ReadingDocument.Focus.allCases {
            let answer = BaziFrameworkReading.render(selection: #"{"protocolVersion":"suji-bazi-claims-1","claimIDs":["chart","overview"]}"#, catalog: f.catalog, focus: focus)
            XCTAssertEqual(Set(answer.selectedClaimIDs), Set(f.catalog.claimIDs(for: focus)))
            let document = ReadingDocument(catalog: f.catalog, answer: answer, sourceUserID: f.source.id, focus: focus)
            XCTAssertTrue(document.isValid)
            XCTAssertEqual(document.plainText, answer.text)
        }
        let overview = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, focus: .overview).text
        XCTAssertTrue(overview.contains("启发式"))
        XCTAssertTrue(overview.contains("候选"))
        XCTAssertLessThan(overview.count, 260)
        let pattern = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, focus: .pattern).text
        XCTAssertTrue(pattern.contains("不能据此说已经成格"))
    }

    func testFocusedSelectionTransportFailureStillProducesLocalAnswer() async throws {
        let f = try fixture()
        let answer = try await BaziFrameworkReading.compose(catalog: f.catalog, question: "简单说", focus: .overview) { _ in throw URLError(.timedOut) }
        XCTAssertEqual(answer.selectionStatus, "selection-unavailable")
        XCTAssertEqual(answer.selectedClaimIDs, ["chart", "overview"])
        XCTAssertTrue(answer.text.contains("候选"))
    }

    func testFollowupsResolveFromLocallyReboundDocument() throws {
        let f = try fixture()
        for (question, expected) in [("简单说，我到底用哪个？", ReadingDocument.Focus.overview), ("那是不是偏印格已成？不要那些限定。", .pattern), ("土克水，也是在耗水吗？", .relations), ("调候又怎么看？", .climate), ("为什么偏强？", .strength), ("继续", .comparison)] {
            XCTAssertEqual(resolve(question, f), expected, question)
        }
        let focused = try fixture(focus: .pattern)
        XCTAssertEqual(resolve("再解释一下", focused), .pattern)
        XCTAssertEqual(resolve("可以简单说说吗？", f), .overview)
        XCTAssertEqual(resolve("请用一句话解释", f), .overview)
        XCTAssertEqual(resolve("能不能简单一点", focused), .pattern)
    }

    func testDirectPersonalQuestionsNeedNoHistoricalAuthority() throws {
        let f = try fixture()
        for (question, expected) in [("那日主和月令之间是什么关系？", ReadingDocument.Focus.strength), ("我的扶抑用神是什么？", .strength), ("我的八字格局怎么看？", .pattern), ("我的调候用神呢？", .climate), ("命盘五行生克关系怎么看？", .relations)] {
            XCTAssertEqual(resolve(question, f, entries: []), expected)
        }
    }

    func testMonthRelationAnswerIncludesReturnedSeasonalBasisWithoutPromotingItToFullStrength() throws {
        let f = try fixture()
        let old = try XCTUnwrap(f.receipts.first)
        var root = try JSONSerialization.jsonObject(with: Data(old.output.utf8)) as! [String: Any]
        var bazi = root["bazi"] as! [String: Any]
        bazi["structureReference"] = ["yueLingState": "相", "evidence": ["basis": "engineering-heuristic", "monthMethod": "month-branch-main-qi", "monthBranch": "申", "monthMainQi": "庚", "monthMainElement": "金", "monthRelation": "resource"]]
        root["bazi"] = bazi
        let output = String(decoding: try JSONSerialization.data(withJSONObject: root), as: UTF8.self)
        let receipt = ToolReceipt(callID: old.callID, name: old.name, arguments: old.arguments, output: output, context: f.context)
        let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: f.context))
        let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: .strength)
        XCTAssertTrue(answer.text.contains("月支申"))
        XCTAssertTrue(answer.text.contains("本气庚金"))
        XCTAssertTrue(answer.text.contains("生我"))
        XCTAssertTrue(answer.text.contains("未按月内司令"))
        XCTAssertFalse(answer.text.contains("得令所以身强"))
        XCTAssertTrue(ReadingDocument(catalog: catalog, answer: answer, sourceUserID: f.source.id, focus: .strength).isValid)
    }

    func testTopicSwitchesAndRefusalsDoNotInheritBaziExplanation() throws {
        let f = try fixture()
        for question in ["那我今天吃什么？", "所以我明年什么时候换工作？", "别看八字，我想谈谈失恋", "不用调候，谈谈我的心情", "格局放大一点，我为什么心情不好", "不要比较扶抑用神和格局用神，我只问今年大运", "扶抑用神与格局用神为什么不同，顺便看今年流年", "换个话题", "我的朋友说了什么？"] {
            XCTAssertNil(resolve(question, f), question)
        }
        XCTAssertNil(resolve("简单说", f, mode: "倾诉"))
    }

    func testProseOrDetachedMetadataCannotEstablishContinuity() throws {
        var f = try fixture()
        f.reply.readingDocument = nil
        XCTAssertNil(resolve("简单说", f))
        f = try fixture(); f.reply.text += "偏印格已成。"
        XCTAssertNil(resolve("简单说", f))
        f = try fixture(); f.source.toolContext = nil
        XCTAssertNil(resolve("简单说", f))
        f = try fixture(); f.source.toolReceipts = nil
        XCTAssertNil(resolve("简单说", f))
        f = try fixture(); f.source.id = UUID()
        XCTAssertNil(resolve("简单说", f))
        f = try fixture()
        XCTAssertNil(resolve("简单说", f, entries: [f.source, f.reply, .init(role: "user", text: "其他问题"), f.next]))
    }

    func testEditedBodyQualificationEvidenceOrFocusCannotRebind() throws {
        for mutation in ["body", "qualification", "evidence", "focus"] {
            var f = try fixture()
            let document = try alteredDocument(f.reply.readingDocument!) { object in
                if mutation == "focus" { object["focus"] = "overview"; return }
                var sections = object["sections"] as! [[String: Any]]
                if mutation == "body" { sections[1]["body"] = "偏印格已成，不用再核实。" }
                if mutation == "qualification" { sections[1]["qualification"] = "calculated" }
                if mutation == "evidence" { sections[1]["evidence"] = [] }
                object["sections"] = sections
            }
            f.reply.readingDocument = document; f.reply.text = document.plainText
            XCTAssertNil(resolve("简单说", f), mutation)
        }
    }

    func testNewReferenceDateAllowsTopicButCannotReuseOldReceipts() throws {
        let f = try fixture()
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(f.context)) as! [String: Any]
        object["referenceDate"] = f.context.referenceDate.timeIntervalSinceReferenceDate + 60
        let newer = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(resolve("简单说", f, context: newer), .overview)
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: f.receipts, context: newer))
        object["engineRevision"] = "other-engine"
        let changed = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(resolve("简单说", f, context: changed))
        object["engineRevision"] = f.context.engineRevision
        object["birthFingerprint"] = String(repeating: "a", count: 64)
        let differentBirth = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(resolve("简单说", f, context: differentBirth))
    }

    func testLocalPersistenceRetainsDocumentExternalImportDropsAuthority() throws {
        let f = try fixture()
        var state = AppState(); state.conversations = f.entries
        let encoded = try ArchiveCodec.encode(state)
        let local = try JSONDecoder().decode(AppState.self, from: encoded)
        XCTAssertEqual(local.conversations[1].readingDocument?.plainText, f.reply.text)
        XCTAssertEqual(resolve("简单说", f, entries: local.conversations), .overview)
        let imported = try ArchiveCodec.decode(encoded)
        XCTAssertNil(imported.conversations[1].readingDocument)
        XCTAssertEqual(imported.conversations[1].text, f.reply.text)
        XCTAssertNil(resolve("简单说", f, entries: imported.conversations))
    }

    func testMalformedDocumentCannotEnterArchive() throws {
        let f = try fixture()
        for mutation in ["title", "body", "pointer", "version"] {
            let document = try alteredDocument(f.reply.readingDocument!) { object in
                if mutation == "version" { object["version"] = "untrusted-version"; return }
                var sections = object["sections"] as! [[String: Any]]
                if mutation == "title" { sections[0]["title"] = "已验证的预测" }
                if mutation == "body" { sections[0]["body"] = String(repeating: "x", count: 6_001) }
                if mutation == "pointer" {
                    var evidence = sections[0]["evidence"] as! [[String: Any]]
                    evidence[0]["pointer"] = "/unrelated/data"; sections[0]["evidence"] = evidence
                }
                object["sections"] = sections
            }
            XCTAssertFalse(document.isValid)
            var state = AppState(); var reply = f.reply; reply.readingDocument = document; reply.text = document.plainText
            state.conversations = [f.source, reply]
            XCTAssertThrowsError(try ArchiveCodec.encode(state), mutation)
        }
        var state = AppState(); var user = f.source; user.readingDocument = f.reply.readingDocument
        state.conversations = [user]
        XCTAssertThrowsError(try ArchiveCodec.encode(state))
    }

    func testMissingClimateSourceExplainsMissingEvidenceInsteadOfInferring() throws {
        let f = try fixture()
        var receipt = f.receipts[0]
        var root = try JSONSerialization.jsonObject(with: Data(receipt.output.utf8)) as! [String: Any]
        var bazi = root["bazi"] as! [String: Any]; bazi.removeValue(forKey: "tiaoHou"); root["bazi"] = bazi
        receipt.output = String(decoding: try JSONSerialization.data(withJSONObject: root), as: UTF8.self)
        let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: f.context))
        let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, focus: .climate)
        XCTAssertEqual(answer.selectedClaimIDs, ["chart", "climate-unavailable"])
        XCTAssertTrue(answer.text.contains("暂不列出你的调候候选"))
        XCTAssertFalse(catalog.defaultClaimIDs.contains("climate-unavailable"))
    }
}
