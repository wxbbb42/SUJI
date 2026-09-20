import Foundation

struct ProbeCase: Codable {
    let label: String
    let expected: Int
    let actual: Int
}

@main struct Probe {
    static func main() throws {
        let file = "/Users/xiaqobenwang/Documents/SUJI/native/Engine/validation/reasoning/core-d5-results.json"
        let archive = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: file))) as! [String: Any]
        let row = (archive["cases"] as! [[String: Any]])[0]
        let history = try JSONDecoder().decode([ChatMessage].self, from: JSONSerialization.data(withJSONObject: row["writerHistory"]!))
        let draft = row["draft"] as! String
        let intro = "比较2025年8月8日与8月9日的紫微流月。"
        let wrong = "农历月序号从6月进到7月"
        var cases: [ProbeCase] = []
        func run(_ name: String, _ text: String, _ h: [ChatMessage], _ expected: Int) {
            cases.append(.init(label: name, expected: expected, actual: ZiweiMonthlyCalendarAssertions.issues(text, history: h).count))
        }
        func set(_ value: JSONValue, _ parts: ArraySlice<String>, _ next: JSONValue?) -> JSONValue {
            guard let key = parts.first else { return next ?? .null }
            switch value {
            case var .object(o):
                if parts.count == 1 { o[key] = next }
                else { o[key] = set(o[key] ?? .null, parts.dropFirst(), next) }
                return .object(o)
            case var .array(a):
                let i = Int(key)!; a[i] = set(a[i], parts.dropFirst(), next); return .array(a)
            default: return value
            }
        }
        func mutate(_ h: [ChatMessage], _ index: Int, _ path: String, _ next: JSONValue?) -> [ChatMessage] {
            var h = h
            let value = try! JSONDecoder().decode(JSONValue.self, from: Data(h[index].content!.utf8))
            h[index].content = ReadingVerificationEvidence.encoded(set(value, path.split(separator: "/").map(String.init)[...], next))
            return h
        }
        run("archived-actual-shipping-history", draft, history, 1)
        run("archived-corrected", draft.replacingOccurrences(of: wrong, with: "两天农历均为闰六月，排盘月序从6变为7"), history, 0)
        for claim in ["不是："+wrong, "如果："+wrong, "有人声称："+wrong, "“结论："+wrong+"”", "‘结论："+wrong+"’", "他说："+wrong, "旧盘结论："+wrong, "农历月序号从6月进到7月，这个说法不成立", "农历均为闰六月；排盘月序号从6月进到7月"] {
            run("framing: "+claim, intro+"\n\n"+claim, history, 0)
        }
        for text in ["2025年8月8日与8月9日的紫微流月。\n\n2024年8月8日："+wrong, intro+"\n\n8月10日："+wrong, "比较8月8日与8月9日的紫微流月。\n\n"+wrong, intro+"\n\n2025-08-10："+wrong] {
            run("date-scope: "+text, text, history, 0)
        }
        let text = intro+"\n\n"+wrong
        for label in ["8月10号", "8/10", "2025/08/10", "农历2025年8月8日与8月9日"] {
            run("unparsed-date: "+label,intro+"\n\n"+label+"："+wrong,history,0)
        }
        run("explicit-lunar-header", "比较农历2025年8月8日与8月9日的紫微流月。\n\n"+wrong,history,0)
        run("unclosed-single-curly-quote",intro+"\n\n‘结论："+wrong+"；待续’",history,0)
        for (name, index, path, next): (String, Int, String, JSONValue?) in [
            ("source-hash",3,"/ruleSources/1/references/0/sha256","bad"),
            ("source-version",3,"/ruleSources/1/version","2"),
            ("source-id",3,"/ruleSources/1/id","different"),
            ("wrong-index-pointer",4,"/reusedFacts/2/pointer","/ruleSources/0/references"),
            ("missing-source-ref",4,"/reusedFacts/2/toolCallID","missing"),
            ("source-error",3,"/error","bad"),
            ("compacted-source-has-conflicting-string",4,"/ruleSources/1/references","bad"),
            ("compacted-source-has-explicit-null",4,"/ruleSources/1/references",.null),
            ("sparse-month",4,"/monthly/calendar/month",nil),
            ("sparse-method",4,"/monthly/method",nil),
            ("wrong-civil-date",4,"/civilDate","2025-08-08")
        ] { run(name,text,mutate(history,index,path,next),0) }
        var reordered = history
        reordered.swapAt(2,3)
        run("receipt-before-original-call",text,reordered,0)
        let firstRoot = try JSONDecoder().decode(JSONValue.self, from: Data(history[3].content!.utf8))
        let secondRoot = try JSONDecoder().decode(JSONValue.self, from: Data(history[4].content!.utf8))
        let sourceOnly: JSONValue = firstRoot
        let sourceCall = ChatToolCall(id: "independent-source", name: "get_ziwei_timing", arguments: history[2].toolCalls![0].arguments)
        let sourceMessages = [ChatMessage.assistantToolCalls([sourceCall]), .toolResult(.init(callID:sourceCall.id,output:ReadingVerificationEvidence.encoded(sourceOnly)))]
        var linked = history
        var updated = secondRoot
        if case let .array(links) = ReadingVerificationEvidence.pointer("/reusedFacts",in:secondRoot) {
            for i in links.indices where ReadingVerificationEvidence.pointer("/path",in:links[i]) == .string("/ruleSources/1/references") {
                updated = set(updated,["reusedFacts",String(i),"toolCallID"][...],.string(sourceCall.id))
            }
        }
        linked[4].content = ReadingVerificationEvidence.encoded(updated)
        linked.insert(contentsOf:sourceMessages,at:2)
        run("independent-earlier-source-valid",text,linked,1)
        var wrongArgs = linked
        wrongArgs[2].toolCalls = [.init(id:sourceCall.id,name:"get_domain",arguments:["domain":"bazi"])]
        run("independent-source-wrong-domain-args",text,wrongArgs,0)
        var malformedArgs = linked
        malformedArgs[2].toolCalls = [.init(id:sourceCall.id,name:"get_ziwei_timing",arguments:[:])]
        run("independent-source-sparse-timing-args",text,malformedArgs,0)
        run("independent-source-duplicate-call-after-receipts",text,linked+[.assistantToolCalls([sourceCall])],0)
        run("independent-source-duplicate-output-after-receipts",text,linked+[sourceMessages[1]],0)
        var sourceReorder = linked
        sourceReorder.swapAt(2,3)
        run("independent-source-output-before-call",text,sourceReorder,0)
        let encoded = try JSONEncoder().encode(cases)
        try encoded.write(to:URL(fileURLWithPath:"/tmp/suji-f5-independent-review/results.json"))
        print(String(decoding:encoded,as:UTF8.self))
    }
}
