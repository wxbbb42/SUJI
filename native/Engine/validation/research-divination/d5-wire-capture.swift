import Foundation
private final class CaptureProtocol:URLProtocol {
 override class func canInit(with request:URLRequest)->Bool{true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
 override func startLoading(){
  do {
   let data:Data
   if let body=request.httpBody{data=body}else if let stream=request.httpBodyStream{stream.open();defer{stream.close()};var body=Data();var bytes=[UInt8](repeating:0,count:4096);while stream.hasBytesAvailable{let n=stream.read(&bytes,maxLength:bytes.count);if n<=0{break};body.append(bytes,count:n)};data=body}else{throw URLError(.cannotDecodeContentData)}
   try data.write(to:URL(fileURLWithPath:"/tmp/suji-d5-actual-chatclient-wire.json"))
   let response=HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:["Content-Type":"application/json"])!
   client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
   client?.urlProtocol(self,didLoad:Data(#"{"choices":[{"message":{"role":"assistant","content":"captured"}}]}"#.utf8))
   client?.urlProtocolDidFinishLoading(self)
  }catch{client?.urlProtocol(self,didFailWithError:error)}
 }
 override func stopLoading(){}
}
@main struct Capture{
 static func main()async throws{
  let index=CommandLine.arguments.dropFirst().first.flatMap(Int.init) ?? 0
  guard (0..<12).contains(index) else { throw URLError(.badURL) }
  let data=try Data(contentsOf:URL(fileURLWithPath:"/tmp/suji-d5-capacity-request-\(index).json"));let messages=try JSONDecoder().decode([ChatMessage].self,from:data)
  let configuration=URLSessionConfiguration.ephemeral;configuration.protocolClasses=[CaptureProtocol.self]
  let session=URLSession(configuration:configuration);defer{session.invalidateAndCancel()}
  let client=ChatClient(configuration:.init(baseURL:URL(string:"https://local-wire-capture.invalid")!,model:"test-model",api:.chatCompletions,authentication:.none),credential:nil,session:session)
  let result=try await client.complete(messages:messages)
  print("Captured fixture\(index) through actual ChatClient without network: \(result)")
 }
}
