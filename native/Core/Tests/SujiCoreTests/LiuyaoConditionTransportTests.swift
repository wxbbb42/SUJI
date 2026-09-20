import XCTest
@testable import SujiCore

final class LiuyaoConditionTransportTests: XCTestCase {
    private func layoutFixture() -> JSONValue {
        guard case var .object(root)=fixture() else { fatalError("fixture") }
        root["contexts"] = .array((0..<24).map { index in
            ["calendarInfluence":["ganZhi":"丁酉","elementRelation":.string(index % 2 == 0 ? "生爻" : "克爻"),"sameBranch":.bool(index % 3 == 0),"clash":false,"combination":false],
             "originalObjectPath":.string("/lines/\(index % 6)"),"monthState":"囚","futureField":.null,"emptyPositions":[]]
        })
        return .object(root)
    }

    func testObjectLayoutsRestoreNestedFieldsNullFalseAndLegacyConditionsExactly() throws {
        let original=layoutFixture(),raw=ReadingVerificationEvidence.encoded(original)
        let legacy=LiuyaoConditionTransport.encode(raw)
        let packed=LiuyaoConditionTransport.encodeLayouts(legacy)
        XCTAssertLessThan(packed.utf16.count,legacy.utf16.count - 1_000)
        let value=try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))
        XCTAssertNotNil(ReadingVerificationEvidence.pointer("/liuyaoObjectRows",in:value))
        XCTAssertEqual(LiuyaoConditionTransport.expand(value),original)
        XCTAssertEqual(LiuyaoConditionTransport.encodeLayouts(packed),packed)
        XCTAssertEqual(LiuyaoConditionTransport.expand(try JSONDecoder().decode(JSONValue.self,from:Data(legacy.utf8))),original)
        func facts(_ output:String) -> [String:JSONValue] {
            Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts([.assistantToolCalls([.init(id:"layout",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"layout",output:output))]).map{($0.factKey,.array([.string($0.pointer),$0.value]))})
        }
        XCTAssertEqual(facts(packed),facts(raw))
    }

    func testMalformedObjectLayoutsFailClosedWithoutPartialFacts() throws {
        let packed=LiuyaoConditionTransport.encodeLayouts(LiuyaoConditionTransport.encode(ReadingVerificationEvidence.encoded(layoutFixture())))
        let original=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(packed.utf8)) as? [String:Any])
        let originalMetadata=try XCTUnwrap(original["liuyaoObjectRows"] as? [String:Any])
        let originalLayouts=try XCTUnwrap(originalMetadata["layouts"] as? [[String]])
        var variants:[[String:Any]]=[]
        var missing=original;missing.removeValue(forKey:"liuyaoObjectRows");variants.append(missing)
        for field in ["version","layouts","format"] {
            var root=original,metadata=originalMetadata
            if field == "version" { metadata[field]=99 } else { metadata[field]="bad" }
            root["liuyaoObjectRows"]=metadata;variants.append(root)
        }
        for layouts:[Any] in [[],originalLayouts + [originalLayouts[0]],originalLayouts + [["unusedField"]],[["duplicate","duplicate"]],[["$row"]],[[""]],[[false]]] {
            var root=original,metadata=originalMetadata;metadata["layouts"]=layouts
            root["liuyaoObjectRows"]=metadata;variants.append(root)
        }
        for marker:Any in [[],[-1],[999],[0.5],[false],[0],[0,"extra"],"bad"] {
            var root=original,contexts=root["contexts"] as! [Any]
            contexts[0] = ["$row":marker];root["contexts"]=contexts;variants.append(root)
        }
        var extra=original,contexts=extra["contexts"] as! [[String:Any]]
        contexts[0]["extra"]=false;extra["contexts"]=contexts;variants.append(extra)
        var partial=original
        partial["contexts"]=try JSONSerialization.jsonObject(with:Data(ReadingVerificationEvidence.encoded(ReadingVerificationEvidence.pointer("/contexts",in:layoutFixture())!).utf8))
        variants.append(partial)
        for root in variants {
            let data=try JSONSerialization.data(withJSONObject:root),value=try JSONDecoder().decode(JSONValue.self,from:data)
            XCTAssertNil(LiuyaoConditionTransport.expand(value))
            XCTAssertTrue(ReadingVerificationEvidence.facts([.assistantToolCalls([.init(id:"bad",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"bad",output:String(decoding:data,as:UTF8.self)))]).isEmpty)
        }
    }

    func testLayoutReservedKeyCollisionsAreNotReencoded() {
        for value:JSONValue in [["liuyaoObjectRows":false,"lines":[]],["nested":["$row":"future-schema"]]] {
            let raw=ReadingVerificationEvidence.encoded(value)
            XCTAssertEqual(LiuyaoConditionTransport.encodeLayouts(raw),raw)
        }
    }

    func testLayoutProjectionAuthenticationRejectsValidEditedValues() throws {
        guard case var .object(root)=layoutFixture() else { return XCTFail("fixture") }
        let question=String(repeating:"问",count:1600)
        root["question"] = .string(question);root["unchangedPayload"] = .string(String(repeating:"x",count:28_000))
        let raw=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        let call=ChatToolCall(id:"layout-auth",name:"cast_liuyao",arguments:["question":.string(question)])
        let context=try ToolContext(birth:nil,engineRevision:"transport-test",referenceDate:Date(timeIntervalSince1970:0),mode:"起卦")
        let receipt=ToolReceipt(callID:call.id,name:call.name,arguments:call.arguments,output:raw,evidence:[call.id],context:context)
        let prefix=[ChatMessage.assistantToolCalls([call])]
        let projected=NatalEvidenceProjection.output(raw,name:call.name,delivered:prefix,callID:call.id)
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:prefix+[.toolResult(.init(callID:call.id,output:projected))]))
        var edited=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(projected.utf8)) as? [String:Any])
        let layouts=(edited["liuyaoObjectRows"] as! [String:Any])["layouts"] as! [[String]]
        var contexts=edited["contexts"] as! [[String:Any]],row=contexts[0]["$row"] as! [Any]
        let index=row[0] as! Int,column=try XCTUnwrap(layouts[index].firstIndex(of:"monthState"))
        row[column+1]="旺";contexts[0]["$row"]=row;edited["contexts"]=contexts
        let editedData=try JSONSerialization.data(withJSONObject:edited),value=try JSONDecoder().decode(JSONValue.self,from:editedData)
        XCTAssertNotNil(LiuyaoConditionTransport.expand(value),"Valid changed data must still fail receipt authentication")
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:prefix+[.toolResult(.init(callID:call.id,output:ReadingVerificationEvidence.encoded(value)))]))
        XCTAssertEqual(receipt.output,raw)
    }

    func testUnknownSpecialAndEmptyObjectKeysRoundTripWithoutPrototypeSemantics() throws {
        let original:JSONValue=["records":.array((0..<24).map { _ in ["__proto__":["polluted":true],"constructor":false,"prototype":.null,"unknownFutureValue":["a/b~c":"原文"]] }),"emptyKey":["":[]]]
        let raw=ReadingVerificationEvidence.encoded(original),packed=LiuyaoConditionTransport.encodeLayouts(raw)
        XCTAssertNotEqual(packed,raw)
        XCTAssertEqual(LiuyaoConditionTransport.expand(try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))),original)
    }

    private func fixture() -> JSONValue {
        let conditions: [JSONValue] = [
            ["id":"changed-month-break","state":"matched","factPaths":["/lines/0/changed/context/month/clash"]],
            ["id":"combined-effectiveness","state":"unresolved","factPaths":[]],
            ["id":"changed-day-support","state":"not-matched","factPaths":["/lines/0/context/isVoid"]]
        ]
        return ["lines":.array((0..<6).map { _ in ["rules":["returning":["conditions":.array(conditions)],"advanceRetreat":["conditions":.array(conditions)]]] }),
                "tombExtinction":["efficacyEstablished":false,"objects":[]],"question":"原始问题"]
    }

    func testLosslessRoundTripPreservesOrderEmptyPathsStatesAndEveryOtherField() throws {
        let original=fixture(), raw=ReadingVerificationEvidence.encoded(original)
        let packed=LiuyaoConditionTransport.encode(raw)
        XCTAssertLessThan(packed.utf16.count,raw.utf16.count)
        let value=try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))
        XCTAssertNotNil(ReadingVerificationEvidence.pointer("/ruleConditionRows",in:value))
        XCTAssertEqual(LiuyaoConditionTransport.expand(value),original)
        XCTAssertEqual(LiuyaoConditionTransport.encode(packed),packed)
        let call=ChatToolCall(id:"receipt",name:"cast_liuyao",arguments:[:])
        func facts(_ output:String) -> [String:JSONValue] {
            Dictionary(uniqueKeysWithValues:ReadingVerificationEvidence.facts([.assistantToolCalls([call]),.toolResult(.init(callID:call.id,output:output))]).map{($0.factKey,.array([.string($0.pointer),$0.value]))})
        }
        XCTAssertEqual(facts(packed),facts(raw))
    }

    func testMalformedLayoutOrRowsCannotYieldPartialEvidence() throws {
        let packed=LiuyaoConditionTransport.encode(ReadingVerificationEvidence.encoded(fixture()))
        let original=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(packed.utf8)) as? [String:Any])
        var variants:[[String:Any]]=[]
        var missing=original;missing.removeValue(forKey:"ruleConditionRows");variants.append(missing)
        for field in ["version","columns","ids","states","paths"] {
            var root=original,format=root["ruleConditionRows"] as? [String:Any] ?? [:]
            if field == "version" { format[field]=99 } else { format[field]=["bad","bad"] }
            root["ruleConditionRows"]=format;variants.append(root)
        }
        for row:[Any] in [[999,0,[]],[-1,0,[]],[0.5,0,[]],[0,"invented",[]],[0,3,[]],[0,-1,[]],[0,0.5,[]],[0,0,[false]],[0,0,[-1]],[0,0,[999]],[0,0],[0,0,[],"extra"]] {
            var root=original,lines=root["lines"] as! [[String:Any]],rules=lines[0]["rules"] as! [String:Any],rule=rules["returning"] as! [String:Any]
            rule["conditions"]=[row];rules["returning"]=rule;lines[0]["rules"]=rules;root["lines"]=lines;variants.append(root)
        }
        for root in variants {
            let data=try JSONSerialization.data(withJSONObject:root),value=try JSONDecoder().decode(JSONValue.self,from:data)
            XCTAssertNil(LiuyaoConditionTransport.expand(value))
            XCTAssertTrue(ReadingVerificationEvidence.facts([.assistantToolCalls([.init(id:"bad",name:"cast_liuyao",arguments:[:])]),.toolResult(.init(callID:"bad",output:String(decoding:data,as:UTF8.self)))]).isEmpty)
        }
    }

    func testLegacyAndUnknownConditionFieldsRemainIntact() throws {
        XCTAssertEqual(LiuyaoConditionTransport.expand(fixture()),fixture())
        var root=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(ReadingVerificationEvidence.encoded(fixture()).utf8)) as? [String:Any])
        var lines=root["lines"] as! [[String:Any]],rules=lines[0]["rules"] as! [String:Any],rule=rules["returning"] as! [String:Any]
        var conditions=rule["conditions"] as! [[String:Any]]
        conditions[0]["futureField"]=false
        rule["conditions"]=conditions;rules["returning"]=rule;lines[0]["rules"]=rules;root["lines"]=lines
        let raw=String(decoding:try JSONSerialization.data(withJSONObject:root),as:UTF8.self)
        XCTAssertEqual(LiuyaoConditionTransport.encode(raw),raw)
    }

    func testProjectedReceiptAuthenticationRejectsEditedConditionsAndMissingQuestionSource() throws {
        guard case var .object(root)=fixture() else { return XCTFail("fixture") }
        let question=String(repeating:"问",count:1600)
        root["question"] = .string(question);root["unchangedPayload"] = .string(String(repeating:"x",count:28_000))
        let raw=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        let call=ChatToolCall(id:"original",name:"cast_liuyao",arguments:["question":.string(question)])
        let context=try ToolContext(birth:nil,engineRevision:"transport-test",referenceDate:Date(timeIntervalSince1970:0),mode:"起卦")
        let receipt=ToolReceipt(callID:call.id,name:call.name,arguments:call.arguments,output:raw,evidence:[call.id],context:context)
        let prefix=[ChatMessage.assistantToolCalls([call])]
        let projected=NatalEvidenceProjection.output(raw,name:call.name,delivered:prefix,callID:call.id)
        XCTAssertTrue(projected.contains("ruleConditionRows"));XCTAssertTrue(projected.contains("questionFromArguments"))
        let tool=ChatMessage.toolResult(.init(callID:call.id,output:projected))
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:prefix+[tool]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[tool]))
        let expanded=try XCTUnwrap(LiuyaoConditionTransport.expand(JSONDecoder().decode(JSONValue.self,from:Data(projected.utf8))))
        let legacy=LiuyaoConditionTransport.encode(ReadingVerificationEvidence.encoded(expanded))
        XCTAssertTrue(NatalEvidenceProjection.wasDelivered(receipt,in:prefix+[.toolResult(.init(callID:call.id,output:legacy))]))
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:[.toolResult(.init(callID:call.id,output:legacy))]))
        var editedRoot=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(legacy.utf8)) as? [String:Any])
        var editedLines=editedRoot["lines"] as! [[String:Any]],editedRules=editedLines[0]["rules"] as! [String:Any],editedRule=editedRules["returning"] as! [String:Any],editedRows=editedRule["conditions"] as! [[Any]]
        editedRows[0][1]=1
        editedRule["conditions"]=editedRows;editedRules["returning"]=editedRule;editedLines[0]["rules"]=editedRules;editedRoot["lines"]=editedLines
        let editedValue=try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:editedRoot))
        XCTAssertNotNil(LiuyaoConditionTransport.expand(editedValue),"A valid but different condition is still not authenticated")
        let edited=ReadingVerificationEvidence.encoded(editedValue)
        XCTAssertNotEqual(edited,projected)
        XCTAssertFalse(NatalEvidenceProjection.wasDelivered(receipt,in:prefix+[.toolResult(.init(callID:call.id,output:edited))]))
        XCTAssertEqual(NatalEvidenceProjection.output(raw,name:"setup_qimen",delivered:[],callID:call.id),raw)
    }
}
