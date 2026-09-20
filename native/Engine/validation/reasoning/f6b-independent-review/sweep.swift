import Foundation
import SujiCore
@main struct Sweep {
 static func encode(_ x:Any) throws -> String { String(decoding:try JSONSerialization.data(withJSONObject:x),as:UTF8.self) }
 static func value(_ x:Any) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self,from:Data(encode(x).utf8)) }
 static func main() async throws {
  let bridge=try MingliBridge(scriptURL:URL(fileURLWithPath:"/Users/xiaqobenwang/Documents/SUJI/native/Resources/mingli.js"))
  let fixtures=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/fixtures.json"))) as! [[String:Any]]
  var cases=0, failures:[[String:String]]=[]
  for f in fixtures {
   let name=f["name"] as! String, source=f["source"] as! [String:Any], provenance=source["provenance"] as! [String:Any]
   let context=try ToolContext(birth:nil,engineRevision:provenance["engineRevision"] as! String,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦")
   var original=ConversationEntry(role:"user",text:"核对自身情况");original.date=context.referenceDate;original.toolContext=context
   original.toolReceipts=[ToolReceipt(callID:"original",name:name,arguments:try value(f["args"]!),output:try encode(source),context:context)]
   let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
   for category in CastQuestionDraft.questionTypes {for subject in CastQuestionDraft.subjects {for horizon in CastQuestionDraft.timeHorizons {for refOnly in [false,true] {
    var user=ConversationEntry(role:"user",text:"valid supplement");user.toolContext=context;user.castSupplement=link
    let args:[String:Any]=["question":"补充核对","questionType":category,"subject":subject,"event":refOnly ? "":"明确事项","timeHorizon":horizon]
    var draft=try CastQuestionDraft(call:ChatToolCall(id:"valid",name:name,arguments:try value(args)));draft.referenceOnly=refOnly
    let confirmation=try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
    let accepted=try JSONSerialization.jsonObject(with:JSONEncoder().encode(confirmation.call.arguments))
    let data=try await bridge.request(encode(["command":"reassess-question","name":name,"sourceCallID":"original","original":source,"arguments":accepted]))
    let result=(try JSONSerialization.jsonObject(with:data) as! [String:Any])["result"]!
    let receipt=ToolReceipt(callID:"valid",name:link.derivedName,arguments:confirmation.call.arguments,output:try encode(result),context:context)
    user.confirmedCastQuestions=[confirmation];user.toolReceipts=[receipt];cases += 1
    do {_=try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[original,user],context:context)}
    catch {failures.append(["method":name,"category":category,"subject":subject,"horizon":horizon,"referenceOnly":String(refOnly),"error":error.localizedDescription])}
   }}}}
  }
  let data=try JSONSerialization.data(withJSONObject:["cases":cases,"failures":failures],options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/sweep-results.json"));print(String(decoding:data,as:UTF8.self))
 }
}
