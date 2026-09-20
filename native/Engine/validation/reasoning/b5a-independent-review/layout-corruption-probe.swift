import Foundation
struct Fixture:Decodable{let date:String;let rows:[Row]}
struct Row:Decodable{let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Probe {
 static let folder="native/Engine/validation/reasoning/b5a-independent-review/"
 static func json(_ v:JSONValue)->String{ReadingVerificationEvidence.encoded(v)}
 static func parse(_ s:String)throws->JSONValue{try JSONDecoder().decode(JSONValue.self,from:Data(s.utf8))}
 static func set(_ value:JSONValue,_ path:ArraySlice<String>,_ next:JSONValue?)->JSONValue {
  guard let first=path.first else{return next ?? .null};switch value{
  case var .object(v):if path.count==1{v[first]=next}else{v[first]=set(v[first] ?? .null,path.dropFirst(),next)};return .object(v)
  case var .array(v):guard let n=Int(first),v.indices.contains(n) else{return value};v[n]=set(v[n],path.dropFirst(),next);return .array(v)
  default:return value}
 }
 static func edit(_ v:JSONValue,_ p:[String],_ n:JSONValue?)->JSONValue{set(v,p[...],n)}
 static func markers(_ v:JSONValue,_ path:[String]=[])->[([String],[JSONValue])]{switch v{
  case let .object(o):if case let .array(row)=o["$row"]{return [(path,row)]+row.enumerated().flatMap{markers($0.element,path+["$row",String($0.offset)])}};return o.keys.sorted().flatMap{markers(o[$0]!,path+[$0])}
  case let .array(a):return a.enumerated().flatMap{markers($0.element,path+[String($0.offset)])}
  default:return []}}
 static func main()throws{
  var results=[[String:Any]]()
  let values:[JSONValue]=[.null,false,true,0,-17,.integer(9007199254740991),.double(1.25),"","quote\"\\\n🚀",[],.object([:]),[1,.null,[]],.object(["deep":[true,.object([:])]])]
  let synthetic:JSONValue=["items":.array(values.map{["alphaLongFieldName":$0,"betaLongFieldName":[],"gammaLongFieldName":.object([:]),"deltaLongFieldName":.null,"__proto__":"prototype-key-is-data","constructor":"constructor-is-data"]})]
  let encoded=try parse(LiuyaoConditionTransport.encodeLayouts(json(synthetic)))
  precondition(encoded != synthetic && LiuyaoConditionTransport.expand(encoded)==synthetic)
  try JSONEncoder().encode(["original":synthetic,"packed":encoded]).write(to:URL(fileURLWithPath:folder+"layout-synthetic-values.json"))
  results.append(["case":"nested-json-types-and-prototype-keys","equal":true,"variants":values.count])
  for(i,v) in values.enumerated(){let raw=json(v);precondition(LiuyaoConditionTransport.encodeLayouts(raw)==raw);precondition(LiuyaoConditionTransport.expand(v)==v);results.append(["case":"unpacked-value-\(i)","equal":true])}
  for (name,v) in [("root-marker",JSONValue.object(["$row":[]])),("nested-marker",JSONValue.object(["items":[["$row":[0]]]])),("nested-metadata",JSONValue.object(["items":[["liuyaoObjectRows":[:]]]]))]{let raw=json(v);precondition(LiuyaoConditionTransport.encodeLayouts(raw)==raw);precondition(LiuyaoConditionTransport.expand(v)==nil);results.append(["case":name,"encoderNoOp":true,"expandRejected":true])}
  let f=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:folder+"fixtures.json")))[0],r=f.rows[0]
  guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:r.output)else{fatalError("revision")}
  let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:f.date)!,mode:"起卦"),call=ChatToolCall(id:String(repeating:"a",count:200),name:r.name,arguments:r.arguments)
  let receipt=ToolReceipt(callID:call.id,name:r.name,arguments:r.arguments,output:json(r.output),context:context),prior=[ChatMessage.assistantToolCalls([call])]
  let packed=try parse(NatalEvidenceProjection.output(receipt.output,name:r.name,delivered:prior,callID:call.id))
  let found=markers(packed);precondition(!found.isEmpty)
  let (path,row)=found[0],meta=["liuyaoObjectRows"]
  guard case let .array(layouts)=ReadingVerificationEvidence.pointer("/liuyaoObjectRows/layouts",in:packed),case let .integer(idx)=row[0],case let .array(fields)=layouts[Int(idx)]else{fatalError("layouts")}
  let keys=fields.map{v->String in guard case let .string(k)=v else{fatalError("key")};return k}
  var mutations:[(String,JSONValue)]=[
   ("layout-metadata-missing",edit(packed,meta,nil)),("layout-metadata-null",edit(packed,meta,.null)),
   ("layout-version-wrong",edit(packed,meta+["version"],2)),("layout-format-wrong",edit(packed,meta+["format"],"wrong")),
   ("layout-extra-key",edit(packed,meta+["extra"],true)),("layouts-empty",edit(packed,meta+["layouts"],[])),
   ("layouts-duplicate",edit(packed,meta+["layouts"],.array(layouts+[layouts[0]]))),
   ("layouts-unused",edit(packed,meta+["layouts"],.array(layouts+[["a-new-unused-key"]]))),
   ("layout-empty-fields",edit(packed,meta+["layouts",String(idx)],[])),
   ("layout-duplicate-field",edit(packed,meta+["layouts",String(idx)],.array(fields+[fields[0]]))),
   ("layout-empty-name",edit(packed,meta+["layouts",String(idx),"0"],"")),
   ("layout-non-string",edit(packed,meta+["layouts",String(idx),"0"],false)),
   ("layout-reserved-name",edit(packed,meta+["layouts",String(idx),"0"],"$row")),
   ("layout-nested-metadata-name",edit(packed,meta+["layouts",String(idx),"0"],"liuyaoObjectRows")),
   ("marker-not-array",edit(packed,path+["$row"],true)),("marker-empty-row",edit(packed,path+["$row"],[])),
   ("marker-negative-index",edit(packed,path+["$row","0"],-1)),("marker-huge-index",edit(packed,path+["$row","0"],99999)),
   ("marker-float-index",edit(packed,path+["$row","0"],.double(1.5))),
   ("marker-long-row",edit(packed,path+["$row"],.array(row+[.null]))),
   ("marker-short-row",edit(packed,path+["$row"],.array(Array(row.dropLast())))),
   ("marker-extra-object-key",edit(packed,path+["extra"],true)),
   ("partial-unpacking",edit(packed,path,.object(Dictionary(uniqueKeysWithValues:zip(keys,row.dropFirst()))))),
   ("nested-metadata-marker",edit(packed,path+["$row","1"],["liuyaoObjectRows":[:]])),
   ("marker-in-excluded-dictionary",edit(packed,["ruleConditionRows","$row"],[0])),
   ("marker-in-question-reference",edit(packed,["questionFromArguments","$row"],[0])),
   ("root-marker-with-layouts",edit(packed,["$row"],[0])),
  ]
  if fields.count>1{mutations.append(("layout-unsorted-fields",edit(packed,meta+["layouts",String(idx)],.array(fields.reversed()))))}
  for(name,v) in mutations{precondition(v != packed,"no-op \(name)");let history=prior+[ChatMessage.toolResult(.init(callID:call.id,output:json(v)))],expanded=LiuyaoConditionTransport.expand(v) != nil,facts=ReadingVerificationEvidence.facts(history).count,auth=NatalEvidenceProjection.wasDelivered(receipt,in:history);precondition(!expanded && facts==0 && !auth,"accepted \(name)");results.append(["case":name,"expandAccepted":expanded,"factCount":facts,"authenticated":auth,"mutationChanged":true])}
  var valid=packed;valid=edit(valid,path+["$row","1"],"changed-valid-JSON-value")
  precondition(valid != packed)
  let auth=NatalEvidenceProjection.wasDelivered(receipt,in:prior+[.toolResult(.init(callID:call.id,output:json(valid)))]);precondition(!auth);results.append(["case":"well-shaped-value-tamper","expandAccepted":LiuyaoConditionTransport.expand(valid) != nil,"authenticated":auth])
  try JSONSerialization.data(withJSONObject:results,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:folder+"layout-corruption-report.json"));print("\(results.count) layout/primitive boundaries passed")
 }
}
