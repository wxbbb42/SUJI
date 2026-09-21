import XCTest
@testable import SujiCore

/// Independent test inverse: reconstruct every identity and follow original
/// pointers; no values are obtained from the expected facts under comparison.
enum ReferenceFactIndexTestDecoder {
    static func identity(_ id: String, _ key: String, _ pointer: String) -> String {
        ReadingVerificationEvidence.encoded([id, key, pointer])
    }
    static func restore(_ raw:String,history:[ChatMessage]) throws -> [String:JSONValue] {
        let root=try JSONSerialization.jsonObject(with:Data(raw.utf8)) as! [String:Any]
        let ids=root["toolCallIDs"] as! [String], sequences=root["numberSequences"] as! [Any]
        var charts:[String:JSONValue]=[:],result:[String:JSONValue]=[:]
        for (i,m) in history.enumerated() where m.role == .tool {
            charts[m.toolCallID!]=ToolOutputWire.decode(m,history:Array(history.prefix(i)))
        }
        let tokens = try XCTUnwrap(root["stringTokens"] as? [String])
        let version = try XCTUnwrap(root["referenceIndexVersion"] as? Int)
        XCTAssertTrue([1,2].contains(version))
        let nodes: [[Int]]
        let patterns: [[Any]]
        if version == 2 {
            let flatNodes = try XCTUnwrap(root["stringNodes"] as? [Int])
            let flatPatterns = try XCTUnwrap(root["patterns"] as? [Any])
            XCTAssertEqual(flatNodes.count % 2,0); XCTAssertEqual(flatPatterns.count % 4,0)
            nodes = stride(from:0,to:flatNodes.count,by:2).map{Array(flatNodes[$0..<($0+2)])}
            patterns = stride(from:0,to:flatPatterns.count,by:4).map{Array(flatPatterns[$0..<($0+4)])}
        } else {
            nodes = try XCTUnwrap(root["stringNodes"] as? [[Int]])
            patterns = try XCTUnwrap(root["patterns"] as? [[Any]])
        }
        var parts: [String] = []
        for node in nodes {
            XCTAssertEqual(node.count, 2)
            let parent = node[0], token = node[1]
            XCTAssertTrue(parent >= -1 && parent < parts.count)
            XCTAssertTrue(tokens.indices.contains(token))
            parts.append((parent == -1 ? "" : parts[parent]) + tokens[token])
        }
        for pattern in patterns {
            let id=ids[pattern[0] as! Int],kp=(pattern[1] as! [Int]).map{$0 == -1 ? "" : parts[$0]},pp=(pattern[2] as! [Int]).map{$0 == -1 ? "" : parts[$0]}
            let sequence=sequences[pattern[3] as! Int],rows:[[Int]]
            if let literal=sequence as? [[Int]] { rows=literal }
            else {
                let range=sequence as! [String:Any],start=range["start"] as! [Int],step=range["step"] as! [Int]
                rows=(0..<(range["count"] as! Int)).map { n in start.indices.map { start[$0]+n*step[$0] } }
            }
            for row in rows {
                XCTAssertEqual(row.count,kp.count+pp.count-2)
                var i=0
                func join(_ parts:[String])->String {
                    parts.enumerated().map { j,part in
                        guard j>0 else{return part};defer{i+=1};return String(row[i])+part
                    }.joined()
                }
                let key=join(kp),pointer=join(pp),chart=try XCTUnwrap(charts[id])
                let value=try XCTUnwrap(ReadingVerificationEvidence.pointer(pointer,in:chart))
                let token=identity(id,key,pointer)
                XCTAssertNil(result[token]);result[token] = [.string(pointer),value]
            }
        }
        return result
    }
}

