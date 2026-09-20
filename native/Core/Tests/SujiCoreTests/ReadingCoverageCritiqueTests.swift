import Foundation
import XCTest
@testable import SujiCore

/// Independent usefulness review. These are ordinary requests, not adversarial
/// protocol mutations. A recognized topic alone is not a completed explanation.
final class ReadingCoverageCritiqueTests: XCTestCase {
    private struct Fixture {
        let context: ToolContext
        let receipts: [ToolReceipt]
        let catalog: BaziFrameworkReading.Catalog
        let records: [[String: Any]]
    }

    private func fixture() throws -> Fixture {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let report = try JSONSerialization.jsonObject(with: Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/native-round9-results.json"))) as! [String: Any]
        let records = report["cases"] as! [[String: Any]]
        let context = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: records[0]["context"]!))
        let receipts = try JSONDecoder().decode([ToolReceipt].self, from: JSONSerialization.data(withJSONObject: records[0]["receipts"]!))
        return Fixture(context: context, receipts: receipts, catalog: try XCTUnwrap(BaziFrameworkReading.catalog(receipts: receipts, context: context)), records: records)
    }

    private func currentFixture() async throws -> Fixture {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let metadata = try JSONDecoder().decode(JSONValue.self, from: await bridge.request(#"{"command":"metadata"}"#))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/engineRevision", in: metadata) else { throw NSError(domain: "ReadingCoverageCritique", code: 1) }
        let birth = BirthProfile(year: 1990, month: 8, day: 15, hour: 10, minute: 0, gender: "女", city: "合成资料", longitude: 120)
        let now = Date(timeIntervalSince1970: 1_706_976_000)
        let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: now, mode: "命理")
        let request: [String: Any] = ["command": "tool", "name": "get_domain", "id": "coverage-strength-tie", "arguments": ["domain": "事业"], "now": ISO8601DateFormatter().string(from: now), "birth": try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))]
        let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
        try EngineContract.validate(raw, command: "tool")
        let root = try JSONDecoder().decode(JSONValue.self, from: raw)
        let output = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: root))
        let receipt = ToolReceipt(callID: "coverage-strength-tie", name: "get_domain", arguments: ["domain": "事业"], output: ReadingVerificationEvidence.encoded(output), context: context)
        return Fixture(context: context, receipts: [receipt], catalog: try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: context)), records: try fixture().records)
    }

    private func resolve(_ question: String, fixture f: Fixture, previousFocus: ReadingDocument.Focus? = nil) -> ReadingDocument.Presentation? {
        let next = ConversationEntry(role: "user", text: question)
        var entries: [ConversationEntry] = []
        if let previousFocus {
            var source = ConversationEntry(role: "user", text: "结合我的八字解释依据")
            source.toolContext = f.context
            source.toolReceipts = f.receipts
            source.analysisMode = "命理"
            let answer = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, focus: previousFocus)
            var reply = ConversationEntry(role: "assistant", text: answer.text)
            reply.readingDocument = ReadingDocument(catalog: f.catalog, answer: answer, sourceUserID: source.id, focus: previousFocus)
            entries = [source, reply]
        }
        return BaziReadingRequest.resolveRequest(question: question, mode: "命理", entries: entries + [next], currentUserID: next.id, context: f.context)
    }

    private func answer(_ question: String, fixture f: Fixture, previousFocus: ReadingDocument.Focus? = nil) async throws -> BaziFrameworkReading.Answer? {
        guard let presentation = resolve(question, fixture: f, previousFocus: previousFocus) else { return nil }
        // Deliberately invalid selection exercises the deterministic renderer the
        // product also uses when optional model ordering is unavailable.
        return try await BaziFrameworkReading.compose(catalog: f.catalog, question: question, presentation: presentation) { _ in .text("") }
    }

    func testNaturalQuestionCoverageMatrixRecordsActualProtectedAndFreeRoutes() async throws {
        let f = try await currentFixture()
        let scenarios: [(String, String, ReadingDocument.Focus?, String)] = [
            ("S01", "为什么我身强，具体是哪几项累加？", nil, "Give actual counted contributions, totals and threshold, with heuristic qualification."),
            ("S02", "我的同类和异类分别是多少，按什么权重？", nil, "Give peer/resource versus output/wealth/officer totals and weights."),
            ("S03", "日主自己这一分算不算？不算还强吗？", .strength, "State inclusion of day stem and distinguish counterfactual counting from the actual rule."),
            ("S04", "月令申对我的旺衰具体起什么作用？", nil, "Distinguish the month-branch fact from an unapplied seasonal coefficient."),
            ("S05", "我的通根在哪几柱，壬水和癸水要分开吗？", nil, "List root facts and distinguish same-element from same-stem roots."),
            ("S06", "月令申藏哪三个干？本气为什么不是月干甲？", .pattern, "List 庚壬戊 and distinguish branch main qi from exposed month stem."),
            ("S07", "结合我的八字，分别讲扶抑和调候。", nil, "Cover both strength and climate."),
            ("S08", "我的八字格局怎么看？也说一下调候。", nil, "Cover both pattern and climate."),
            ("S09", "只讲我的扶抑和调候，不要讲格局。", nil, "Cover the two requested topics without interpreting one exclusion as withdrawal from all Bazi."),
            ("S10", "庚透年干，那月干甲食神受克会不会破格？", .pattern, "Explain the actual adjacent edge, while not upgrading it to established pattern failure."),
            ("S11", "乙庚合了，庚是不是不能当格局用神？", .pattern, "Explain the actual nonadjacent combination assessment and unresolved outcome."),
            ("S12", "申子是不是已经合水，所以日主更强？", .strength, "Name the partial combination and missing 辰; do not infer transformation or extra score."),
            ("S13", "能不能简单一点", .climate, "Return a genuinely shorter climate explanation, not the same paragraphs."),
            ("S14", "调候那段能不能只用两句白话？", .climate, "Respect explicit brevity and retain source/condition limits."),
            ("S15", "我的五行里，木克土是什么意思？", nil, "Answer the requested 木→土 edge, rather than only 水-relative edges."),
            ("S16", "为什么我偏强？", nil, "Recognize ordinary direct strength wording without requiring prior protected metadata."),
            ("S17", "我的八字格局和身强身弱有什么关系？", nil, "Cover pattern and strength without treating the two heuristics as mutual validation."),
            ("S18", "我的扶抑、格局、调候分别怎么看？", nil, "Cover all three positively requested topics."),
            ("S19", "那你说的参考，具体怎么计算出来的？", .strength, "Continue the strength evidence topic and expose its calculation."),
            ("S20", "水生木为什么叫泄？", .relations, "Explain the directed element definition."),
            ("S21", "我最近睡不好，先聊聊作息。", .strength, "Remain outside the protected Bazi explanation route."),
            ("S22", "那是不是偏印格已成？", .pattern, "Preserve candidate status while explaining available pattern evidence.")
        ]
        var rows: [[String: Any]] = []
        for (id, question, previousFocus, expected) in scenarios {
            let presentation = resolve(question, fixture: f, previousFocus: previousFocus)
            let rendered = try await answer(question, fixture: f, previousFocus: previousFocus)
            rows.append(["id": id, "question": question, "engineRevision": f.context.engineRevision, "previousFocus": previousFocus?.rawValue ?? "none", "route": presentation == nil ? "free-prose-plus-verifier" : "protected-local-claims", "focus": presentation?.focuses.map(\.rawValue).joined(separator: "+") ?? "none", "detail": presentation?.detail.rawValue ?? "none", "claimIDs": rendered?.selectedClaimIDs ?? [], "answer": rendered?.text ?? "Not generated: no live model used in this independent review.", "expected": expected])
        }
        XCTAssertEqual(rows.count, 22)
        let output = URL(fileURLWithPath: "/tmp/suji-reading-coverage-observations.json")
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: output, options: .atomic)
        print("Independent coverage observations: \(output.path)")
    }

    func testRoundNineActuallyRepeatedClimateAnswerRatherThanSimplifying() throws {
        let records = try fixture().records
        // Historical evidence only. Changing the renderer must not rewrite this
        // immutable report or turn its old result into a claim about today's UI.
        XCTAssertEqual(records[4]["question"] as? String, "调候又怎么看？")
        XCTAssertEqual(records[5]["question"] as? String, "能不能简单一点")
        XCTAssertEqual(records[4]["answer"] as? String, records[5]["answer"] as? String)
    }

    func testSimpleFollowupActuallyShortensEachSingleTopic() async throws {
        let f = try await currentFixture()
        for previous in [ReadingDocument.Focus.strength, .pattern, .climate, .relations] {
            let full = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, focus: previous)
            let short = try await answer("能不能简单一点", fixture: f, previousFocus: previous)
            let result = try XCTUnwrap(short, previous.rawValue)
            print("Coverage brevity \(previous.rawValue): standard=\(full.text.count), brief=\(result.text.count)")
            XCTAssertLessThan(result.text.count, full.text.count * 4 / 5, "\(previous.rawValue): this representative fixture should visibly shorten by at least 20 percent")
            if previous == .pattern { XCTAssertTrue(result.text.contains("候选")) }
            if previous == .climate {
                XCTAssertTrue(result.text.contains("戊")); XCTAssertTrue(result.text.contains("丁"))
                XCTAssertTrue(result.text.contains("条件") || result.text.contains("未") || result.text.contains("不能"))
            }
        }
        let explicit = try await answer("调候那段能不能只用两句白话？", fixture: f, previousFocus: .climate)
        let explicitResult = try XCTUnwrap(explicit)
        let fullClimate = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, focus: .climate)
        XCTAssertLessThan(explicitResult.text.count, fullClimate.text.count * 4 / 5, "Explicit plain-language brevity must affect the actual answer")
    }

    func testMixedPositiveRequestsKeepEachRequestedExplanation() async throws {
        let f = try await currentFixture()
        for (question, required) in [
            ("结合我的八字，分别讲扶抑和调候。", ["strength", "tiaohou"]),
            ("我的八字格局怎么看？也说一下调候。", ["pattern", "tiaohou"]),
            ("我的扶抑、格局、调候分别怎么看？", ["strength", "pattern", "tiaohou"])
        ] {
            let result = try await answer(question, fixture: f)
            guard let result else { XCTFail("\(question): expected a protected explanation"); continue }
            let actual = Set(result.selectedClaimIDs)
            XCTAssertTrue(Set(required).isSubset(of: actual), "\(question): expected \(required), got \(actual.sorted())")
        }
    }

    func testExcludingPatternDoesNotDiscardRequestedStrengthAndClimate() async throws {
        let f = try await currentFixture()
        let result = try await answer("只讲我的扶抑和调候，不要讲格局。", fixture: f)
        let ids = Set(try XCTUnwrap(result, "A topic exclusion is not a withdrawal from all Bazi").selectedClaimIDs)
        XCTAssertTrue(["strength", "tiaohou"].allSatisfy(ids.contains))
        XCTAssertFalse(ids.contains("pattern"))
    }

    func testRequestedElementPairIsActuallyExplained() async throws {
        let f = try await currentFixture()
        let result = try await answer("我的五行里，木克土是什么意思？", fixture: f)
        let text = try XCTUnwrap(result).text
        XCTAssertTrue(text.contains("木克土"), "Water-relative definitions do not answer the requested wood-to-earth relation")
    }

    func testMixedDocumentPersistenceRetainsBothTopicsForBriefFollowup() throws {
        let f = try fixture()
        let presentation = ReadingDocument.Presentation(focuses: [.strength, .climate])
        var source = ConversationEntry(role: "user", text: "只讲我的扶抑和调候")
        source.toolContext = f.context
        source.toolReceipts = f.receipts
        source.analysisMode = "命理"
        let full = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, presentation: presentation)
        let document = ReadingDocument(catalog: f.catalog, answer: full, sourceUserID: source.id, presentation: presentation)
        XCTAssertTrue(document.isValid)
        let restored = try JSONDecoder().decode(ReadingDocument.self, from: JSONEncoder().encode(document))
        var reply = ConversationEntry(role: "assistant", text: restored.plainText)
        reply.readingDocument = restored
        let next = ConversationEntry(role: "user", text: "能不能简单一点")
        let request = try XCTUnwrap(BaziReadingRequest.resolveRequest(question: next.text, mode: "命理", entries: [source, reply, next], currentUserID: next.id, context: f.context))
        XCTAssertEqual(request.focuses, [.strength, .climate])
        XCTAssertEqual(request.detail, .brief)
        let short = BaziFrameworkReading.render(selection: nil, catalog: f.catalog, presentation: request)
        XCTAssertTrue(short.selectedClaimIDs.contains { $0.hasPrefix("strength") })
        XCTAssertTrue(short.selectedClaimIDs.contains { $0.hasPrefix("tiaohou") })
        XCTAssertFalse(short.selectedClaimIDs.contains { $0.hasPrefix("pattern") })
        XCTAssertLessThan(short.text.count, full.text.count)
        let shortDocument = ReadingDocument(catalog: f.catalog, answer: short, sourceUserID: next.id, presentation: request)
        XCTAssertTrue(shortDocument.isValid)
        XCTAssertEqual(shortDocument.plainText, short.text)
    }

    func testIndependentFixtureArithmeticIdentifiesTieAndDayStemSensitivity() throws {
        let f = try fixture()
        let raw = try JSONSerialization.jsonObject(with: Data(f.receipts[0].output.utf8)) as! [String: Any]
        let bazi = raw["bazi"] as! [String: Any]
        let pillars = bazi["pillars"] as! [String: [String: Any]]
        var totals: [String: Double] = [:]
        for position in ["year", "month", "day", "hour"] {
            let pillar = try XCTUnwrap(pillars[position])
            let ganZhi = pillar["ganZhi"] as! [String: Any]
            totals[ganZhi["ganWuXing"] as! String, default: 0] += 1
            for hidden in pillar["cangGan"] as! [[String: Any]] {
                totals[hidden["wuXing"] as! String, default: 0] += (hidden["weight"] as! NSNumber).doubleValue
            }
        }
        let support = totals["水"]! + totals["金"]!
        let drain = totals["木"]! + totals["火"]! + totals["土"]!
        XCTAssertEqual(totals["水"]!, 2.2, accuracy: 0.000001)
        XCTAssertEqual(totals["金"]!, 1.8, accuracy: 0.000001)
        XCTAssertEqual(totals["木"]!, 2, accuracy: 0.000001)
        XCTAssertEqual(totals["火"]!, 1.3, accuracy: 0.000001)
        XCTAssertEqual(totals["土"]!, 0.7, accuracy: 0.000001)
        XCTAssertEqual(support, 4, accuracy: 0.000001)
        XCTAssertEqual(drain, 4, accuracy: 0.000001)
        XCTAssertEqual(totals.values.reduce(0, +), 8, accuracy: 0.000001)
        XCTAssertLessThan(support - 1, drain)
        XCTAssertEqual((bazi["strengthReference"] as! [String: Any])["riZhuStrong"] as? Bool, true)
        // This proves the stated count's tie boundary, not traditional strength
        // validity, and is not permission for the UI to invent absent evidence.
    }

    func testActualEngineReceiptExplainsTheTieWithAuditableCountEvidence() async throws {
        let f = try await currentFixture()
        let receipt = try XCTUnwrap(f.receipts.first)
        let output = try JSONDecoder().decode(JSONValue.self, from: Data(receipt.output.utf8))
        let strength = try XCTUnwrap(f.catalog.claims.first { $0.id == "strength" })
        let trace = try XCTUnwrap(BaziStrengthTrace.from(evidence: strength.evidence), "Actual get_domain, compiler and reader must all carry count evidence")
        XCTAssertEqual(trace.supportTotal, 4)
        XCTAssertEqual(trace.drainTotal, 4)
        XCTAssertTrue(trace.summary.contains("相等"), "A tie must not be described as more support than drain")
        XCTAssertTrue(trace.summary.contains("≥"))
        let rows = trace.groups.flatMap(\.rows).map { $0.title + $0.detail }.joined(separator: "\n")
        for fact in ["壬", "癸", "庚", "0.2", "0.6", "日主本人", "月令未额外加权"] {
            XCTAssertTrue(rows.contains(fact), "The rendered evidence must expose \(fact)")
        }
        XCTAssertTrue(strength.text.contains("4"))
        XCTAssertTrue(strength.text.contains("相等") || strength.text.contains("≥"))
        XCTAssertEqual(strength.qualification, .heuristic)
        for field in strength.evidence {
            XCTAssertEqual(field.toolCallID, receipt.callID)
            XCTAssertEqual(ReadingVerificationEvidence.pointer(field.pointer, in: output), field.value)
        }
        let audit: [String: Any] = ["engineRevision": f.context.engineRevision, "answer": strength.text, "summary": trace.summary, "rows": rows, "footnote": trace.footnote]
        try JSONSerialization.data(withJSONObject: audit, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: URL(fileURLWithPath: "/tmp/suji-reading-coverage-runtime-strength.json"), options: .atomic)
    }
}
