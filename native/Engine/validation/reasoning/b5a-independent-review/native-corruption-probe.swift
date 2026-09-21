import Foundation
struct Fixture:Decodable{let date:String;let rows:[Row]}
struct Row:Decodable{let name:String;let arguments:JSONValue;let output:JSONValue}
@main struct Probe {
 static let folder="native/Engine/validation/reasoning/b5a-independent-review/"
 static func set(_ value:JSONValue,_ path:ArraySlice<String>,_ next:JSONValue?)->JSONValue {
  guard let first=path.first else{return next ?? .null};switch value{
  case var .object(v):if path.count==1{v[first]=next}else{v[first]=set(v[first] ?? .null,path.dropFirst(),next)};return .object(v)
  case var .array(v):guard let n=Int(first),v.indices.contains(n) else{return value};v[n]=set(v[n],path.dropFirst(),next);return .array(v)
  default:return value}
 }
 static func edit(_ v:JSONValue,_ p:String,_ n:JSONValue?)->JSONValue{set(v,p.split(separator:"/").map(String.init)[...],n)}
 static func json(_ v:JSONValue)->String{ReadingVerificationEvidence.encoded(v)}
 static func direct(_ root:JSONValue)->Bool{(try? LiuyaoFanfuTrace.sections(root:root,receiptID:"source-review",sourcePaths:[])) != nil}
 static func main() throws {
  let fixtures=try JSONDecoder().decode([Fixture].self,from:Data(contentsOf:URL(fileURLWithPath:folder+"source-fixtures.json")))
  var reports=[[String:Any]]()
  for (i,f) in fixtures.enumerated(){let r=f.rows[0];precondition(direct(r.output));reports.append(["case":"valid-source-\(i)","directAccepted":true])}
  let f=fixtures[0],r=f.rows[0],root=r.output
  guard case let .string(revision)=ReadingVerificationEvidence.pointer("/provenance/engineRevision",in:root)else{fatalError("revision")}
  let context=try ToolContext(birth:nil,engineRevision:revision,referenceDate:ISO8601DateFormatter().date(from:f.date)!,mode:"起卦")
  var mutations:[(String,JSONValue)]=[
   ("missing-moving-row",edit(root,"/fanfu/lines",[ReadingVerificationEvidence.pointer("/fanfu/lines/0",in:root)!])),
   ("static-original-path",edit(root,"/fanfu/lines/0/originalPath","/lines/0")),
   ("borrow-other-change",edit(root,"/fanfu/lines/0/changedPath","/lines/2/changed")),
   ("wrong-clash",edit(root,"/fanfu/lines/0/branchClash",false)),
   ("wrong-same-stem",edit(root,"/fanfu/lines/0/sameStem",true)),
   ("wrong-same-branch",edit(root,"/fanfu/lines/0/sameBranch",true)),
   ("full-projection-as-movers",edit(root,"/fanfu/trigrams/0/movingPositions",[1,2,3])),
   ("static-as-repeated",edit(root,"/fanfu/trigrams/1/branchRelation","repeated")),
   ("opposition-scope-confused",edit(root,"/fanfu/trigrams/0/directionalOpposition",true)),
   ("efficacy-promoted",edit(root,"/fanfu/efficacyEstablished",true)),
   ("source-id-wrong",edit(root,"/fanfu/sourceId","other")),
   ("missing-unknowns",edit(root,"/fanfu/unresolved",[])),
   ("extra-field",edit(root,"/fanfu/aggregateVerdict","反吟")),
   ("wrong-values-count",edit(root,"/lineValues",[8,6,6])),
   ("wrong-moving-index",edit(root,"/changingYao",[1,2,3])),
   ("static-change-decoration",edit(root,"/lines/0/changed",ReadingVerificationEvidence.pointer("/lines/1/changed",in:root)!)),
   ("wrong-projected-stem",edit(root,"/guaRelations/resulting/ganZhi/0","甲丑")),
   ("wrong-actual-change",edit(root,"/lines/1/changed/ganZhi","甲子")),
  ]
  var joint=edit(root,"/benGua/lower","艮");joint=edit(joint,"/fanfu/trigrams/0/from","艮")
  for (i,gz) in ["丙辰","丙午","丙申"].enumerated(){joint=edit(joint,"/guaRelations/original/ganZhi/\(i)",.string(gz));joint=edit(joint,"/lines/\(i)/ganZhi",.string(gz))}
  joint=edit(joint,"/fanfu/trigrams/0/branchRelation","neither");joint=edit(joint,"/fanfu/lines/0/branchClash",false);joint=edit(joint,"/fanfu/lines/1/branchClash",false)
  mutations.append(("joint-label-projection-and-flags-forgery",joint))
  var joint2=edit(root,"/bianGua/lower","乾");joint2=edit(joint2,"/fanfu/trigrams/0/to","乾")
  for(i,gz) in ["甲子","甲寅","甲辰"].enumerated(){joint2=edit(joint2,"/guaRelations/resulting/ganZhi/\(i)",.string(gz));if i>0{joint2=edit(joint2,"/lines/\(i)/changed/ganZhi",.string(gz))}}
  joint2=edit(joint2,"/fanfu/trigrams/0/branchRelation","neither");joint2=edit(joint2,"/fanfu/lines/0/branchClash",false);joint2=edit(joint2,"/fanfu/lines/1/branchClash",false)
  mutations.append(("joint-resulting-label-projection-forgery",joint2))
  for(name,v)in mutations{precondition(v != root,"no-op \(name)");let receipt=ToolReceipt(callID:"source-review",name:r.name,arguments:r.arguments,output:json(v),context:context);let d=direct(v),render=LiuyaoReferenceReading.render(receipts:[receipt],context:context) != nil;precondition(!d && !render,"accepted \(name)");reports.append(["case":name,"mutationChanged":true,"directAccepted":d,"renderAccepted":render])}
  if case let .array(sources)=ReadingVerificationEvidence.pointer("/ruleSources",in:root){
   for (name,s) in [("missing-source",sources.filter{ReadingVerificationEvidence.pointer("/id",in:$0) != "liuyao-fanfu-selected-v1"}),("hash-corruption",sources.map{ReadingVerificationEvidence.pointer("/id",in:$0) == "liuyao-fanfu-selected-v1" ? edit($0,"/references/0/sha256","forged"):$0})]{let v=edit(root,"/ruleSources",.array(s)),receipt=ToolReceipt(callID:"source-review",name:r.name,arguments:r.arguments,output:json(v),context:context);let render=LiuyaoReferenceReading.render(receipts:[receipt],context:context) != nil;precondition(!render);reports.append(["case":name,"renderAccepted":render])}
  }
  try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:folder+"native-corruption-report.json"));print("\(reports.count) source/native boundaries passed")
 }
}
