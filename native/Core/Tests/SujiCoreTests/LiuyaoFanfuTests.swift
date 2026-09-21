import XCTest
@testable import SujiCore

final class LiuyaoFanfuTests: XCTestCase {
    private func fixture(_ values:[Int]) async throws -> (ToolReceipt,ToolContext) {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script=try String(contentsOf:native.appendingPathComponent("Resources/mingli.js"),encoding:.utf8)
        let temp=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:temp,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:temp) }
        let draws=values.flatMap{Array(repeating:0.75,count:$0-6)+Array(repeating:0.0,count:9-$0)}
        let file=temp.appendingPathComponent("engine.js")
        try (script+"\nlet n=0;const draws="+ReadingVerificationEvidence.encoded(draws)+";Math.random=()=>draws[n++];").write(to:file,atomically:true,encoding:.utf8)
        let bridge=try MingliBridge(scriptURL:file),now="2026-09-20T04:00:00Z"
        let args:JSONValue=["question":"核对这次卦的条件","questionType":"general","subject":"self","event":"核对条件","timeHorizon":"near"]
        let data=try await bridge.request(ReadingVerificationEvidence.encoded(JSONValue.object(["command":"tool","name":"cast_liuyao","arguments":args,"now":.string(now)])))
        let result=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:JSONDecoder().decode(JSONValue.self,from:data)))
        guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:result) else { throw EngineError.execution("revision") }
        let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:now)!,mode:"起卦")
        return (.init(callID:"fanfu-original",name:"cast_liuyao",arguments:args,output:try CastReceiptStorage.encode(ReadingVerificationEvidence.encoded(result)),context:context),context)
    }

    func testDifferentStemsCanRepeatBranchesWithoutGivingStaticLinesChangedObjects() async throws {
        let (receipt,context)=try await fixture([8,7,7,7,9,9]) // 姤→恒，壬申/戌→庚申/戌
        let root=try JSONDecoder().decode(JSONValue.self,from:try CastReceiptStorage.expandedData(receipt.output))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/lines/0/originalPath",in:root),"/lines/4")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/lines/0/sameStem",in:root),false)
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/lines/0/sameBranch",in:root),true)
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/0/branchRelation",in:root),"unchanged")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/1/branchRelation",in:root),"repeated")
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        let section=try XCTUnwrap(report.sections.first{$0.id=="fanfu-line-5"})
        XCTAssertTrue(section.text.contains("同支"));XCTAssertTrue(section.text.contains("异干"))
        XCTAssertNil(report.sections.first{$0.id=="fanfu-line-4"})
        for section in report.sections.filter({$0.id.hasPrefix("fanfu-")}) {
            XCTAssertFalse(section.evidence.isEmpty)
            for field in section.evidence {
                XCTAssertEqual(field.toolCallID,receipt.callID)
                XCTAssertEqual(field.value,ReadingVerificationEvidence.pointer(field.pointer,in:root),field.pointer)
            }
        }
        let history:[ChatMessage]=[.assistantToolCalls([.init(id:receipt.callID,name:receipt.name,arguments:receipt.arguments)]),.toolResult(.init(callID:receipt.callID,output:receipt.output))]
        let facts=Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts(history).map{($0.factKey,$0)})
        XCTAssertEqual(facts["liuyao.fanfu.line1.sameStem"]?.value,false)
        XCTAssertEqual(facts["liuyao.fanfu.line1.sameStem"]?.pointer,"/fanfu/lines/0/sameStem")
        XCTAssertEqual(facts["liuyao.fanfu.trigram1.movingPositions"]?.value,[])
    }

    func testBranchOppositionAndSelectedDirectionalOppositionStaySeparate() async throws {
        let (bi,context)=try await fixture([8,6,6,8,7,8]) // 比→井
        let root=try JSONDecoder().decode(JSONValue.self,from:try CastReceiptStorage.expandedData(bi.output))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/0/branchRelation",in:root),"opposed")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/0/directionalOpposition",in:root),false)
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[bi],context:context))
        XCTAssertNotNil(report.sections.first{$0.id=="fanfu-line-2"})
        XCTAssertNil(report.sections.first{$0.id=="fanfu-line-1"})
        let (directional,other)=try await fixture([9,7,7,9,7,7]) // 乾→巽
        let second=try JSONDecoder().decode(JSONValue.self,from:try CastReceiptStorage.expandedData(directional.output))
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/0/branchRelation",in:second),"neither")
        XCTAssertEqual(ReadingVerificationEvidence.pointer("/fanfu/trigrams/0/directionalOpposition",in:second),true)
        XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[directional],context:other)?.sections.first{$0.id=="fanfu-lower"})
    }

    func testStaticPureChartAndLegacyArchiveDoNotAcquireDynamicFanfu() async throws {
        let (receipt,context)=try await fixture([7,7,7,7,7,7])
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(receipt.output)) as? [String:Any])
        let layer=try XCTUnwrap(root["fanfu"] as? [String:Any])
        XCTAssertEqual((layer["lines"] as? [Any])?.count,0)
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        XCTAssertFalse(report.sections.contains{$0.id.hasPrefix("fanfu-line-")})
        root.removeValue(forKey:"fanfu")
        // A pre-fanfu archive also predates the later triad layer that requires it.
        root.removeValue(forKey:"triads")
        root.removeValue(forKey:"efficacy")
        root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{!["liuyao-fanfu-selected-v1","liuyao-triad-selected-v1","liuyao-efficacy-zengshan-v1"].contains($0["id"] as? String ?? "")}
        var legacy=receipt;legacy.output=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self)
        XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[legacy],context:context))
    }

    func testWrongScopeMembershipFlagsSourceAndEfficacyCannotRender() async throws {
        let (receipt,context)=try await fixture([8,6,6,8,7,8])
        let original=try XCTUnwrap(JSONSerialization.jsonObject(with:try CastReceiptStorage.expandedData(receipt.output)) as? [String:Any])
        _=try XCTUnwrap(original["fanfu"])
        for mutation in 0..<13 {
            var root=original,layer=root["fanfu"] as! [String:Any],lines=layer["lines"] as! [[String:Any]],trigrams=layer["trigrams"] as! [[String:Any]]
            switch mutation {
            case 0: lines[0]["originalPath"]="/lines/0"
            case 1: lines[0]["changedPath"]="/lines/2/changed"
            case 2: lines[0]["branchClash"]=false
            case 3: lines.removeLast()
            case 4: trigrams[0]["movingPositions"]=[1,2,3]
            case 5: trigrams[1]["branchRelation"]="repeated"
            case 6: trigrams[0]["directionalOpposition"]=true
            case 7: layer["efficacyEstablished"]=true
            case 8: root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-fanfu-selected-v1"}
            case 9:
                // Two mutually consistent labels still disagree with lineValues.
                var gua=root["benGua"] as! [String:Any];gua["lower"]="乾";root["benGua"]=gua
                trigrams[0]["from"]="乾"
            case 10:
                var relation=root["guaRelations"] as! [String:Any],projection=relation["original"] as! [String:Any]
                var branches=projection["ganZhi"] as! [String];branches[0]="甲子";projection["ganZhi"]=branches
                relation["original"]=projection;root["guaRelations"]=relation
            case 11:
                var chart=root["lines"] as! [[String:Any]];chart[0]["changed"]=chart[1]["changed"];root["lines"]=chart
            default:
                var sources=root["ruleSources"] as! [[String:Any]]
                let index=sources.firstIndex{($0["id"] as? String)=="liuyao-fanfu-selected-v1"}!
                var refs=sources[index]["references"] as! [[String:Any]];refs[0]["sha256"]="forged"
                sources[index]["references"]=refs;root["ruleSources"]=sources
            }
            layer["lines"]=lines;layer["trigrams"]=trigrams;root["fanfu"]=layer
            var bad=receipt;bad.output=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self)
            XCTAssertNotEqual(bad.output,receipt.output)
            XCTAssertNil(LiuyaoReferenceReading.render(receipts:[bad],context:context),"mutation \(mutation)")
        }
    }
}
