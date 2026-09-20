import XCTest
@testable import SujiCore

final class LiuyaoTriadTests: XCTestCase {
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
        return (.init(callID:"fanfu-original",name:"cast_liuyao",arguments:args,output:ReadingVerificationEvidence.encoded(result),context:context),context)
    }

    // Test oracle: explicit route pools and literal branch triples, independent of native validator.
    private func proposed(_ receipt: ToolReceipt) throws -> [String:Any] {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any])
        let lines=root["lines"] as! [[String:Any]], calendar=root["castGanZhi"] as! [String:String]
        let tombs=(root["tombExtinction"] as! [String:Any])["objects"] as! [[String:Any]]
        func b(_ object:[String:Any])->String { String((object["ganZhi"] as! String).suffix(1)) }
        var routes:[(String,String?,[(String,String)])]=[("visible-originals",nil,lines.enumerated().map{("/lines/\($0.offset)",b($0.element))})]
        for i in lines.indices where lines[i]["isChanging"] as! Bool {
            routes.append(("calendar-moving-anchor","/lines/\(i)",[("/lines/\(i)",b(lines[i])),("/castGanZhi/month",String(calendar["month"]!.suffix(1))),("/castGanZhi/day",String(calendar["day"]!.suffix(1)))]))
        }
        for (scope,a,z) in [("inner-change",0,2),("outer-change",3,5)] where lines[a]["isChanging"] as! Bool && lines[z]["isChanging"] as! Bool {
            routes.append((scope,nil,[a,z].flatMap{[("/lines/\($0)",b(lines[$0])),("/lines/\($0)/changed",b(lines[$0]["changed"] as! [String:Any]))]}))
        }
        var groups=[[String:Any]]()
        for (scope,anchor,pool) in routes {
            for (letters,element) in [("申子辰","水"),("巳酉丑","金"),("寅午戌","火"),("亥卯未","木")] {
                let branches=letters.map(String.init), missing=branches.filter{branch in !pool.contains{$0.1==branch}}
                if missing.count>1 || (anchor != nil && !branches.contains(pool[0].1)) { continue }
                let members=branches.enumerated().map{j,branch -> [String:Any] in ["branch":branch,"role":["birth","center","tomb"][j],"objectPaths":pool.filter{$0.1==branch}.map{$0.0}]}
                let paths=branches.flatMap{branch in pool.filter{$0.1==branch}.map{$0.0}}, objects=paths.filter{$0.hasPrefix("/lines/")}
                groups.append(["scope":scope,"anchorPath":anchor as Any? ?? NSNull(),"element":element,"members":members,"missingBranches":missing,"complete":missing.isEmpty,"centerPresent": !missing.contains(branches[1]),"contextPaths":objects.map{$0+"/context"},"tombReferencePaths":objects.map{p in "/tombExtinction/objects/"+String(tombs.firstIndex{($0["objectPath"] as? String)==p}!)},"dayClashRulePaths":objects.filter{p in p.split(separator:"/").count==2 && (lines[Int(p.split(separator:"/")[1])!]["rules"] as? [String:Any])?["dayClash"] != nil}.map{$0+"/rules/dayClash"}])
            }
        }
        root["triads"]=["sourceId":"liuyao-triad-selected-v1","assessmentStatus":"structural-only","efficacyEstablished":false,"groups":groups,"unresolved":["motion-threshold","dark-movement","member-strength","void-break-effectiveness","tomb-effectiveness","clash-effectiveness","binding-or-transformation","selected-object","event-outcome"]]
        var sources=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-triad-selected-v1"}
        let urls=["https://zh.wikisource.org/wiki/增刪卜易/19","https://zh.wikisource.org/wiki/增刪卜易","https://zh.wikisource.org/wiki/易林補遺/1"]
        let hashes=["087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf","897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07","abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967"]
        sources.append(["id":"liuyao-triad-selected-v1","version":"1","editionStatus":"electronic-transcription-not-print-collated","references":urls.indices.map{["url":urls[$0],"sha256":hashes[$0],"locator":"三合结构与条件"]}]);root["ruleSources"]=sources
        return root
    }
    private func changed(_ receipt:ToolReceipt,_ root:[String:Any]) throws -> ToolReceipt {
        var copy=receipt;copy.output=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self);return copy
    }
    func testProposedEndpointReceiptRendersWithOriginalEvidence() async throws {
        let (base,context)=try await fixture([9,8,9,9,8,9])
        let receipt=try changed(base,proposed(base))
        let report=try XCTUnwrap(LiuyaoReferenceReading.render(receipts:[receipt],context:context),"B5b proposed triads must render")
        let root=try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
        let sections=report.sections.filter{$0.id.hasPrefix("triads-")}
        XCTAssertGreaterThan(sections.count,2)
        XCTAssertTrue(sections.contains{$0.text.contains("内卦") && $0.text.contains("木")})
        XCTAssertTrue(sections.contains{$0.text.contains("外卦") && $0.text.contains("金")})
        for section in sections { for evidence in section.evidence {
            XCTAssertEqual(evidence.toolCallID,base.callID)
            XCTAssertEqual(evidence.value,ReadingVerificationEvidence.pointer(evidence.pointer,in:root))
        } }
    }
    func testActualEngineLayerMatchesIndependentPoolOracleAndIndexesEmptyFields() async throws {
        for values in [[9,8,9,9,8,9],[9,8,6,8,8,8],[7,8,7,9,7,6],[7,7,7,7,7,7],[7,6,7,7,9,7]] {
            let (receipt,context)=try await fixture(values)
            let root=try JSONDecoder().decode(JSONValue.self,from:Data(receipt.output.utf8))
            let expected=try changed(receipt,proposed(receipt))
            let oracle=try JSONDecoder().decode(JSONValue.self,from:Data(expected.output.utf8))
            XCTAssertEqual(ReadingVerificationEvidence.pointer("/triads",in:root),ReadingVerificationEvidence.pointer("/triads",in:oracle))
            XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[receipt],context:context),"actual engine \(values)")
            let history:[ChatMessage]=[.assistantToolCalls([.init(id:receipt.callID,name:receipt.name,arguments:receipt.arguments)]),.toolResult(.init(callID:receipt.callID,output:receipt.output))]
            let facts=ReadingVerificationEvidence.facts(history)
            guard case let .array(groups)=ReadingVerificationEvidence.pointer("/triads/groups",in:root) else { return XCTFail("missing groups") }
            for i in groups.indices {
                let base="/triads/groups/\(i)"
                for key in ["scope","anchorPath","element","missingBranches","complete","centerPresent","contextPaths","tombReferencePaths","dayClashRulePaths"] {
                    let fact=try XCTUnwrap(facts.first{$0.pointer==base+"/"+key})
                    XCTAssertEqual(fact.value,ReadingVerificationEvidence.pointer(fact.pointer,in:root))
                }
                for j in 0..<3 { for key in ["branch","role","objectPaths"] {
                    let pointer=base+"/members/\(j)/"+key
                    XCTAssertEqual(try XCTUnwrap(facts.first{$0.pointer==pointer}).value,ReadingVerificationEvidence.pointer(pointer,in:root))
                } }
            }
        }
    }

    func testMalformedLayersSourcesAndJointForgeriesCannotRender() async throws {
        let (receipt,context)=try await fixture([9,8,9,9,8,9])
        let original=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any])
        XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[receipt],context:context))
        for mutation in 0..<27 {
            var root=original,layer=root["triads"] as! [String:Any],groups=layer["groups"] as! [[String:Any]]
            var members=groups[0]["members"] as! [[String:Any]]
            var sources=root["ruleSources"] as! [[String:Any]]
            let source=sources.firstIndex{($0["id"] as? String)=="liuyao-triad-selected-v1"}!
            switch mutation {
            case 0: groups[0]["complete"] = !(groups[0]["complete"] as! Bool)
            case 1: groups[0]["centerPresent"] = !(groups[0]["centerPresent"] as! Bool)
            case 2: groups[0]["missingBranches"]=["子","午"]
            case 3: groups[0]["anchorPath"]="/lines/1"
            case 4: groups[0]["scope"]="inner-change"
            case 5: groups[0]["element"]="土"
            case 6: members[0]["objectPaths"]=["/lines/1/changed"]
            case 7: members[0]["branch"]="丑"
            case 8: members[0]["role"]="center"
            case 9: groups[0]["contextPaths"]=["/lines/1/context"]
            case 10: groups[0]["tombReferencePaths"]=["/tombExtinction/objects/1"]
            case 11: groups[0]["dayClashRulePaths"]=["/lines/0/rules/dayClash"]
            case 12: layer["efficacyEstablished"]=true
            case 13: layer["unresolved"]=[]
            case 14: sources[source]["version"]="2"
            case 15: sources[source]["editionStatus"]="print-collated"
            case 16: sources.remove(at:source)
            case 17,18,19,20,21,22:
                var refs=sources[source]["references"] as! [[String:Any]]
                refs[(mutation-17)/2][mutation%2==1 ? "url" : "sha256"]="forged"
                sources[source]["references"]=refs
            case 23:
                var lines=root["lines"] as! [[String:Any]],c=lines[0]["context"] as! [String:Any]
                c["isVoid"] = !(c["isVoid"] as! Bool);lines[0]["context"]=c;root["lines"]=lines
            case 24:
                // Self-consistent triad rewrite still cannot override independently reconstructed Najia.
                var lines=root["lines"] as! [[String:Any]];lines[0]["ganZhi"]="甲子";root["lines"]=lines
                root=try proposed(changed(receipt,root));layer=root["triads"] as! [String:Any];groups=layer["groups"] as! [[String:Any]];members=groups[0]["members"] as! [[String:Any]]
            case 25: root.removeValue(forKey:"fanfu");sources=sources.filter{($0["id"] as? String) != "liuyao-fanfu-selected-v1"}
            default: root.removeValue(forKey:"tombExtinction");sources=sources.filter{($0["id"] as? String) != "liuyao-tomb-extinction-v1"}
            }
            groups[0]["members"]=members;layer["groups"]=groups;root["triads"]=layer;root["ruleSources"]=sources
            let bad=try changed(receipt,root)
            XCTAssertNotEqual(bad.output,receipt.output)
            XCTAssertNil(LiuyaoReferenceReading.render(receipts:[bad],context:context),"mutation \(mutation)")
        }
    }

    func testLegacySymmetryAndMissingEntireGroup() async throws {
        let (receipt,context)=try await fixture([7,7,7,7,7,7])
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(receipt.output.utf8)) as? [String:Any])
        let original=root
        root.removeValue(forKey:"triads")
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[try changed(receipt,root)],context:context))
        root["ruleSources"]=(root["ruleSources"] as! [[String:Any]]).filter{($0["id"] as? String) != "liuyao-triad-selected-v1"}
        XCTAssertNotNil(LiuyaoReferenceReading.render(receipts:[try changed(receipt,root)],context:context))
        root=original
        var layer=root["triads"] as! [String:Any];layer["groups"]=[];root["triads"]=layer
        XCTAssertNil(LiuyaoReferenceReading.render(receipts:[try changed(receipt,root)],context:context))
    }
}
