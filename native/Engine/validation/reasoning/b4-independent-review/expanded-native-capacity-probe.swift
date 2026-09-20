import Foundation
struct Fixture:Decodable {let date:String;let rows:[Row]}
struct Row:Decodable {let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Probe {
 static func main() async throws {
  let fixtures=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:"native/Engine/validation/reasoning/b4-independent-review/expanded-capacity-fixtures.json")))
  var reports:[[String:Any]]=[]
  for (index,fixture) in fixtures.enumerated() {
   let calls=fixture.rows.enumerated().map { ChatToolCall(id:String(repeating:$0.offset == 0 ? "a":"b",count:32),name:$0.element.name,arguments:$0.element.arguments) }
   let outputs=Dictionary(uniqueKeysWithValues:zip(calls,fixture.rows).map {($0.0.id,ReadingVerificationEvidence.encoded($0.1.output))})
   let definitions=calls.map {ChatToolDefinition(name:$0.name,description:$0.name,parameters:["type":"object"])}
   let now=ISO8601DateFormatter().date(from:fixture.date)!
   guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:fixture.rows[0].output) else {fatalError("missing revision")}
   let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:now,mode:"起卦")
   let instruction=ChatMessage(role:.system,content:ReadingPrompt.instruction(tone:"清晰",mode:"起卦",referenceDate:now,hasBirth:true)+"\n"+ReadingPrompt.writer)
   var round=0
   let orchestrator=ToolOrchestrator(complete:{_,_ in round+=1;return round == 1 ? .toolCalls(calls):.text("ready")},execute:{call in .init(output:outputs[call.id]!,evidence:[call.id])})
   let result=try await orchestrator.run(history:[instruction],definitions:definitions,context:context)
   let live=result.messages.filter{$0.role == .tool}
   var entry=ConversationEntry(role:"user",text:String(repeating:"问",count:1600));entry.toolReceipts=result.receipts
   let replay=[instruction]+ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context)
   let retry=ToolOrchestrator(complete:{_,_ in .text("ready")},execute:{_ in fatalError("must not recast")})
   let retried=try await retry.run(history:replay,definitions:definitions,cachedReceipts:result.receipts,context:context)
   var faithful=true,sourceRemovalAccepted=0,authenticated=0
   for (i,message) in live.enumerated() {
    var body=try JSONDecoder().decode(JSONValue.self,from:Data(message.content!.utf8))
    guard case var .object(root)=body else {fatalError("not object")}
    if let ref=root.removeValue(forKey:"questionFromArguments") {
     guard ReadingVerificationEvidence.pointer("/toolCallID",in:ref) == .string(calls[i].id),ReadingVerificationEvidence.pointer("/pointer",in:ref) == "/question" else {fatalError("wrong argument reference")}
     root["question"]=ReadingVerificationEvidence.pointer("/question",in:calls[i].arguments);body = .object(root)
    }
    body=LiuyaoConditionTransport.expand(body) ?? .null
    faithful = faithful && body == fixture.rows[i].output
    if NatalEvidenceProjection.wasDelivered(result.receipts[i],in:replay) { authenticated+=1 }
    if NatalEvidenceProjection.wasDelivered(result.receipts[i],in:replay.filter{!($0.toolCalls ?? []).contains{$0.id == calls[i].id}}) {sourceRemovalAccepted+=1}
   }
   let fullHistory=[instruction,.assistantToolCalls(calls)]+calls.map{ChatMessage.toolResult(.init(callID:$0.id,output:outputs[$0.id]!))}
   func facts(_ h:[ChatMessage])->Set<String>{Set(ReadingVerificationEvidence.facts(h).map{$0.toolCallID+"|"+$0.factKey+"|"+$0.pointer+"="+ReadingVerificationEvidence.encoded($0.value)})}
   let review=ReadingVerifier.messages(draft:String(repeating:"这只说明盘面关系，尚未裁定效力或事件结果。",count:80),history:replay,question:entry.text)
   try JSONEncoder().encode(review).write(to:URL(fileURLWithPath:"native/Engine/validation/reasoning/b4-independent-review/expanded-capacity-request-\(index).json"))
   let liuyaoReceipt=result.receipts.first{$0.name == "cast_liuyao"}!
   let reading=LiuyaoReferenceReading.render(receipts:[liuyaoReceipt],context:context)
   let liuyaoRoot=fixture.rows.first{$0.name == "cast_liuyao"}!.output
   let tombObjects=ReadingVerificationEvidence.pointer("/tombExtinction/objects",in:liuyaoRoot)!
   let objectCount: Int; if case let .array(a)=tombObjects {objectCount=a.count}else{objectCount=0}
   let tombSections=reading?.sections.filter{$0.id.hasPrefix("tomb-") && $0.id != "tomb-policy"} ?? []
   let traceValid=tombSections.count == objectCount && tombSections.allSatisfy { section in section.evidence.allSatisfy { $0.toolCallID == liuyaoReceipt.callID && $0.value == ReadingVerificationEvidence.pointer($0.pointer,in:liuyaoRoot) } }
   let decodedReceipt=try JSONDecoder().decode(ToolReceipt.self,from:JSONEncoder().encode(liuyaoReceipt))
   let renderRoundtrip=reading?.text == LiuyaoReferenceReading.render(receipts:[decodedReceipt],context:context)?.text
   let row:[String:Any]=["referenceRenderAccepted":reading != nil,"objectCount":objectCount,"renderedObjectCount":tombSections.count,"tracePointersExact":traceValid,"renderRoundtrip":renderRoundtrip,"index":index,"date":fixture.date,"liveBytes":live.reduce(0){$0+($1.content?.utf8.count ?? 0)},"maxToolUTF16":live.map{$0.content!.utf16.count}.max()!,"receiptCount":result.receipts.count,"faithfulChartRoundtrip":faithful,"factsPreserved":facts(fullHistory)==facts(replay),"replayEqualsLive":live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content),"retryEvidence":retried.evidence,"authenticated":authenticated,"sourceRemovalAccepted":sourceRemovalAccepted,"reviewUTF16":review.reduce(0){$0+($1.content?.utf16.count ?? 0)},"messageCount":review.count]
   reports.append(row)
  }
  let data=try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"native/Engine/validation/reasoning/b4-independent-review/expanded-native-capacity-report.json"));print("Completed \(reports.count) native delivery/replay probes")
 }
}
