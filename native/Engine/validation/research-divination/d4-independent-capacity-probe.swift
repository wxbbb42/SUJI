import Foundation
struct Fixture:Decodable {let birth:JSONValue;let rows:[Row];let rawBytes:Int}
struct Row:Decodable {let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Review {
 static func main() async throws {
  let input=try Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-d4-capacity-fixtures.json"));let fixtures=try JSONDecoder().decode([Fixture].self,from:input);var reports:[[String:Any]]=[]
  for (fidx,fixture) in fixtures.enumerated(){
   let calls=fixture.rows.enumerated().map{ ChatToolCall(id:"call_"+String(repeating:"r",count:23)+String($0.offset),name:$0.element.name,arguments:$0.element.arguments)}
   let outputs=Dictionary(uniqueKeysWithValues:zip(calls,fixture.rows).map{($0.0.id,ReadingVerificationEvidence.encoded($0.1.output))});let definitions=Set(calls.map(\.name)).map{ChatToolDefinition(name:$0,description:$0,parameters:["type":"object"])}
   var round=0;let orchestrator=ToolOrchestrator(complete:{_,_ in round+=1;return round==1 ? .toolCalls(calls):.text("ready")},execute:{call in .init(output:outputs[call.id]!,evidence:[call.id])})
   let context=try ToolContext(birth:nil,engineRevision:"fixture",referenceDate:Date(timeIntervalSince1970:1_738_123_200),mode:"命理");let result=try await orchestrator.run(history:[],definitions:definitions,context:context);let delivered=result.messages.filter{$0.role == .tool}
   var entry=ConversationEntry(role:"user",text:String(repeating:"请依据已返回的本命宫干与各层四化资料逐项说明。",count:80).prefix(1600).description);entry.toolReceipts=result.receipts;let restored=[ChatMessage(role:.system,content:ReadingPrompt.instruction(tone:"温和",mode:"命理",referenceDate:context.referenceDate,hasBirth:true)+"\n"+ReadingPrompt.writer)]+ReadingPrompt.history(from:[entry],currentUserID:entry.id,context:context);let replay=restored.filter{$0.role == .tool};let facts=ReadingVerificationEvidence.facts(restored);let review=ReadingVerifier.messages(draft:String(repeating:"这个关系只记录宫干和星曜落宫，不推定现实事件。",count:80),history:restored,question:entry.text)
   
   let fullHistory=[ChatMessage.assistantToolCalls(calls)]+calls.map{ChatMessage.toolResult(.init(callID:$0.id,output:outputs[$0.id]!))}
   let fullFacts=ReadingVerificationEvidence.facts(fullHistory)
   func factSet(_ f:[ReadingVerificationEvidence.Fact])->Set<String>{Set(f.map{$0.factKey+"="+ReadingVerificationEvidence.encoded($0.value)})}
   let factValuesPreserved=factSet(facts)==factSet(fullFacts)
   var actualSources:[String:JSONValue]=[:];var referenceCount=0;var referenceErrors=0;var unauthenticated=0;var removalAccepted=0
   for message in delivered {let id=message.toolCallID!;let body=try JSONDecoder().decode(JSONValue.self,from:Data(message.content!.utf8));let full=try JSONDecoder().decode(JSONValue.self,from:Data(outputs[id]!.utf8))
    if case let .array(refs)=ReadingVerificationEvidence.pointer("/reusedFacts",in:body){for ref in refs{referenceCount+=1
     guard case let .string(sourceId)=ReadingVerificationEvidence.pointer("/toolCallID",in:ref),case let .string(pointer)=ReadingVerificationEvidence.pointer("/pointer",in:ref),case let .string(path)=ReadingVerificationEvidence.pointer("/path",in:ref),let original=actualSources[sourceId],let value=ReadingVerificationEvidence.pointer(pointer,in:original),value==ReadingVerificationEvidence.pointer(path,in:full),ReadingVerificationEvidence.pointer(path,in:body)==nil else{referenceErrors+=1;continue}
     let receipt=result.receipts.first{$0.callID==id}!
     if NatalEvidenceProjection.wasDelivered(receipt,in:restored.filter{$0.toolCallID != sourceId}){removalAccepted+=1}
    }}
    if !NatalEvidenceProjection.wasDelivered(result.receipts.first{$0.callID==id}!,in:restored){unauthenticated+=1}
    actualSources[id]=body
   }
   try JSONEncoder().encode(review).write(to:URL(fileURLWithPath:"/tmp/suji-d4-capacity-request-\(fidx).json"));reports.append(["index":fidx,"birth":ReadingVerificationEvidence.encoded(fixture.birth),"rawBytes":fixture.rawBytes,"liveBytes":delivered.reduce(0){$0+($1.content?.utf8.count ?? 0)},"receiptCount":result.receipts.count,"liveCount":delivered.count,"replayCount":replay.count,"liveErrorCount":delivered.filter{$0.content?.contains("\"error\"")==true}.count,"replayEqualsLive":replay.map(\.content)==delivered.map(\.content),"factValuesPreserved":factValuesPreserved,"referenceCount":referenceCount,"referenceErrors":referenceErrors,"unauthenticatedReceipts":unauthenticated,"acceptedAfterSourceRemoval":removalAccepted,"factCount":facts.count,"flightFactCount":facts.filter{$0.factKey.hasPrefix("ziwei.palaceFlights")}.count,"reviewUTF16":review.reduce(0){$0+($1.content?.utf16.count ?? 0)},"reviewJSONBytes":try JSONEncoder().encode(review).count+1024])
  }
  let output=try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]);try output.write(to:URL(fileURLWithPath:"/tmp/suji-d4-native-capacity-final.json"));print(String(decoding:output,as:UTF8.self))
 }
}
