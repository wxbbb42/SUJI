import XCTest
@testable import SujiCore

final class NatalReadingReportTests: XCTestCase {
    // Deliberately invented profiles; never copied from a user or reference screenshot.
    private let samples = [
        BirthProfile(year: 1988, month: 4, day: 9, hour: 6, minute: 20, gender: "女", city: "合成甲", longitude: 116.4),
        BirthProfile(year: 2001, month: 11, day: 22, hour: 23, minute: 40, gender: "男", city: "合成乙", longitude: 121.47)
    ]
    private var expectedPayloadRevision = ""
    private let revision = String(repeating: "a", count: 64)
    private var native: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func run(_ command: String, birth: BirthProfile) async throws -> Data {
        let bridge = try MingliBridge(scriptURL: native.appendingPathComponent("Resources/mingli.js"))
        let metadata = try await bridge.request(#"{"command":"metadata"}"#)
        expectedPayloadRevision = try XCTUnwrap((JSONSerialization.jsonObject(with: metadata) as? [String: Any])?["engineRevision"] as? String)
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(birth))
        let request = try JSONSerialization.data(withJSONObject: ["command": command, "birth": object], options: [.sortedKeys])
        return try await bridge.request(String(decoding: request, as: UTF8.self))
    }
    private func compile(_ data: Data, birth: BirthProfile) throws -> [NatalReadingReport] {
        try NatalReadingCompiler.natal(dossier: NatalDossier(ownerID: "synthetic", birth: birth, engineRevision: revision, payload: data), ownerID: "synthetic", birth: birth, engineRevision: revision, enginePayloadRevision: expectedPayloadRevision)
    }
    private func changed(_ data: Data, path: [String], value: Any?) throws -> Data {
        func change(_ original: Any, _ path: ArraySlice<String>) -> Any {
            guard let key = path.first else { return value ?? NSNull() }
            if var array = original as? [Any], let index = Int(key) {
                array[index] = change(array[index], path.dropFirst()); return array
            }
            var object = original as! [String: Any]
            if path.count == 1 { object[key] = value } else { object[key] = change(object[key]!, path.dropFirst()) }
            return object
        }
        return try JSONSerialization.data(withJSONObject: change(JSONSerialization.jsonObject(with: data), path[...]), options: [.sortedKeys])
    }
    private func resolve(_ pointer: String, in data: Data) throws -> Any {
        var node = try JSONSerialization.jsonObject(with: data)
        for token in pointer.split(separator: "/").map(String.init) {
            if let object = node as? [String: Any] { node = try XCTUnwrap(object[token]) }
            else if let array = node as? [Any], let index = Int(token), array.indices.contains(index) { node = array[index] }
            else { throw EngineContract.Failure.invalid }
        }
        return node
    }
    func testReadableModulesDistinguishSupportedBlockedAndUnresolvedLocalPaths() async throws {
        var summaries: [String] = []
        for (day, expected) in [(10, "仍有条件未定"), (20, "有一条局部配合可用"), (30, "这条配合受到牵制")] {
            let birth = BirthProfile(year: 1984, month: 9, day: day, hour: 17, minute: 30, gender: "男", city: "合成条件盘", longitude: 120)
            let data = try await run("natal", birth: birth)
            let report = try XCTUnwrap(compile(data, birth: birth).first)
            let modules = report.entries.filter { $0.id.hasPrefix("module.") }
            XCTAssertEqual(modules.map(\.id), ["module.day-month", "module.elements", "module.relations", "module.pattern", "module.methods"])
            let pattern = try XCTUnwrap(modules.first { $0.id == "module.pattern" })
            XCTAssertTrue(pattern.summary.contains(expected), pattern.summary)
            XCTAssertTrue(pattern.boundary.contains("不等于整格成败"))
            XCTAssertFalse(pattern.sources.isEmpty)
            for field in modules.flatMap(\.evidence) { _ = try resolve(field.pointer, in: data) }
            summaries.append(pattern.summary)
        }
        XCTAssertEqual(Set(summaries).count, 3, "Different efficacy must change the main reading, not just a footnote")
    }
    func testInvalidAdvancedRuleCannotContaminateOtherModulesOrHeadline() async throws {
        let birth = BirthProfile(year: 1984, month: 9, day: 20, hour: 17, minute: 30, gender: "男", city: "合成反例", longitude: 120)
        let data = try await run("natal", birth: birth)
        let baseline = try XCTUnwrap(compile(data, birth: birth).first)
        let invalid: [([String], Any?)] = [
            (["mingPan", "geJuV2", "rescueEvidence", "dependencyResolution", "actions", "0", "status"], "blocked"),
            (["mingPan", "geJuV2", "conditionalEvidence", "sources", "0", "sha256"], "unknown"),
            (["mingPan", "geJuV2", "conditionalEvidence", "selectedYong"], "正官"),
            (["mingPan", "geJuV2", "name"], "正官格"),
            (["mingPan", "geJuV2", "selectionBasis"], "future-selector"),
            (["mingPan", "geJuV2", "selectionBasis"], nil),
            (["mingPan", "geJuV2", "selectionBasis"], "yueling-benqi-tougan"),
            (["mingPan", "geJuV2"], nil)
        ]
        for (path, value) in invalid {
            let report = try XCTUnwrap(compile(changed(data, path: path, value: value), birth: birth).first)
            XCTAssertTrue(report.entries.first { $0.id == "module.pattern" }!.title.contains("暂不能确认"), path.joined(separator: "/"))
            XCTAssertFalse(report.summary.contains("局部配合可用"))
            for id in ["module.day-month", "module.elements", "module.relations"] {
                XCTAssertEqual(report.entries.first { $0.id == id }, baseline.entries.first { $0.id == id })
            }
            XCTAssertTrue(report.entries.first { $0.id == "module.methods" }!.summary.contains("格局模块尚未通过"))
        }
    }
    func testAbsentOptionalStrengthStructureDoesNotEraseOtherReports() async throws {
        let data = try await run("natal", birth: samples[0])
        let baseline = try compile(data, birth: samples[0])
        let reports = try compile(changed(data, path: ["mingPan", "riZhuStructure"], value: nil), birth: samples[0])
        XCTAssertEqual(reports.map(\.system), [.bazi, .ziwei])
        XCTAssertEqual(reports[1], baseline[1])
        for id in ["module.day-month", "module.elements", "module.relations", "module.pattern"] {
            XCTAssertEqual(reports[0].entries.first { $0.id == id }, baseline[0].entries.first { $0.id == id })
        }
        XCTAssertTrue(reports[0].entries.first { $0.id == "module.methods" }!.title.contains("暂待核对"))
    }
    func testCandidateReasonExplainsMiddleQiAndPeerNamesAreMonthBound() async throws {
        let middle = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "合成取格", longitude: 121.47)
        let middleData = try await run("natal", birth: middle)
        let pattern = try XCTUnwrap(compile(middleData, birth: middle).first?.entries.first { $0.id == "module.pattern" })
        XCTAssertTrue(pattern.explanation.contains("中气壬"), pattern.explanation)
        XCTAssertTrue(pattern.explanation.contains("时干"))
        XCTAssertFalse(pattern.explanation.contains("完整条件"))
        for (day, expected, incorrect) in [(24, "建禄格", "比肩结构（格局待辨）"), (23, "月刃格", "月劫格")] {
            let birth = BirthProfile(year: 1984, month: 9, day: day, hour: 17, minute: 30, gender: "男", city: "合成取格反例", longitude: 120)
            let data = try await run("natal", birth: birth)
            XCTAssertEqual(try resolve("/mingPan/geJuV2/name", in: data) as? String, expected)
            let report = try XCTUnwrap(compile(changed(data, path: ["mingPan", "geJuV2", "name"], value: incorrect), birth: birth).first)
            XCTAssertTrue(report.entries.first { $0.id == "module.pattern" }!.title.contains("暂不能确认"))
        }
    }
    func testReadableSyntheticSamplePackAndAdvancedCoverageRemainHonest() async throws {
        let conditional = [10, 20, 30].map { BirthProfile(year: 1984, month: 9, day: $0, hour: 17, minute: 30, gender: "男", city: "合成条件盘", longitude: 120) }
        let noPath = BirthProfile(year: 1995, month: 8, day: 15, hour: 19, minute: 30, gender: "女", city: "合成覆盖盘", longitude: 121.47)
        var prose = "# 本地模块报告：六份合成样稿\n\n全部资料为测试构造，不来自用户或竞品截图。B1/B2/B3/B5为结构与方法导读，B4只在审核的子集内给条件解释。这些样稿不代表完整个体报告或人口覆盖率。\n"
        for (index, birth) in (conditional + samples + [noPath]).enumerated() {
            let data = try await run("natal", birth: birth)
            let report = try XCTUnwrap(compile(data, birth: birth).first)
            let modules = report.entries.filter { $0.id.hasPrefix("module.") }
            XCTAssertEqual(modules.count, 5)
            XCTAssertEqual(report, try compile(data, birth: birth).first)
            prose += "\n## 合成样稿 \(index + 1)\n\n\(birth.label)；\(birth.gender)；经度 \(birth.longitude)。\n\n概览：\(report.summary)\n\n范围：\(report.boundary)\n"
            for m in modules {
                XCTAssertFalse(m.summary.isEmpty); XCTAssertFalse(m.boundary.isEmpty)
                prose += "\n### \(m.title)\n\n\(m.summary)\n\n\(m.explanation)\n\n适用范围：\(m.boundary)\n\n依据：\(m.sources.map(\.id).joined(separator: "、"))\n\n字段：\(m.evidence.map(\.pointer).joined(separator: "、"))\n"
            }
        }
        if let path = ProcessInfo.processInfo.environment["SUJI_MODULE_SAMPLES_OUTPUT"] {
            try prose.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
    func testRealEngineSamplesAreStableDetailedAndEveryEvidenceResolves() async throws {
        var reportsBySample: [[NatalReadingReport]] = []
        for (index,birth) in samples.enumerated() {
            let data = try await run("natal", birth: birth)
            let reports = try compile(data, birth: birth)
            XCTAssertEqual(reports.map(\.system), [.bazi, .ziwei])
            let repeated = try await run("natal", birth: birth)
            XCTAssertEqual(reports, try compile(repeated, birth: birth))
            XCTAssertGreaterThan(reports[0].entries.count, 12)
            XCTAssertEqual(reports[1].entries.filter { $0.id.hasPrefix("palace.") }.count, 12)
            XCTAssertFalse(reports[0].entries.contains { $0.id == "stem.day" })
            for report in reports {
                XCTAssertEqual(report.contentVersion, NatalReadingCompiler.contentVersion)
                for entry in report.entries {
                    XCTAssertFalse(entry.explanation.isEmpty); XCTAssertFalse(entry.boundary.isEmpty)
                    XCTAssertFalse(entry.sources.isEmpty); XCTAssertFalse(entry.evidence.isEmpty)
                    for evidence in entry.evidence {
                        let value = try resolve(evidence.pointer, in: data)
                        if let string = value as? String { XCTAssertEqual(evidence.value, string) }
                        else {
                            let expected = try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys, .withoutEscapingSlashes])
                            XCTAssertEqual(evidence.value, String(decoding: expected, as: UTF8.self))
                        }
                    }
                }
            }
            let polluted = try changed(data, path: ["personality", "coreTraits"], value: ["污染：发财能力爆表"])
            XCTAssertEqual(reports, try compile(polluted, birth: birth))
            reportsBySample.append(reports)
            if ProcessInfo.processInfo.environment["SUJI_WRITE_REPORT_SAMPLES"] == "1" {
                let directory = native.appendingPathComponent("artifacts/report-figma-2026-09-23")
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let reportSections: [String] = reports.map { report in
                    let heading = "## \(report.title)\n\(report.summary)\n\(report.boundary)\n"
                    let entries: [String] = report.entries.map { entry in
                        let details = "### \(entry.title)\n事实：\(entry.summary)\n结构/词义：\(entry.explanation)\n范围：\(entry.boundary)\n"
                        let reflection = entry.reflection.map { "编辑提问：\($0)\n" } ?? ""
                        let evidence = entry.evidence.map { "- `\($0.pointer)`：\($0.value)" }.joined(separator: "\n")
                        let sources = entry.sources.map { "来源：\($0.title) · \($0.locator) · \($0.note)" }.joined(separator: "\n")
                        return details + reflection + evidence + "\n" + sources
                    }
                    return heading + entries.joined(separator: "\n\n")
                }
                let prose = reportSections.joined(separator: "\n\n")
                try ("# 合成样稿 \(index + 1)\n明确合成、非用户资料。\(birth.label)；\(birth.gender)；经度\(birth.longitude)。\n内容版本：\(NatalReadingCompiler.contentVersion)\n\n" + prose).write(to: directory.appendingPathComponent("synthetic-sample-\(index + 1).md"), atomically: true, encoding: .utf8)
            }
        }
        XCTAssertNotEqual(reportsBySample[0][0].entries, reportsBySample[1][0].entries)
        XCTAssertNotEqual(reportsBySample[0][1].entries, reportsBySample[1][1].entries)
        let entries = reportsBySample.flatMap { $0[1].entries }
        XCTAssertTrue(entries.contains { $0.explanation.contains("没有十四主星") })
        XCTAssertTrue(entries.contains { $0.explanation.contains("同宫并列") })
    }
    func testRejectsScopeAndInternalBirthMismatch() async throws {
        let birth = samples[0], data = try await run("natal", birth: samples[0])
        let dossier = try NatalDossier(ownerID: "synthetic", birth: birth, engineRevision: revision, payload: data)
        XCTAssertThrowsError(try NatalReadingCompiler.natal(dossier: dossier, ownerID: "other", birth: birth, engineRevision: revision, enginePayloadRevision: expectedPayloadRevision))
        XCTAssertThrowsError(try NatalReadingCompiler.natal(dossier: dossier, ownerID: "synthetic", birth: birth, engineRevision: "different", enginePayloadRevision: expectedPayloadRevision))
        var different = birth; different.city = "另一个显示城市"
        XCTAssertThrowsError(try NatalReadingCompiler.natal(dossier: dossier, ownerID: "synthetic", birth: different, engineRevision: revision, enginePayloadRevision: expectedPayloadRevision))
        different = birth; different.minute += 1
        XCTAssertThrowsError(try compile(data, birth: different))
        for path in [["mingPan", "birthDateTime"], ["ziweiPan", "birthDateTime"], ["mingPan", "calculationPolicy", "civilBirthTime"]] {
            XCTAssertThrowsError(try compile(changed(data, path: path, value: "2000-01-01T00:00:00.000Z"), birth: birth))
        }
        for chart in ["mingPan", "ziweiPan"] {
            XCTAssertThrowsError(try compile(changed(data, path: [chart, "gender"], value: "男"), birth: birth))
        }
        XCTAssertThrowsError(try compile(changed(data, path: ["birthKey"], value: "[]"), birth: birth))
    }
    func testRejectsMissingUnknownAndSemanticallyAlteredNatalFields() async throws {
        let birth = samples[0], data = try await run("natal", birth: samples[0])
        let cases: [([String], Any?)] = [
            (["mingPan","siZhu","year","shiShen"], "陌生关系"),
            (["mingPan","siZhu","year","shiShen"], "正官"),
            (["mingPan","siZhu","year","cangGan"], []),
            (["mingPan","siZhu","year","cangGan","0","shiShen"], "比肩"),
            (["mingPan","siZhu","year","cangGan","0","weight"], 0),
            (["mingPan","riZhu","gan"], "癸"),
            (["ziweiPan","palaces","0","mainStars"], nil),
            (["ziweiPan","palaces","0","mainStars","0","brightness"], "未来亮度"),
            (["ziweiPan","palaces","0","mainStars","0","brightness"], nil),
            (["ziweiPan","palaces","0","mainStars","0","sihua"], ["化忌"]),
            (["ziweiPan","mingGongPosition"], "午"),
            (["ziweiPan","method","algorithm"], "future-method"),
            (["calendarPolicy","version"], "future-calendar")
        ]
        for (path,value) in cases { XCTAssertThrowsError(try compile(changed(data, path: path, value: value), birth: birth), path.joined(separator: "/")) }
    }
    func testAstronomyUsesActualMansionAndRulerChainAndRejectsFutureMethods() async throws {
        let birth = samples[0], data = try await run("natal-astronomy", birth: samples[0])
        let payload = try NatalAstronomyPayload.validated(data)
        let dossier = try NatalAstronomyDossier(ownerID: "synthetic", birth: birth, engineRevision: revision, enginePayloadRevision: payload.engineRevision, payload: data)
        let reports = try NatalReadingCompiler.astronomy(dossier: dossier, ownerID: "synthetic", birth: birth, engineRevision: revision, enginePayloadRevision: payload.engineRevision)
        XCTAssertEqual(reports.map(\.system), [.mansions, .qizheng])
        XCTAssertTrue(reports[1].entries.contains { $0.summary.contains("宫主") && $0.summary.contains("度主") })
        for report in reports { for entry in report.entries { for evidence in entry.evidence { _ = try resolve(evidence.pointer, in: data) } } }
        XCTAssertThrowsError(try NatalReadingCompiler.astronomy(dossier: dossier, ownerID: "other", birth: birth, engineRevision: revision, enginePayloadRevision: payload.engineRevision))
        XCTAssertThrowsError(try NatalReadingCompiler.astronomy(dossier: dossier, ownerID: "synthetic", birth: birth, engineRevision: revision, enginePayloadRevision: String(repeating: "b", count: 64)))
        for module in ["sevenBodies", "mansions", "fourResiduals", "lifeDegree"] {
            let altered = try changed(data, path: [module,"methodVersion"], value: "future")
            XCTAssertThrowsError(try NatalAstronomyDossier(ownerID: "synthetic", birth: birth, engineRevision: revision, enginePayloadRevision: payload.engineRevision, payload: altered))
        }
    }
    func testInnerCalendarPolicyCannotDisagreeWithSupportedOuterPolicy() async throws {
        let data = try await run("natal", birth: samples[0])
        for (key,value) in [("timezone","UTC"),("monthBoundary","future-month"),("provider","future-provider")] {
            XCTAssertThrowsError(try compile(changed(data, path: ["mingPan","calculationPolicy",key], value: value), birth: samples[0]))
        }
    }
    func testUncataloguedStarsRemainFactsWithExplicitReadingLimit() async throws {
        let data = try await run("natal", birth: samples[0])
        let original = try resolve("/ziweiPan/palaces/0/minorStars", in: data) as! [[String:Any]]
        let altered = try changed(data, path: ["ziweiPan","palaces","0","minorStars"], value: original + [["name":"合成未知辅星","type":"other","source":"minor"]])
        let reports = try compile(altered, birth: samples[0])
        let palace = try XCTUnwrap(reports[1].entries.first { $0.id == "palace.福德宫" })
        XCTAssertTrue(palace.evidence.contains { $0.value.contains("合成未知辅星") })
        XCTAssertTrue(palace.boundary.contains("辅杂曜") && palace.boundary.contains("未逐星解读"))
    }
    func testUnknownMainStarDoesNotBecomeFourteenStarCombinationOrEmptyPalace() async throws {
        let data = try await run("natal", birth: samples[0])
        let original = try resolve("/ziweiPan/palaces/0/mainStars", in: data) as! [[String:Any]]
        let altered = try changed(data, path: ["ziweiPan","palaces","0","mainStars"], value: original + [["name":"合成未知主星","brightness":"平","type":"major","source":"major"]])
        let palace = try XCTUnwrap(compile(altered, birth: samples[0])[1].entries.first { $0.id == "palace.福德宫" })
        XCTAssertTrue(palace.explanation.contains("未收录"))
        XCTAssertTrue(palace.explanation.contains("不判定空宫、单星或同宫组合"))
        XCTAssertFalse(palace.explanation.contains("同宫并列"))
        XCTAssertTrue(palace.evidence.contains { $0.value.contains("合成未知主星") })
    }
    func testRejectsPlausibleButUntrustedInnerEngineRevision() async throws {
        let data = try await run("natal", birth: samples[0])
        let altered = try changed(data, path: ["engineRevision"], value: String(repeating: "f", count: 64))
        XCTAssertThrowsError(try compile(altered, birth: samples[0]), "A plausible digest is not the bundled engine's trusted metadata revision")
    }
    func testBirthKeyRequiresTypedNumbersRatherThanCoercingBooleanToOne() async throws {
        let birth = BirthProfile(year: 1999, month: 1, day: 1, hour: 1, minute: 1, gender: "女", city: "合成类型反例", longitude: 116.4)
        let data = try await run("natal", birth: birth)
        let invalidKey = "[1999,1,1,1,true,\"女\",116.4,\"Asia/Shanghai\"]"
        XCTAssertThrowsError(try compile(changed(data, path: ["birthKey"], value: invalidKey), birth: birth))
    }
}
