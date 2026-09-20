import Foundation
import SujiCore

@main struct Probe {
 static func json(_ x:Any) throws -> String { String(decoding:try JSONSerialization.data(withJSONObject:x,options:[.sortedKeys]),as:UTF8.self) }
 static func value(_ x:Any) throws -> JSONValue { try JSONDecoder().decode(JSONValue.self,from:Data(json(x).utf8)) }
 static func main() throws {
  let data=try Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/fixtures.json"))
  let cases=try JSONSerialization.jsonObject(with:data) as! [[String:Any]]
  var results:[[String:Any]]=[]
  for f in cases {
   let name=f["name"] as! String, source=f["source"] as! [String:Any], revised=f["revised"] as! [String:Any]
   let provenance=source["provenance"] as! [String:Any]
   let context=try ToolContext(birth:nil,engineRevision:provenance["engineRevision"] as! String,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦")
   var original=ConversationEntry(role:"user",text:"核对自身情况");original.date=context.referenceDate;original.toolContext=context
   original.toolReceipts=[ToolReceipt(callID:"original",name:name,arguments:try value(f["args"]!),output:try json(source),context:context)]
   let link=try CastSupplement.select(entryID:original.id,callID:"original",entries:[original],context:context)
   var user=ConversationEntry(role:"user",text:"补充父亲的情况");user.castSupplement=link;user.toolContext=context
   let draft=try CastQuestionDraft(call:ChatToolCall(id:"revised",name:name,arguments:try value(f["revisedArgs"]!)))
   let confirmation=try ConfirmedCastQuestion(draft:draft,userID:user.id,context:context)
   user.confirmedCastQuestions=[confirmation]
   var receipt=ToolReceipt(callID:"revised",name:link.derivedName,arguments:confirmation.call.arguments,output:try json(revised),context:context)
   user.toolReceipts=[receipt]
   _=try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[original,user],context:context)
   var bad=revised
   for key in ["yongShen","yingQi"] + (name=="cast_liuyao" ? ["roleRelations"] : []) { bad[key]=source[key] }
   receipt.output=try json(bad);user.toolReceipts=[receipt]
   do {
    let report=try link.render(receipt:receipt,confirmation:confirmation,userID:user.id,entries:[original,user],context:context)
    results.append(["case":"stale old mutable fields", "name":name,"accepted":true,"report":report])
   } catch {results.append(["case":"stale old mutable fields","name":name,"accepted":false,"error":error.localizedDescription])}
   var forgedSource=source
   var forgedProvenance=provenance;forgedProvenance["referenceDate"]="2025-01-01T00:00:00Z";forgedSource["provenance"]=forgedProvenance
   var badOriginal=original;badOriginal.toolReceipts![0].output=try json(forgedSource)
   do { _=try CastSupplement.select(entryID:badOriginal.id,callID:"original",entries:[badOriginal],context:context);results.append(["case":"tampered original referenceDate","name":name,"accepted":true]) }
   catch {results.append(["case":"tampered original referenceDate","name":name,"accepted":false])}
   if let forgedLink=try? CastSupplement.select(entryID:badOriginal.id,callID:"original",entries:[badOriginal],context:context) {
   var forgedUser=user;forgedUser.castSupplement=forgedLink
   var forgedRevised=revised;forgedRevised["provenance"]=forgedProvenance
   var forgedReceipt=receipt;forgedReceipt.output=try json(forgedRevised);forgedUser.toolReceipts=[forgedReceipt]
   do { _=try forgedLink.render(receipt:forgedReceipt,confirmation:confirmation,userID:forgedUser.id,entries:[badOriginal,forgedUser],context:context);results.append(["case":"retry forged referenceDate equal source and derived","name":name,"accepted":true]) }
   catch {results.append(["case":"retry forged referenceDate equal source and derived","name":name,"accepted":false])}
   } else { results.append(["case":"retry forged referenceDate equal source and derived","name":name,"accepted":false]) }
  }
  let out=try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]);try out.write(to:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/core-results.json"))
  for r in results {print("\(r["name"]!) \(r["case"]!): accepted=\(r["accepted"]!)")}
 }
}
