import XCTest
@testable import SujiCore

final class QimenReferenceReadingTests: XCTestCase {
    private func fixture(now: String = "2024-02-04T04:00:00Z", args: [String:Any] = ["question":"核对本次盘面","questionType":"event","subject":"self","event":"签约","timeHorizon":"near"]) async throws -> (ToolReceipt,ToolContext) {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let raw = try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:["command":"tool","name":"setup_qimen","arguments":args,"now":now]),as:UTF8.self))
        let envelope = try JSONDecoder().decode(JSONValue.self,from:raw)
        let result = try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .string(revision) = ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:result) else { throw EngineError.execution("Missing version") }
        let context = try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        return (ToolReceipt(callID:"chart-A",name:"setup_qimen",arguments:[:],output:ReadingVerificationEvidence.encoded(result),context:context),context)
    }
    private func edited(_ receipt: ToolReceipt, _ change: (inout [String:Any]) -> Void) throws -> ToolReceipt {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any])
        change(&object)
        var result = receipt
        result.output = String(decoding:try JSONSerialization.data(withJSONObject:object,options:.sortedKeys),as:UTF8.self)
        return result
    }
    private func assertEvidence(_ report: QimenReferenceReading.Report, receipt: ToolReceipt) throws {
        let root = try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
        XCTAssertEqual(report.sourceReceiptID,receipt.callID)
        for section in report.sections {
            XCTAssertFalse(section.evidence.isEmpty,section.id)
            for item in section.evidence {
                XCTAssertEqual(item.toolCallID,receipt.callID)
                XCTAssertEqual(item.value,ReadingVerificationEvidence.pointer(item.pointer,in:root),item.pointer)
            }
        }
    }
    func testActualChartSeparatesBothRolesAndBothHostedLayersWithoutModelProse() async throws {
        let (receipt,context) = try await fixture()
        let report = try XCTUnwrap(QimenReferenceReading.render(receipts:[receipt],context:context))
        let day = try XCTUnwrap(report.sections.first { $0.id == "day-stem" })
        let hour = try XCTUnwrap(report.sections.first { $0.id == "hour-stem" })
        for section in [day,hour] {
            XCTAssertTrue(section.text.contains("地盘戊在震宫"))
            XCTAssertTrue(section.text.contains("天盘戊在巽宫"))
            XCTAssertTrue(section.evidence.contains { $0.pointer == "/palaces/2/diPanGan" && $0.value == .string("戊") })
            XCTAssertTrue(section.evidence.contains { $0.pointer == "/palaces/3/tianPanGan" && $0.value == .string("戊") })
        }
        XCTAssertTrue(day.evidence.contains { $0.pointer == "/yongShen/candidates/0/id" && $0.value == .string("day-stem") })
        XCTAssertTrue(hour.evidence.contains { $0.pointer == "/yongShen/candidates/1/id" && $0.value == .string("hour-stem") })
        let hosted = try XCTUnwrap(report.sections.first { $0.id == "hosted-plates" })
        XCTAssertTrue(hosted.text.contains("地盘寄干庚在坤宫"))
        XCTAssertTrue(hosted.text.contains("天禽寄干庚在兑宫"))
        XCTAssertTrue(report.text.contains("产品参考约定"))
        XCTAssertTrue(report.text.contains("没有单列事项类别候选"))
        XCTAssertTrue(report.text.contains("尚未定用"))
        XCTAssertTrue(report.text.contains("不能确定日期"))
        XCTAssertFalse(report.text.contains("同干不同宫"))
        XCTAssertFalse(report.text.contains("由你指定"))
        try assertEvidence(report,receipt:receipt)
    }
    func testJiaUsesOwnCarrierAndCategoryCandidatesKeepTheirSources() async throws {
        let (receipt,context) = try await fixture(now:"2026-09-19T04:00:00Z",args:["question":"代问父亲","questionType":"wealth","subject":"parent","event":"采购","timeHorizon":"far"])
        let report = try XCTUnwrap(QimenReferenceReading.render(receipts:[receipt],context:context))
        let hour = try XCTUnwrap(report.sections.first { $0.id == "hour-stem" })
        XCTAssertTrue(hour.text.contains("时干甲"))
        XCTAssertTrue(hour.text.contains("本柱旬仪辛"))
        XCTAssertTrue(hour.text.contains("地盘辛在乾宫"))
        XCTAssertTrue(hour.text.contains("天盘辛在乾宫"))
        XCTAssertTrue(report.sections.contains { $0.id.hasPrefix("category-") && $0.text.contains("生门") })
        XCTAssertTrue(report.text.contains("代占"))
        XCTAssertFalse(report.text.contains("日干代表父亲"))
        try assertEvidence(report,receipt:receipt)
    }
    func testMissingContextAndConflictingOrUntrustedReceiptsDoNotCreateAReading() async throws {
        let (receipt,context) = try await fixture(args:["question":"核对盘面","questionType":"event"])
        let report = try XCTUnwrap(QimenReferenceReading.render(receipts:[receipt],context:context))
        for word in ["所问对象","具体事件","时间范围"] { XCTAssertTrue(report.text.contains(word),word) }
        var untrusted = receipt; untrusted.context = nil
        XCTAssertNil(QimenReferenceReading.render(receipts:[untrusted],context:context))
        let stale = try ToolContext(birth:nil,engineRevision:"other",referenceDate:context.referenceDate,mode:"起卦")
        XCTAssertNil(QimenReferenceReading.render(receipts:[receipt],context:stale))
        var conflict = try edited(receipt) { $0["hourGanZhi"] = "庚午" }; conflict.callID = "different"
        XCTAssertNil(QimenReferenceReading.render(receipts:[receipt,conflict],context:context))
        XCTAssertNil(QimenReferenceReading.render(receipts:[],context:context))
        var sparse = receipt; sparse.output = #"{"palaces":[{"id":2,"diPanGan":"庚"}]}"#
        XCTAssertNil(QimenReferenceReading.render(receipts:[sparse],context:context))
        var other = receipt; other.name = "cast_liuyao"
        XCTAssertNil(QimenReferenceReading.render(receipts:[receipt,other],context:context))
    }
    func testBrokenObjectPointersMissingOccurrenceOrSourceCannotBeRewrittenAsFacts() async throws {
        let (receipt,context) = try await fixture()
        for change in [0,1,2,3,4] {
            let invalid = try edited(receipt) { root in
                if change == 0 { root["ruleSources"] = []; return }
                if change == 1 { root["provenance"] = ["engineRevision":"wrong"]; return }
                var selection = root["yongShen"] as! [String:Any]
                if change == 2 { selection["selectionEstablished"] = true }
                else {
                    var candidates = selection["candidates"] as! [[String:Any]]
                    var occurrences = candidates[0]["occurrences"] as! [[String:Any]]
                    if change == 3 { occurrences[0]["objectPath"] = "/palaces/3/tianPanGan" }
                    else { occurrences.removeLast() }
                    candidates[0]["occurrences"] = occurrences; selection["candidates"] = candidates
                }
                root["yongShen"] = selection
            }
            XCTAssertNil(QimenReferenceReading.render(receipts:[invalid],context:context),"mutation \(change)")
        }
    }
    func testUnavailableDoesNotClaimAChartExistsAndExclusiveGateKeepsMixedRequests() async throws {
        let (receipt,context) = try await fixture()
        let missing = QimenReferenceReading.unavailableReply(receipts:[])
        XCTAssertTrue(missing.contains("尚未取得"))
        XCTAssertFalse(missing.contains("已有原盘"))
        var error = receipt; error.output = #"{"error":"failed"}"#
        XCTAssertEqual(QimenReferenceReading.unavailableReply(receipts:[error]),missing)
        XCTAssertNil(QimenReferenceReading.render(receipts:[error],context:context))
        let incomplete = QimenReferenceReading.unavailableReply(receipts:[receipt])
        XCTAssertTrue(incomplete.contains("计算记录"))
        XCTAssertFalse(incomplete.contains("已有原盘"))
        let qimen = ChatToolDefinition(name:"setup_qimen",description:"",parameters:[:])
        let liuyao = ChatToolDefinition(name:"cast_liuyao",description:"",parameters:[:])
        XCTAssertTrue(QimenReferenceReading.isExclusiveRequest(definitions:[qimen],question:"请用奇门"))
        XCTAssertFalse(QimenReferenceReading.isExclusiveRequest(definitions:[],question:"请用奇门"))
        XCTAssertFalse(QimenReferenceReading.isExclusiveRequest(definitions:[liuyao],question:"请用奇门"))
        XCTAssertFalse(QimenReferenceReading.isExclusiveRequest(definitions:[qimen,liuyao],question:"请用奇门"))
    }

    func testReorderedPalacesAndCategoryBreadthPreserveExactObjects() async throws {
        for (category,expected) in [("career",["category-door-开门","category-deity-值符"]),("marriage",["category-deity-六合"]),("health",["category-star-天芮"])] {
            let (receipt,context) = try await fixture(args:["question":"核对参考","questionType":category,"subject":"self","event":"核对","timeHorizon":"near"])
            let reordered = try edited(receipt) { root in
                let palaces = root["palaces"] as! [[String:Any]]
                root["palaces"] = Array(palaces.reversed())
                var selection = root["yongShen"] as! [String:Any]
                var candidates = selection["candidates"] as! [[String:Any]]
                for i in candidates.indices {
                    var occurrences = candidates[i]["occurrences"] as! [[String:Any]]
                    for j in occurrences.indices {
                        let parts = (occurrences[j]["objectPath"] as! String).split(separator:"/")
                        occurrences[j]["objectPath"] = "/palaces/\(8 - Int(parts[1])!)/\(parts[2])"
                    }
                    candidates[i]["occurrences"] = occurrences
                }
                selection["candidates"] = candidates; root["yongShen"] = selection
            }
            let report = try XCTUnwrap(QimenReferenceReading.render(receipts:[reordered],context:context))
            XCTAssertEqual(report.sections.filter { $0.id.hasPrefix("category-") }.map(\.id),expected)
            XCTAssertTrue(report.text.contains("地盘戊在震宫"))
            XCTAssertTrue(report.text.contains("天禽寄干庚在兑宫"))
            try assertEvidence(report,receipt:reordered)
        }
    }

    func testUnsupportedMetadataAndCorruptHostedFlagsFailClosed() async throws {
        let (receipt,context) = try await fixture()
        for change in 0...4 {
            let invalid = try edited(receipt) { root in
                if change == 0 {
                    var method = root["method"] as! [String:Any]; method["algorithm"] = "unknown"; root["method"] = method
                } else if change == 1 {
                    var sources = root["ruleSources"] as! [[String:Any]]
                    for i in sources.indices where sources[i]["id"] as? String == "qimen-question-references-v1" { sources[i]["version"] = "2" }
                    root["ruleSources"] = sources
                } else {
                    var palaces = root["palaces"] as! [[String:Any]]
                    if change == 2 { palaces[6]["hostsTianQin"] = false }
                    if change == 3 { palaces[3]["hostsTianQin"] = true }
                    if change == 4 { palaces[3]["hostedDiPanGan"] = "乙" }
                    root["palaces"] = palaces
                }
            }
            XCTAssertNil(QimenReferenceReading.render(receipts:[invalid],context:context),"host mutation \(change)")
        }
    }

    func testActualOrchestratorRetryUsesOriginalReceiptWithoutExecutingOrSavingAgain() async throws {
        let (receipt,context) = try await fixture()
        let expected = try XCTUnwrap(QimenReferenceReading.render(receipts:[receipt],context:context))
        let definition = ChatToolDefinition(name:"setup_qimen",description:"",parameters:["type":"object"])
        let orchestrator = ToolOrchestrator(complete: { messages,_ in
            if messages.contains(where: { $0.role == .tool }) { return .text("ready") }
            return .toolCalls((0..<8).map { ChatToolCall(id:"retry-\($0)",name:"setup_qimen",arguments:["question":"模型改写，不能更换原问题"]) })
        },execute: { _ in
            XCTFail("Retry must not recalculate"); return ToolExecutionResult(output:"{}")
        },persistReceipt: { _ in XCTFail("Retry must not save a new chart") })
        let result = try await orchestrator.run(history:[],definitions:[definition],cachedReceipts:[receipt],context:context)
        XCTAssertEqual(result.receipts.count,8)
        XCTAssertEqual(result.receipts[0].arguments,receipt.arguments)
        XCTAssertEqual(result.receipts[0].createdAt,receipt.createdAt)
        let report = try XCTUnwrap(QimenReferenceReading.render(receipts:[receipt] + result.receipts,context:context))
        XCTAssertEqual(report.text,expected.text)
        try assertEvidence(report,receipt:receipt)
    }

    func testAppSubsecondQuestionClockMatchesSerializedToolTimeButNotAnotherSecond() async throws {
        let (receipt,context) = try await fixture()
        let subsecondContext = try ToolContext(birth:nil,engineRevision:context.engineRevision,referenceDate:context.referenceDate.addingTimeInterval(0.789),mode:"起卦")
        var actual = receipt; actual.context = subsecondContext
        XCTAssertNotNil(QimenReferenceReading.render(receipts:[actual],context:subsecondContext))
        let different = try ToolContext(birth:nil,engineRevision:context.engineRevision,referenceDate:context.referenceDate.addingTimeInterval(1.001),mode:"起卦")
        actual.context = different
        XCTAssertNil(QimenReferenceReading.render(receipts:[actual],context:different))
    }

    func testJiaCarrierAndTianqinHostCannotBeInternallyReboundToOtherRealPositions() async throws {
        let (jia,context) = try await fixture(now:"2026-09-19T04:00:00Z")
        let wrongCarrier = try edited(jia) { root in
            let palaces = root["palaces"] as! [[String:Any]]
            var selection = root["yongShen"] as! [String:Any]
            var candidates = selection["candidates"] as! [[String:Any]]
            candidates[1]["carrierStem"] = "庚"
            var occurrences: [[String:Any]] = []
            for (index,palace) in palaces.enumerated() {
                for (field,plate) in [("diPanGan","earth"),("hostedDiPanGan","hosted-earth"),("tianPanGan","sky"),("hostedTianPanGan","hosted-sky")] where palace[field] as? String == "庚" {
                    let effectivePlate = field == "tianPanGan" && palace["id"] as? Int == 5 ? "center-record" : plate
                    occurrences.append(["objectPath":"/palaces/\(index)/\(field)","palaceId":palace["id"]!,"plate":effectivePlate,"isEffectiveSky":effectivePlate == "sky" || effectivePlate == "hosted-sky"])
                }
            }
            candidates[1]["occurrences"] = occurrences
            selection["candidates"] = candidates; root["yongShen"] = selection
        }
        XCTAssertNil(QimenReferenceReading.render(receipts:[wrongCarrier],context:context))

        let (receipt,ordinaryContext) = try await fixture()
        let wrongHost = try edited(receipt) { root in
            var palaces = root["palaces"] as! [[String:Any]]
            palaces[2]["hostsTianQin"] = true; palaces[2]["hostedTianPanGan"] = palaces[6]["hostedTianPanGan"]
            palaces[6].removeValue(forKey:"hostsTianQin"); palaces[6].removeValue(forKey:"hostedTianPanGan")
            root["tianQinPalaceId"] = 3; root["palaces"] = palaces
        }
        XCTAssertNil(QimenReferenceReading.render(receipts:[wrongHost],context:ordinaryContext))
    }

    func testActualIntentFilteringCannotTurnMixedSystemQuestionIntoExclusiveQimen() async throws {
        let native = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge = try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let data = try await bridge.request(#"{"command":"tools"}"#)
        for hasBirth in [true,false] {
            for other in ["八字","紫微","紫薇","六爻"] {
                let question = "请用奇门和\(other)分别分析这次租约"
                let definitions = try ReadingIntent.definitions(from:data,mode:"起卦",question:question,hasBirth:hasBirth)
                XCTAssertFalse(QimenReferenceReading.isExclusiveRequest(definitions:definitions,question:question),question)
            }
            let question = "请用奇门核对本次租约盘面"
            let definitions = try ReadingIntent.definitions(from:data,mode:"起卦",question:question,hasBirth:hasBirth)
            XCTAssertTrue(QimenReferenceReading.isExclusiveRequest(definitions:definitions,question:question))
        }
    }

}
