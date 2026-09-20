import fs from 'node:fs';
import assert from 'node:assert/strict';
import {providerRequest,MAX_BODY_BYTES} from '../../../../../supabase/functions/suji-chat/handler.mjs';
const folder='native/Engine/validation/reasoning/b4-independent-review/';
const fixtures=['capacity-fixtures.json','expanded-capacity-fixtures.json','escaped-event-fixtures.json'].flatMap(f=>JSON.parse(fs.readFileSync(folder+f,'utf8')));
const canonical=value=>JSON.stringify(value&&typeof value==='object'?(Array.isArray(value)?value.map(v=>JSON.parse(canonical(v))):Object.fromEntries(Object.keys(value).sort().map(k=>[k,JSON.parse(canonical(value[k]))]))):value);
const factToken=f=>canonical([f.toolCallID,f.factKey,f.pointer,f.value]);
const output=[];
let packedCharts=0,packedRows=0,emptyPathRows=0,IDDictionaryMessages=0,layoutMessages=0;
for(let i=0;i<fixtures.length;i++){
 const bytes=fs.readFileSync(folder+`final-wire-request-${i}.json`),request=JSON.parse(bytes);
 assert.ok(bytes.length<=MAX_BODY_BYTES);providerRequest(request);
 const expected=JSON.parse(fs.readFileSync(folder+`final-expected-facts-${i}.json`,'utf8')).map(factToken).sort();
 const reconstructed=[];const calls=new Map();let charts=0;
 for(const message of request.messages){
  for(const c of message.tool_calls??[])calls.set(c.id,c);
  if(message.role==='tool'){
   const call=calls.get(message.tool_call_id),chart=JSON.parse(message.content),raw=fixtures[i].rows.find(r=>r.name===call.function.name).output;
   if(chart.questionFromArguments){const ref=chart.questionFromArguments;assert.equal(ref.toolCallID,call.id);assert.equal(ref.pointer,'/question');chart.question=JSON.parse(call.function.arguments).question;delete chart.questionFromArguments;}
   if(chart.ruleConditionRows){
    const meta=chart.ruleConditionRows;
    assert.deepEqual(meta.columns,['idIndex','stateIndex','factPathIndices']);assert.deepEqual(meta.states,['matched','not-matched','unresolved']);
    for(const line of chart.lines)for(const rule of Object.values(line.rules))if(rule.conditions){
     rule.conditions=rule.conditions.map(row=>{assert.equal(row.length,3);packedRows++;if(!row[2].length)emptyPathRows++;return{id:meta.ids[row[0]],state:meta.states[row[1]],factPaths:row[2].map(p=>meta.paths[p])}});
    }
    delete chart.ruleConditionRows;packedCharts++;
   }
   assert.deepEqual(chart,raw);charts++;
  }
  if(!message.content?.startsWith('显式字段索引'))continue;
  const root=JSON.parse(message.content.slice(message.content.indexOf('\n{')+1));
  assert.deepEqual(root.columns,['factKeySuffix','pointerSuffix','value']);if(root.toolCallIDs)IDDictionaryMessages++;if(root.layouts)layoutMessages++;
  for(const g of root.groups){
   const ids=g.toolCallID!==undefined?[g.toolCallID]:g.toolCallIDs!==undefined?g.toolCallIDs:g.toolCallIDIndex!==undefined?[root.toolCallIDs[g.toolCallIDIndex]]:g.toolCallIDIndices.map(n=>root.toolCallIDs[n]);
   assert.ok(ids.every(x=>typeof x==='string'&&calls.has(x)));
   let rows=g.facts;
   if(rows===undefined){const pairs=root.layouts[g.layout];assert.equal(pairs.length,g.values.length);rows=pairs.map((p,j)=>[...p,g.values[j]])}
   for(const [key,pointer,value] of rows){assert.equal(typeof key,'string');for(const id of ids)reconstructed.push(factToken({toolCallID:id,factKey:g.factKeyPrefix+key,pointer:g.pointerPrefix+(pointer===null?key.replaceAll('.','/'):pointer),value}));}
  }
 }
 assert.equal(charts,2);assert.deepEqual(reconstructed.sort(),expected);
 const totalUTF16=request.messages.reduce((s,m)=>s+(m.content?.length??0)+(m.tool_calls??[]).reduce((t,c)=>t+c.function.arguments.length,0),0);
 const maxMessageUTF16=Math.max(...request.messages.map(m=>m.content?.length??0));
 output.push({index:i,eventVariant:fixtures[i].label??'plain-matrix',providerValidatorAccepted:true,actualChatClientBodyBytes:bytes.length,backendTotalUTF16:totalUTF16,maxMessageUTF16,messages:request.messages.length,facts:expected.length,indexFacts:reconstructed.length,chartsRestoredExactly:charts});
}
const report={passed:output.length,packedCharts,packedRows,emptyPathRows,IDDictionaryMessages,layoutMessages,maxBackendTotalUTF16:Math.max(...output.map(r=>r.backendTotalUTF16)),maxBodyBytes:Math.max(...output.map(r=>r.actualChatClientBodyBytes)),maxMessageUTF16:Math.max(...output.map(r=>r.maxMessageUTF16)),scope:'Actual native ChatClient captured request body, real backend providerRequest, MAX_BODY_BYTES; independent JS decoding of question references, condition tuples including path dictionary, reviewer fact prefix/layout/receipt-ID dictionaries; exact equality to full Engine objects and full native facts. No provider call.',cases:output};
fs.writeFileSync(folder+'final-wire-decoder-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify({...report,cases:undefined},null,2));
