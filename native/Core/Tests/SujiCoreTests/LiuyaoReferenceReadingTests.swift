import XCTest
@testable import SujiCore

final class LiuyaoReferenceReadingTests: XCTestCase {
    private var native: URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }
    private func fixture(_ values: [Int] = [9,6,6,6,6,9], now: String = "2024-02-04T04:00:00Z", args: [String:Any] = ["question":"我近期能否收款","questionType":"wealth","subject":"self","event":"收款","timeHorizon":"near"]) async throws -> (ToolReceipt,ToolContext) {
        let script = try String(contentsOf:native.appendingPathComponent("Resources/mingli.js"),encoding:.utf8)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let draws = values.flatMap { Array(repeating:0.75,count:$0-6) + Array(repeating:0.0,count:9-$0) }
        let seeded = directory.appendingPathComponent("engine.js")
        try (script + "\nlet n=0;const draws=" + ReadingVerificationEvidence.encoded(draws) + ";Math.random=()=>draws[n++];").write(to:seeded,atomically:true,encoding:.utf8)
        let bridge = try MingliBridge(scriptURL:seeded)
        let raw = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:["command":"tool","name":"cast_liuyao","arguments":args,"now":now]),as:UTF8.self))
        let envelope = try JSONDecoder().decode(JSONValue.self,from:raw)
        let root = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root) else { throw EngineError.execution("version") }
        let context = try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        return (.init(callID:"liuyao-original",name:"cast_liuyao",arguments:[:],output:ReadingVerificationEvidence.encoded(root),context:context),context)
    }
    private func evidence(_ report: LiuyaoReferenceReading.Report, _ receipt: ToolReceipt) throws {
        let root = try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
        XCTAssertEqual(report.sourceReceiptID,receipt.callID)
        for section in report.sections {
            XCTAssertFalse(section.evidence.isEmpty,section.id)
            for field in section.evidence {
                XCTAssertEqual(field.toolCallID,receipt.callID)
                XCTAssertEqual(field.value,ReadingVerificationEvidence.pointer(field.pointer,in:root),field.pointer)
            }
        }
    }
    private func edited(_ receipt: ToolReceipt, _ change: (inout [String:Any]) -> Void) throws -> ToolReceipt {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any]);change(&root)
        var result=receipt;result.output=String(decoding:try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys,.withoutEscapingSlashes]),as:UTF8.self);return result
    }
    func testArchivedFalseProseBecomesSourceBoundCandidatesAndActualTriggerBranches() throws {
        let data = try Data(contentsOf:native.appendingPathComponent("Engine/validation/reasoning/core-f1-final-results.json"))
        let archive = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        let sample = (archive["cases"] as! [[String:Any]])[0]
        let receipt = try JSONDecoder().decode(ToolReceipt.self,from:JSONSerialization.data(withJSONObject:(sample["receipts"] as! [[String:Any]])[0]))
        let context = try XCTUnwrap(receipt.context)
        XCTAssertTrue((sample["draft"] as! String).contains("丑戌相合"))
        let report = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        XCTAssertTrue(report.text.contains("山雷颐"));XCTAssertTrue(report.text.contains("泽风大过"))
        let first = try XCTUnwrap(report.sections.first { $0.id == "timing-original-3" })
        XCTAssertTrue(first.text.contains("辰、酉"));XCTAssertTrue(first.text.contains("戌、卯"))
        XCTAssertTrue(first.text.contains("本爻辰与变爻酉相合"))
        XCTAssertFalse(report.text.contains("丑戌相合"));XCTAssertFalse(report.text.contains("暗动"))
        XCTAssertTrue(first.evidence.contains { $0.pointer == "/lines/2/changed/ganZhi" })
        XCTAssertTrue(first.evidence.contains { $0.value == .string("liuyao-question-timing-v1") })
        XCTAssertEqual(report.sections.filter { $0.id.hasPrefix("candidate-") }.count,2)
        XCTAssertTrue(report.text.contains("尚未定用"));XCTAssertTrue(report.text.contains("不能确定到账或其他事件日期"))
        try evidence(report,receipt)
    }
    func testActualChangedHiddenAndFullProjectionDoNotBorrowEachOthersIdentity() async throws {
        let (receipt,context) = try await fixture([9,8,7,7,8,7])
        let report = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        XCTAssertTrue(report.text.contains("六冲变六合"))
        XCTAssertTrue(report.sections.first { $0.id == "line-1" }!.text.contains("变爻丙辰"))
        XCTAssertFalse(report.sections.first { $0.id == "line-2" }!.text.contains("变爻"))
        XCTAssertFalse(report.text.contains("必成"))
        try evidence(report,receipt)
        let (withHidden,hiddenContext) = try await fixture()
        let hiddenReport = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[withHidden],context:hiddenContext))
        let line = try XCTUnwrap(hiddenReport.sections.first { $0.id == "line-3" })
        XCTAssertTrue(line.text.contains("伏神辛酉"));XCTAssertTrue(line.text.contains("飞生伏"))
        XCTAssertTrue(line.evidence.contains { $0.pointer == "/lines/2/hidden/context/isVoid" })
        try evidence(hiddenReport,withHidden)
    }
    func testStaticDayClashIsConditionalAndCalendarHiddenObjectsAreNotMovingLines() async throws {
        let (receipt,context) = try await fixture([7,8,8,8,8,7])
        let report = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let third = try XCTUnwrap(report.sections.first { $0.id == "line-3" })
        XCTAssertTrue(third.text.contains("静爻日冲"));XCTAssertTrue(third.text.contains("候选"));XCTAssertTrue(third.text.contains("未裁定"))
        let (gou,otherContext) = try await fixture([8,7,7,7,7,7],now:"2024-02-05T04:00:00Z")
        let hidden = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[gou],context:otherContext))
        XCTAssertTrue(hidden.sections.contains { $0.id == "candidate-month" && $0.text.contains("月建") })
        XCTAssertTrue(hidden.sections.contains { $0.id == "candidate-hidden-2" && $0.text.contains("伏神甲寅") })
        let timing = try XCTUnwrap(hidden.sections.first { $0.id == "timing-hidden-2" })
        XCTAssertFalse(timing.text.contains("静值冲"));XCTAssertFalse(timing.text.contains("动值合"))
        XCTAssertTrue(timing.text.contains("出伏"));try evidence(hidden,gou)
    }
    func testMissingObjectsDoNotBecomeQuerentVerdictAndSourceFailuresStayUnavailable() async throws {
        let (receipt,context) = try await fixture(args:["question":"问一件事","questionType":"general"])
        let report = try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        XCTAssertTrue(report.text.contains("没有确定候选对象"))
        for word in ["所问对象","具体事件","时间范围"] { XCTAssertTrue(report.text.contains(word)) }
        for mutation in 0..<6 {
            let invalid = try edited(receipt) { root in
                if mutation == 0 { root["ruleSources"]=[] }
                if mutation == 1 { root["provenance"]=["engineRevision":"wrong"] }
                if mutation == 2 { root["castTime"]="2024-02-04T04:00:01Z" }
                if mutation == 3 { var y=root["yongShen"] as! [String:Any];y["selectionEstablished"]=true;root["yongShen"]=y }
                if mutation == 4 { var lines=root["lines"] as! [[String:Any]];lines[0]["position"]=3;root["lines"]=lines }
                if mutation == 5 { var s=root["ruleSources"] as! [[String:Any]];s[0]["version"]="99";root["ruleSources"]=s }
            }
            XCTAssertTrue(LiuyaoReferenceReading.render(receipts:[invalid],context:context) == nil,"mutation \(mutation)")
        }
        var untrusted=receipt;untrusted.context=nil
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[untrusted],context:context))
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[],context:context))
        var other=receipt;other.name="setup_qimen"
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[receipt,other],context:context))
        let conflicting=try edited(receipt) { $0["question"]="another" }
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[receipt,conflicting],context:context))
        XCTAssertTrue(LiuyaoReferenceReading.unavailableReply(receipts:[]).contains("尚未取得"))
    }
    func testCandidateAndTimingPointersCannotBorrowChangedOrAnotherOriginalLine() async throws {
        let (receipt,context)=try await fixture()
        for mutation in 0..<4 {
            let invalid=try edited(receipt) { root in
                if mutation < 2 {
                    var y=root["yongShen"] as! [String:Any],c=y["candidates"] as! [[String:Any]]
                    c[0]["objectPath"]=mutation == 0 ? "/lines/2/changed" : "/lines/3";y["candidates"]=c;root["yongShen"]=y
                } else {
                    var y=root["yingQi"] as! [String:Any],c=y["branchesByCandidate"] as! [[String:Any]]
                    if mutation == 2 { c[0]["objectPath"]="/lines/3" }
                    else { y["sourceId"]="liuyao-flying-hidden-v1" }
                    y["branchesByCandidate"]=c;root["yingQi"]=y
                }
            }
            XCTAssertNil(LiuyaoReferenceReading.render(receipts:[invalid],context:context))
        }
    }
    func testRuleConditionsCannotBorrowAnotherObjectOrContradictTheirFacts() async throws {
        let (receipt,context)=try await fixture()
        for mutation in 0..<5 {
            let invalid=try edited(receipt) { root in
                if mutation == 4 { var sources=root["ruleSources"] as! [[String:Any]];sources[0]["references"]=["not a source"];root["ruleSources"]=sources;return }
                if mutation == 3 { var y=root["yingQi"] as! [String:Any],c=y["branchesByCandidate"] as! [[String:Any]];c[0]["conditionsPath"]="/lines/5/context";y["branchesByCandidate"]=c;root["yingQi"]=y;return }
                var lines=root["lines"] as! [[String:Any]],rules=lines[0]["rules"] as! [String:Any],advance=rules["advanceRetreat"] as! [String:Any],conditions=advance["conditions"] as! [[String:Any]]
                if mutation == 0 { conditions[0]["factPaths"]=["/lines/5/context/isVoid"] }
                if mutation == 1 { conditions[0]["state"]="matched" }
                if mutation == 2 { conditions.remove(at:0) }
                advance["conditions"]=conditions;rules["advanceRetreat"]=advance;lines[0]["rules"]=rules;root["lines"]=lines
            }
            XCTAssertTrue(LiuyaoReferenceReading.render(receipts:[invalid],context:context) == nil,"mutation \(mutation)")
        }
    }
    func testActualIntentGateRecognizesTraditionalMixedRequestsAndDiscussion() async throws {
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let definitions=try await bridge.request(#"{"command":"tools"}"#)
        for question in ["用六爻與奇門看","解释什么是六爻","不要起卦，只解释六爻里的世爻和应爻"] {
            let available=try ReadingIntent.definitions(from:definitions,mode:"起卦",question:question,hasBirth:false)
            XCTAssertFalse(LiuyaoReferenceReading.isExclusiveRequest(definitions:available,question:question),question)
        }
        let q="不要奇门，只用六爻"
        let available=try ReadingIntent.definitions(from:definitions,mode:"起卦",question:q,hasBirth:false)
        XCTAssertTrue(LiuyaoReferenceReading.isExclusiveRequest(definitions:available,question:q))
    }
    func testReturningRelationshipsMustAgreeWithTheirOwnOriginalAndChangedObjects() async throws {
        let (receipt,context)=try await fixture()
        for field in ["branchRelation","relation"] {
            let invalid=try edited(receipt) { root in
                var lines=root["lines"] as! [[String:Any]],rules=lines[2]["rules"] as! [String:Any],returning=rules["returning"] as! [String:Any]
                returning[field]=field == "branchRelation" ? "六冲" : "回头克"
                rules["returning"]=returning;lines[2]["rules"]=rules;root["lines"]=lines
            }
            XCTAssertNil(LiuyaoReferenceReading.render(receipts:[invalid],context:context),field)
        }
    }
    func testAdvanceFlyingAndCandidateReasonMustMatchTheirObjectScope() async throws {
        let (receipt,context)=try await fixture()
        for mutation in 0..<3 {
            let invalid=try edited(receipt) { root in
                if mutation == 2 {
                    var y=root["yongShen"] as! [String:Any],c=y["candidates"] as! [[String:Any]]
                    c[0]["reason"]="absent-visible-calendar-role";y["candidates"]=c;root["yongShen"]=y;return
                }
                let index=mutation == 0 ? 0 : 2,key=mutation == 0 ? "advanceRetreat" : "flyingHidden"
                var lines=root["lines"] as! [[String:Any]],rules=lines[index]["rules"] as! [String:Any],rule=rules[key] as! [String:Any]
                rule[mutation == 0 ? "kind" : "relation"]=mutation == 0 ? "进神" : "飞克伏"
                rules[key]=rule;lines[index]["rules"]=rules;root["lines"]=lines
            }
            XCTAssertTrue(LiuyaoReferenceReading.render(receipts:[invalid],context:context) == nil,"mutation \(mutation)")
        }
    }
    func testExplicitSpouseCandidatesRemainValidWithoutInferringFromGender() async throws {
        for subject in ["wife","husband"] {
            let (receipt,context)=try await fixture(args:["question":"婚姻对象参考","questionType":"marriage","subject":subject,"event":"关系沟通","timeHorizon":"near"])
            let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context),subject)
            XCTAssertTrue(report.sections.contains { $0.id.hasPrefix("candidate-") })
            try evidence(report,receipt)
        }
    }
    func testExclusiveGateAndActualRetryRetainOriginalCast() async throws {
        let definition=ChatToolDefinition(name:"cast_liuyao",description:"",parameters:["type":"object"])
        XCTAssertTrue(LiuyaoReferenceReading.isExclusiveRequest(definitions:[definition],question:"请用六爻问收款"))
        for text in ["六爻结合八字","六爻和紫微一起看","用六爻与奇门看", "看七政四余"] {
            XCTAssertFalse(LiuyaoReferenceReading.isExclusiveRequest(definitions:[definition],question:text))
        }
        let (receipt,context)=try await fixture()
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let orchestrator=ToolOrchestrator(complete:{ messages,_ in
            messages.contains(where:{$0.role == .tool}) ? .text("ready") : .toolCalls((0..<8).map { .init(id:"retry-\($0)",name:"cast_liuyao",arguments:["question":"changed wording"]) })
        },execute:{_ in XCTFail("No recast");return .init(output:"{}")},persistReceipt:{_ in XCTFail("No new receipt")})
        let result=try await orchestrator.run(history:[],definitions:[definition],cachedReceipts:[receipt],context:context)
        XCTAssertEqual(result.receipts.count,8)
        XCTAssertTrue(result.receipts.allSatisfy { $0.output == receipt.output })
        let replay=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt]+result.receipts,context:context))
        XCTAssertEqual(replay.text,report.text);try evidence(replay,receipt)
    }
    func testCandidateRoleReadingRetainsStaticActorsAndOnlyActualMovingChains() async throws {
        let (receipt,context)=try await fixture([8,7,7,7,9,6],args:["question":"核对自身对象","questionType":"health","subject":"self","event":"仅核对角色","timeHorizon":"near"])
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let section=try XCTUnwrap(report.sections.first { $0.id == "roles-original-4" })
        XCTAssertTrue(section.text.contains("元神：第3、5爻"))
        XCTAssertTrue(section.text.contains("忌神：第1、6爻"))
        XCTAssertTrue(section.text.contains("仇神：无"))
        XCTAssertTrue(section.text.contains("第6爻→第5爻"))
        XCTAssertTrue(section.text.contains("尚未裁定"))
        XCTAssertTrue(section.text.contains("忌克用的直接关系仍保留"))
        XCTAssertTrue(section.text.contains("墓绝"))
        for p in ["/lines/3/context","/lines/5/isChanging","/lines/4/isChanging","/lines/5/rules/returning/branchRelation","/lines/5/rules/advanceRetreat","/roleRelations/sourceId"] { XCTAssertTrue(section.evidence.contains { $0.pointer == p },p) }
        try evidence(report,receipt)
        let (allMoving,movingContext)=try await fixture([9,6,6,6,6,9])
        let movingReport=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[allMoving],context:movingContext))
        XCTAssertFalse(movingReport.text.contains("暗动"))
    }
    func testRoleReadingRejectsWrongCandidateActorsChainsSourcesAndMissingGroup() async throws {
        let (receipt,context)=try await fixture([8,7,7,7,9,6],args:["question":"核对自身对象","questionType":"health","subject":"self","event":"仅核对角色"])
        for mutation in 0..<8 {
            let invalid=try edited(receipt) { root in
                guard var role=root["roleRelations"] as? [String:Any],var groups=role["groups"] as? [[String:Any]],!groups.isEmpty else { return }
                if mutation == 0 { var refs=groups[0]["candidateRefs"] as! [[String:Any]];refs[0]["contextPath"]="/lines/1/context";groups[0]["candidateRefs"]=refs }
                if mutation == 1 { groups[0]["yuanPositions"]=[5] }
                if mutation == 2 { groups[0]["jiYuanMovingPairs"]=[["jiPosition":6,"yuanPosition":3]] }
                if mutation == 3 { var e=groups[0]["elements"] as! [String:Any];e["chou"]="木";groups[0]["elements"]=e }
                if mutation == 4 { role["sourceId"]="liuyao-day-clash-v1" }
                if mutation == 5 { groups=[] }
                if mutation == 6 { role["inspectedOriginalPaths"]=["/lines/0/changed"] }
                role["groups"]=groups;root["roleRelations"]=role
                if mutation == 7 { root.removeValue(forKey:"roleRelations") }
            }
            XCTAssertTrue(LiuyaoReferenceReading.render(receipts:[invalid],context:context) == nil,"mutation \(mutation)")
        }
    }

}
