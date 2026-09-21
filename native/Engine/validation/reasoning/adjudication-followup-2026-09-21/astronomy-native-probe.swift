import Foundation
struct Fixture:Codable {let date:String;let label:String?;let rows:[Row];var birth:BirthProfile?=nil}
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
  for body in ["all","Moon","Rahu","Ketu","Apogee","PurpleQi","LifeDegree"] {
   let args:JSONValue=["body":.string(body)]
   let request:JSONValue=["command":"tool","name":"get_natal_astronomy","birth":birthValue,"astronomy":cache,"arguments":args,"now":"2026-09-20T04:00:00Z"]
   let data=try await bridge.request(ReadingVerificationEvidence.encoded(request))
   let response=try JSONDecoder().decode(JSONValue.self,from:data)
   let output=ReadingVerificationEvidence.pointer("/result",in:response)!
   precondition(ReadingVerificationEvidence.pointer("/engineRevision",in:output) == .string(typed.engineRevision))
   guard case let .array(positions)=ReadingVerificationEvidence.pointer("/sevenBodies/positions",in:output) else {fatalError("positions missing")}
   precondition(positions.count == (body == "all" ? 7 : body == "Moon" ? 1 : 0))
   if body == "Moon" {precondition(ReadingVerificationEvidence.pointer("/sevenBodies/positions/0/body",in:output) == "Moon")}
   fixtures.append(Fixture(date:"2026-09-20T04:00:00Z",label:body,rows:[Row(name:"get_natal_astronomy",arguments:args,output:output)]))
  }
  for (label, b) in [("bazi-competition-unresolved",BirthProfile(year:1984,month:9,day:10,hour:17,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-competition-available",BirthProfile(year:1984,month:9,day:20,hour:17,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-competition-blocked",BirthProfile(year:1984,month:9,day:30,hour:17,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-occurrence-selection",BirthProfile(year:1986,month:3,day:11,hour:13,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-rooted-selection",BirthProfile(year:1986,month:3,day:31,hour:13,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-regular",birth),("bazi-earth",BirthProfile(year:1980,month:1,day:26,hour:7,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai")),("bazi-rooted",BirthProfile(year:1993,month:6,day:8,hour:13,minute:30,gender:"男",city:"北京",longitude:120,timeZoneID:"Asia/Shanghai"))] {
   let value=try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(b))
   var rows:[Row]=[]
   for domain in ["事业","财富"] {
    let args:JSONValue=["domain":.string(domain)]
    let response=try JSONDecoder().decode(JSONValue.self,from:await bridge.request(ReadingVerificationEvidence.encoded(["command":"tool","name":"get_domain","birth":value,"arguments":args,"now":"2026-09-20T04:00:00Z"])))
    guard let output=ReadingVerificationEvidence.pointer("/result",in:response) else {fatalError("domain output")}
    rows.append(Row(name:"get_domain",arguments:args,output:output))
   }
   fixtures.append(Fixture(date:"2026-09-20T04:00:00Z",label:label,rows:rows,birth:b))
  }
  fixtures.append(Fixture(date:"2026-09-20T04:00:00Z",label:"astronomy-and-bazi",rows:[fixtures[0].rows[0],fixtures[12].rows[0]],birth:birth))
  try JSONEncoder().encode(fixtures).write(to:URL(fileURLWithPath:folder+"fixtures.json"))
  var reports:[[String:Any]]=[]
  let sessionConfiguration=URLSessionConfiguration.ephemeral
  sessionConfiguration.protocolClasses=[CaptureProtocol.self]
  let apiConfiguration=try ManagedAI.configuration(supabase:SupabaseConfiguration(url:URL(string:"https://review.invalid")!,anonKey:"test-public"))
  let client=ChatClient(configuration:apiConfiguration,credential:"test-session",session:URLSession(configuration:sessionConfiguration))
  for (index,fixture) in fixtures.enumerated() {
   let calls=fixture.rows.enumerated().map { ChatToolCall(id:String(repeating:$0.offset == 0 ? "a":"b",count:200),name:$0.element.name,arguments:$0.element.arguments) }
   let outputs=Dictionary(uniqueKeysWithValues:zip(calls,fixture.rows).map {($0.0.id,ReadingVerificationEvidence.encoded($0.1.output))})
   let definitions=Array(Set(calls.map(\.name))).sorted().map {ChatToolDefinition(name:$0,description:$0,parameters:["type":"object"])}
   let now=ISO8601DateFormatter().date(from:fixture.date)!
   let revision=typed.engineRevision
   let context=try ToolContext(birth:fixture.birth ?? birth,engineRevision:revision,referenceDate:now,mode:"命理")
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
    let messageIndex=result.messages.firstIndex(of:message)!
    guard var body=ToolOutputWire.decode(message,history:Array(result.messages.prefix(messageIndex))) else {fatalError("invalid wire grammar")}
    guard case var .object(root)=body else {fatalError("not object")}
    if let ref=root.removeValue(forKey:"questionFromArguments") {
     guard ReadingVerificationEvidence.pointer("/toolCallID",in:ref) == .string(calls[i].id),ReadingVerificationEvidence.pointer("/pointer",in:ref) == "/question" else {fatalError("wrong argument reference")}
     root["question"]=ReadingVerificationEvidence.pointer("/question",in:calls[i].arguments);body = .object(root)
    }
    // Same natal fields may point to an earlier delivered concrete receipt.
    if case var .object(root)=body,case let .array(refs)=root.removeValue(forKey:"reusedFacts") {
     root.removeValue(forKey:"reusedFactsFormat")
     func set(_ path:[Substring],_ value:JSONValue,_ object:inout [String:JSONValue]) {
      let key=String(path[0]);if path.count==1 {object[key]=value;return}
      if case var .object(child)=object[key] {set(Array(path.dropFirst()),value,&child);object[key] = .object(child)}
      else if case var .array(array)=object[key],let n=Int(path[1]),case var .object(child)=array[n] {set(Array(path.dropFirst(2)),value,&child);array[n] = .object(child);object[key] = .array(array)}
      else {fatalError("reference target")}
     }
     for ref in refs {
      guard case let .string(target)=ReadingVerificationEvidence.pointer("/path",in:ref),case let .string(sourceID)=ReadingVerificationEvidence.pointer("/toolCallID",in:ref),case let .string(sourcePath)=ReadingVerificationEvidence.pointer("/pointer",in:ref),let j=calls.firstIndex(where:{$0.id==sourceID}),j<i,let v=ReadingVerificationEvidence.pointer(sourcePath,in:fixture.rows[j].output) else {fatalError("reference source")}
      set(target.split(separator:"/"),v,&root)
     }
     body = .object(root)
    }
    faithful = faithful && body == fixture.rows[i].output
    if NatalEvidenceProjection.wasDelivered(result.receipts[i],in:replay) { authenticated+=1 }
    if NatalEvidenceProjection.wasDelivered(result.receipts[i],in:replay.filter{!($0.toolCalls ?? []).contains{$0.id == calls[i].id}}) {sourceRemovalAccepted+=1}
   }
   let fullHistory=[instruction,.assistantToolCalls(calls)]+calls.map{ChatMessage.toolResult(.init(callID:$0.id,output:outputs[$0.id]!))}
   func facts(_ h:[ChatMessage])->Set<String>{Set(ReadingVerificationEvidence.facts(h).map{$0.toolCallID+"|"+$0.factKey+"|"+$0.pointer+"="+ReadingVerificationEvidence.encoded($0.value)})}
   // Natal sharing intentionally cites the earlier concrete receipt rather
   // than inventing a second source ID for identical values. Require every
   // distinct fact plus exact identity for every retained source.
   func logicalFacts(_ h:[ChatMessage])->Set<String>{Set(ReadingVerificationEvidence.facts(h).map{$0.factKey+"="+ReadingVerificationEvidence.encoded($0.value)})}
   let factsPreserved=logicalFacts(fullHistory)==logicalFacts(replay) && facts(replay).isSubset(of:facts(fullHistory))
   let review=ReadingVerifier.messages(draft:String(repeating:"这只说明盘面关系，尚未裁定效力或事件结果。",count:80),history:replay,question:entry.text)
   try JSONEncoder().encode(review).write(to:URL(fileURLWithPath:folder+"final-capacity-request-\(index).json"))
   try JSONEncoder().encode(ReadingVerificationEvidence.facts(replay)).write(to:URL(fileURLWithPath:folder+"final-expected-facts-\(index).json"))
   CaptureProtocol.outputPath=folder+"final-wire-request-\(index).json"
   _ = try await client.complete(messages:review)
   let row:[String:Any]=["case":fixture.label!,"index":index,"date":fixture.date,"receiptCount":result.receipts.count,"faithfulChartRoundtrip":faithful,"factsPreserved":factsPreserved,"replayEqualsLive":live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content),"authenticated":authenticated,"inlineBodyRemainsAfterCallRemoval":sourceRemovalAccepted,"reviewUTF16":review.reduce(0){$0+($1.content?.utf16.count ?? 0)},"messageCount":review.count]
   if !faithful || !factsPreserved || authenticated != calls.count { try JSONSerialization.data(withJSONObject:row,options:.prettyPrinted).write(to:URL(fileURLWithPath:folder+"failure.json")) }
   precondition(faithful && factsPreserved && authenticated==calls.count)
   precondition(live.map(\.content)==replay.filter{$0.role == .tool}.map(\.content))
   precondition(retried.receipts.isEmpty && result.receipts.count==calls.count && !projected.isEmpty)
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
