import XCTest
@testable import SujiCore

final class JSONValueTransportTests:XCTestCase {
    private func fixture()->JSONValue {
        let shared:JSONValue=["path":"/lines/0/changed/context/month/elementRelation","conditions":["unresolved-actor-effectiveness","awaiting-sufficient-conditions"],"literal":"甲乙丙丁戊己庚辛壬癸", "unknown":.null]
        return ["objects":.array((0..<30).map{["index":.integer(Int64($0)),"first":shared,"second":shared,"empty":[],"flag":false]}),"order":[3,1,2],"future":["__proto__":["a/b~c":true],"":false]]
    }
    func testExactRoundtripUnknownFieldsOrderAndNestedSharedValues() throws {
        let original=fixture(),raw=ReadingVerificationEvidence.encoded(original),packed=JSONValueTransport.encode(raw)
        XCTAssertLessThan(packed.utf8.count,raw.utf8.count/2)
        let value=try JSONDecoder().decode(JSONValue.self,from:Data(packed.utf8))
        XCTAssertEqual(JSONValueTransport.expand(value),original)
        XCTAssertEqual(JSONValueTransport.encode(packed),packed)
        XCTAssertEqual(try CastReceiptStorage.expanded(try CastReceiptStorage.encode(raw)),original)
        if let path=ProcessInfo.processInfo.environment["SUJI_VALUE_CODEC_VECTOR"] {
            try JSONEncoder().encode(["original":original,"packed":value]).write(to:URL(fileURLWithPath:path))
        }
    }
    func testMissingForwardCyclicOutOfBoundsUnusedDuplicateAndReservedValuesFailClosed() throws {
        let packed=JSONValueTransport.encode(ReadingVerificationEvidence.encoded(fixture()))
        let original=try XCTUnwrap(try JSONSerialization.jsonObject(with:Data(packed.utf8)) as? [String:Any])
        let metadata=original["sharedValueRows"] as! [String:Any],values=metadata["values"] as! [Any]
        var variants:[[String:Any]]=[]
        var missing=original;missing.removeValue(forKey:"sharedValueRows");variants.append(missing)
        for wrong:Any in [-1,values.count,0.5,false,"0"] {
            var root=original;root["invalid"]=["$v":wrong];variants.append(root)
        }
        var extra=original;extra["invalid"]=["$v":0,"extra":true];variants.append(extra)
        for wrong:Any in [["$v":0],["$v":values.count],["sharedValueRows":false]] {
            var root=original,m=metadata,v=values;v[0]=wrong;m["values"]=v;root["sharedValueRows"]=m;variants.append(root)
        }
        for added:Any in [values[0],"unused unique long string does not occur elsewhere"] {
            var root=original,m=metadata;m["values"]=values+[added];root["sharedValueRows"]=m;variants.append(root)
        }
        var invalidVersion=original,m=metadata;m["version"]=2;invalidVersion["sharedValueRows"]=m;variants.append(invalidVersion)
        for v in variants {
            let raw=String(decoding:try JSONSerialization.data(withJSONObject:v),as:UTF8.self),value=try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
            XCTAssertNil(JSONValueTransport.expand(value));XCTAssertThrowsError(try CastReceiptStorage.expanded(raw))
        }
        for v:JSONValue in [["nested":["$v":0]],["nested":["sharedValueRows":false]]] {
            let raw=ReadingVerificationEvidence.encoded(v);XCTAssertEqual(JSONValueTransport.encode(raw),raw);XCTAssertNil(JSONValueTransport.expand(v))
        }
    }
}
