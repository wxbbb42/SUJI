import Foundation
struct Fixture:Decodable {let date:String;let label:String?;let rows:[Row]}
struct Row:Decodable {let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Probe {
 static func main() async throws {
  let folder="native/Engine/validation/reasoning/b5a-independent-review/"
  let fixtures=try ["fixtures.json"].flatMap { try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:folder+$0))) }
  var reports:[[String:Any]]=[]
  let sessionConfiguration=URLSessionConfiguration.ephemeral
  sessionConfiguration.protocolClasses=[CaptureProtocol.self]
  let apiConfiguration=try ManagedAI.configuration(supabase:SupabaseConfiguration(url:URL(string:"https://review.invalid")!,anonKey:"test-public"))
  let client=ChatClient(configuration:apiConfiguration,credential:"test-session",session:URLSession(configuration:sessionConfiguration))
  for (index,fixture) in fixtures.enumerated() {
   let calls=fixture.rows.enumerated().map { ChatToolCall(id:String(repeating:$0.offset == 0 ? "a":"b",count:200),name:$0.element.name,arguments:$0.element.arguments) }
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
   let projected=zip(calls,fixture.rows).map { call,row in NatalEvidenceProjection.output(ReadingVerificationEvidence.encoded(row.output),name:call.name,delivered:[.assistantToolCalls(calls)],callID:call.id) }
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
   try JSONEncoder().encode(review).write(to:URL(fileURLWithPath:"native/Engine/validation/reasoning/b5a-independent-review/final-capacity-request-\(index).json"))
   try JSONEncoder().encode(ReadingVerificationEvidence.facts(fullHistory)).write(to:URL(fileURLWithPath:folder+"final-expected-facts-\(index).json"))
   CaptureProtocol.outputPath=folder+"final-wire-request-\(index).json"
   _ = try await client.complete(messages:review)
   let liuyaoReceipt=result.receipts.first{$0.name == "cast_liuyao"}!
   let reading=LiuyaoReferenceReading.render(receipts:[liuyaoReceipt],context:context)
   let liuyaoRoot=fixture.rows.first{$0.name == "cast_liuyao"}!.output
   let tombObjects=ReadingVerificationEvidence.pointer("/tombExtinction/objects",in:liuyaoRoot)!
   let objectCount: Int; if case let .array(a)=tombObjects {objectCount=a.count}else{objectCount=0}
   let tombSections=reading?.sections.filter{$0.id.hasPrefix("tomb-") && $0.id != "tomb-policy"} ?? []
   let fanfuSections=reading?.sections.filter{$0.id.hasPrefix("fanfu-")} ?? []
   let moverCount: Int;if case let .array(movers)=ReadingVerificationEvidence.pointer("/changingYao",in:liuyaoRoot){moverCount=movers.count}else{moverCount=0}
   let fanfuTraceValid=fanfuSections.count == 3+moverCount && fanfuSections.allSatisfy { section in !section.evidence.isEmpty && section.evidence.allSatisfy { $0.toolCallID == liuyaoReceipt.callID && $0.value == ReadingVerificationEvidence.pointer($0.pointer,in:liuyaoRoot) } }
   let traceValid=tombSections.count == objectCount && tombSections.allSatisfy { section in section.evidence.allSatisfy { $0.toolCallID == liuyaoReceipt.callID && $0.value == ReadingVerificationEvidence.pointer($0.pointer,in:liuyaoRoot) } }
   let decodedReceipt=try JSONDecoder().decode(ToolReceipt.self,from:JSONEncoder().encode(liuyaoReceipt))
   let renderRoundtrip=reading?.text == LiuyaoReferenceReading.render(receipts:[decodedReceipt],context:context)?.text
   let row:[String:Any]=["eventVariant":fixture.label ?? "plain-matrix","referenceRenderAccepted":reading != nil,"objectCount":objectCount,"renderedObjectCount":tombSections.count,"tracePointersExact":traceValid,"fanfuTracePointersExact":fanfuTraceValid,"fanfuSections":fanfuSections.count,"renderRoundtrip":renderRoundtrip,"index":index,"date":fixture.date,"liveBytes":live.reduce(0){$0+($1.content?.utf8.count ?? 0)},"maxProjectedUTF16":projected.map(\.utf16.count).max()!,"maxToolUTF16":live.map{$0.content!.utf16.count}.max()!,"receiptCount":result.receipts.count,"capacityError":live.contains{($0.content ?? "").contains("容量不足")},"faithfulChartRoundtrip":faithful,"factsPreserved":facts(fullHistory)==facts(replay),"replayEqualsLive":live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content),"retryEvidence":retried.evidence,"authenticated":authenticated,"sourceRemovalAccepted":sourceRemovalAccepted,"reviewUTF16":review.reduce(0){$0+($1.content?.utf16.count ?? 0)},"messageCount":review.count]
   reports.append(row)
  }
  let data=try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"native/Engine/validation/reasoning/b5a-independent-review/final-native-capacity-report.json"));print("Completed \(reports.count) native delivery/replay probes")
 }
}

// Exercise the real ChatClient JSON encoder without sending any external request.
final class CaptureProtocol:URLProtocol {
 static var outputPath=""
 override class func canInit(with request:URLRequest)->Bool {true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
 override func startLoading(){
  do {
   let bytes:Data
   if let body=request.httpBody {bytes=body}
   else if let stream=request.httpBodyStream {stream.open();defer{stream.close()};var data=Data(),buffer=[UInt8](repeating:0,count:4096);while stream.hasBytesAvailable {let n=stream.read(&buffer,maxLength:buffer.count);if n<0{throw stream.streamError ?? URLError(.cannotDecodeRawData)};if n==0{break};data.append(contentsOf:buffer.prefix(n))};bytes=data}
   else {throw URLError(.zeroByteResource)}
   try bytes.write(to:URL(fileURLWithPath:Self.outputPath))
   let response=HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"application/json"])!
   client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
   client?.urlProtocol(self,didLoad:Data(#"{"choices":[{"message":{"role":"assistant","content":"captured"}}]}"#.utf8))
   client?.urlProtocolDidFinishLoading(self)
  }catch{client?.urlProtocol(self,didFailWithError:error)}
 }
 override func stopLoading(){}
}
