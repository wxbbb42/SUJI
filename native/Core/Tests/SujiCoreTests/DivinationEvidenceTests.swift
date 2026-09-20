import XCTest
@testable import SujiCore

final class DivinationEvidenceTests: XCTestCase {
    func testTombReferencesKeepObjectIdentityFalseEfficacyAndEmptyActorSets() throws {
        let messages=history("cast_liuyao", #"{"tombExtinction":{"sourceId":"liuyao-tomb-extinction-v1","assessmentStatus":"conditional-structure","efficacyEstablished":false,"unresolved":["target-strength"],"objects":[{"objectPath":"/lines/0/hidden","month":"墓","day":"neither","flying":"绝","movingTombPositions":[],"movingExtinctionPositions":[],"supportingMovingPositions":[2]}]}}"#)
        let facts=Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map{($0.factKey,$0)})
        XCTAssertEqual(facts["liuyao.tombExtinction.efficacyEstablished"]?.value,.bool(false))
        XCTAssertEqual(facts["liuyao.tombExtinction.object1.objectPath"]?.value,.string("/lines/0/hidden"))
        XCTAssertEqual(facts["liuyao.tombExtinction.object1.flying"]?.pointer,"/tombExtinction/objects/0/flying")
        XCTAssertEqual(facts["liuyao.tombExtinction.object1.movingTombPositions"]?.value,.array([]))
        try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"只核对结构及未决条件",history:messages,question:"墓绝参考"),history:messages)
    }
    func testCandidateRolesIndexKeepsSeparateObjectsEmptyRolesAndMovingPairs() throws {
        let messages = history("cast_liuyao", #"{"roleRelations":{"assessmentStatus":"candidate-relative-structure","outcomeEstablished":false,"sourceId":"liuyao-candidate-roles-v1","inspectedOriginalPaths":["/lines/0","/lines/1","/lines/2","/lines/3","/lines/4","/lines/5"],"groups":[{"targetElement":"水","candidateRefs":[{"id":"original-4","objectPath":"/lines/3","contextPath":"/lines/3/context"}],"elements":{"yuan":"金","ji":"土","chou":"火"},"yuanPositions":[3,5],"jiPositions":[1,6],"chouPositions":[],"jiYuanMovingPairs":[{"jiPosition":6,"yuanPosition":5}],"chouJiMovingPairs":[]}],"unsupportedCandidates":[{"id":"month","objectPath":"/castGanZhi/month","reason":"calendar-target-outside-line-role-scope"}],"unresolved":["target-viability"],"prediction":"一定有救"}}"#)
        let facts = Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map { ($0.factKey,$0) })
        XCTAssertEqual(facts["liuyao.roleRelations.outcomeEstablished"]?.value,false)
        XCTAssertEqual(facts["liuyao.roleRelations.group1.chouPositions"]?.value,[])
        XCTAssertEqual(facts["liuyao.roleRelations.group1.candidate1.objectPath"]?.value,"/lines/3")
        XCTAssertEqual(facts["liuyao.roleRelations.group1.jiYuanPair1.jiPosition"]?.pointer,"/roleRelations/groups/0/jiYuanMovingPairs/0/jiPosition")
        XCTAssertEqual(facts["liuyao.roleRelations.unsupported1.objectPath"]?.value,"/castGanZhi/month")
        XCTAssertNil(facts["liuyao.roleRelations.prediction"])
        try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"只核对角色",history:messages,question:"元忌仇"),history:messages)
    }

    func testLiuyaoWholeChartPairsAndMovingClashesKeepSeparateEvidence() throws {
        let messages = history("cast_liuyao", #"{"guaRelations":{"assessmentStatus":"structural-only","outcomeEstablished":false,"sourceId":"liuyao-calendar-relations-v1","original":{"guaPath":"/benGua","kind":"六冲","ganZhi":["己卯","己丑","己亥","己酉","己未","己巳"],"pairs":[{"positions":[1,4],"relation":"六冲"}]},"resulting":{"guaPath":"/bianGua","kind":"六合","ganZhi":["丙辰","丙午","丙申","己酉","己未","己巳"],"pairs":[{"positions":[1,4],"relation":"六合"}]},"transition":{"hasChange":true,"fromKind":"六冲","toKind":"六合","kind":"六冲变六合","factPaths":["/changingYao","/guaRelations/original/kind","/guaRelations/resulting/kind"]},"verdict":"必成"},"lines":[{"rules":{"returning":{"branchRelation":"neither","branchSourceId":"liuyao-calendar-relations-v1","from":"/lines/0/changed","to":"/lines/0","sourceId":"liuyao-calendar-relations-v1","assessmentStatus":"structural-relation","conditionsFrom":"/lines/0/rules/advanceRetreat/conditions"}}}]}"#)
        let indexed = Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map { ($0.factKey,$0) })
        XCTAssertEqual(indexed["liuyao.guaRelations.outcomeEstablished"]?.value,.bool(false))
        XCTAssertEqual(indexed["liuyao.guaRelations.original.ganZhi"]?.value,.array(["己卯","己丑","己亥","己酉","己未","己巳"].map(JSONValue.string)))
        XCTAssertEqual(indexed["liuyao.guaRelations.resulting.pair1.positions"]?.value,.array([.integer(1),.integer(4)]))
        XCTAssertEqual(indexed["liuyao.guaRelations.resulting.pair1.relation"]?.pointer,"/guaRelations/resulting/pairs/0/relation")
        XCTAssertEqual(indexed["liuyao.guaRelations.original.pair1.positions"]?.pointer,"/guaRelations/original/pairs/0/positions")
        XCTAssertEqual(indexed["liuyao.guaRelations.transition.kind"]?.value,.string("六冲变六合"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.branchRelation"]?.value,.string("neither"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.branchSourceId"]?.value,.string("liuyao-calendar-relations-v1"))
        XCTAssertEqual(indexed["liuyao.line1.rules.returning.from"]?.pointer,"/lines/0/rules/returning/from")
        XCTAssertNil(indexed["liuyao.line2.rules.returning.clash"])
        XCTAssertNil(indexed["liuyao.guaRelations.verdict"])
        try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"核对整卦及动爻",history:messages,question:"核对"),history:messages)
    }

    func testLiuyaoChartIndexRejectsNestedInterpretationsAndKeepsStaticTransition() {
        let facts = ReadingVerificationEvidence.facts(history("cast_liuyao", #"{"guaRelations":{"outcomeEstablished":{"prediction":"必成"},"original":{"kind":{"text":"六合"},"ganZhi":[{"prediction":"必中"}],"pairs":[{"branches":[["子","丑"]],"relation":{"prediction":"必成"}}]},"transition":{"hasChange":false,"kind":"static"}},"lines":[{"rules":{"returning":{"branchRelation":{"text":"冲散"}}}}]}"#))
        XCTAssertEqual(Set(facts.map(\.factKey)),Set(["liuyao.guaRelations.transition.hasChange","liuyao.guaRelations.transition.kind"]))
        XCTAssertEqual(facts.first(where: { $0.factKey.hasSuffix("hasChange") })?.value,.bool(false))
    }

    func testLiuyaoGuaRelationsSurviveActualJavaScriptCoreTransportAndReplay() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let script = try String(contentsOf:native.appendingPathComponent("Resources/mingli.js"),encoding:.utf8)
        let cases: [([Int],String,String)] = [([9,8,7,7,8,7],"六冲","六冲变六合"),([8,9,9,7,8,8],"ordinary","other-change"),([8,8,8,8,8,8],"六冲","static")]
        for (values,originalKind,transition) in cases {
            // Inject coin results at the random source, without adding a model-controlled seed/API.
            let draws = values.flatMap { value in Array(repeating:0.75,count:value-6) + Array(repeating:0.0,count:9-value) }
            let seeded = directory.appendingPathComponent("engine.js")
            try (script + "\nlet coinCalls=0; const draws=" + ReadingVerificationEvidence.encoded(draws) + "; Math.random=()=>draws[coinCalls++];").write(to:seeded,atomically:true,encoding:.utf8)
            let bridge = try MingliBridge(scriptURL:seeded)
            let raw = try await bridge.request(#"{"command":"tool","name":"cast_liuyao","arguments":{"question":"核对原卦与变卦的结构"},"now":"2026-09-19T04:00:00Z"}"#)
            let root = try JSONDecoder().decode(JSONValue.self,from:raw)
            let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:root))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/lineValues",in:result),.array(values.map { .integer(Int64($0)) }))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/guaRelations/original/kind",in:result),.string(originalKind))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/guaRelations/transition/kind",in:result),.string(transition))
            if transition == "六冲变六合" {
                XCTAssertEqual(ReadingVerificationEvidence.pointer("/guaRelations/resulting/pairs/1/positions",in:result),.array([.integer(2),.integer(5)]))
                XCTAssertNil(ReadingVerificationEvidence.pointer("/lines/1/changed",in:result))
            } else if transition == "other-change" {
                XCTAssertEqual(ReadingVerificationEvidence.pointer("/lines/2/rules/returning/branchRelation",in:result),.string("六冲"))
                XCTAssertEqual(ReadingVerificationEvidence.pointer("/lines/2/rules/returning/relation",in:result),.string("本爻克变"))
            }
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/lineContextPolicy/assessmentStatus",in:result),.string("calendar-relations-only"))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/lineContextPolicy/sourceIds",in:result),.array([.string("liuyao-calendar-relations-v1")]))
            let output = ReadingVerificationEvidence.encoded(result)
            let messages = history("cast_liuyao",output)
            let facts = ReadingVerificationEvidence.facts(messages)
            XCTAssertEqual(facts.first(where:{$0.factKey == "liuyao.lineContextPolicy.assessmentStatus"})?.pointer,"/lineContextPolicy/assessmentStatus")
            XCTAssertEqual(facts.first(where:{$0.factKey == "liuyao.lineContextPolicy.sourceIds"})?.value,.array([.string("liuyao-calendar-relations-v1")]))
            XCTAssertEqual(facts.first(where:{$0.factKey == "liuyao.guaRelations.transition.kind"})?.value,.string(transition))
            try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"只核对结构",history:messages,question:"核对结构"),history:messages)
            let context = try ToolContext(birth:nil,engineRevision:"b2-test",referenceDate:Date(timeIntervalSince1970:1_789_790_400),mode:"起卦")
            let receipt = ToolReceipt(callID:"receipt",name:"cast_liuyao",arguments:["question":"核对原卦与变卦的结构"],output:output,evidence:["receipt"],context:context)
            var entry = ConversationEntry(role:"user",text:"核对原卦与变卦的结构")
            entry.toolReceipts = [receipt]
            let replay = ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
            XCTAssertEqual(replay.first(where:{$0.role == .tool})?.content,output)
        }
    }

    func testQimenEarthHostingIsIndependentOfSkyHostingAndArrayOrder() throws {
        let messages = history("setup_qimen", #"{"palaces":[{"id":7,"diPanGan":"壬","hostedTianPanGan":"庚"},{"id":2,"diPanGan":"乙","tianPanGan":"丁","hostedDiPanGan":"庚"},{"id":5,"diPanGan":"庚","tianPanGan":"庚"}]}"#)
        let indexed = Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map { ($0.factKey,$0) })
        XCTAssertEqual(indexed["qimen.palace2.hostedDiPanGan"]?.value,.string("庚"))
        XCTAssertEqual(indexed["qimen.palace2.hostedDiPanGan"]?.pointer,"/palaces/1/hostedDiPanGan")
        XCTAssertEqual(indexed["qimen.palace7.hostedTianPanGan"]?.pointer,"/palaces/0/hostedTianPanGan")
        XCTAssertNil(indexed["qimen.palace2.hostedTianPanGan"])
        try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"核对两层寄干",history:messages,question:"核对"),history:messages)
    }
    func testQimenQuestionObjectsKeepScopedPointersNullAndUnresolvedTiming() throws {
        let messages = history("setup_qimen", #"{"questionContext":{"subject":"parent","event":"untrusted narrative","timeHorizon":"near"},"yongShen":{"selectionStatus":"requires-clarification","selectionEstablished":false,"selectedCandidateId":null,"missingContext":["proxy-perspective"],"sourceId":"qimen-question-references-v1","candidates":[{"id":"hour-stem","role":"hour-reference","symbol":"甲","calendarPath":"/hourGanZhi","carrierStem":"庚","carrierMethod":"own-pillar-xun","occurrences":[{"palaceId":8,"plate":"hosted-sky","objectPath":"/palaces/0/hostedTianPanGan","isEffectiveSky":true,"elementRelation":{"stemElement":"木","palaceElement":"土","relation":"干克宫","assessmentStatus":"stem-palace-only"}},{"palaceId":5,"plate":"center-record","objectPath":"/palaces/1/tianPanGan","isEffectiveSky":false}]}]},"yingQi":{"assessmentStatus":"unresolved","outcomeEstablished":false,"sourceId":"qimen-question-references-v1","timeScale":"unresolved","unresolved":["time-unit"],"triggers":[],"dates":[],"observedFactPaths":["/hourVoid","/horse"]},"ruleSources":[{"id":"qimen-question-references-v1","editionStatus":"product-policy"}]}"#)
        let indexed = Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(messages).map { ($0.factKey,$0) })
        XCTAssertEqual(indexed["qimen.question.subject"]?.value,.string("parent"))
        XCTAssertNil(indexed["qimen.question.event"])
        XCTAssertEqual(indexed["qimen.yongShen.selectedCandidateId"]?.value,.null)
        XCTAssertEqual(indexed["qimen.yongShen.selectionEstablished"]?.value,.bool(false))
        XCTAssertEqual(indexed["qimen.yongShen.candidate1.carrierStem"]?.value,.string("庚"))
        XCTAssertEqual(indexed["qimen.yongShen.candidate1.occurrence1.objectPath"]?.value,.string("/palaces/0/hostedTianPanGan"))
        XCTAssertEqual(indexed["qimen.yongShen.candidate1.occurrence1.elementRelation.relation"]?.pointer,"/yongShen/candidates/0/occurrences/0/elementRelation/relation")
        XCTAssertEqual(indexed["qimen.yongShen.candidate1.occurrence2.isEffectiveSky"]?.value,.bool(false))
        XCTAssertNil(indexed["qimen.yongShen.candidate1.occurrence2.elementRelation.relation"])
        XCTAssertEqual(indexed["qimen.timing.outcomeEstablished"]?.value,.bool(false))
        XCTAssertEqual(indexed["qimen.timing.triggers"]?.value,.array([]))
        XCTAssertEqual(indexed["qimen.timing.dates"]?.value,.array([]))
        XCTAssertEqual(indexed["qimen.ruleSource1.editionStatus"]?.value,.string("product-policy"))
        try assertIndexRestoresFacts(review:ReadingVerifier.messages(draft:"核对候选身份",history:messages,question:"核对"),history:messages)
    }
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

    func testLiuyaoCapacityAtIndependentWorstCaseDatesPreservesBothCasts() async throws {
        try await assertCombinedCharts(values:[6,6,9,9,6,6],questionType:"career",subject:"self",instant:"2026-09-11T04:00:00Z")
        try await assertCombinedCharts(values:[6,6,6,6,9,9],questionType:"parents",subject:"parent",instant:"2026-09-12T04:00:00Z")
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

    func testLargestReviewedCastPreservesBothChartsWithMaximumLegalCallIDs() async throws {
        try await assertCombinedCharts(values:[9,9,6,6,9,9],questionType:"kids",subject:"child",instant:"2026-09-20T04:00:00Z",callIDLength:200)
    }

    func testMaximumEscapedEventAndCallIDsPreserveBothChartsAndVerificationBudget() async throws {
        try await assertCombinedCharts(values:[9,9,6,6,9,9],questionType:"kids",subject:"child",instant:"2026-09-20T04:00:00Z",callIDLength:200,event:"事"+String(repeating:"\u{1}",count:199))
    }

    private func assertCombinedCharts(values: [Int],questionType:String = "parents",subject:String = "parent",instant:String = "2026-09-19T04:00:00Z",callIDLength:Int = 32,event:String = String(repeating:"事",count:200)) async throws {
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
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from:instant))
        let question = String(("用六爻和奇门分别解释这次盘面，请保留各自依据。" + String(repeating: "需要比较盘面细节。", count: 180)).prefix(1600))
        var messages = [ChatMessage(role: .system, content: ReadingPrompt.instruction(tone: "清晰", mode: "起卦", referenceDate: now, hasBirth: true))]
        for (index, name) in ["cast_liuyao", "setup_qimen"].enumerated() {
            let id = String(repeating: index == 0 ? "a" : "b", count: callIDLength)
            let arguments = ["question": question, "questionType": name == "cast_liuyao" ? questionType : "career", "subject": subject, "event": event, "timeHorizon": "near"]
            let request: [String: Any] = ["command": "tool", "name": name, "arguments": arguments, "now": instant]
            let raw = try await bridge.request(String(decoding: JSONSerialization.data(withJSONObject: request), as: UTF8.self))
            let root = try JSONDecoder().decode(JSONValue.self, from: raw)
            let output = ReadingVerificationEvidence.encoded(try XCTUnwrap(ReadingVerificationEvidence.pointer("/result", in: root)))
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
        let modelOutputs=delivery.messages.filter { $0.role == .tool }.map { $0.content! }
        for (call,modelOutput) in zip(calls,modelOutputs) {
            XCTAssertLessThanOrEqual(modelOutput.utf16.count,32_000)
            var projected=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(modelOutput.utf8)) as? [String:Any])
            if projected.removeValue(forKey:"questionFromArguments") != nil { projected["question"]=question }
            let restored=try XCTUnwrap(LiuyaoConditionTransport.expand(JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:projected))))
            let original=try JSONDecoder().decode(JSONValue.self,from:Data(outputs[call.id]!.utf8))
            XCTAssertTrue(restored == original,"Every original chart field must survive projection")
        }
        XCTAssertLessThanOrEqual(modelOutputs.reduce(0){$0+$1.utf8.count},ToolOrchestrator.outputByteLimit)
        var entry = ConversationEntry(role:"user",text:question)
        entry.toolReceipts = delivery.receipts
        let replay = ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
        XCTAssertTrue(replay.filter { $0.role == .tool }.map { $0.content! } == modelOutputs)
        let retry = ToolOrchestrator(complete:{ _,_ in .text("ready") },execute:{ _ in XCTFail("Retry must retain the original casts"); return .init(output:"{}") })
        let retried = try await retry.run(history:replay,definitions:definitions,cachedReceipts:delivery.receipts,context:context)
        XCTAssertEqual(retried.evidence,calls.map(\.id))
        let review = ReadingVerifier.messages(draft: String(repeating: "本次仅列出盘面事实和条件。", count: 60), history: delivery.messages, question: question)
        try assertIndexRestoresFacts(review:review,history:delivery.messages)
        let total = review.reduce(0) { $0 + ($1.content?.utf16.count ?? 0) + ($1.toolCalls ?? []).reduce(0) { $0 + ReadingVerificationEvidence.encoded($1.arguments).utf16.count } }
        XCTAssertLessThanOrEqual(total, 120_000, "Backend rejects a valid two-chart review when the fact index repeats too much metadata")
        XCTAssertLessThanOrEqual(review.count, 120)
        XCTAssertLessThan(try JSONEncoder().encode(review).count + 1024,262_144)
        for message in review { XCTAssertLessThanOrEqual(message.content?.utf16.count ?? 0, 32_000) }
        print("Divination evidence capacity: \(total) UTF-16 code units, \(review.count) messages, casts \(modelOutputs.reduce(0) { $0 + $1.utf8.count }) bytes")
    }

    func testCompactIndexPreservesEveryFactAndItsToolIdentity() throws {
        let messages = history("cast_liuyao", #"{"castGanZhi":{"day":"甲子"},"lines":[{"context":{"isVoid":false},"changed":{"context":{"isVoid":true}}}]}"#)
        let review = ReadingVerifier.messages(draft: "核对盘面", history: messages, question: "盘面事实")
        try assertIndexRestoresFacts(review:review,history:messages)
    }

    func testSharedIndexRetainsAgreeingAndConflictingReceiptIdentities() throws {
        var messages:[ChatMessage]=[]
        for (id,stem) in [("a","甲"),("b","甲"),("c","乙")] {
            messages += [.assistantToolCalls([.init(id:id,name:"setup_qimen",arguments:[:])]),.toolResult(.init(callID:id,output:"{\"dayGanZhi\":\"\(stem)子\"}"))]
        }
        let review=ReadingVerifier.messages(draft:"核对事实",history:messages,question:"核对")
        XCTAssertTrue(review.contains { $0.content?.contains("\"toolCallIDs\":[\"a\",\"b\"]") == true })
        XCTAssertEqual(review.filter { $0.role == .tool }.count,3)
        try assertIndexRestoresFacts(review:review,history:messages)
    }

    func testSharedLongReceiptIDsRestoreAgreeingAndConflictingGroupsExactly() throws {
        var messages:[ChatMessage]=[]
        for (token,stem) in [("a","甲"),("b","甲"),("c","乙")] {
            let id=String(repeating:token,count:200)
            let output:JSONValue=["dayGanZhi":.string(stem+"子"),"hourGanZhi":"丙子","palaces":[["id":1,"diPanGan":"戊","tianPanGan":"庚"],["id":2,"diPanGan":"丙","tianPanGan":"丁"]]]
            messages += [.assistantToolCalls([.init(id:id,name:"setup_qimen",arguments:[:])]),.toolResult(.init(callID:id,output:ReadingVerificationEvidence.encoded(output)))]
        }
        let review=ReadingVerifier.messages(draft:"逐一核对三份回执",history:messages,question:"核对")
        XCTAssertTrue(review.contains{$0.content?.contains("\"toolCallIDIndices\"") == true})
        XCTAssertTrue(review.contains{$0.content?.contains("\"toolCallIDIndex\"") == true})
        try assertIndexRestoresFacts(review:review,history:messages)
    }

    func testRepeatedFieldLayoutsPreserveValuesAndAllReceiptCoordinates() throws {
        let edges: [JSONValue] = (0..<24).map { index in
            ["scope":"natal-palace-stem","sourcePalace":"夫妻宫","sourcePosition":"辰","sourceStem":"丙","star":.string(index % 2 == 0 ? "天同" : "文昌"),"transformation":"化禄","targetPalace":"福德宫","targetPosition":"午","isSelf":.bool(index % 2 == 0),"sourceId":"ziwei-palace-flights-selected-v1"]
        }
        let output = ReadingVerificationEvidence.encoded(JSONValue.object(["palace":"夫妻宫","mainStars":[],"palaceFlights":["incoming":.array(edges),"outgoing":[]]]))
        let messages = history("get_ziwei_palace",output)
        let review = ReadingVerifier.messages(draft:"核对来源",history:messages,question:"核对")
        XCTAssertTrue(review.contains { $0.content?.contains("\"layouts\"") == true })
        try assertIndexRestoresFacts(review:review,history:messages)
        XCTAssertEqual(review.filter { $0.role == .tool }.map(\.content),messages.filter { $0.role == .tool }.map(\.content))
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
                let ids:[String]
                if case let .string(id) = ReadingVerificationEvidence.pointer("/toolCallID",in:group) { ids=[id] }
                else if case let .array(values) = ReadingVerificationEvidence.pointer("/toolCallIDs",in:group) {
                    ids = values.compactMap { if case let .string(id) = $0 { return id }; return nil }
                    XCTAssertEqual(ids.count,values.count)
                    XCTAssertEqual(Set(ids).count,ids.count)
                } else if let index=ReadingVerificationEvidence.pointer("/toolCallIDIndex",in:group) {
                    guard case let .integer(i)=index,case let .string(id)=ReadingVerificationEvidence.pointer("/toolCallIDs/\(i)",in:envelope) else { return XCTFail("Missing full ID") }
                    ids=[id]
                } else if case let .array(indices)=ReadingVerificationEvidence.pointer("/toolCallIDIndices",in:group) {
                    ids=try indices.map { index in
                        guard case let .integer(i)=index,case let .string(id)=ReadingVerificationEvidence.pointer("/toolCallIDs/\(i)",in:envelope) else { throw NSError(domain:"Missing full ID",code:1) }
                        return id
                    }
                    XCTAssertEqual(Set(ids).count,ids.count)
                } else { return XCTFail("Missing receipt identity") }
                guard case let .string(keyPrefix) = ReadingVerificationEvidence.pointer("/factKeyPrefix",in:group),
                      case let .string(pathPrefix) = ReadingVerificationEvidence.pointer("/pointerPrefix",in:group) else { return XCTFail("Missing lossless prefixes") }
                let rows: [JSONValue]
                if case let .array(inline) = ReadingVerificationEvidence.pointer("/facts",in:group) { rows = inline }
                else {
                    guard case let .integer(index) = ReadingVerificationEvidence.pointer("/layout",in:group),
                          case let .array(layout) = ReadingVerificationEvidence.pointer("/layouts/\(index)",in:envelope),
                          case let .array(values) = ReadingVerificationEvidence.pointer("/values",in:group),
                          values.count == layout.count else { return XCTFail("Missing exact field layout") }
                    rows = try zip(layout,values).map { fields,value in
                        guard case let .array(pair) = fields, pair.count == 2 else { throw NSError(domain:"Invalid layout",code:1) }
                        return .array(pair+[value])
                    }
                }
                for row in rows {
                    guard case let .array(values) = row, values.count == 3,
                          case let .string(key) = values[0] else { return XCTFail("Malformed fact row") }
                    let path: String
                    if values[1] == .null { path = key.replacingOccurrences(of:".",with:"/") }
                    else if case let .string(explicit) = values[1] { path = explicit }
                    else { return XCTFail("Malformed pointer suffix") }
                    for id in ids {
                        XCTAssertNil(restored[id + ":" + keyPrefix + key])
                        restored[id + ":" + keyPrefix + key] = .array([.string(pathPrefix + path),values[2]])
                    }
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
