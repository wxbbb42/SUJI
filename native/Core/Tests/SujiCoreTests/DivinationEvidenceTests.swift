import XCTest
@testable import SujiCore

final class DivinationEvidenceTests: XCTestCase {
    private func history(_ name: String, _ raw: String) -> [ChatMessage] {
        [.assistantToolCalls([.init(id: "receipt", name: name, arguments: [:])]), .toolResult(.init(callID: "receipt", output: raw))]
    }

    func testOriginalChangedAndHiddenContextsHaveDistinctPointers() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"castGanZhi":{"month":"庚申","day":"甲子","hour":"甲子"},"lines":[{"position":1,"ganZhi":"丙午","wuXing":"火","dayCombination":false,"context":{"isVoid":false,"day":{"sameBranch":false}},"changed":{"ganZhi":"辛亥","context":{"isVoid":true,"month":{"elementRelation":"生爻"}}},"hidden":{"ganZhi":"甲寅","context":{"month":{"clash":true}}}}]}"#))
        let indexed = Dictionary(uniqueKeysWithValues: facts.map { ($0.factKey, $0) })
        XCTAssertEqual(indexed["liuyao.calendar.month"]?.value, .string("庚申"))
        XCTAssertEqual(indexed["liuyao.line1.context.isVoid"]?.value, .bool(false))
        XCTAssertEqual(indexed["liuyao.line1.changed.context.isVoid"]?.value, .bool(true))
        XCTAssertEqual(indexed["liuyao.line1.changed.context.isVoid"]?.pointer, "/lines/0/changed/context/isVoid")
        XCTAssertEqual(indexed["liuyao.line1.hidden.context.month.clash"]?.pointer, "/lines/0/hidden/context/month/clash")
        XCTAssertEqual(indexed["liuyao.line1.changed.context.month.elementRelation"]?.value, .string("生爻"))
        XCTAssertEqual(indexed["liuyao.line1.dayCombination"]?.value, .bool(false))
        XCTAssertNil(indexed["liuyao.line2.changed.context.isVoid"])
    }

    func testMethodsCandidateScopeAndSourceVersionAreCitable() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"method":{"algorithm":"jingfang-najia-v1","caveats":["初选"]},"yongShen":{"yaoIndex":2,"state":"囚","candidateYaoIndices":[2,4]},"ruleSources":[{"id":"liuyao-calendar-relations-v1","version":"1","editionStatus":"electronic-transcription-not-print-collated","references":[{"url":"https://zh.wikisource.org/wiki/增刪卜易/17","locator":"日辰章第十七"}]}]}"#))
        let indexed = Dictionary(uniqueKeysWithValues: facts.map { ($0.factKey, $0) })
        XCTAssertEqual(indexed["liuyao.method.algorithm"]?.value, .string("jingfang-najia-v1"))
        XCTAssertEqual(indexed["liuyao.yongShen.candidateYaoIndices"]?.value, .array([.integer(2), .integer(4)]))
        XCTAssertEqual(indexed["liuyao.ruleSource1.version"]?.value, .string("1"))
        XCTAssertEqual(indexed["liuyao.ruleSource1.reference1.locator"]?.pointer, "/ruleSources/0/references/0/locator")
    }

    func testQimenFactsUsePalaceIdentityAndPreserveHourScope() {
        let facts = ReadingVerificationEvidence.facts(history("setup_qimen", #"{"monthGanZhi":"丁酉","hourGanZhi":"甲午","hourVoid":{"scope":"hour","branches":["辰","巳"],"palaces":[{"palaceId":4,"branches":["辰","巳"],"coverage":"full"}]},"horse":{"scope":"hour","branch":"申","palaceId":2},"palaces":[{"id":6,"doorRelation":{"relation":"门克宫","isPressure":true}},{"id":2,"starSeason":{"star":"天芮","state":"旺"},"hostedStarSeason":{"star":"天禽","state":"旺"}}],"method":{"clockPolicy":"beijing-standard"}}"#))
        let indexed = Dictionary(uniqueKeysWithValues: facts.map { ($0.factKey, $0) })
        XCTAssertEqual(indexed["qimen.monthGanZhi"]?.value, .string("丁酉"))
        XCTAssertEqual(indexed["qimen.hourVoid.scope"]?.value, .string("hour"))
        XCTAssertEqual(indexed["qimen.hourVoid.palace4.coverage"]?.pointer, "/hourVoid/palaces/0/coverage")
        XCTAssertEqual(indexed["qimen.horse.branch"]?.value, .string("申"))
        XCTAssertEqual(indexed["qimen.palace6.doorRelation.isPressure"]?.pointer, "/palaces/0/doorRelation/isPressure")
        XCTAssertEqual(indexed["qimen.palace2.hostedStarSeason.star"]?.value, .string("天禽"))
        XCTAssertEqual(indexed["qimen.method.clockPolicy"]?.value, .string("beijing-standard"))
        XCTAssertNil(indexed["qimen.palace1.doorRelation.isPressure"])
    }

    func testLegacySparsePayloadDoesNotInventFactsAndIgnoresUnlistedInterpretation() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"lines":[{"ganZhi":"甲子","prediction":"必然成功"}],"inventedRule":"必中"}"#))
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.factKey, "liuyao.line1.ganZhi")
        XCTAssertEqual(facts.first?.value, .string("甲子"))
    }

    func testCombinedRealChartsAndEvidenceFitBackendContextLimits() async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try String(contentsOf: native.appendingPathComponent("Resources/mingli.js"), encoding: .utf8)
        let seeded = directory.appendingPathComponent("engine.js")
        // Test-only fair-coin sequence [6,9,9,9,9,9]: all-moving 姤, including a hidden line.
        try (script + "\nlet coinCalls=0; Math.random=()=>coinCalls++<3?0:0.75;").write(to: seeded, atomically: true, encoding: .utf8)
        let bridge = try MingliBridge(scriptURL: seeded)
        let now = Date(timeIntervalSince1970: 1_789_790_400)
        let question = "用六爻和奇门分别解释这次盘面，请保留各自依据。" + String(repeating: "需要比较盘面细节。", count: 120)
        var messages = [ChatMessage(role: .system, content: ReadingPrompt.instruction(tone: "清晰", mode: "起卦", referenceDate: now, hasBirth: true))]
        for (index, name) in ["cast_liuyao", "setup_qimen"].enumerated() {
            let id = String(repeating: index == 0 ? "a" : "b", count: 32)
            let request: [String: Any] = ["command": "tool", "name": name, "arguments": ["question": question, "questionType": "general"], "now": "2026-09-19T04:00:00Z"]
            let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            let root = try JSONDecoder().decode(JSONValue.self, from: raw)
            let output = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: root)))
            XCTAssertLessThanOrEqual(output.utf16.count, 32_000)
            messages.append(.assistantToolCalls([.init(id: id, name: name, arguments: ["question": .string(question)])]))
            messages.append(.toolResult(.init(callID: id, output: output)))
        }
        let review = ReadingVerifier.messages(draft: String(repeating: "本次仅列出盘面事实和条件。", count: 60), history: messages, question: question)
        let total = review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) + ($1.toolCalls ?? []).reduce(0) { $0 + ReadingVerificationEvidence.encoded($1.arguments).utf16.count } }
        XCTAssertLessThanOrEqual(total, 120_000, "Backend rejects a valid two-chart review when the fact index repeats too much metadata")
        XCTAssertLessThanOrEqual(review.count, 120)
        for message in review { XCTAssertLessThanOrEqual(message.content?.utf16.count ?? 0, 32_000) }
        print("Divination evidence capacity: \(total) UTF-16 code units, \(review.count) messages")
    }

    func testCompactIndexPreservesEveryFactAndItsToolIdentity() throws {
        let messages = history("cast_liuyao", #"{"castGanZhi":{"day":"甲子"},"lines":[{"context":{"isVoid":false},"changed":{"context":{"isVoid":true}}}]}"#)
        let facts = ReadingVerificationEvidence.facts(messages)
        let review = ReadingVerifier.messages(draft: "核对盘面", history: messages, question: "盘面事实")
        let index = try XCTUnwrap(review.first { $0.content?.hasPrefix("显式字段索引") == true }?.content)
        let raw = try XCTUnwrap(index.components(separatedBy: "\n").last)
        let envelope = try JSONDecoder().decode(JSONValue.self, from: Data(raw.utf8))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/toolCallID", in: envelope), .string("receipt"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/columns", in: envelope), .array([.string("factKey"), .string("pointer"), .string("value")]))
        for (index, fact) in facts.enumerated() {
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/facts/\(index)", in: envelope), .array([.string(fact.factKey), .string(fact.pointer), fact.value]))
        }
    }

    func testMalformedContextAndProvenanceCannotSmuggleObjectsIntoScalarFacts() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"lines":[{"context":{"isVoid":{"prediction":"必中"},"sourceIds":[{"prediction":"必中"}],"day":{"elementRelation":{"text":"生爻"}}}}],"ruleSources":[{"id":{"prediction":"必中"},"limitations":[["嵌套数组"]],"references":[{"quote":{"prediction":"必中"}}]}]}"#))
        XCTAssertTrue(facts.isEmpty)
    }
}
