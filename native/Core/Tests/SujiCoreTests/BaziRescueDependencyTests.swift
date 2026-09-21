import XCTest
@testable import SujiCore

final class BaziRescueDependencyTests:XCTestCase {
    private let base="/bazi/patternAnalysis/rescueEvidence/dependencyResolution"
    private func fixture(_ name:String)throws->JSONValue {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONDecoder().decode(JSONValue.self,from:Data(contentsOf:native.appendingPathComponent("Engine/validation/research-bazi/dependencies-2026-09-21/\(name).json")))
    }
    private func replace(_ root:JSONValue,_ path:String,_ value:JSONValue?)->JSONValue {
        func set(_ node:JSONValue,_ parts:ArraySlice<String>)->JSONValue {
            guard let key=parts.first else{return value ?? .null}
            if case var .object(object)=node {
                if parts.count==1{object[key]=value;return .object(object)}
                if let child=object[key]{object[key]=set(child,parts.dropFirst());return .object(object)}
            }
            if case var .array(array)=node,let i=Int(key),array.indices.contains(i){array[i]=set(array[i],parts.dropFirst());return .array(array)}
            XCTFail("Missing path \(path)");return node
        }
        return set(root,path.split(separator:"/").map(String.init)[...])
    }
    func testIndependentPropagationExplainsProtectionAndBlocking() throws {
        let protected=try XCTUnwrap(BaziAdjudicationTrace.make(root:fixture("protected")))
        XCTAssertTrue(protected.text.contains("癸受合牵制"),protected.text)
        XCTAssertTrue(protected.text.contains("丁制月令本气辛"),protected.text)
        let blocked=try XCTUnwrap(BaziAdjudicationTrace.make(root:fixture("blocked")))
        XCTAssertTrue(blocked.text.contains("救应路径受阻"),blocked.text)
        for name in ["protected","rooted-attacker","blocked","co-supported","selected","selected-rooted","lin","conflict"] {
            let root=try fixture(name),trace=try XCTUnwrap(BaziAdjudicationTrace.make(root:root),name)
            for path in trace.paths{XCTAssertNotNil(ReadingVerificationEvidence.pointer(path,in:root),path)}
        }
    }
    func testPositionSelectionAndCoSupportedPathsRemainDistinctFromGlobalSuccess() throws {
        let selected=try XCTUnwrap(BaziAdjudicationTrace.make(root:fixture("selected")))
        XCTAssertTrue(selected.text.contains("月干辛"));XCTAssertTrue(selected.text.contains("保留时干辛"))
        let rooted=try XCTUnwrap(BaziAdjudicationTrace.make(root:fixture("selected-rooted")))
        XCTAssertTrue(rooted.text.contains("有根"));XCTAssertTrue(rooted.text.contains("全局"))
        let multiple=try XCTUnwrap(BaziAdjudicationTrace.make(root:fixture("co-supported")))
        XCTAssertTrue(multiple.text.contains("并存"),multiple.text)
    }
    func testRejectsAlteredDependencyAndMissingNewPayloadWithoutLegacyDowngrade() throws {
        let root=try fixture("protected")
        let changes:[(String,JSONValue?)]=[
            (base+"/actions/1/status","blocked"),(base+"/actions/1/attacks/0/actorPosition",3),
            (base+"/actions/1/attacks/0/protectionCombinationIndexes",.array([])),
            (base+"/threatResolutions/1/status","unresolved"),(base+"/selectedYong","正官"),
            (base+"/outcomeEstablished",true),(base,nil),
            ("/bazi/patternAnalysis/conditionalEvidence/selectedYong","正官"),
            ("/bazi/patternAnalysis/conditionalEvidence/selectedYong",nil),
            ("/bazi/patternAnalysis/rescueEvidence/sources/4/quote","unsupported quote"),
            ("/bazi/patternAnalysis/rescueEvidence/sources/0/quote","unsupported helper rule"),
            ("/bazi/patternAnalysis/rescueEvidence/combinations/0/blockingPositions",.array([0])),
        ]
        for (path,value) in changes{XCTAssertNil(BaziAdjudicationTrace.make(root:replace(root,path,value)),path)}
    }
    func testLegacyReceiptWithoutNewSourceAndPayloadRemainsReadable() throws {
        let root=try fixture("protected")
        guard case var .array(sources)=ReadingVerificationEvidence.pointer("/bazi/patternAnalysis/rescueEvidence/sources",in:root) else{return XCTFail()}
        sources.removeLast()
        let legacy=replace(replace(root,base,nil),"/bazi/patternAnalysis/rescueEvidence/sources",.array(sources))
        XCTAssertNotNil(BaziAdjudicationTrace.make(root:legacy))
    }
    func testActualJSCFullBriefAndArchivedDocumentKeepResolvedAndBlockedDependencies() async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        for (day,status,phrase) in [(10,"unresolved","局部效力未定"),(20,"available","甲受合牵制后"),(30,"blocked","救应路径受阻")] {
            let request=#"{"command":"tool","name":"get_domain","arguments":{"domain":"事业"},"now":"2026-09-21T04:00:00Z","birth":{"year":1984,"month":9,"day":DAY,"hour":17,"minute":30,"gender":"男","longitude":120}}"#.replacingOccurrences(of:"DAY",with:String(day))
            let data=try await bridge.request(request),envelope=try JSONDecoder().decode(JSONValue.self,from:data)
            let root=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:envelope))
            XCTAssertEqual(ReadingVerificationEvidence.pointer(base+"/actions/0/status",in:root),.string(status))
            let context=try ToolContext(birth:nil,engineRevision:"bazi-dependency-regression",referenceDate:Date(timeIntervalSince1970:1_790_000_000),mode:"命理")
            let receipt=ToolReceipt(callID:"dependency-\(day)",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(root),context:context)
            let catalog=try XCTUnwrap(BaziFrameworkReading.catalog(receipts:[receipt],context:context))
            for id in ["pattern","pattern-brief"] {
                let claim=try XCTUnwrap(catalog.claims.first{$0.id==id})
                XCTAssertTrue(claim.text.contains(phrase),claim.text)
                XCTAssertTrue(claim.text.contains("不等于全局成败"),claim.text)
                XCTAssertTrue(claim.evidence.contains{$0.pointer==base+"/actions/0"})
                XCTAssertLessThanOrEqual(claim.evidence.count,48)
                XCTAssertLessThanOrEqual(claim.text.utf8.count,6_000)
                for field in claim.evidence{XCTAssertEqual(ReadingVerificationEvidence.pointer(field.pointer,in:root),field.value)}
            }
            let answer=BaziFrameworkReading.render(selection:nil,catalog:catalog,focus:.pattern)
            let userID=UUID(),document=ReadingDocument(catalog:catalog,answer:answer,sourceUserID:userID,focus:.pattern)
            XCTAssertTrue(document.isValid)
            var entry=ConversationEntry(role:"assistant",text:answer.text)
            entry.readingDocument=document;entry.toolReceipts=[receipt];entry.toolContext=context
            let restored=try JSONDecoder().decode(ConversationEntry.self,from:JSONEncoder().encode(entry))
            let receipts=try XCTUnwrap(restored.toolReceipts),saved=try XCTUnwrap(restored.readingDocument)
            XCTAssertTrue(saved.isValid)
            let replay=try XCTUnwrap(BaziFrameworkReading.catalog(receipts:receipts,context:context))
            XCTAssertEqual(replay.claims.first{$0.id=="pattern"}?.text,catalog.claims.first{$0.id=="pattern"}?.text)
            XCTAssertTrue(saved.sections.contains{$0.body.contains(phrase)})
        }
    }
    func testActualPositionCompetitionSurvivesNativeReadingAndDocumentLimits() async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        for (day,status) in [(11,"available"),(31,"retained")] {
            let request=#"{"command":"tool","name":"get_domain","arguments":{"domain":"事业"},"now":"2026-09-21T04:00:00Z","birth":{"year":1986,"month":3,"day":DAY,"hour":13,"minute":30,"gender":"男","longitude":120}}"#.replacingOccurrences(of:"DAY",with:String(day))
            let data=try await bridge.request(request)
            let root=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:JSONDecoder().decode(JSONValue.self,from:data)))
            XCTAssertEqual(ReadingVerificationEvidence.pointer(base+"/actions/0/status",in:root),.string(status))
            let context=try ToolContext(birth:nil,engineRevision:"bazi-position-regression",referenceDate:Date(timeIntervalSince1970:1_790_000_000),mode:"命理")
            let receipt=ToolReceipt(callID:"position-\(day)",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(root),context:context)
            let catalog=try XCTUnwrap(BaziFrameworkReading.catalog(receipts:[receipt],context:context))
            for id in ["pattern","pattern-brief"] {
                let claim=try XCTUnwrap(catalog.claims.first{$0.id==id})
                XCTAssertTrue(claim.text.contains("保留时干辛"),claim.text)
                XCTAssertTrue(claim.text.contains(day==11 ? "月干辛的局部受制作用成立":"月干辛仍保留作用"),claim.text)
                XCTAssertTrue(claim.evidence.contains{$0.pointer==base+"/actions/0"})
                XCTAssertLessThanOrEqual(claim.evidence.count,48)
                XCTAssertLessThanOrEqual(claim.text.utf8.count,6_000)
            }
            let answer=BaziFrameworkReading.render(selection:nil,catalog:catalog,focus:.pattern)
            XCTAssertTrue(ReadingDocument(catalog:catalog,answer:answer,sourceUserID:UUID(),focus:.pattern).isValid)
        }
    }

    func testCatalogRejectsContradictoryOrMissingSelectedYongInNewReceipt() async throws {
        let native=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let bridge=try MingliBridge(scriptURL:native.appendingPathComponent("Resources/mingli.js"))
        let data=try await bridge.request(#"{"command":"tool","name":"get_domain","arguments":{"domain":"事业"},"now":"2026-09-21T04:00:00Z","birth":{"year":1984,"month":9,"day":20,"hour":17,"minute":30,"gender":"男","longitude":120}}"#)
        let root=try XCTUnwrap(ReadingVerificationEvidence.pointer("/result",in:JSONDecoder().decode(JSONValue.self,from:data)))
        let path="/bazi/patternAnalysis/conditionalEvidence/selectedYong"
        let actual=try XCTUnwrap(ReadingVerificationEvidence.pointer(path,in:root))
        XCTAssertEqual(actual,ReadingVerificationEvidence.pointer("/bazi/patternAnalysis/yongShenShiShen",in:root))
        let context=try ToolContext(birth:nil,engineRevision:"bazi-yong-binding",referenceDate:Date(timeIntervalSince1970:1_790_000_000),mode:"命理")
        func catalog(_ value:JSONValue)->BaziFrameworkReading.Catalog? {
            let receipt=ToolReceipt(callID:"yong-binding",name:"get_domain",arguments:["domain":"事业"],output:ReadingVerificationEvidence.encoded(value),context:context)
            return BaziFrameworkReading.catalog(receipts:[receipt],context:context)
        }
        XCTAssertNotNil(catalog(root))
        for value:JSONValue? in [actual == "正官" ? "七杀":"正官", nil] {
            let changed=replace(root,path,value)
            XCTAssertNil(BaziAdjudicationTrace.make(root:changed))
            // The shared catalog supplies both full and brief readings, including fallback.
            XCTAssertNil(catalog(changed))
        }
    }
}
