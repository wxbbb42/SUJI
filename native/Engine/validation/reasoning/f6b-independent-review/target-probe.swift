import Foundation
import SujiCore
@main struct Targets {
 static func encode(_ x:Any) throws -> String { String(decoding:try JSONSerialization.data(withJSONObject:x),as:UTF8.self) }
 static func value(_ x:Any) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self,from:Data(encode(x).utf8)) }
 static func main() throws {
  let cases=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/target-fixtures.json"))) as! [[String:Any]]
  var results:[[String:Any]]=[]
  for f in cases {
   let source=f["source"] as! [String:Any], p=source["provenance"] as! [String:Any]
   let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
   let context=try ToolContext(birth:nil,engineRevision:p["engineRevision"] as! String,referenceDate:formatter.date(from:source["castTime"] as! String)!,mode:"起卦")
   var original=ConversationEntry(role:"user",text:"核对自身情况");original.date=context.referenceDate;original.toolContext=context
   original.toolReceipts=[ToolReceipt(callID:"original",name:"cast_liuyao",arguments:try value(f["args"]!),output:try encode(source),context:context)]
   let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
   var user=ConversationEntry(role:"user",text:"target supplement");user.toolContext=context;user.castSupplement=link
   var draft=try CastQuestionDraft(call:ChatToolCall(id:"derived",name:"cast_liuyao",arguments:try value(f["revisedArgs"]!)));draft.referenceOnly=f["refOnly"] as! Bool
   let confirmation=try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
   let receipt=ToolReceipt(callID:"derived",name:link.derivedName,arguments:confirmation.call.arguments,output:try encode(f["revised"]!),context:context)
   user.confirmedCastQuestions=[confirmation];user.toolReceipts=[receipt]
   var result:[String:Any]=["layer":f["layer"]!,"arguments":f["revisedArgs"]!,"referenceOnly":f["refOnly"]!]
   do {_=try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[original,user],context:context);result["accepted"]=true}
   catch {result["accepted"]=false;result["error"]=error.localizedDescription}
   results.append(result)
  }
  let result:[String:Any]=["cases":results.count,"accepted":results.filter{$0["accepted"] as? Bool == true}.count,"results":results]
  let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/target-results.json"));print("Target cases: \(results.count), accepted: \(result["accepted"]!)")
 }
}
