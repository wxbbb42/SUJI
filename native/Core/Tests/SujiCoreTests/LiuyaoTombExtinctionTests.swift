import XCTest
@testable import SujiCore

final class LiuyaoTombExtinctionTests: XCTestCase {
    private var native: URL { URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }

    private func fixture(_ values: [Int] = [7,7,7,7,7,7], now: String = "2024-02-04T04:00:00Z") async throws -> (ToolReceipt, ToolContext) {
        let script = try String(contentsOf:native.appendingPathComponent("Resources/mingli.js"),encoding:.utf8)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:temp) }
        let draws = values.flatMap { Array(repeating:0.75,count:$0-6) + Array(repeating:0.0,count:9-$0) }
        let file=temp.appendingPathComponent("engine.js")
        try (script+"\nlet n=0;const draws="+ReadingVerificationEvidence.encoded(draws)+";Math.random=()=>draws[n++];").write(to:file,atomically:true,encoding:.utf8)
        let bridge=try MingliBridge(scriptURL:file)
        let arguments:[String:JSONValue] = ["question":.string("我近期收款的条件"),"questionType":.string("wealth"),"subject":.string("self"),"event":.string("收款"),"timeHorizon":.string("near")]
        let request: [String:JSONValue] = ["command":.string("tool"),"name":.string("cast_liuyao"),"arguments":.object(arguments),"now":.string(now)]
        let data=try await bridge.request(ReadingVerificationEvidence.encoded(request))
        let envelope=try JSONDecoder().decode(JSONValue.self,from:data)
        let root=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root) else { throw EngineError.execution("revision") }
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        return (.init(callID:"tomb-original",name:"cast_liuyao",arguments:.object(arguments),output:ReadingVerificationEvidence.encoded(root),context:context),context)
    }

    private func edited(_ receipt:ToolReceipt,_ change:(inout [String:Any])->Void) throws -> ToolReceipt {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any]);change(&root)
        var result=receipt;result.output=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self);return result
    }

    func testActualCalendarTombsHaveSeparateObjectsAndConditionalEvidence() async throws {
        let (receipt,context)=try await fixture()
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let root=try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/castGanZhi/month",in:root),.string("乙丑"))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/castGanZhi/day",in:root),.string("戊戌"))
        let metal=try XCTUnwrap(report.sections.first{$0.id=="tomb-5-original"})
        let fire=try XCTUnwrap(report.sections.first{$0.id=="tomb-4-original"})
        XCTAssertTrue(metal.text.contains("月支丑为墓"))
        XCTAssertTrue(metal.text.contains("土生金"))
        XCTAssertTrue(fire.text.contains("日支戌为墓"))
        XCTAssertTrue(report.text.contains("效力未定"))
        XCTAssertFalse(report.text.contains("已入真墓"))
        for section in report.sections.filter({$0.id.hasPrefix("tomb-")}) {
            XCTAssertFalse(section.evidence.isEmpty)
            for field in section.evidence {
                XCTAssertEqual(field.toolCallID,receipt.callID)
                XCTAssertEqual(field.value,ReadingVerificationEvidence.pointer(field.pointer,in:root),field.pointer)
            }
        }
        XCTAssertTrue(metal.evidence.contains{$0.pointer=="/lines/4/context/month/elementRelation"})
        let restored=try JSONDecoder().decode(ToolReceipt.self,from:JSONEncoder().encode(receipt))
        XCTAssertEqual(LiuyaoReferenceReading.render(receipts:[restored],context:context)?.text,report.text)
    }

    func testHiddenAndChangedRowsKeepTheirOwnReferenceScope() async throws {
        let (receipt,context)=try await fixture([6,7,7,7,7,7])
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let original=try XCTUnwrap(report.sections.first{$0.id=="tomb-1-original"})
        let changed=try XCTUnwrap(report.sections.first{$0.id=="tomb-1-changed"})
        let hidden=try XCTUnwrap(report.sections.first{$0.id=="tomb-2-hidden"})
        XCTAssertTrue(original.text.contains("同位化爻"))
        XCTAssertFalse(changed.text.contains("同位化爻"))
        XCTAssertTrue(hidden.text.contains("本位飞神"))
        XCTAssertTrue(hidden.evidence.contains{$0.pointer=="/lines/1/hidden/wuXing"})
        XCTAssertFalse(changed.text.contains("动墓爻位"))
    }

    func testWrongTableObjectActorSourceAndEfficacyAreRejected() async throws {
        let (receipt,context)=try await fixture([6,7,7,7,7,7])
        let root=try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
        _=try XCTUnwrap(ReadingVerificationEvidence.pointer("/tombExtinction/objects",in:root))
        for mutation in 0..<8 {
            let invalid=try edited(receipt){root in
                var layer=root["tombExtinction"] as! [String:Any]
                var rows=layer["objects"] as! [[String:Any]]
                switch mutation {
                case 0: rows[0]["month"]="墓"
                case 1: rows[0]["objectPath"]="/lines/1"
                case 2: rows[1]["movingTombPositions"]=[1]
                case 3: rows[2]["ownChange"]="绝"
                case 4: layer["efficacyEstablished"]=true
                case 5: layer["sourceId"]="liuyao-calendar-relations-v1"
                case 6: rows.removeLast()
                default: root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-tomb-extinction-v1"}
                }
                layer["objects"]=rows;root["tombExtinction"]=layer
            }
            XCTAssertNil(LiuyaoReferenceReading.render(receipts:[invalid],context:context),"mutation \(mutation)")
        }
    }

    func testEarthSiExceptionKeepsDaySupportAndRejectsBorrowedSourceContext() async throws {
        let (receipt,context)=try await fixture([8,8,8,8,8,8],now:"2024-02-11T04:00:00Z")
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let first=try XCTUnwrap(report.sections.first{$0.id=="tomb-1-original"})
        XCTAssertTrue(first.text.contains("日支巳为绝"))
        XCTAssertTrue(first.text.contains("日对该对象生爻"))
        XCTAssertTrue(first.text.contains("不能见巳就认定绝已成立"))
        XCTAssertTrue(first.evidence.contains{$0.pointer=="/lines/0/context/day/elementRelation" && $0.value == .string("生爻")})
        let corrupted=try edited(receipt){root in
            var lines=root["lines"] as! [[String:Any]],c=lines[0]["context"] as! [String:Any],day=c["day"] as! [String:Any]
            day["elementRelation"]="克爻";c["day"]=day;lines[0]["context"]=c;root["lines"]=lines
        }
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[corrupted],context:context))
    }
}