final class ReadingFactReferenceIndexTests:XCTestCase {
    func testNumericRangesLiteralZerosEscapedPointersAndConflictingToolsRestoreExactly() throws {
        let values:JSONValue = ["rows":.array((0..<172).map { i in ["field":.integer(Int64(i))] }),"a/b~c":false,"fixed01":[],"leaf":.null,"9007199254740992":true,"9007199254740993":false,"🌙宿": "星"]
        let calls=[ChatToolCall(id:"a",name:"setup_qimen",arguments:[:]),ChatToolCall(id:"b",name:"setup_qimen",arguments:[:])]
        let other: JSONValue = ["rows":.array((0..<172).map { i in ["field":.integer(Int64(-i-1))] }),"a/b~c":true,"fixed01":[],"leaf":.null,"9007199254740992":true,"9007199254740993":false,"🌙宿": "星"]
        let history=[ChatMessage.assistantToolCalls(calls)]+calls.map { .toolResult(.init(callID:$0.id,output:ReadingVerificationEvidence.encoded($0.id == "a" ? values : other))) }
        var facts:[ReadingVerificationEvidence.Fact]=[]
        for id in ["a","b"] {
            for i in 0..<172 { facts.append(.init(factKey:"qimen.date\(i+1).field",toolCallID:id,pointer:"/rows/\(i)/field",value:.integer(Int64(id == "a" ? i : -i-1)))) }
            facts.append(.init(factKey:"fixed01",toolCallID:id,pointer:"/fixed01",value:[]))
            facts.append(.init(factKey:"escaped",toolCallID:id,pointer:"/a~1b~0c",value:.bool(id == "b")))
            for key in ["leaf","9007199254740992","9007199254740993","🌙宿"] {
                facts.append(.init(factKey:key,toolCallID:id,pointer:"/"+key,value:ReadingVerificationEvidence.pointer("/"+key,in:values)!))
            }
        }
        for (j, i) in [5, 3, 1].enumerated() {
            facts.append(.init(factKey:"descending\(j)",toolCallID:"a",pointer:"/rows/\(i)/field",value:.integer(Int64(i))))
        }
        for (j, i) in [1, 4, 9].enumerated() {
            facts.append(.init(factKey:"nonlinear\(j)",toolCallID:"b",pointer:"/rows/\(i)/field",value:.integer(Int64(-i-1))))
        }
        facts.append(.init(factKey:"same.key",toolCallID:"a",pointer:"/leaf",value:.null))
        facts.append(.init(factKey:"same.key",toolCallID:"a",pointer:"/fixed01",value:[]))
        let messages=ReadingFactReferenceIndex.messages(facts)
        XCTAssertEqual(messages.count,1)
        XCTAssertLessThan(messages[0].content!.utf16.count,4_000)
        let restored=try ReferenceFactIndexTestDecoder.restore(messages[0].content!.components(separatedBy:"\n").last!,history:history)
        XCTAssertEqual(restored.count,facts.count)
        for f in facts { XCTAssertEqual(restored[ReferenceFactIndexTestDecoder.identity(f.toolCallID,f.factKey,f.pointer)],[.string(f.pointer),f.value]) }
        // Independently regroup the v2 rows into the earlier v1 representation:
        // both must recover exactly the same identity/value set.
        var old=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(messages[0].content!.components(separatedBy:"\n").last!.utf8)) as? [String:Any])
        XCTAssertEqual(old["referenceIndexVersion"] as? Int,2)
        let nodes=try XCTUnwrap(old["stringNodes"] as? [Int]),patterns=try XCTUnwrap(old["patterns"] as? [Any])
        old["referenceIndexVersion"]=1
        old["stringNodes"]=stride(from:0,to:nodes.count,by:2).map{Array(nodes[$0..<($0+2)])}
        old["patterns"]=stride(from:0,to:patterns.count,by:4).map{Array(patterns[$0..<($0+4)])}
        let legacy=String(decoding:try JSONSerialization.data(withJSONObject:old),as:UTF8.self)
        XCTAssertEqual(try ReferenceFactIndexTestDecoder.restore(legacy,history:history),restored)
    }
}
