import Foundation

/// Final, self-contained sharing of exact repeated JSON subtrees and strings.
/// Dictionary references only point backwards; every original field is restored.
enum JSONValueTransport {
    private static let key="sharedValueRows",marker="$v"
    private static let format="Expand each {\"$v\":i} from values[i], recursively. Dictionary values may reference only earlier entries. Then remove sharedValueRows and expand object, condition and date layouts; original JSON pointers apply after expansion."
    private enum Invalid:Error {case record}
    private static func reserved(_ value:JSONValue)->Bool {
        switch value {
        case let .array(a):return a.contains(where:reserved)
        case let .object(o):return o[key] != nil || o[marker] != nil || o.values.contains(where:reserved)
        default:return false
        }
    }
    static func encode(_ raw:String)->String {
        guard let value=try? JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8)),case var .object(root)=value,!reserved(value) else{return raw}
        var counts:[String:Int]=[:]
        func token(_ v:JSONValue)->String? {
            switch v {case .array,.object,.string:
                let s=ReadingVerificationEvidence.encoded(v);return s.utf8.count>24 ? s:nil
            default:return nil}
        }
        func collect(_ v:JSONValue){
            if let t=token(v){counts[t,default:0]+=1}
            switch v{case let .array(a):a.forEach(collect);case let .object(o):o.keys.sorted().forEach{collect(o[$0]!)};default:break}
        }
        root.keys.sorted().forEach{collect(root[$0]!)}
        var values:[JSONValue]=[],indices:[String:Int]=[:]
        func pack(_ v:JSONValue)->JSONValue {
            let t=token(v),candidate=t.map{counts[$0,default:0]>1 && (counts[$0,default:0]-1)*$0.utf8.count>counts[$0,default:0]*14+4} ?? false
            if candidate,let t,let i=indices[t]{return .object([marker:.integer(Int64(i))])}
            let packed:JSONValue
            switch v{case let .array(a):packed = .array(a.map(pack));case let .object(o):packed = .object(Dictionary(uniqueKeysWithValues:o.keys.sorted().map{($0,pack(o[$0]!))}));default:packed=v}
            if candidate,let t,values.count<4096 {
                let i=values.count;values.append(packed);indices[t]=i;return .object([marker:.integer(Int64(i))])
            }
            return packed
        }
        root.keys.sorted().forEach{root[$0]=pack(root[$0]!)}
        guard !values.isEmpty else{return raw}
        root[key]=["version":1,"values":.array(values),"format":.string(format)]
        let packed=ReadingVerificationEvidence.encoded(JSONValue.object(root))
        return packed.utf8.count<raw.utf8.count && packed.utf16.count<raw.utf16.count ? packed:raw
    }
    static func expand(_ value:JSONValue)->JSONValue? {
        guard case var .object(root)=value else{if reserved(value){return nil};return value}
        guard let metadata=root[key] else{if reserved(value){return nil};return value}
        guard root[marker]==nil,case let .object(m)=metadata,Set(m.keys)==Set(["version","values","format"]),m["version"]==1,m["format"] == .string(format),case let .array(values)=m["values"],!values.isEmpty,values.count<=4096 else{return nil}
        var decoded:[JSONValue]=[],costs:[Int]=[],used=Set<Int>(),unique=Set<String>()
        func unpack(_ v:JSONValue,_ limit:Int)throws->(JSONValue,Int){
            switch v{
            case let .array(a):
                var out:[JSONValue]=[],cost=2
                for item in a{let(x,n)=try unpack(item,limit);cost+=n+1;guard cost<=2_000_000 else{throw Invalid.record};out.append(x)}
                return(.array(out),cost)
            case let .object(o):
                guard o[key]==nil else{throw Invalid.record}
                if let ref=o[marker]{guard o.count==1,case let .integer(i)=ref,i>=0,i<limit else{throw Invalid.record};used.insert(Int(i));return(decoded[Int(i)],costs[Int(i)])}
                var out:[String:JSONValue]=[:],cost=2
                for k in o.keys.sorted(){let(x,n)=try unpack(o[k]!,limit);cost+=n+k.utf8.count*6+4;guard cost<=2_000_000 else{throw Invalid.record};out[k]=x}
                return(.object(out),cost)
            default:let n=ReadingVerificationEvidence.encoded(v).utf8.count;guard n<=2_000_000 else{throw Invalid.record};return(v,n)
            }
        }
        do{
            for entry in values {
                let(v,n)=try unpack(entry,decoded.count)
                guard unique.insert(ReadingVerificationEvidence.encoded(v)).inserted else{return nil}
                decoded.append(v);costs.append(n)
            }
            root.removeValue(forKey:key)
            let(result,_)=try unpack(.object(root),decoded.count)
            guard used.count==values.count else{return nil};return result
        }catch{return nil}
    }
}
