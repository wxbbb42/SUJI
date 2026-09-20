import Foundation
struct Fixture:Codable {let date:String;let label:String?;let rows:[Row]}
struct Row:Codable {let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Probe {
 static func main() async throws {
  let folder=URL(fileURLWithPath:CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "native/Engine/validation/reasoning/astronomy-launch/data").standardizedFileURL.path+"/"
  try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
  let bridge=try MingliBridge(scriptURL:URL(fileURLWithPath:"native/Resources/mingli.js"))
  let birth=BirthProfile(year:1995,month:8,day:15,hour:19,minute:30,gender:"女",city:"北京",longitude:116.4,timeZoneID:"Asia/Shanghai")
  let birthValue=try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(birth))
  let cacheData=try await bridge.request(ReadingVerificationEvidence.encoded(["command":"natal-astronomy","birth":birthValue]))
  let cache=try JSONDecoder().decode(JSONValue.self,from:cacheData)
  let typed=try NatalAstronomyPayload.validated(cacheData)
  var fixtures:[Fixture]=[]
  for body in ["all","Moon"] {
   let args:JSONValue=["body":.string(body)]
   let request:JSONValue=["command":"tool","name":"get_natal_astronomy","birth":birthValue,"astronomy":cache,"arguments":args,"now":"2026-09-20T04:00:00Z"]
   let data=try await bridge.request(ReadingVerificationEvidence.encoded(request))
   let response=try JSONDecoder().decode(JSONValue.self,from:data)
   let output=ReadingVerificationEvidence.pointer("/result",in:response)!
   precondition(ReadingVerificationEvidence.pointer("/engineRevision",in:output) == .string(typed.engineRevision))
   guard case let .array(positions)=ReadingVerificationEvidence.pointer("/sevenBodies/positions",in:output) else {fatalError("positions missing")}
   precondition(positions.count == (body == "all" ? 7 : 1))
   if body == "Moon" {precondition(ReadingVerificationEvidence.pointer("/sevenBodies/positions/0/body",in:output) == "Moon")}
   fixtures.append(Fixture(date:"2026-09-20T04:00:00Z",label:body,rows:[Row(name:"get_natal_astronomy",arguments:args,output:output)]))
  }
  try JSONEncoder().encode(fixtures).write(to:URL(fileURLWithPath:folder+"fixtures.json"))
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
   guard case let .string(revision)=ReadingVerificationEvidence.pointer("/engineRevision",in:fixture.rows[0].output) else {fatalError("missing revision")}
   let context=try ToolContext(birth:birth,engineRevision:revision,referenceDate:now,mode:"命理")
   let instruction=ChatMessage(role:.system,content:ReadingPrompt.instruction(tone:"清晰",mode:"命理",referenceDate:now,hasBirth:true)+"\n"+ReadingPrompt.writer)
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
   try JSONEncoder().encode(review).write(to:URL(fileURLWithPath:folder+"final-capacity-request-\(index).json"))
   try JSONEncoder().encode(ReadingVerificationEvidence.facts(fullHistory)).write(to:URL(fileURLWithPath:folder+"final-expected-facts-\(index).json"))
   CaptureProtocol.outputPath=folder+"final-wire-request-\(index).json"
   _ = try await client.complete(messages:review)
   let row:[String:Any]=["case":fixture.label!,"index":index,"date":fixture.date,"receiptCount":result.receipts.count,"faithfulChartRoundtrip":faithful,"factsPreserved":facts(fullHistory)==facts(replay),"replayEqualsLive":live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content),"authenticated":authenticated,"inlineBodyRemainsAfterCallRemoval":sourceRemovalAccepted,"reviewUTF16":review.reduce(0){$0+($1.content?.utf16.count ?? 0)},"messageCount":review.count]
   precondition(faithful && facts(fullHistory)==facts(replay) && authenticated==1 && sourceRemovalAccepted==1)
   precondition(live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content))
   precondition(retried.receipts.isEmpty && result.receipts.count==1 && !projected.isEmpty)
   precondition(ReadingVerificationEvidence.facts(replay.filter{($0.toolCalls ?? []).isEmpty}).isEmpty)
   reports.append(row)
  }
  let data=try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:folder+"final-native-capacity-report.json"));print("Completed \(reports.count) native delivery/replay probes")
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
