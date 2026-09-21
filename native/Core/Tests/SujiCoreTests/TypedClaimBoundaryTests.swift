import Foundation
import XCTest
@testable import SujiCore

/// Independently authored against immutable live receipts. These assert the
/// boundary between source facts and display claims, not provider acceptance.
final class TypedClaimBoundaryTests: XCTestCase {
    private func fixture(round: Int = 4) throws -> (ToolContext, [ToolReceipt]) {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: native.appendingPathComponent("Engine/validation/reasoning/native-round\(round)-results.json"))
        let report = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let record = try XCTUnwrap((report["cases"] as? [[String: Any]])?.first { $0["id"] as? String == "interpretation-disagreement" })
        let context = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: record["context"]!))
        let receipts = try JSONDecoder().decode([ToolReceipt].self, from: JSONSerialization.data(withJSONObject: record["receipts"]!))
        return (context, receipts)
    }

    private func replacing(_ receipt: ToolReceipt, _ path: [String], with replacement: JSONValue?) throws -> ToolReceipt {
        func update(_ root: JSONValue, at path: ArraySlice<String>) -> JSONValue {
            guard let head = path.first else { return replacement ?? .null }
            if case var .object(object) = root {
                if path.count == 1 { object[head] = replacement }
                else if let child = object[head] { object[head] = update(child, at: path.dropFirst()) }
                return .object(object)
            }
            if case var .array(array) = root, let index = Int(head), array.indices.contains(index) {
                array[index] = update(array[index], at: path.dropFirst())
                return .array(array)
            }
            return root
        }
        let root = try JSONDecoder().decode(JSONValue.self, from: Data(receipt.output.utf8))
        var result = receipt
        result.output = String(decoding: try JSONEncoder().encode(update(root, at: path[...])), as: UTF8.self)
        return result
    }

    private func catalog(_ context: ToolContext, _ receipts: [ToolReceipt]) throws -> BaziFrameworkReading.Catalog {
        try XCTUnwrap(BaziFrameworkReading.catalog(receipts: receipts, context: context))
    }

    private func selection(_ ids: [String], version: String = BaziFrameworkReading.protocolVersion) throws -> String {
        String(decoding: try JSONSerialization.data(withJSONObject: ["protocolVersion": version, "claimIDs": ids]), as: UTF8.self)
    }

    func testComparisonScopeDoesNotCaptureRefusalsOrOtherModes() {
        for question in [
            "为什么扶抑参考用神和格局用神可能不一样？结合我的命盘说，别把流派不同当计算错误。",
            "扶抑说用土，格局说用金，怎么理解这两个结果？",
            "扶抑用神和格局用神两个都取土，是否证明计算正确？",
        ] { XCTAssertTrue(BaziFrameworkReading.applies(question: question, mode: "命理"), question) }
        for question in [
            "不要比较扶抑用神和格局用神，我只问今年大运",
            "解释一下扶抑参考用神这个词，格局暂时不用看，为什么叫用神？",
            "格局放大一点，为什么心情会不同？", "我的扶抑参考用神是什么？",
        ] { XCTAssertFalse(BaziFrameworkReading.applies(question: question, mode: "命理"), question) }
        for mode in ["倾诉", "起卦"] {
            XCTAssertFalse(BaziFrameworkReading.applies(question: "扶抑用神与格局用神为什么不同？", mode: mode))
        }
    }

    func testHistoricalFalseAcceptancesBecomeUsefulQualifiedComparisons() throws {
        for round in [3, 4] {
            let (context, receipts) = try fixture(round: round)
            let answer = BaziFrameworkReading.render(selection: nil, catalog: try catalog(context, receipts)).text
            XCTAssertTrue(answer.contains("庚午、甲申、壬子、乙巳"))
            XCTAssertTrue(answer.contains("偏印格候选"))
            XCTAssertTrue(answer.contains("参考用神为土"))
            XCTAssertTrue(answer.contains("格局用神记为金"))
            XCTAssertTrue(answer.contains("月支申的本气庚出现在年干"))
            XCTAssertTrue(answer.contains("不能证明两套计算都正确"))
            XCTAssertTrue(answer.contains("土克水"))
            XCTAssertTrue(answer.contains("水克火称为“耗”"))
            XCTAssertFalse(answer.contains("成的是**偏印格**"))
            XCTAssertFalse(answer.contains("各自成立"))
            XCTAssertFalse(answer.contains("土克它、耗它"))
        }
    }

    func testEveryEvidencePointerResolvesToExactCurrentReceiptValue() throws {
        let (context, receipts) = try fixture()
        let source = Dictionary(uniqueKeysWithValues: receipts.map { ($0.callID, $0) })
        for claim in try catalog(context, receipts).claims {
            XCTAssertFalse(claim.evidence.isEmpty, claim.id)
            for evidence in claim.evidence {
                let receipt = try XCTUnwrap(source[evidence.toolCallID])
                XCTAssertEqual(receipt.context, context)
                let root = try JSONDecoder().decode(JSONValue.self, from: Data(receipt.output.utf8))
                XCTAssertEqual(ReadingVerificationEvidence.pointer(evidence.pointer, in: root), evidence.value, claim.id)
            }
        }
    }

    func testStaleOrImportedReceiptsCannotSupplyCurrentClaims() throws {
        let (context, receipts) = try fixture()
        for changedField in ["birthFingerprint", "engineRevision", "referenceDate", "mode"] {
            var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: Any])
            switch changedField {
            case "birthFingerprint": object[changedField] = String(repeating: "a", count: 64)
            case "engineRevision": object[changedField] = "other-engine"
            case "referenceDate": object[changedField] = context.referenceDate.timeIntervalSinceReferenceDate + 1
            default: object[changedField] = "起卦"
            }
            let stale = try JSONDecoder().decode(ToolContext.self, from: JSONSerialization.data(withJSONObject: object))
            let altered = receipts.map { item in var item = item; item.context = stale; return item }
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: altered, context: context), changedField)
            let mixed = try catalog(context, altered + receipts)
            XCTAssertEqual(mixed.context, context)
        }
        let imported = receipts.map { item in var item = item; item.context = nil; return item }
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: imported, context: context))
    }

    func testMatchingDomainReceiptsDoNotMultiplyEvidenceOrValidationClaims() throws {
        let (context, receipts) = try fixture()
        let one = try catalog(context, [receipts[0]])
        let several = try catalog(context, receipts)
        XCTAssertEqual(one.defaultClaimIDs, several.defaultClaimIDs)
        XCTAssertEqual(one.claims.map(\.text), several.claims.map(\.text))
        XCTAssertEqual(Set(several.claims.flatMap(\.evidence).map(\.toolCallID)), [receipts[0].callID])
    }

    func testConflictingDomainFactsCannotBeMergedIntoOneStory() throws {
        let (context, receipts) = try fixture()
        let conflicts: [([String], JSONValue?)] = [
            (["bazi", "pillars", "year", "ganZhi", "gan"], .string("辛")),
            (["bazi", "strengthReference", "riZhuStrong"], .bool(false)),
            (["bazi", "patternAnalysis", "assessmentStatus"], .string("established")),
            (["bazi", "tiaoHou", "conditions"], nil),
        ]
        for (path, value) in conflicts {
            let altered = try replacing(receipts[1], path, with: value)
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: [receipts[0], altered], context: context), path.joined(separator: "/"))
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: [altered, receipts[0]], context: context), "Selection must not depend on which conflicting receipt comes first")
        }
    }

    func testErrorsAndUnrelatedToolsCannotMasqueradeAsDomainEvidence() throws {
        let (context, receipts) = try fixture()
        var wrongName = receipts[0]; wrongName.name = "get_timing"
        var malformed = receipts[0]; malformed.output = "{"
        let error = try replacing(receipts[0], ["error"], with: .string("synthetic failure"))
        for rejected in [wrongName, malformed, error] {
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: [rejected], context: context))
        }
    }

    func testLegacyPatternLabelCannotOverrideQualifiedAnalysis() throws {
        let (context, receipts) = try fixture()
        let altered = try replacing(receipts[0], ["bazi", "pattern", "name"], with: .string("已经成格且必然富贵"))
        let result = BaziFrameworkReading.render(selection: nil, catalog: try catalog(context, [altered])).text
        XCTAssertTrue(result.contains("偏印格候选"))
        XCTAssertFalse(result.contains("必然富贵"))
    }

    func testMissingOrUpgradedQualificationCannotCreateAnUnqualifiedCatalog() throws {
        let (context, receipts) = try fixture()
        let invalid: [([String], JSONValue?)] = [
            (["bazi", "patternAnalysis", "assessmentStatus"], .string("established")),
            (["bazi", "patternAnalysis", "assessmentStatus"], nil),
            (["bazi", "patternAnalysis", "conditions"], .array([])),
            (["bazi", "strengthReference", "suggestionStatus"], .string("validated")),
            (["bazi", "strengthReference", "suggestionBasis"], nil),
            (["bazi", "strengthReference", "tiaohouApplied"], .bool(true)),
        ]
        for (path, replacement) in invalid {
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: [try replacing(receipts[0], path, with: replacement)], context: context), path.joined(separator: "/"))
        }
    }

    func testAdversarialModelSelectionFallsBackToFullLocalAnswer() throws {
        let (context, receipts) = try fixture()
        let data = try catalog(context, receipts)
        let expected = BaziFrameworkReading.render(selection: nil, catalog: data)
        let badSelections = [
            try selection([]), try selection(["chart"]),
            try selection(data.defaultClaimIDs + ["established-pattern"]),
            try selection(data.defaultClaimIDs + ["pattern"]),
            try selection(data.defaultClaimIDs, version: "suji-bazi-claims-0"),
            #"{"protocolVersion":"suji-bazi-claims-1","claimIDs":["chart","strength","pattern","comparison"],"text":"成的是偏印格，土克水耗水"}"#,
            #"{"protocolVersion":"suji-bazi-claims-1","claimIDs":["chart","strength","pattern","comparison"],"established":true}"#,
            String(repeating: "x", count: 2_001), "成的是偏印格", "```json\n{}\n```",
        ]
        for input in badSelections {
            let result = BaziFrameworkReading.render(selection: input, catalog: data)
            XCTAssertEqual(result.selectionStatus, "default-selection")
            XCTAssertEqual(result.text, expected.text)
            XCTAssertEqual(result.selectedClaimIDs, expected.selectedClaimIDs)
        }
    }

    func testAcceptedOrderingCannotSplitClaimFromItsQualification() throws {
        let (context, receipts) = try fixture()
        let data = try catalog(context, receipts)
        let result = BaziFrameworkReading.render(selection: try selection(["comparison", "pattern", "strength", "chart"]), catalog: data)
        XCTAssertEqual(result.selectionStatus, "validated-selection")
        XCTAssertEqual(result.selectedClaimIDs, ["chart", "pattern", "strength", "comparison"])
        for claim in data.claims where result.selectedClaimIDs.contains(claim.id) {
            XCTAssertTrue(result.text.contains(claim.text), "A selected claim must remain indivisible: \(claim.id)")
        }
        XCTAssertTrue(result.text.contains("偏印格候选"))
    }

    func testFiveElementRelationsUseDayMasterPerspectiveForAllFiveElements() {
        let expected: [BaziFrameworkReading.Element: [(String, String, String)]] = [
            .wood: [("水", "木", "生我"), ("金", "木", "克我"), ("木", "火", "我生为泄"), ("木", "土", "我克为耗")],
            .fire: [("木", "火", "生我"), ("水", "火", "克我"), ("火", "土", "我生为泄"), ("火", "金", "我克为耗")],
            .earth: [("火", "土", "生我"), ("木", "土", "克我"), ("土", "金", "我生为泄"), ("土", "水", "我克为耗")],
            .metal: [("土", "金", "生我"), ("火", "金", "克我"), ("金", "水", "我生为泄"), ("金", "木", "我克为耗")],
            .water: [("金", "水", "生我"), ("土", "水", "克我"), ("水", "木", "我生为泄"), ("水", "火", "我克为耗")],
        ]
        for (day, edges) in expected {
            let actual = BaziFrameworkReading.relations(to: day)
            XCTAssertEqual(actual.count, 4)
            for (a, e) in zip(actual, edges) {
                XCTAssertEqual(a.subject.rawValue, e.0)
                XCTAssertEqual(a.object.rawValue, e.1)
                XCTAssertEqual(a.kind.rawValue, e.2)
            }
        }
    }

    func testTraceUsesActualExposedColumnInsteadOfHistoricalYearStem() throws {
        let (context, receipts) = try fixture()
        let noYearGeng = try replacing(receipts[0], ["bazi", "pillars", "year", "ganZhi", "gan"], with: .string("辛"))
        let hourGeng = try replacing(noYearGeng, ["bazi", "pillars", "hour", "ganZhi", "gan"], with: .string("庚"))
        let text = BaziFrameworkReading.render(selection: nil, catalog: try catalog(context, [hourGeng])).text
        XCTAssertTrue(text.contains("月支申的本气庚出现在时干"))
        XCTAssertFalse(text.contains("庚出现在年干"))
    }

    func testUnsupportedSelectionBasisCannotClaimBenqiExposure() throws {
        let (context, receipts) = try fixture()
        for basis in ["sanhe", "sanhui", "jianlu-yueliu", "invented-basis"] {
            let changed = try replacing(receipts[0], ["bazi", "patternAnalysis", "selectionBasis"], with: .string(basis))
            let text = BaziFrameworkReading.render(selection: nil, catalog: try catalog(context, [changed])).text
            XCTAssertFalse(text.contains("本气庚出现在"), basis)
            XCTAssertTrue(text.contains("偏印格候选"), basis)
        }
    }

    func testConditionalQuotationRequiresApplicableSourceAndConditions() throws {
        let (context, receipts) = try fixture()
        let original = try catalog(context, [receipts[0]])
        XCTAssertTrue(original.claims.contains { $0.id == "tiaohou" && $0.qualification == .conditionalSource && $0.text.contains("专用戊土，次取丁火佐戊制庚") && $0.text.contains("辰戌戊与申中戊的区别") })
        let invalid: [(String, JSONValue?)] = [
            ("dayStem", .string("癸")), ("monthBranch", .string("酉")),
            ("automatedSelection", .bool(true)), ("conditions", .array([])),
            ("sourceSha256", .string("unverified")), ("reviewStatus", .string("not-checked")),
            ("editionStatus", nil), ("sourceDocument", .string("model-memory")),
        ]
        for (key, replacement) in invalid {
            let changed = try replacing(receipts[0], ["bazi", "tiaoHou", key], with: replacement)
            let result = try catalog(context, [changed])
            XCTAssertFalse(result.claims.contains { $0.id == "tiaohou" }, key)
            XCTAssertTrue(result.claims.contains { $0.id == "pattern" }, "Missing optional quote must not erase the useful core comparison")
        }
    }

    func testContradictoryPatternStemElementCannotGenerateAConfidentTrace() throws {
        let (context, receipts) = try fixture()
        let changed = try replacing(receipts[0], ["bazi", "patternAnalysis", "yongShen"], with: .string("土"))
        if let result = BaziFrameworkReading.catalog(receipts: [changed], context: context) {
            let text = BaziFrameworkReading.render(selection: nil, catalog: result).text
            XCTAssertFalse(text.contains("本气庚出现在年干"), "The claimed pattern element conflicts with its selected stem; report an unresolved trace or decline this catalog")
        }
    }

    func testWeakStrengthBranchDoesNotBecomeMutualValidationWhenElementsMatch() throws {
        let (context, receipts) = try fixture()
        let weak = try replacing(receipts[0], ["bazi", "strengthReference", "riZhuStrong"], with: .bool(false))
        let suppliedByMetal = try replacing(weak, ["bazi", "strengthReference", "yongShen"], with: .string("金"))
        let answer = BaziFrameworkReading.render(selection: nil, catalog: try catalog(context, [suppliedByMetal])).text
        XCTAssertTrue(answer.contains("偏弱"))
        XCTAssertTrue(answer.contains("参考用神为金"))
        XCTAssertTrue(answer.contains("恰好都列出金"))
        XCTAssertTrue(answer.contains("也不构成互相验证"))
        let impossibleRelation = try replacing(weak, ["bazi", "strengthReference", "yongShen"], with: .string("火"))
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: [impossibleRelation], context: context))
    }

    func testMissingEvidenceRecoveryIsNativeAndPreservesActualBirthState() {
        let existing = BaziFrameworkReading.unavailableReply(hasBirth: true)
        XCTAssertTrue(existing.contains("出生资料已保留，无需重填"))
        XCTAssertTrue(existing.contains("暂时不能结合你的命盘比较"))
        let missing = BaziFrameworkReading.unavailableReply(hasBirth: false)
        XCTAssertTrue(missing.contains("补充出生资料"))
        for answer in [existing, missing] {
            XCTAssertFalse(answer.contains("庚午"))
            XCTAssertFalse(answer.contains("偏印格"))
            XCTAssertFalse(answer.contains("原盘"))
            XCTAssertFalse(answer.contains("已算出"))
        }
    }

    func testRetryPlannerCanStopWithoutLosingThisQuestionsExistingReceipt() async throws {
        let (context, receipts) = try fixture()
        var oldReceipt = try replacing(receipts[0], ["bazi", "patternAnalysis", "name"], with: .string("正官格"))
        oldReceipt.callID = "older-question-only"
        var previous = ConversationEntry(role: "user", text: "上一问的格局是什么？")
        previous.toolContext = context
        previous.toolReceipts = [oldReceipt]
        var current = ConversationEntry(role: "user", text: "扶抑用神和格局用神为什么不同？")
        current.toolContext = context
        current.toolReceipts = [receipts[0]]
        let history = ReadingPrompt.history(from: [previous, current], currentUserID: current.id, context: context)
        XCTAssertEqual(history.filter { $0.role == .tool }.compactMap(\.toolCallID), [receipts[0].callID])
        let unsafePlannerText = "偏印格已经成立，两个框架都正确"
        let orchestrator = ToolOrchestrator(complete: { _, _ in .text(unsafePlannerText) }, execute: { _ in
            XCTFail("A retry with a complete current receipt does not require re-execution")
            throw URLError(.unknown)
        }, persistReceipt: { _ in XCTFail("No new result was executed") })
        let cached = try XCTUnwrap(current.toolReceipts)
        let result = try await orchestrator.run(history: history, definitions: [], cachedReceipts: cached, context: context)
        XCTAssertTrue(result.receipts.isEmpty)
        XCTAssertFalse(result.messages.contains { $0.content == unsafePlannerText })
        // Same composition as ChatSession; cache belongs to this current user entry.
        let data = try catalog(context, cached + result.receipts)
        let reply = BaziFrameworkReading.render(selection: nil, catalog: data)
        XCTAssertTrue(reply.text.contains("偏印格候选"))
        XCTAssertFalse(reply.text.contains("正官格"))
        XCTAssertEqual(Set(data.claims.flatMap(\.evidence).map(\.toolCallID)), [receipts[0].callID])
    }

    func testOptionalOrderingTransportFailureStillReturnsFullLocalExplanation() async throws {
        let (context, receipts) = try fixture()
        let data = try catalog(context, receipts)
        let answer = try await BaziFrameworkReading.compose(catalog: data, question: "扶抑与格局用神为什么不同？") { _ in
            throw URLError(.networkConnectionLost)
        }
        XCTAssertEqual(answer.selectionStatus, "selection-unavailable")
        XCTAssertEqual(answer.text, BaziFrameworkReading.render(selection: nil, catalog: data).text)
        XCTAssertTrue(answer.text.contains("偏印格候选"))
    }

    func testOrderingCancellationIsNotReclassifiedAsTransportFailure() async throws {
        let (context, receipts) = try fixture()
        let data = try catalog(context, receipts)
        do {
            _ = try await BaziFrameworkReading.compose(catalog: data, question: "扶抑与格局用神为什么不同？") { _ in
                throw CancellationError()
            }
            XCTFail("Explicit cancellation must stop delivery")
        } catch is CancellationError {
            // Expected; never return an otherwise available default answer.
        }
        let raw = try selection(data.defaultClaimIDs)
        let task = Task {
            try await BaziFrameworkReading.compose(catalog: data, question: "扶抑与格局用神为什么不同？") { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return .text(raw)
            }
        }
        do {
            _ = try await task.value
            XCTFail("Cancellation after receiving a valid order must still stop delivery")
        } catch is CancellationError {
            // Expected after the complete closure returns its normal response.
        }
    }

    func testNamedSchoolCannotBeInferredFromAnUnspecifiedOrDifferentPolicy() throws {
        let (context, receipts) = try fixture()
        for (key, value) in [
            ("structureYongShen", JSONValue.string("another-school")),
            ("status", JSONValue.string("empirically-validated")),
        ] {
            let altered = try replacing(receipts[0], ["bazi", "interpretationPolicy", key], with: value)
            XCTAssertNil(BaziFrameworkReading.catalog(receipts: [altered], context: context), key)
        }
        let missing = try replacing(receipts[0], ["bazi", "interpretationPolicy"], with: nil)
        XCTAssertNil(BaziFrameworkReading.catalog(receipts: [missing], context: context))
        let pattern = try XCTUnwrap(try catalog(context, receipts).claims.first { $0.id == "pattern" })
        XCTAssertTrue(pattern.evidence.contains { $0.pointer == "/bazi/interpretationPolicy/structureYongShen" && $0.value == .string("月令格局用神（子平真诠口径）") })
    }

    func testLocalRulesHaveResolvableSourceFilesAndDoNotAlterSourceConditions() throws {
        let (context, receipts) = try fixture()
        let data = try catalog(context, receipts)
        let registry = Dictionary(uniqueKeysWithValues: data.ruleSources.map { ($0.id, $0) })
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for claim in data.claims {
            for id in claim.ruleIDs {
                let rule = try XCTUnwrap(registry[id], id)
                XCTAssertFalse(rule.scope.isEmpty)
                for reference in rule.source.components(separatedBy: "; ") {
                    let path = String(reference.split(separator: "#")[0])
                    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), path)
                }
            }
        }
        let tiaohou = try XCTUnwrap(data.claims.first { $0.id == "tiaohou" })
        XCTAssertFalse(tiaohou.text.contains("。。"))
        let conditions = try XCTUnwrap(tiaohou.evidence.first { $0.pointer == "/bazi/tiaoHou/conditions" })
        if case let .array(values) = conditions.value, case let .string(last) = values.last {
            XCTAssertTrue(last.hasSuffix("。"), "Display punctuation may normalize but recorded evidence remains exact")
        } else { XCTFail("Original source conditions must remain an exact array") }
    }
}
