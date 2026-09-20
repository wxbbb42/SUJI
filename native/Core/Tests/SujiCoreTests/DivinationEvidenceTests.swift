import XCTest
@testable import SujiCore

final class DivinationEvidenceTests: XCTestCase {
    func testQuestionObjectAndTimingIndexPreservesCandidatesAndUnresolvedPremises() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"questionContext":{"subject":"parent","event":"untrusted narrative","timeHorizon":"near"},"yongShen":{"selectionStatus":"candidates-only","selectedCandidateId":null,"missingContext":["event"],"candidates":[{"id":"hidden-2","layer":"hidden","position":2,"objectPath":"/lines/1/hidden","contextPath":"/lines/1/hidden/context","reason":"absent-visible-pure-palace-role"}],"excluded":[{"objectPath":"/lines/0","reason":"different-role"}]},"yingQi":{"assessmentStatus":"conditional-triggers-only","outcomeEstablished":false,"unresolved":["selected-object"],"branchesByCandidate":[{"candidateId":"hidden-2","objectPath":"/lines/1/hidden","unresolved":["hidden-emergence"],"rules":[{"id":"void-fill-clash","branches":["寅","申"],"factPaths":["/lines/1/hidden/context/isVoid"]}]}]}}"#))
        let indexed = Dictionary(uniqueKeysWithValues:facts.map { ($0.factKey,$0) })
        XCTAssertEqual(indexed["liuyao.question.subject"]?.value,.string("parent"))
        XCTAssertNil(indexed["liuyao.question.event"])
        XCTAssertEqual(indexed["liuyao.yongShen.selectionStatus"]?.value,.string("candidates-only"))
        XCTAssertEqual(indexed["liuyao.yongShen.candidate1.objectPath"]?.value,.string("/lines/1/hidden"))
        XCTAssertEqual(indexed["liuyao.yongShen.excluded1.reason"]?.pointer,"/yongShen/excluded/0/reason")
        XCTAssertEqual(indexed["liuyao.timing.outcomeEstablished"]?.value,.bool(false))
        XCTAssertEqual(indexed["liuyao.timing.candidate1.unresolved"]?.value,.array([.string("hidden-emergence")]))
        XCTAssertEqual(indexed["liuyao.timing.candidate1.rule1.branches"]?.pointer,"/yingQi/branchesByCandidate/0/rules/0/branches")
        XCTAssertEqual(indexed["liuyao.timing.candidate1.rule1.factPaths"]?.value,.array([.string("/lines/1/hidden/context/isVoid")]))
    }

    func testConditionalRelationsKeepDirectionsStatesAndNoVerdict() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"lines":[{"rules":{"returning":{"relation":"回头克","from":"/lines/0/changed","to":"/lines/0","assessmentStatus":"structural-relation","sourceId":"liuyao-changing-relations-v1","conditions":[{"id":"changed-void","state":"not-matched","factPaths":["/lines/0/changed/context/isVoid"]},{"id":"combined-effectiveness","state":"unresolved","factPaths":[]}]},"dayClash":{"kind":"static-day-clash","candidates":["暗动","日破"],"voidClash":false,"conditions":[{"id":"day-support","state":"matched","factPaths":["/lines/0/context/day/elementRelation"]}]}}}]}"#))
        let indexed = Dictionary(uniqueKeysWithValues:facts.map { ($0.factKey,$0) })
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.relation"]?.value,.string("回头克"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.from"]?.value,.string("/lines/0/changed"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.condition.changed-void"]?.value,.string("not-matched"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.condition.combined-effectiveness"]?.pointer,"/lines/0/rules/returning/conditions/1/state")
        XCTAssertEqual(indexed["liuyao.line1.rules.dayClash.candidates"]?.value,.array([.string("暗动"),.string("日破")]))
        XCTAssertEqual(indexed["liuyao.line1.rules.dayClash.voidClash"]?.value,.bool(false))
        XCTAssertEqual(indexed["liuyao.line1.rules.dayClash.condition.day-support"]?.value,.string("matched"))
        XCTAssertFalse(facts.contains { $0.factKey.hasSuffix("verdict") })
    }
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
        for values in [[6,9,9,9,9,9], [9,9,9,6,6,9]] { try await assertCombinedCharts(values:values) }
        try await assertCombinedCharts(values:[9,6,6,6,6,9],questionType:"wealth",subject:"self")
        try await assertCombinedCharts(values:[9,9,9,6,6,9],questionType:"kids",subject:"child")
    }

    func testRepeatedStableChartIndicesFitMessageLimit() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let raw = try await bridge.request(#"{"command":"tool","name":"setup_qimen","arguments":{"question":"核对本次奇门盘","questionType":"general"},"now":"2026-09-19T04:00:00Z"}"#)
        let root = try JSONDecoder().decode(JSONValue.self,from:raw)
        let output = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:root)))
        XCTAssertLessThanOrEqual(output.utf8.count * 4,ToolOrchestrator.outputByteLimit)
        var messages = [ChatMessage(role:.system,content:ReadingPrompt.instruction(tone:"清晰",mode:"起卦",referenceDate:Date(timeIntervalSince1970:1_789_790_400),hasBirth:false))]
        for index in 0..<4 {
            messages.append(.assistantToolCalls([.init(id:"cached_qimen_\(index)",name:"setup_qimen",arguments:["question":"核对本次奇门盘"])]))
            messages.append(.toolResult(.init(callID:"cached_qimen_\(index)",output:output)))
        }
        let review = ReadingVerifier.messages(draft:"本次只核对盘面。",history:messages,question:"核对本次奇门盘")
        XCTAssertLessThanOrEqual(review.count,120)
        XCTAssertLessThanOrEqual(review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) },120_000)
        XCTAssertLessThan(try JSONEncoder().encode(review).count + 1024,262_144)
        for message in review { XCTAssertLessThanOrEqual(message.content?.utf16.count ?? 0,32_000) }
        try assertIndexRestoresFacts(review:review,history:messages)
    }

    private func assertCombinedCharts(values: [Int],questionType:String = "parents",subject:String = "parent") async throws {
        let native = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let script = try String(contentsOf: native.appendingPathComponent("Resources/mingli.js"), encoding: .utf8)
        let seeded = directory.appendingPathComponent("engine.js")
        // Test-only coins: 姤 and maximum-size all-moving 大畜 (two hidden lines).
        let draws = values.flatMap { value in Array(repeating:value == 6 ? 0.0 : 0.75,count:3) }
        try (script + "\nlet coinCalls=0; const draws=" + ReadingVerificationEvidence.encoded(draws) + "; Math.random=()=>draws[coinCalls++];").write(to: seeded, atomically: true, encoding: .utf8)
        let bridge = try MingliBridge(scriptURL: seeded)
        let now = Date(timeIntervalSince1970: 1_789_790_400)
        let question = String(("用六爻和奇门分别解释这次盘面，请保留各自依据。" + String(repeating: "需要比较盘面细节。", count: 180)).prefix(1600))
        var messages = [ChatMessage(role: .system, content: ReadingPrompt.instruction(tone: "清晰", mode: "起卦", referenceDate: now, hasBirth: true))]
        for (index, name) in ["cast_liuyao", "setup_qimen"].enumerated() {
            let id = String(repeating: index == 0 ? "a" : "b", count: 32)
            let arguments = name == "cast_liuyao" ? ["question": question, "questionType": questionType, "subject": subject, "event": String(repeating:"事",count:200), "timeHorizon": "near"] : ["question": question, "questionType": "general"]
            let request: [String: Any] = ["command": "tool", "name": name, "arguments": arguments, "now": "2026-09-19T04:00:00Z"]
            let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            let root = try JSONDecoder().decode(JSONValue.self, from: raw)
            let output = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: root)))
            XCTAssertLessThanOrEqual(output.utf16.count, 32_000)
            messages.append(.assistantToolCalls([.init(id: id, name: name, arguments: .object(arguments.mapValues(JSONValue.string)))]))
            messages.append(.toolResult(.init(callID: id, output: output)))
        }
        let calls = messages.flatMap { $0.toolCalls ?? [] }
        let expectedOutputs = messages.filter { $0.role == .tool }.map { $0.content! }
        let outputs = Dictionary(uniqueKeysWithValues:zip(calls.map(\.id),expectedOutputs))
        let definitions = calls.map { ChatToolDefinition(name:$0.name,description:$0.name,parameters:["type":"object","properties":["question":["type":"string"]],"required":["question"]]) }
        var round = 0
        let context = try ToolContext(birth:nil,engineRevision:"conditional-rules-test",referenceDate:now,mode:"起卦")
        let orchestrator = ToolOrchestrator(complete:{ _,_ in round += 1; return round == 1 ? .toolCalls(calls) : .text("ready") },execute:{ call in .init(output:outputs[call.id]!,evidence:[call.id]) })
        let delivery = try await orchestrator.run(history:Array(messages.prefix(1)),definitions:definitions,context:context)
        XCTAssertEqual(delivery.receipts.map(\.output),expectedOutputs)
        XCTAssertEqual(delivery.messages.filter { $0.role == .tool }.map(\.content),expectedOutputs)
        var entry = ConversationEntry(role:"user",text:question)
        entry.toolReceipts = delivery.receipts
        let replay = ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
        XCTAssertEqual(replay.filter { $0.role == .tool }.map(\.content),expectedOutputs)
        let retry = ToolOrchestrator(complete:{ _,_ in .text("ready") },execute:{ _ in XCTFail("Retry must retain the original casts"); return .init(output:"{}") })
        let retried = try await retry.run(history:replay,definitions:definitions,cachedReceipts:delivery.receipts,context:context)
        XCTAssertEqual(retried.evidence,calls.map(\.id))
        let review = ReadingVerifier.messages(draft: String(repeating: "本次仅列出盘面事实和条件。", count: 60), history: messages, question: question)
        try assertIndexRestoresFacts(review:review,history:messages)
        let total = review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) + ($1.toolCalls ?? []).reduce(0) { $0 + ReadingVerificationEvidence.encoded($1.arguments).utf16.count } }
        XCTAssertLessThanOrEqual(total, 120_000, "Backend rejects a valid two-chart review when the fact index repeats too much metadata")
        XCTAssertLessThanOrEqual(review.count, 120)
        XCTAssertLessThan(try JSONEncoder().encode(review).count + 1024,262_144)
        for message in review { XCTAssertLessThanOrEqual(message.content?.utf16.count ?? 0, 32_000) }
        print("Divination evidence capacity: \(total) UTF-16 code units, \(review.count) messages, casts \(expectedOutputs.reduce(0) { $0 + $1.utf8.count }) bytes")
    }

    func testCompactIndexPreservesEveryFactAndItsToolIdentity() throws {
        let messages = history("cast_liuyao", #"{"castGanZhi":{"day":"甲子"},"lines":[{"context":{"isVoid":false},"changed":{"context":{"isVoid":true}}}]}"#)
        let review = ReadingVerifier.messages(draft: "核对盘面", history: messages, question: "盘面事实")
        try assertIndexRestoresFacts(review:review,history:messages)
    }

    private func assertIndexRestoresFacts(review: [ChatMessage], history: [ChatMessage]) throws {
        let facts = ReadingVerificationEvidence.facts(history)
        var restored: [String:JSONValue] = [:]
        for message in review where message.content?.hasPrefix("显式字段索引") == true {
            let raw = try XCTUnwrap(message.content?.components(separatedBy:"\n").last)
            let envelope = try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/columns",in:envelope),.array([.string("factKeySuffix"),.string("pointerSuffix"),.string("value")]))
            guard case let .array(groups) = ReadingVerificationEvidence.pointer("/groups",in:envelope) else { return XCTFail("Missing index groups") }
            for group in groups {
                guard case let .string(id) = ReadingVerificationEvidence.pointer("/toolCallID",in:group),
                      case let .string(keyPrefix) = ReadingVerificationEvidence.pointer("/factKeyPrefix",in:group),
                      case let .string(pathPrefix) = ReadingVerificationEvidence.pointer("/pointerPrefix",in:group),
                      case let .array(rows) = ReadingVerificationEvidence.pointer("/facts",in:group) else { return XCTFail("Missing lossless prefixes") }
                for row in rows {
                    guard case let .array(values) = row, values.count == 3,
                          case let .string(key) = values[0] else { return XCTFail("Malformed fact row") }
                    let path: String
                    if values[1] == .null { path = key.replacingOccurrences(of:".",with:"/") }
                    else if case let .string(explicit) = values[1] { path = explicit }
                    else { return XCTFail("Malformed pointer suffix") }
                    XCTAssertNil(restored[id + ":" + keyPrefix + key])
                    restored[id + ":" + keyPrefix + key] = .array([.string(pathPrefix + path),values[2]])
                }
            }
        }
        XCTAssertEqual(restored.count,facts.count)
        for fact in facts { XCTAssertEqual(restored[fact.toolCallID + ":" + fact.factKey],.array([.string(fact.pointer),fact.value])) }
    }

    func testMalformedContextAndProvenanceCannotSmuggleObjectsIntoScalarFacts() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"lines":[{"context":{"isVoid":{"prediction":"必中"},"sourceIds":[{"prediction":"必中"}],"day":{"elementRelation":{"text":"生爻"}}}}],"ruleSources":[{"id":{"prediction":"必中"},"limitations":[["嵌套数组"]],"references":[{"quote":{"prediction":"必中"}}]}]}"#))
        XCTAssertTrue(facts.isEmpty)
    }
}
