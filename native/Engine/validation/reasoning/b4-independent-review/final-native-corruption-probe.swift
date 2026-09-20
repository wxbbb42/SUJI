import Foundation
@main struct Probe {
 static let folder="native/Engine/validation/reasoning/b4-independent-review/"
 static func json(_ value:JSONValue)->String {ReadingVerificationEvidence.encoded(value)}
 static func set(_ value:JSONValue,_ path:ArraySlice<String>,_ next:JSONValue?)->JSONValue {
  guard let first=path.first else{return next ?? .null}
  switch value {
  case var .object(v):if path.count==1{v[first]=next}else{v[first]=set(v[first] ?? .null,path.dropFirst(),next)};return .object(v)
  case var .array(v):guard let n=Int(first),v.indices.contains(n) else{return value};v[n]=set(v[n],path.dropFirst(),next);return .array(v)
  default:return value
  }
 }
 static func edit(_ value:JSONValue,_ path:String,_ next:JSONValue?)->JSONValue{set(value,path.split(separator:"/").map(String.init)[...],next)}
 static func main() async throws {
  let fixtures=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:folder+"capacity-fixtures.json")))
  let fixture=fixtures[0],r=fixture.rows[0]
  guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:r.output) else{fatalError("revision")}
  let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:fixture.date)!,mode:"起卦")
  var results:[[String:Any]]=[]
  for idLength in [32,129,130,200]{
   let call=ChatToolCall(id:String(repeating:"x",count:idLength),name:r.name,arguments:r.arguments)
   let receipt=ToolReceipt(callID:call.id,name:r.name,arguments:r.arguments,output:json(r.output),context:context)
   let prior=[ChatMessage.assistantToolCalls([call])]
   let projected=NatalEvidenceProjection.output(receipt.output,name:r.name,delivered:prior,callID:call.id)
   var count=0
   let orchestrator=ToolOrchestrator(complete:{_,_ in count+=1;return count==1 ? .toolCalls([call]):.text("ready")},execute:{_ in .init(output:receipt.output,evidence:["cast-record"])})
   let outcome=try await orchestrator.run(history:[],definitions:[.init(name:r.name,description:"test",parameters:["type":"object"])],context:context)
   let actual=outcome.messages.first{$0.role == .tool}!.content!
   let body=try JSONDecoder().decode(JSONValue.self,from:Data(actual.utf8))
   results.append(["case":"native-capacity-id-\(idLength)","projectedUTF16":projected.utf16.count,"actualToolUTF16":actual.utf16.count,"capacityError":ReadingVerificationEvidence.pointer("/error",in:body) != nil,"savedReceipts":outcome.receipts.count,"savedFull":outcome.receipts.first?.output == receipt.output,"deliveredEvidence":outcome.evidence])
  }
  let call=ChatToolCall(id:String(repeating:"x",count:32),name:r.name,arguments:r.arguments)
  let receipt=ToolReceipt(callID:call.id,name:r.name,arguments:r.arguments,output:json(r.output),context:context)
  let prior=[ChatMessage.assistantToolCalls([call])]
  let raw=NatalEvidenceProjection.output(receipt.output,name:r.name,delivered:prior,callID:call.id)
  let packed=try JSONDecoder().decode(JSONValue.self,from:Data(raw.utf8))
  let facts:(JSONValue)->[ReadingVerificationEvidence.Fact]={v in ReadingVerificationEvidence.facts(prior+[.toolResult(.init(callID:call.id,output:json(v)))])}
  let baseFacts=facts(packed).count
  let firstPath="/lines/0/rules/advanceRetreat/conditions/0"
  var variants:[(String,JSONValue)]=[
   ("missing-layout-metadata",edit(packed,"/ruleConditionRows",nil)),
   ("paths-missing",edit(packed,"/ruleConditionRows/paths",nil)),
   ("path-index-negative",edit(packed,firstPath+"/2",[-1])),
   ("path-index-too-large",edit(packed,firstPath+"/2",[99999])),
   ("path-index-float",edit(packed,firstPath+"/2",[.double(0.5)])),
   ("path-index-null",edit(packed,firstPath+"/2",[.null])),
   ("states-missing",edit(packed,"/ruleConditionRows/states",nil)),
   ("states-reversed",edit(packed,"/ruleConditionRows/states",["unresolved","not-matched","matched"])),
   ("states-extra",edit(packed,"/ruleConditionRows/states",["matched","not-matched","unresolved","broken"])),
   ("state-index-negative",edit(packed,firstPath+"/1",-1)),
   ("state-index-too-large",edit(packed,firstPath+"/1",3)),
   ("state-index-float",edit(packed,firstPath+"/1",.double(0.5))),
   ("metadata-null",edit(packed,"/ruleConditionRows",.null)),
   ("metadata-version-2",edit(packed,"/ruleConditionRows/version",2)),
   ("metadata-extra-key",edit(packed,"/ruleConditionRows/extra",true)),
   ("columns-reordered",edit(packed,"/ruleConditionRows/columns",["state","idIndex","factPaths"])),
   ("tuple-short",edit(packed,firstPath,[0,"matched"])),
   ("tuple-object",edit(packed,firstPath,["id":"changed-void","state":"matched","factPaths":[]])),
   ("tuple-index-invalid",edit(packed,firstPath+"/0",999)),
   ("tuple-state-invalid",edit(packed,firstPath+"/1","broken")),
   ("tuple-path-invalid",edit(packed,firstPath+"/2",[false])),
   ("line-missing-rules",edit(packed,"/lines/5/rules",nil)),
   ("valid-state-tamper",edit(packed,firstPath+"/1",ReadingVerificationEvidence.pointer(firstPath+"/1",in:packed) == .integer(0) ? 1 : 0)),
   ("valid-question-tamper",edit(packed,"/questionFromArguments/toolCallID","other")),
  ]
  if case let .array(ids)=ReadingVerificationEvidence.pointer("/ruleConditionRows/ids",in:packed) {
   variants.append(("duplicate-dictionary-id",edit(packed,"/ruleConditionRows/ids",.array(ids+[ids[0]]))))
   variants.append(("unused-dictionary-id",edit(packed,"/ruleConditionRows/ids",.array(ids+["unused"]))))
  }
  if case let .array(paths)=ReadingVerificationEvidence.pointer("/ruleConditionRows/paths",in:packed) {
   variants.append(("duplicate-path-dictionary",edit(packed,"/ruleConditionRows/paths",.array(paths+[paths[0]]))))
   variants.append(("unused-path-dictionary",edit(packed,"/ruleConditionRows/paths",.array(paths+["/unused"]))))
   variants.append(("path-dictionary-invalid",edit(packed,"/ruleConditionRows/paths/0","relative")))
  }
  for (name,v) in variants {
   precondition(v != packed,"no-op corruption: \(name)")
   let history=prior+[ChatMessage.toolResult(.init(callID:call.id,output:json(v)))]
   results.append(["mutationChanged":v != packed,"case":name,"expandAccepted":LiuyaoConditionTransport.expand(v) != nil,"factCount":facts(v).count,"originalFactCount":baseFacts,"authenticated":NatalEvidenceProjection.wasDelivered(receipt,in:history)])
  }
  var sourceVariants:[(String,JSONValue)]=[
   ("row-object-swap",edit(r.output,"/tombExtinction/objects/0/objectPath","/lines/1")),
   ("row-own-change-reversal",edit(r.output,"/tombExtinction/objects/0/ownChange","墓")),
   ("false-final-efficacy",edit(r.output,"/tombExtinction/efficacyEstablished",true)),
   ("actor-support-self",edit(r.output,"/tombExtinction/objects/0/supportingMovingPositions",[1])),
   ("changed-cross-actor",edit(r.output,"/tombExtinction/objects/1/movingTombPositions",[1])),
   ("context-day-branch-borrowed",edit(r.output,"/lines/0/changed/context/day/branch","子")),
   ("context-void-toggled",edit(r.output,"/lines/0/context/isVoid",ReadingVerificationEvidence.pointer("/lines/0/context/isVoid",in:r.output) == .bool(true) ? false : true))
  ]
  if case let .array(rows)=ReadingVerificationEvidence.pointer("/tombExtinction/objects",in:r.output) {sourceVariants.append(("missing-last-object",edit(r.output,"/tombExtinction/objects",.array(Array(rows.dropLast())))))}
  for(name,v) in sourceVariants{
   precondition(v != r.output,"no-op source corruption: \(name)")
   var mutated=receipt;mutated.output=json(v)
   results.append(["mutationChanged":v != r.output,"case":name,"renderAccepted":LiuyaoReferenceReading.render(receipts:[mutated],context:context) != nil])
  }
  let data=try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:folder+"final-native-corruption-report.json"))
  print(String(decoding:data,as:UTF8.self))
 }
}
struct Fixture:Decodable{let date:String;let rows:[Row]}
struct Row:Decodable{let name:String;let arguments:JSONValue;let output:JSONValue}
