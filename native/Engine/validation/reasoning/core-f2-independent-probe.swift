import Foundation
struct Item: Decodable { let label:String;let root:JSONValue }
func replace(_ root:JSONValue,_ path:String,_ replacement:JSONValue)->JSONValue {
 let keys=path.split(separator:"/").map(String.init)
 func go(_ v:JSONValue,_ i:Int)->JSONValue { if i==keys.count{return replacement};switch v {case var .object(o):o[keys[i]]=go(o[keys[i]] ?? .null,i+1);return .object(o);case var .array(a):a[Int(keys[i])!]=go(a[Int(keys[i])!],i+1);return .array(a);default:return v} };return go(root,0)
}
@main struct Probe {
 static func main() throws {
  let rows=try String(contentsOfFile:CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "/tmp/suji-f2-review-fixtures.ndjson",encoding:.utf8).split(separator:"\n");var missing:[String]=[],badEvidence=0,rendered=0,fieldCount=0,allMovingDark:[String]=[];var example:JSONValue?;var receiptCounts:[String:Bool]=[:]
  func render(_ root:JSONValue)throws->LiuyaoReferenceReading.Report? {let rev=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root)!;guard case let .string(revision)=rev else{fatalError()};let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦");let receipt=ToolReceipt(callID:"independent",name:"cast_liuyao",arguments:[:],output:ReadingVerificationEvidence.encoded(root),context:context);return LiuyaoReferenceReading.render(receipts:[receipt],context:context)}
  for line in rows { let item=try JSONDecoder().decode(Item.self,from:Data(line.utf8));if item.label=="33:wealth:self"{example=item.root};guard let report=try render(item.root)else{missing.append(item.label);continue};rendered+=1;for s in report.sections{for f in s.evidence{fieldCount+=1;if ReadingVerificationEvidence.pointer(f.pointer,in:item.root) != f.value || f.toolCallID != "independent"{badEvidence+=1}}};if Int(item.label.split(separator:":")[0])!<64 && report.text.contains("暗动"){allMovingDark.append(item.label)}}
  let root=example!;do { guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root) else {fatalError()};let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:"2024-02-04T04:00:00Z")!,mode:"起卦");let receipts=(0..<9).map{ ToolReceipt(callID:"reuse-\($0)",name:"cast_liuyao",arguments:[:],output:ReadingVerificationEvidence.encoded(root),context:context) };for count in [1,4,5,8,9] {receiptCounts[String(count)]=LiuyaoReferenceReading.render(receipts:Array(receipts.prefix(count)),context:context) != nil} };let mutations:[(String,String,JSONValue)] = [
   ("wrong-advance-pair","/lines/0/rules/advanceRetreat/kind","进神"),
   ("wrong-flying-hidden-relation","/lines/2/rules/flyingHidden/relation","飞克伏"),
   ("original-candidate-as-calendar","/yongShen/candidates/0/reason","absent-visible-calendar-role"),
   ("wrong-source-references","/ruleSources/0/references",["not a source"]),
   ("changed-void-borrows-other-line","/lines/0/rules/advanceRetreat/conditions/0/factPaths",["/lines/5/context/isVoid"]),
   ("wrong-condition-state","/lines/0/rules/advanceRetreat/conditions/0/state","matched"),
   ("wrong-return-branch-pair","/lines/0/rules/returning/branchRelation","六冲"),
   ("timing-wrong-context-path","/yingQi/branchesByCandidate/0/conditionsPath","/lines/5/context")
  ];var acceptedMutations:[String]=[]
  for (name,path,value)in mutations { if try render(replace(root,path,value)) != nil {acceptedMutations.append(name)} }
  let definition=ChatToolDefinition(name:"cast_liuyao",description:"",parameters:["type":"object"]);let defs:[String:Any]=["function":["name":"cast_liuyao","description":"","parameters":["type":"object"]]];let qdef:[String:Any]=["function":["name":"setup_qimen","description":"","parameters":["type":"object"]]];let data=try JSONSerialization.data(withJSONObject:[defs,qdef]);var gates:[String:Bool]=[:];for text in ["请用六爻问收款","六爻结合八字","用六爻与奇门看","用六爻與奇門看","不要奇门，只用六爻","六爻和紫微一起看","解释什么是六爻","不要起卦，只解释六爻里的世爻和应爻"] {let ds=try ReadingIntent.definitions(from:data,mode:"起卦",question:text,hasBirth:true);gates[text]=LiuyaoReferenceReading.isExclusiveRequest(definitions:ds,question:text)}
  let output:[String:Any]=["acceptedDuplicateReceiptCounts":receiptCounts,"records":rows.count,"rendered":rendered,"nilCount":missing.count,"firstNil":Array(missing.prefix(20)),"evidenceFields":fieldCount,"badEvidence":badEvidence,"allMovingDarkMentions":allMovingDark,"acceptedMutations":acceptedMutations,"actualGates":gates];let result=try JSONSerialization.data(withJSONObject:output,options:[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]);try result.write(to:URL(fileURLWithPath:"/tmp/suji-f2-review-final-cap-report.json"));print(String(decoding:result,as:UTF8.self));_ = definition
 }
}
