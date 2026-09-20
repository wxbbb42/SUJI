import Foundation
import SujiCore
struct Document {
 let value:Any
 subscript(_ key:String)->Document { Document(value:(value as? [String:Any])?[key] ?? NSNull()) }
 var text:String {value as? String ?? ""}
 var strings:[String] {value as? [String] ?? []}
 var json:String {String(decoding:(try? JSONSerialization.data(withJSONObject:value,options:[.sortedKeys,.fragmentsAllowed])) ?? Data("null".utf8),as:UTF8.self)}
}
@MainActor final class AppStore {
 var state=AppState()
 var scopeRevision=UUID()
 var writes:[UUID]=[]
 let bridge:MingliBridge
 init() throws {bridge=try MingliBridge(scriptURL:URL(fileURLWithPath:"/Users/xiaqobenwang/Documents/SUJI/native/Resources/mingli.js"))}
 func request(_ input:[String:Any]) async throws -> Document {
  let data=try await bridge.request(String(decoding:JSONSerialization.data(withJSONObject:input),as:UTF8.self))
  return Document(value:try JSONSerialization.jsonObject(with:data))
 }
 func saveThrowing() throws {writes.append(scopeRevision)}
 func save() {try? saveThrowing()}
 func chatClient() async throws -> ChatClient {throw EngineError.execution("provider forbidden")}
 func birthJSON(_ b:BirthProfile) throws -> Any {try JSONSerialization.jsonObject(with:JSONEncoder().encode(b))}
}
@main struct SessionProbe {
 @MainActor static func main() async throws {
  let store=try AppStore()
  let fixtures=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/fixtures.json"))) as! [[String:Any]]
  let f=fixtures[0], source=f["source"] as! [String:Any], provenance=source["provenance"] as! [String:Any]
  let context=try ToolContext(birth:nil,engineRevision:provenance["engineRevision"] as! String,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦")
  var original=ConversationEntry(role:"user",text:"original");original.date=context.referenceDate;original.toolContext=context
  original.toolReceipts=[ToolReceipt(callID:"original",name:"cast_liuyao",arguments:try JSONDecoder().decode(JSONValue.self,from:JSONSerialization.data(withJSONObject:f["args"]!)),output:Document(value:source).json,context:context)]
  store.state.conversations=[original]
  let session=ChatSession()
  session.supplement(entryID:original.id,callID:"original",store:store)
  while session.castConfirmation.pending == nil && session.working {try await Task.sleep(for:.milliseconds(1))}
  let pending=session.castConfirmation.pending!
  session.castConfirmation.confirm(id:pending.id,drafts:pending.drafts)
  // Account B contains an imported copy, preserving entry UUIDs and context.
  let oldAccount=store.state
  store.scopeRevision=UUID()
  let newScope=store.scopeRevision
  store.state=try JSONDecoder().decode(AppState.self,from:JSONEncoder().encode(oldAccount))
  while session.working {try await Task.sleep(for:.milliseconds(1))}
  let results:[String:Any]=["oldAccountConfirmationCount":oldAccount.conversations[1].confirmedCastQuestions?.count ?? 0,"newAccountConfirmationCount":store.state.conversations[1].confirmedCastQuestions?.count ?? 0,"newScopeSaved":store.writes.contains(newScope),"newAccountReceiptCount":store.state.conversations[1].toolReceipts?.count ?? 0]
  let data=try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"/tmp/suji-f6b-independent-review/session-results.json"));print(String(decoding:data,as:UTF8.self))
 }
}
