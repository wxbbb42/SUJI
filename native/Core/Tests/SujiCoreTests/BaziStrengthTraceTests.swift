import Foundation
import XCTest
@testable import SujiCore

final class BaziStrengthTraceTests: XCTestCase {
    private func fixture(month: Int = 8, day: Int = 15, hour: Int = 10) async throws -> JSONValue {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let raw = try await bridge.request("{\"command\":\"tool\",\"name\":\"get_domain\",\"arguments\":{\"domain\":\"事业\"},\"now\":\"2026-09-20T04:00:00Z\",\"birth\":{\"year\":1990,\"month\":\(month),\"day\":\(day),\"hour\":\(hour),\"minute\":0,\"gender\":\"女\",\"city\":\"合成资料\",\"longitude\":120}}")
        let root = try JSONDecoder().decode(JSONValue.self, from: raw)
        return try XCTUnwrap(ReadingVerificationEvidence.pointer("/result/bazi", in: root))
    }
    private func make(_ bazi: JSONValue) -> BaziStrengthTrace? {
        guard let pillars = ReadingVerificationEvidence.pointer("/pillars", in: bazi), let strength = ReadingVerificationEvidence.pointer("/strengthReference", in: bazi) else { return nil }
        return BaziStrengthTrace.make(pillars: pillars, strength: strength, structure: ReadingVerificationEvidence.pointer("/structureReference", in: bazi))
    }
    private func replacing(_ root: JSONValue, path: String, with replacement: JSONValue) -> JSONValue {
        func set(_ value: JSONValue, _ segments: ArraySlice<String>) -> JSONValue {
            guard let head = segments.first else { return replacement }
            if case var .object(object) = value, let child = object[head] { object[head] = set(child, segments.dropFirst()); return .object(object) }
            if case var .array(items) = value, let index = Int(head), items.indices.contains(index) { items[index] = set(items[index], segments.dropFirst()); return .array(items) }
            XCTFail("Missing mutation path: \(path)"); return value
        }
        return set(root, path.split(separator: "/").map(String.init)[...])
    }
    func testRealFloatingPointBoundaryUsesRecordedExactTie() async throws {
        let bazi = try await fixture(month: 3, hour: 12)
        let trace = try XCTUnwrap(make(bazi))
        XCTAssertEqual(trace.supportTotal, 4)
        XCTAssertEqual(trace.drainTotal, 4)
        XCTAssertTrue(trace.summary.contains("相等"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/strengthReference/riZhuStrong", in: bazi), .bool(true))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/strengthReference/yongShen", in: bazi), .string("木"))
    }
    func testCountTraceCannotRewriteRecordedContributionsOrAggregate() async throws {
        let bazi = try await fixture()
        let mutations: [(String, JSONValue)] = [
            ("/strengthReference/evidence/supportTotal", 5),
            ("/strengthReference/evidence/drainTotal", 3),
            ("/strengthReference/evidence/dayMasterContribution", 2),
            ("/strengthReference/evidence/supportExcludingDayMaster", 4),
            ("/strengthReference/evidence/contributions/0/weight", 2),
            ("/strengthReference/evidence/contributions/0/relation", "officer"),
            ("/strengthReference/evidence/contributions/2/isDayMaster", false),
            ("/strengthReference/evidence/contributions/4/gan", "甲"),
            ("/strengthReference/evidence/relationTotals/peer", 9),
            ("/strengthReference/evidence/elementTotals/金", 9),
            ("/strengthReference/evidence/threshold", "supportTotal > drainTotal"),
            ("/strengthReference/evidence/monthWeightApplied", true),
            ("/strengthReference/riZhuStrong", false),
            ("/strengthReference/yongShen", "火")
        ]
        for (path, replacement) in mutations { XCTAssertNil(make(replacing(bazi, path: path, with: replacement)), path) }
    }
    func testStructuralLabelAndRuleMustMatchRecordedMonthAndRootFacts() async throws {
        let bazi = try await fixture()
        XCTAssertNotNil(make(bazi))
        let mutations: [(String, JSONValue)] = [
            ("/structureReference/strength", "tairuo"),
            ("/structureReference/rootStrength/label", "无根"),
            ("/structureReference/rootStrength/totalRoot", 0),
            ("/structureReference/deLing", false),
            ("/structureReference/yueLingState", "死"),
            ("/structureReference/evidence/strengthRule", "shi-ling-minimal-root"),
            ("/structureReference/evidence/daySeatSameElementRoot", false),
            ("/structureReference/evidence/rootWeights/ben", 2),
            ("/structureReference/evidence/rootLabelBands/0/upperExclusive", 1),
            ("/structureReference/evidence/sameElementRoots/0/kind", "yin"),
            ("/structureReference/evidence/monthMainQi", "甲")
        ]
        for (path, replacement) in mutations { XCTAssertNil(make(replacing(bazi, path: path, with: replacement)), path) }
    }
    func testAllTenDayStemsProduceUsableRecordedTrace() async throws {
        for day in 15...24 {
            let bazi = try await fixture(day: day)
            let trace = try XCTUnwrap(make(bazi), "day \(day)")
            XCTAssertEqual(trace.supportTotal + trace.drainTotal, 8, accuracy: 0.00001)
            XCTAssertEqual(trace.groups.first?.rows.count, 4)
        }
    }

