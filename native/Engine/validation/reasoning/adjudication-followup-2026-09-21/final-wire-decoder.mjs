import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {providerRequest,MAX_BODY_BYTES} from '../../../../../supabase/functions/suji-chat/handler.mjs';
const folder=(process.argv[2]??'native/Engine/validation/reasoning/b5b-launch-acceptance/data').replace(/\/$/,'')+'/';
const fixtures=['fixtures.json'].flatMap(f=>JSON.parse(fs.readFileSync(folder+f,'utf8')));
const canonical=value=>JSON.stringify(value&&typeof value==='object'?(Array.isArray(value)?value.map(v=>JSON.parse(canonical(v))):Object.fromEntries(Object.keys(value).sort().map(k=>[k,JSON.parse(canonical(value[k]))]))):value);
const factToken=f=>canonical([f.toolCallID,f.factKey,f.pointer,f.value]);
// Independent expansion of the existing backward-only value dictionary in
// source messages; verify the digest only after reconstructing the full text.
function expandDirectory(raw){
 const meta=raw.sharedValueRows;if(!meta)return raw;
 assert.equal(meta.version,1);assert.ok(Array.isArray(meta.values)&&meta.values.length>0);
 const values=[],used=new Set();
 const expand=v=>{
  if(Array.isArray(v))return v.map(expand);
  if(!v||typeof v!=='object')return v;
  if(Object.hasOwn(v,'$v')){
   assert.deepEqual(Object.keys(v),['$v']);assert.ok(Number.isInteger(v.$v)&&v.$v>=0&&v.$v<values.length);used.add(v.$v);return structuredClone(values[v.$v]);
  }
  assert.ok(!Object.hasOwn(v,'sharedValueRows'));return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,expand(x)]));
 };
 for(const value of meta.values)values.push(expand(value));
 const body={...raw};delete body.sharedValueRows;const result=expand(body);
 assert.equal(used.size,values.length);return result;
}
const output=[];
let packedCharts=0,packedRows=0,emptyPathRows=0,IDDictionaryMessages=0,layoutMessages=0,objectLayoutCharts=0,objectLayoutRows=0,sourceDirectories=0;
for(let i=0;i<fixtures.length;i++){
 const bytes=fs.readFileSync(folder+`final-wire-request-${i}.json`),request=JSON.parse(bytes);
 assert.ok(bytes.length<=MAX_BODY_BYTES);providerRequest(request);
 const expected=JSON.parse(fs.readFileSync(folder+`final-expected-facts-${i}.json`,'utf8')).map(factToken).sort();
 const reconstructed=[];const calls=new Map(),restored=new Map(),directories=new Map();let charts=0;
 for(const message of request.messages){
  const sourcePrefix='完整规则来源目录（同轮工具证据）：\n';
  if(message.role==='system'&&message.content?.startsWith(sourcePrefix)){
   const directory=expandDirectory(JSON.parse(message.content.slice(sourcePrefix.length)));
   assert.equal(directory.version,1);assert.ok(!directories.has(directory.toolCallID));
   assert.ok(Array.isArray(directory.ruleSources));
   assert.equal(directory.sha256,createHash('sha256').update(canonical(directory.ruleSources)).digest('hex'));
   directories.set(directory.toolCallID,directory);sourceDirectories++;
  }
  for(const c of message.tool_calls??[])calls.set(c.id,c);
  if(message.role==='tool'){
   const call=calls.get(message.tool_call_id),rawChart=JSON.parse(message.content),raw=fixtures[i].rows.find(r=>r.name===call.function.name&&canonical(r.arguments)===canonical(JSON.parse(call.function.arguments))).output;
   const valueMeta=rawChart.sharedValueRows,values=[];
   const unpackValue=v=>{if(Array.isArray(v))return v.map(unpackValue);if(!v||typeof v!=='object')return v;if(Object.hasOwn(v,'$v')){assert.deepEqual(Object.keys(v),['$v']);assert.ok(Number.isInteger(v.$v)&&v.$v>=0&&v.$v<values.length);return structuredClone(values[v.$v]);}return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,unpackValue(x)]));};
   if(valueMeta){assert.equal(valueMeta.version,1);for(const value of valueMeta.values)values.push(unpackValue(value));delete rawChart.sharedValueRows;}
   const chart=unpackValue(rawChart);
   if(chart.questionFromArguments){const ref=chart.questionFromArguments;assert.equal(ref.toolCallID,call.id);assert.equal(ref.pointer,'/question');chart.question=JSON.parse(call.function.arguments).question;delete chart.questionFromArguments;}
   if(chart.liuyaoObjectRows){
    const meta=chart.liuyaoObjectRows;assert.equal(meta.version,1);assert.ok(Array.isArray(meta.layouts));
    const unpack=value=>{
     if(Array.isArray(value))return value.map(unpack);
     if(value===null||typeof value!=='object')return value;
     if(Object.hasOwn(value,'$row')){assert.deepEqual(Object.keys(value),['$row']);const [index,...values]=value.$row,keys=meta.layouts[index];assert.ok(Number.isInteger(index));assert.equal(keys.length,values.length);objectLayoutRows++;return Object.fromEntries(keys.map((k,n)=>[k,unpack(values[n])]))}
     return Object.fromEntries(Object.entries(value).map(([k,v])=>[k,unpack(v)]));
    };
    for(const key of Object.keys(chart))if(!['liuyaoObjectRows','ruleConditionRows','questionFromArguments'].includes(key))chart[key]=unpack(chart[key]);
    delete chart.liuyaoObjectRows;objectLayoutCharts++;
   }
   if(chart.qimenTimingDateRows){
    const meta=chart.qimenTimingDateRows;assert.equal(meta.version,1);
    assert.deepEqual(meta.columns,['unit','ganZhi','branch','startsAt','endsAt','eligibleStart','eligibleEnd','triggerIds','firstWindow']);
    const times=Array.isArray(meta.timestamps)?meta.timestamps:meta.timestamps.offsets.map(n=>new Date(Date.parse(meta.timestamps.base)+n*meta.timestamps.stepMilliseconds).toISOString());
    chart.timing.dates=chart.timing.dates.map(row=>{assert.equal(row.length,9);return Object.fromEntries(meta.columns.map((key,j)=>[key,j>=3&&j<=6?times[row[j]]:j===7?meta.triggerSets[row[j]]:row[j]]));});
    delete chart.qimenTimingDateRows;
   }
   if(chart.ruleConditionRows){
    const meta=chart.ruleConditionRows;
    assert.deepEqual(meta.columns,['idIndex','stateIndex','factPathIndices']);assert.deepEqual(meta.states,['matched','not-matched','unresolved']);
    for(const line of chart.lines)for(const rule of Object.values(line.rules))if(rule.conditions){
     rule.conditions=rule.conditions.map(row=>{assert.equal(row.length,3);packedRows++;if(!row[2].length)emptyPathRows++;return{id:meta.ids[row[0]],state:meta.states[row[1]],factPaths:row[2].map(p=>meta.paths[p])}});
    }
    delete chart.ruleConditionRows;packedCharts++;
   }
   if(chart.ruleSourcesFromDirectory){
    const ref=chart.ruleSourcesFromDirectory,directory=directories.get(ref.toolCallID);
    assert.ok(directory);assert.equal(ref.toolCallID,call.id);
    assert.equal(ref.toolName,call.function.name);assert.equal(directory.toolName,ref.toolName);
    assert.equal(directory.sha256,ref.sha256);assert.ok(!Object.hasOwn(chart,'ruleSources'));
    chart.ruleSources=structuredClone(directory.ruleSources);delete chart.ruleSourcesFromDirectory;
   }
   if(chart.reusedFacts){
    const pointer=(o,p)=>p.split('/').slice(1).reduce((v,k)=>v[k.replaceAll('~1','/').replaceAll('~0','~')],o);
    for(const r of chart.reusedFacts){assert.ok(restored.has(r.toolCallID));const keys=r.path.split('/').slice(1),last=keys.pop(),parent=keys.reduce((v,k)=>v[k],chart);parent[last]=pointer(restored.get(r.toolCallID),r.pointer);}
    delete chart.reusedFacts;delete chart.reusedFactsFormat;
   }
   assert.deepEqual(chart,raw);restored.set(call.id,chart);charts++;
  }
  if(!message.content?.startsWith('显式字段索引'))continue;
  const root=JSON.parse(message.content.slice(message.content.indexOf('\n{')+1));
  if(root.referenceIndexVersion!==undefined){
   assert.ok([1,2].includes(root.referenceIndexVersion));assert.equal(root.valuesFromTool,true);
   const regroup=(flat,width)=>{assert.ok(Array.isArray(flat));assert.equal(flat.length%width,0);return Array.from({length:flat.length/width},(_,i)=>flat.slice(i*width,(i+1)*width));};
   const nodes=root.referenceIndexVersion===2?regroup(root.stringNodes,2):root.stringNodes;
   const patterns=root.referenceIndexVersion===2?regroup(root.patterns,4):root.patterns;
   const parts=[];
   assert.ok(Array.isArray(root.stringTokens)&&root.stringTokens.every(t=>typeof t==='string'));
   for(const node of nodes){
    assert.equal(node.length,2);const [parent,token]=node;
    assert.ok(Number.isInteger(parent)&&parent>=-1&&parent<parts.length);
    assert.ok(Number.isInteger(token)&&token>=0&&token<root.stringTokens.length);
    parts.push((parent===-1?'':parts[parent])+root.stringTokens[token]);
   }
   const part=i=>{assert.ok(Number.isInteger(i)&&i>=-1&&i<parts.length);return i===-1?'':parts[i];};
   for(const [idIndex,keyPartIndices,pointerPartIndices,sequenceIndex] of patterns){
    const keyParts=keyPartIndices.map(part),pointerParts=pointerPartIndices.map(part);
    const id=root.toolCallIDs[idIndex],chart=restored.get(id),s=root.numberSequences[sequenceIndex];
    assert.ok(chart);const rows=Array.isArray(s)?s:Array.from({length:s.count},(_,n)=>s.start.map((x,j)=>x+n*s.step[j]));
    for(const numbers of rows){
     assert.equal(numbers.length,keyParts.length+pointerParts.length-2);assert.ok(numbers.every(Number.isSafeInteger));
     let n=0;const join=parts=>parts.reduce((text,part,j)=>text+(j?String(numbers[n++]):'')+part,'');
     const factKey=join(keyParts),pointer=join(pointerParts);
     const value=pointer.split('/').slice(1).reduce((v,k)=>{const key=k.replaceAll('~1','/').replaceAll('~0','~');assert.ok(Object.hasOwn(v,key));return v[key];},chart);
     reconstructed.push(factToken({toolCallID:id,factKey,pointer,value}));
    }
   }
   continue;
  }
  assert.deepEqual(root.columns,['factKeySuffix','pointerSuffix','value']);if(root.toolCallIDs)IDDictionaryMessages++;if(root.layouts)layoutMessages++;
  if(root.groupRows){
   assert.ok(Array.isArray(root.groupColumns));
   root.groups=root.groupRows.map(row=>{const [index,...values]=row;assert.ok(Number.isInteger(index));const keys=root.groupColumns[index];assert.equal(keys.length,values.length);assert.equal(new Set(keys).size,keys.length);return Object.fromEntries(keys.map((k,n)=>[k,values[n]]))});
  }
  for(const g of root.groups){
   const ids=g.toolCallID!==undefined?[g.toolCallID]:g.toolCallIDs!==undefined?g.toolCallIDs:g.toolCallIDIndex!==undefined?[root.toolCallIDs[g.toolCallIDIndex]]:g.toolCallIDIndices.map(n=>root.toolCallIDs[n]);
   assert.ok(ids.every(x=>typeof x==='string'&&calls.has(x)));
   let rows=g.facts;
   if(rows===undefined){const pairs=root.layouts[g.layout];assert.equal(pairs.length,g.values.length);rows=pairs.map((p,j)=>[...p,g.values[j]])}
   for(const [key,pointer,value] of rows){assert.equal(typeof key,'string');for(const id of ids)reconstructed.push(factToken({toolCallID:id,factKey:g.factKeyPrefix+key,pointer:g.pointerPrefix+(pointer===null?key.replaceAll('.','/'):pointer),value}));}
  }
 }
 assert.equal(charts,fixtures[i].rows.length);assert.deepEqual(reconstructed.sort(),expected);
 const totalUTF16=request.messages.reduce((s,m)=>s+(m.content?.length??0)+(m.tool_calls??[]).reduce((t,c)=>t+c.function.arguments.length,0),0);
 const maxMessageUTF16=Math.max(...request.messages.map(m=>m.content?.length??0));
 output.push({index:i,eventVariant:fixtures[i].label??'plain-matrix',providerValidatorAccepted:true,actualChatClientBodyBytes:bytes.length,backendTotalUTF16:totalUTF16,maxMessageUTF16,messages:request.messages.length,facts:expected.length,indexFacts:reconstructed.length,chartsRestoredExactly:charts});
}
const report={passed:output.length,objectLayoutCharts,objectLayoutRows,packedCharts,packedRows,emptyPathRows,IDDictionaryMessages,layoutMessages,sourceDirectories,maxBackendTotalUTF16:Math.max(...output.map(r=>r.backendTotalUTF16)),maxBodyBytes:Math.max(...output.map(r=>r.actualChatClientBodyBytes)),maxMessageUTF16:Math.max(...output.map(r=>r.maxMessageUTF16)),scope:'Actual native ChatClient captured request body, real backend providerRequest, MAX_BODY_BYTES; independent JS decoding of question references, exact rule-source directories with SHA256, recursive object layouts, condition tuples including path dictionary, reviewer fact prefix/layout/receipt-ID dictionaries and token-prefix-node/numeric-reference index; exact equality to full Engine objects and full native facts. No provider call.',cases:output};
fs.writeFileSync(folder+'final-wire-decoder-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify({...report,cases:undefined},null,2));
