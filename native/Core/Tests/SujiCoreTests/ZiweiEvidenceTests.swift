import XCTest
@testable import SujiCore

final class ZiweiEvidenceTests: XCTestCase {
    func testRealNatalAndTimingToolsFitLiveAndReplayBudgets() async throws {
        try await assertNatalAndTimingDelivery(birth:["year":2023,"month":1,"day":22,"hour":0,"minute":0,"gender":"男","longitude":120],palaces:["命宫","福德宫"])
    }
    func testLargePalaceFlightReadingLeavesRoomForQuestionAndDraft() async throws {
        try await assertNatalAndTimingDelivery(birth:["year":1986,"month":8,"day":15,"hour":14,"minute":30,"gender":"女","longitude":120],palaces:["夫妻宫","父母宫"],draft:String(repeating:"这个关系只记录宫干和星曜落宫，不推定现实事件。",count:80),question:String(repeating:"核对来源和落宫。",count:200))
    }
    func testRelatedPalaceFlightReadingLeavesRoomForFullContext() async throws {
        for gender in ["男","女"] {
            try await assertNatalAndTimingDelivery(birth:["year":1989,"month":8,"day":15,"hour":7,"minute":30,"gender":gender,"longitude":120],palaces:["财帛宫","命宫"],draft:String(repeating:"这个关系只记录宫干和星曜落宫，不推定现实事件。",count:80),question:String(repeating:"核对来源和落宫。",count:200))
        }
    }
    private func assertNatalAndTimingDelivery(birth:[String:Any],palaces:[String],draft:String="核对时间层",question:String="核对本命和2025年紫微时间层") async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let request = try JSONSerialization.data(withJSONObject:["command":"natal","birth":birth])
        let natalData = try await bridge.request(String(decoding:request,as:UTF8.self))
        let natal = try JSONSerialization.jsonObject(with:natalData)
        let callArguments: [(String,[String:JSONValue])] = [("get_domain",["domain":"事业"]),("get_domain",["domain":"婚姻"]),("get_ziwei_palace",["palace":.string(palaces[0]),"withPalaceFlights":true]),("get_ziwei_palace",["palace":.string(palaces[1]),"withPalaceFlights":true]),("get_ziwei_timing",["date":"2025-01-29"])]
        let calls = callArguments.enumerated().map { ChatToolCall(id:"call_" + String(repeating:"z",count:23) + String($0.offset),name:$0.element.0,arguments:.object($0.element.1)) }
        var outputs: [String:String] = [:]
        for call in calls {
            let arguments = try JSONSerialization.jsonObject(with:JSONEncoder().encode(call.arguments))
            let request: [String:Any] = ["command":"tool","name":call.name,"birth":birth,"natal":natal,"now":"2025-01-29T04:00:00Z","arguments":arguments]
            let data = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:request),as:UTF8.self))
            let envelope = try JSONDecoder().decode(JSONValue.self,from:data)
            outputs[call.id] = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope)))
        }
        let definitions = Set(calls.map(\.name)).map { ChatToolDefinition(name:$0,description:$0,parameters:["type":"object","properties":["date":["type":"string"],"palace":["type":"string"],"domain":["type":"string"]]]) }
        var round = 0
        let orchestrator = ToolOrchestrator(complete:{ _,_ in round += 1; return round == 1 ? .toolCalls(calls) : .text("ready") },execute:{ call in .init(output:outputs[call.id]!,evidence:[call.id]) })
        let context = try ToolContext(birth:nil,engineRevision:"fixture",referenceDate:Date(timeIntervalSince1970:1_738_123_200),mode:"命理")
        let result = try await orchestrator.run(history:[],definitions:definitions,context:context)
        let toolMessages = result.messages.filter { $0.role == .tool }
        XCTAssertEqual(result.receipts.count,5)
        XCTAssertEqual(toolMessages.count,5)
        for message in toolMessages { XCTAssertFalse(message.content?.contains("\"error\"") == true) }
        var entry = ConversationEntry(role:"user",text:question)
        entry.toolReceipts = result.receipts
        let restored = [ChatMessage(role:.system,content:ReadingPrompt.instruction(tone:"温和",mode:"命理",referenceDate:context.referenceDate,hasBirth:true)+"\n"+ReadingPrompt.writer)] + ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
        XCTAssertEqual(restored.filter { $0.role == .tool }.map(\.content),toolMessages.map(\.content))
        let facts = ReadingVerificationEvidence.facts(restored)
        if palaces[0] == "命宫" { XCTAssertEqual(facts.first { $0.factKey == "ziwei.palaceFlights.incoming" }?.value,.array([])) }
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.palaceFlights.outgoing1.scope" }?.value,.string("natal-palace-stem"))
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.timing.annual.ganZhi" }?.value,.string("乙巳"))
        if palaces[0] == "命宫" { XCTAssertEqual(facts.first { $0.factKey == "ziwei.timing.natalYear.ganZhi" }?.value,.string("癸卯")) }
        let review = ReadingVerifier.messages(draft:draft,history:restored,question:entry.text)
        let contentSize = review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) }
        let argumentSize = calls.reduce(0) { $0 + ReadingVerificationEvidence.encoded($1.arguments).utf16.count }
        XCTAssertLessThanOrEqual(contentSize + argumentSize,120_000)
        XCTAssertLessThan(try JSONEncoder().encode(review).count + 1024,262_144)
        print("Ziwei temporal delivery: \(toolMessages.reduce(0) { $0 + ($1.content?.utf8.count ?? 0) }) bytes")
    }

    func testPalaceFlightsIndexEachDirectedIdentityAndPreserveEmptyAndFalse() throws {
        let output = #"{"palace":"福德宫","position":"辰","palaceFlights":{"status":"available","scope":"natal-palace-stem","assessmentStatus":"structural-only","sourceId":"ziwei-palace-flights-selected-v1","outgoing":[{"scope":"natal-palace-stem","sourcePalace":"福德宫","sourcePosition":"辰","sourceStem":"丙","star":"文昌","transformation":"化科","targetPalace":"财帛宫","targetPosition":"戌","isSelf":false,"sourceId":"ziwei-palace-flights-selected-v1"}],"incoming":[]},"ruleSources":[{"id":"ziwei-palace-flights-selected-v1","version":"1","editionStatus":"pinned-engineering-reference"}]}"#
        for (base,name,text) in [("","get_ziwei_palace",output),("/ziwei","get_domain","{\"ziwei\":"+output+"}")] {
            let facts = ReadingVerificationEvidence.facts(history(text,name:name))
            let edge = "ziwei.palaceFlights.outgoing1."
            XCTAssertEqual(facts.first { $0.factKey == edge+"sourcePalace" }?.value,"福德宫")
            XCTAssertEqual(facts.first { $0.factKey == edge+"targetPalace" }?.value,"财帛宫")
            XCTAssertEqual(facts.first { $0.factKey == edge+"targetPosition" }?.pointer,base+"/palaceFlights/outgoing/0/targetPosition")
            XCTAssertEqual(facts.first { $0.factKey == edge+"isSelf" }?.value,.bool(false))
            XCTAssertEqual(facts.first { $0.factKey == "ziwei.palaceFlights.incoming" }?.value,.array([]))
            let star = try XCTUnwrap(facts.first { $0.factKey == edge+"star" })
            for sentence in ["本命财帛宫文昌生年化科","流年福德宫文昌化科","大限财帛宫文昌化科"] {
                XCTAssertFalse(ReadingVerificationAssertions.binds("文昌",to:star,in:sentence))
            }
        }
    }

    func testUnavailableAndMalformedPalaceFlightsDoNotBecomeInventedStarFacts() {
        let absent = ReadingVerificationEvidence.facts(history(#"{"palace":"命宫","palaceFlights":{"status":"unavailable","reason":"natal-flight-cache-missing"}}"#))
        XCTAssertEqual(absent.first { $0.factKey == "ziwei.palaceFlights.status" }?.value,"unavailable")
        XCTAssertFalse(absent.contains { $0.factKey.contains("outgoing") })
        let malformed = ReadingVerificationEvidence.facts(history(#"{"palace":"命宫","palaceFlights":{"outgoing":[{"star":{"prediction":"一定成功"}}],"incoming":[]}}"#))
        XCTAssertFalse(malformed.contains { $0.factKey.hasSuffix(".star") })
    }
    func testTimingKeepsAnnualDecadalAndNatalIdentitiesSeparate() {
        let output = #"{"referenceDate":"2025-01-29T04:00:00.000Z","referenceMode":"explicit-date-noon","nominalAge":3,"status":"active","natalYear":{"lunarYear":2023,"ganZhi":"癸卯"},"activeDecade":{"index":1,"palace":"命宫","ganZhi":"甲寅","startAge":2,"endAge":11},"annual":{"lunarYear":2025,"ganZhi":"乙巳","appliesToBirth":true,"taiSui":{"position":"巳","natalPalace":"田宅宫"},"transformations":[{"scope":"annual-year-stem","sourceStem":"乙","star":"太阴","transformation":"化忌","targetPalace":"福德宫","targetPosition":"辰","sourceId":"ziwei-timing-selected-v1"}]},"decadalTransformations":[{"scope":"decadal-palace-stem","sourceStem":"甲","star":"太阳","transformation":"化忌","targetPalace":"官禄宫"}],"method":{"ageConvention":"lunar-nominal","yearBoundary":"lunar-new-year"},"ruleSources":[{"id":"ziwei-timing-selected-v1","version":"1"}]}"#
        let facts = Dictionary(uniqueKeysWithValues: ReadingVerificationEvidence.facts(history(output,name:"get_ziwei_timing")).map { ($0.factKey,$0) })
        XCTAssertTrue(ToolOrchestrator.allowedToolNames.contains("get_ziwei_timing"))
        XCTAssertEqual(facts["ziwei.timing.nominalAge"]?.value,.integer(3))
        XCTAssertEqual(facts["ziwei.timing.natalYear.ganZhi"]?.value,.string("癸卯"))
        XCTAssertEqual(facts["ziwei.timing.annual.ganZhi"]?.value,.string("乙巳"))
        XCTAssertEqual(facts["ziwei.timing.activeDecade.ganZhi"]?.value,.string("甲寅"))
        XCTAssertEqual(facts["ziwei.timing.annual.transformation1.scope"]?.pointer,"/annual/transformations/0/scope")
        XCTAssertEqual(facts["ziwei.timing.decadal.transformation1.sourceStem"]?.pointer,"/decadalTransformations/0/sourceStem")
        XCTAssertEqual(facts["ziwei.timing.method.ageConvention"]?.value,.string("lunar-nominal"))
        XCTAssertEqual(facts["ziwei.timing.ruleSource1.version"]?.value,.string("1"))
        XCTAssertFalse(facts.contains { $0.key == "ziwei.福德宫.sihua" })
    }
    private let raw = #"{"palace":"命宫","position":"戌","ganZhi":"丙戌","mainStars":[],"isShenGong":false,"emptyMainPalace":true,"relatedPalaces":[{"relation":"opposite","palace":"迁移宫","position":"辰","mainStars":["天机","天梁"],"starDetails":[{"name":"天机","group":"main","brightness":"利","sihua":["化禄"]}],"natalTransformations":[{"scope":"natal-year-stem","sourceStem":"乙","star":"天机","transformation":"化禄","targetPalace":"迁移宫","targetPosition":"辰","sourceId":"ziwei-sihua-selected-v1"}]}],"emptyPalaceReference":{"status":"opposite-reference","sourcePalace":"迁移宫","sourcePosition":"辰","mainStars":["天机","天梁"]},"natalYear":{"lunarYear":1995,"ganZhi":"乙亥","stem":"乙"},"method":{"calculationDate":"1995-08-15","dayBoundary":"zi-hour"},"ruleSources":[{"id":"ziwei-sihua-selected-v1","version":"1","limitations":["壬年异文"]}]}"#
    private func history(_ output: String, name: String = "get_ziwei_palace") -> [ChatMessage] {
        [.assistantToolCalls([.init(id:"z", name:name, arguments:[:])]), .toolResult(.init(callID:"z", output:output))]
    }
    func testPalaceIdentityScopesStarsAndTransformations() {
        let facts = Dictionary(uniqueKeysWithValues: ReadingVerificationEvidence.facts(history(raw)).map { ($0.factKey,$0) })
        XCTAssertEqual(facts["ziwei.命宫.mainStars"]?.value, .array([]))
        XCTAssertEqual(facts["ziwei.命宫.isShenGong"]?.value, .bool(false))
        XCTAssertEqual(facts["ziwei.迁移宫.mainStars"]?.pointer, "/relatedPalaces/0/mainStars")
        XCTAssertEqual(facts["ziwei.迁移宫.star1.brightness"]?.value, .string("利"))
        XCTAssertEqual(facts["ziwei.迁移宫.transformation1.scope"]?.value, .string("natal-year-stem"))
        XCTAssertEqual(facts["ziwei.迁移宫.transformation1.targetPosition"]?.pointer, "/relatedPalaces/0/natalTransformations/0/targetPosition")
        XCTAssertEqual(facts["ziwei.emptyPalaceReference.sourcePalace"]?.value, .string("迁移宫"))
        XCTAssertEqual(facts["ziwei.natalYear.stem"]?.value, .string("乙"))
        XCTAssertEqual(facts["ziwei.method.calculationDate"]?.value, .string("1995-08-15"))
        XCTAssertEqual(facts["ziwei.ruleSource1.version"]?.value, .string("1"))
    }
    func testAggregatedDomainKeepsNestedPointers() {
        let facts = ReadingVerificationEvidence.facts(history("{\"ziwei\":" + raw + "}", name:"get_domain"))
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.迁移宫.star1.name" }?.pointer, "/ziwei/relatedPalaces/0/starDetails/0/name")
        XCTAssertEqual(facts.first { $0.factKey == "ziwei.ruleSource1.version" }?.pointer, "/ziwei/ruleSources/0/version")
    }
    func testOnlyNamedPalaceAssertionsBindToTheirOwnPalace() throws {
        let facts = ReadingVerificationEvidence.facts(history(raw))
        let ming = try XCTUnwrap(facts.first { $0.factKey == "ziwei.命宫.mainStars" })
        let opposite = try XCTUnwrap(facts.first { $0.factKey == "ziwei.迁移宫.mainStars" })
        XCTAssertTrue(ReadingVerificationAssertions.binds("天机", to:ming, in:"本命命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:opposite, in:"本命命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"命宫的对宫迁移宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"流年命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"如果命宫主星为天机"))
        XCTAssertFalse(ReadingVerificationAssertions.binds("天机", to:ming, in:"命宫主星不是天机"))
    }
    func testMalformedObjectValuesAreNotAdmittedAsStarFacts() {
        let facts = ReadingVerificationEvidence.facts(history(#"{"palace":"命宫","mainStars":[{"name":"假星"}],"starDetails":[{"name":{"prediction":"必定成功"}}],"relatedPalaces":[{"palace":"伪宫","mainStars":["假星"]}]}"#))
        XCTAssertFalse(facts.contains { $0.factKey.hasSuffix("mainStars") || $0.factKey.hasSuffix("star1.name") })
    }
}