    func testMonthHourGridKeepsExpandedEvidenceWithinPersistedDocumentLimits() async throws {
        // The new full trace is larger than a scalar field. Exercise actual
        // month/hour variation so a valid reply cannot silently lose continuity
        // after persistence because one evidence value exceeds its byte limit.
        let now = Date(timeIntervalSince1970: 1_789_876_800)
        var largestField = 0
        for month in 1...12 {
            for hour in stride(from: 0, through: 22, by: 2) {
                let bazi = try await fixture(month: month, hour: hour)
                XCTAssertNotNil(make(bazi), "month \(month), hour \(hour)")
                let birth = BirthProfile(year: 1990, month: month, day: 15, hour: hour, minute: 0, gender: "女", city: "合成资料", longitude: 120)
                let context = try ToolContext(birth: birth, engineRevision: "trace-capacity-test", referenceDate: now, mode: "命理")
                let receipt = ToolReceipt(callID: "capacity", name: "get_domain", arguments: ["domain": "事业"], output: ReadingVerificationEvidence.encoded(JSONValue.object(["bazi": bazi])), context: context)
                let catalog = try XCTUnwrap(BaziFrameworkReading.catalog(receipts: [receipt], context: context))
                for detail in [ReadingDocument.Detail.standard, .brief] {
                    let presentation = ReadingDocument.Presentation(focuses: [.strength, .pattern, .climate], detail: detail)
                    let answer = BaziFrameworkReading.render(selection: nil, catalog: catalog, presentation: presentation)
                    let document = ReadingDocument(catalog: catalog, answer: answer, sourceUserID: UUID(), presentation: presentation)
                    let restored = try JSONDecoder().decode(ReadingDocument.self, from: JSONEncoder().encode(document))
                    XCTAssertTrue(restored.isValid, "month \(month), hour \(hour), \(detail)")
                    XCTAssertEqual(restored.plainText, answer.text)
                    for field in restored.sections.flatMap(\.evidence) {
                        largestField = max(largestField, ReadingVerificationEvidence.encoded(field.value).utf8.count)
                    }
                }
            }
        }
        print("Strength trace capacity: 144 actual month/hour cases; largest persisted evidence value \(largestField) bytes")
    }

    func testEvidencePresentationRequiresSameSourceAndAllInputFields() async throws {
        let bazi = try await fixture()
        let fields = try ["pillars", "strengthReference", "structureReference"].map { name in
            BaziFrameworkReading.FieldEvidence(toolCallID: "actual", pointer: "/bazi/" + name, value: try XCTUnwrap(ReadingVerificationEvidence.pointer("/" + name, in: bazi)))
        }
        XCTAssertNotNil(BaziStrengthTrace.from(evidence: fields))
        XCTAssertNil(BaziStrengthTrace.from(evidence: Array(fields.dropFirst())))
        let conflicting = BaziFrameworkReading.FieldEvidence(toolCallID: "another", pointer: fields[0].pointer, value: fields[0].value)
        XCTAssertNil(BaziStrengthTrace.from(evidence: fields + [conflicting]))
    }
}
