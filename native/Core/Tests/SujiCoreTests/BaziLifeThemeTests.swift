import XCTest
import CryptoKit
@testable import SujiCore

final class BaziLifeThemeTests: XCTestCase {
    private let bundleRevision = String(repeating: "a", count: 64)
    private let owner = "synthetic-theme-owner"
    // These are invented profiles selected through the real calendar engine, not users.
    private var samples: [(String, BirthProfile)] {
        [("mixedLayers", 1, 2, 2), ("missingPair", 1, 5, 2), ("hiddenPair", 1, 8, 22),
         ("bothExposedResource", 2, 14, 14), ("bothExposed", 2, 20, 14)].map {
            ($0.0, BirthProfile(year: 1987, month: $0.1, day: $0.2, hour: $0.3, minute: 20, gender: "女", city: "明确合成主题测试", longitude: 120))
        }
    }
    private var native: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func run(_ request: [String: Any]) async throws -> Data {
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        return try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request, options: [.sortedKeys]), as: UTF8.self))
    }
    private func facts(_ birth: BirthProfile) async throws -> (NatalReadingReport, Data, String) {
        let b = try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))
        let metadata = try await run(["command": "metadata"])
        let revision = try XCTUnwrap((JSONSerialization.jsonObject(with: metadata) as? [String: Any])?["engineRevision"] as? String)
        let data = try await run(["command": "natal", "birth": b])
        let dossier = try NatalDossier(ownerID: owner, birth: birth, engineRevision: bundleRevision, payload: data)
        let report = try XCTUnwrap(NatalReadingCompiler.natal(dossier: dossier, ownerID: owner, birth: birth, engineRevision: bundleRevision, enginePayloadRevision: revision).first { $0.system == .bazi })
        return (report, data, revision)
    }
    func testRealCalendarSamplesHaveDifferentReasoningAndProduceReproducibleSamples() async throws {
        var drafts: [String] = [], themes: [BaziLifeTheme] = []
        for (name, birth) in samples {
            let (report, _, _) = try await facts(birth)
            let theme = try BaziLifeThemeCompiler.compile(report: report)
            XCTAssertEqual(theme.branch.rawValue, name == "bothExposedResource" ? "bothExposed" : name)
            XCTAssertEqual(theme.hasExposedResource, name == "bothExposedResource" || name == "mixedLayers")
            XCTAssertEqual(theme.snapshotID, report.snapshotID)
            XCTAssertEqual(theme, try BaziLifeThemeCompiler.compile(report: report))
            XCTAssertNoThrow(try BaziLifeThemeCompiler.validate(theme, against: report))
            XCTAssertTrue(theme.boundary.contains("不能据此认定"))
            XCTAssertTrue(theme.exercise.contains("现代编辑练习"))
            XCTAssertTrue(theme.observation.contains("不符合"))
            XCTAssertFalse(theme.explanation.contains("天生"))
            XCTAssertFalse(theme.explanation.contains("成功率"))
            XCTAssertFalse(theme.sourceIDs.isEmpty)
            XCTAssertEqual(Set(theme.evidence.map(\.id)).count, theme.evidence.count)
            themes.append(theme)
            drafts.append("## \(name)\n明确合成、非用户资料：\(birth.label)，女，经度120，Asia/Shanghai。\n分支：\(theme.branch.rawValue)；快照：`\(theme.snapshotID)`\n\n### \(theme.title)\n\(theme.summary)\n\n\(theme.explanation)\n\n\(theme.boundary)\n\n自我观察：\(theme.observation)\n\n\(theme.exercise)\n\n\(theme.example)\n\n继续问：\(theme.followUpPrompt)\n\n" + theme.evidence.map { "- `\($0.id)` · `\($0.dossierPointer)` → `\($0.toolPointer)`：\($0.value)" }.joined(separator: "\n"))
        }
        XCTAssertEqual(Set(themes.map(\.explanation)).count, samples.count)
        XCTAssertTrue(themes[1].explanation.contains("不支持"))
        XCTAssertTrue(themes[3].explanation.contains("不能裁定"))
        if let output = ProcessInfo.processInfo.environment["SUJI_THEME_SAMPLES_OUTPUT"] {
            let sources = BaziLifeThemeCompiler.sources.map { "- **\($0.id)** · `\($0.path)` · SHA256 `\($0.sha256)` · \($0.locator)\n  - 引文：\($0.quote)\n  - 适用范围：\($0.scope)" }.joined(separator: "\n")
            let body = "# 八字主题差异样稿（真实历法、合成资料）\n\n本文件由真实本地 JS 引擎 → strict NatalReadingCompiler → BaziLifeThemeCompiler 生成，不调用AI。不同生日的合成资料不是用户资料；现代练习无古籍授权声称。\n内容版本：\(BaziLifeThemeCompiler.contentVersion)；规则版本：\(BaziLifeThemeCompiler.ruleVersion)。\n\n" + drafts.joined(separator: "\n\n") + "\n\n## 固定来源\n" + sources + "\n"
            try body.write(toFile: output, atomically: true, encoding: .utf8)
        }
    }
    func testProjectionRequiresActualMatchingReceiptContextArgumentsAndFacts() async throws {
        let birth = samples[3].1
        let (report, data, revision) = try await facts(birth)
        let theme = try BaziLifeThemeCompiler.compile(report: report)
        let context = try ToolContext(birth: birth, engineRevision: revision, referenceDate: Date(timeIntervalSince1970: 1_790_000_000), mode: "命理")
        let birthObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))
        let output = try await run(["command": "tool", "name": "get_domain", "arguments": ["domain": "事业"], "birth": birthObject, "natal": JSONSerialization.jsonObject(with: data), "now": "2026-09-23T04:00:00Z"])
        let result = try XCTUnwrap((JSONSerialization.jsonObject(with: output) as? [String: Any])?["result"])
        let resultBytes = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys, .withoutEscapingSlashes])
        let receipt = ToolReceipt(callID: "real-theme-projection", name: "get_domain", arguments: ["domain": "事业"], output: String(decoding: resultBytes, as: UTF8.self), context: context)
        XCTAssertNoThrow(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: receipt, context: context))
        var altered = receipt; altered.context = nil
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: altered, context: context))
        altered = receipt; altered.name = "get_timing"
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: altered, context: context))
        altered = receipt; altered.arguments = ["domain": "财富"]
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: altered, context: context))
        altered = receipt; altered.output = receipt.output.replacingOccurrences(of: "伤官", with: "正财")
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: altered, context: context))
        altered = receipt; altered.output = "{\"error\":\"calculation_failed\"}"
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: altered, context: context))
        let other = try ToolContext(birth: birth, engineRevision: revision, referenceDate: context.referenceDate.addingTimeInterval(1), mode: "命理")
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validateProjection(theme: theme, receipt: receipt, context: other))
    }
    func testDecodedThemeDoesNotAuthenticateItsTextOrSourceAndCannotCrossSnapshots() async throws {
        let (report, _, _) = try await facts(samples[0].1)
        let original = try BaziLifeThemeCompiler.compile(report: report)
        let bytes = try JSONEncoder().encode(original)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        for (key, value) in [("explanation", "你天生善于反抗权威"), ("contentVersion", "future"), ("snapshotID", String(repeating: "f", count: 64))] {
            json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any]); json[key] = value
            let corrupted = try JSONDecoder().decode(BaziLifeTheme.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertThrowsError(try BaziLifeThemeCompiler.validate(corrupted, against: report))
        }
        json = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any]); json["sourceIDs"] = ["invented-authority"]
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validate(JSONDecoder().decode(BaziLifeTheme.self, from: JSONSerialization.data(withJSONObject: json)), against: report))
        let (other, _, _) = try await facts(samples[1].1)
        XCTAssertThrowsError(try BaziLifeThemeCompiler.validate(original, against: other))
    }
    func testMissingFactsAreNotTheNoCombinationBranchAndUnrelatedMetadataIsNotContent() async throws {
        let (report, _, _) = try await facts(samples[1].1)
        let noFacts = NatalReadingReport(id: report.id, system: report.system, title: report.title, summary: report.summary, boundary: report.boundary, contentVersion: report.contentVersion, snapshotID: report.snapshotID, adapterVersion: report.adapterVersion, entries: [])
        XCTAssertThrowsError(try BaziLifeThemeCompiler.compile(report: noFacts))
        let notBazi = NatalReadingReport(id: report.id, system: .ziwei, title: report.title, summary: report.summary, boundary: report.boundary, contentVersion: report.contentVersion, snapshotID: report.snapshotID, adapterVersion: report.adapterVersion, entries: report.entries)
        XCTAssertThrowsError(try BaziLifeThemeCompiler.compile(report: notBazi))
    }
    func testAllBundledSourcesStillMatchTheirReviewedFilesAndQuotes() throws {
        let repository = native.deletingLastPathComponent()
        for source in BaziLifeThemeCompiler.sources {
            let bytes = try Data(contentsOf: repository.appendingPathComponent(source.path))
            XCTAssertEqual(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), source.sha256)
            XCTAssertTrue(String(decoding: bytes, as: UTF8.self).contains(source.quote), source.id)
        }
    }
    func testRepeatedHiddenStemKeepsEveryPositionInsteadOfCopyingEffectiveness() async throws {
        let (report, _, _) = try await facts(samples[3].1)
        let theme = try BaziLifeThemeCompiler.compile(report: report)
        // Real 1987-02-14 chart has 丁 in the year stem and in 午 / 未 hidden stems.
        XCTAssertTrue(theme.summary.contains("年干丁"))
        XCTAssertTrue(theme.evidence.contains { $0.dossierPointer == "/mingPan/siZhu/day" && $0.value.contains("丁") })
        XCTAssertTrue(theme.evidence.contains { $0.dossierPointer == "/mingPan/siZhu/hour" && $0.value.contains("丁") })
        XCTAssertTrue(theme.explanation.contains("不能裁定"))
        XCTAssertFalse(theme.explanation.contains("救应成立"))
        XCTAssertFalse(theme.explanation.contains("合去成立"))
    }
    func testConflictingOrCorruptedPillarEvidenceCannotCreateATheme() async throws {
        let (report, _, _) = try await facts(samples[3].1)
        let original = try XCTUnwrap(report.entries.first { $0.id == "group.output" })
        func altered(_ evidence: [NatalReadingReport.Evidence]) -> NatalReadingReport {
            let entry = NatalReadingReport.Entry(id: original.id, title: original.title, summary: original.summary, explanation: original.explanation, boundary: original.boundary, reflection: original.reflection, evidence: evidence, sources: original.sources)
            return NatalReadingReport(id: report.id, system: report.system, title: report.title, summary: report.summary, boundary: report.boundary, contentVersion: report.contentVersion, snapshotID: report.snapshotID, adapterVersion: report.adapterVersion, entries: report.entries + [entry])
        }
        let bad = original.evidence.map { NatalReadingReport.Evidence(pointer: $0.pointer, value: $0.value.replacingOccurrences(of: "伤官", with: "食神")) }
        XCTAssertThrowsError(try BaziLifeThemeCompiler.compile(report: altered(bad)))
        let good = try BaziLifeThemeCompiler.compile(report: report)
        // Duplicated identical evidence may be coalesced; conflicting values may not.
        XCTAssertEqual(good, try BaziLifeThemeCompiler.compile(report: altered(original.evidence)))
    }
    func testEditorialScenarioDoesNotMapHiddenStemsToGuessedDemandsOrBecomeUserHistory() async throws {
        var themes: [BaziLifeTheme] = []
        for sample in [samples[0], samples[1], samples[4]] {
            let (report, _, _) = try await facts(sample.1)
            themes.append(try BaziLifeThemeCompiler.compile(report: report))
        }
        XCTAssertFalse(themes[0].explanation.contains("把这点转成"))
        XCTAssertTrue(themes[0].explanation.contains("没有对应关系"))
        XCTAssertFalse(themes[1].observation.contains("未覆盖分支"))
        XCTAssertFalse(themes[1].observation.contains("不要"))
        XCTAssertTrue(themes[1].observation.contains("跳过"))
        XCTAssertEqual(Set(themes.map(\.example)).count, 1, "A generic scenario must not be disguised as personalized behavior inferred from the chart")
        for theme in themes {
            XCTAssertTrue(theme.example.contains("完全虚构，不是你的经历"))
            XCTAssertTrue(theme.example.contains("两页"))
            XCTAssertTrue(theme.example.contains("事实"))
            XCTAssertTrue(theme.example.contains("推测"))
            XCTAssertTrue(theme.example.contains("同一份本命结构"))
            XCTAssertTrue(theme.example.contains("不能把其中一种反应定为人格"))
        }
    }
}
