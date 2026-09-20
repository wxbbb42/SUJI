// Offline boundary check; no provider request or credentials.
import {readFile,writeFile} from 'node:fs/promises';
import {providerRequest,MAX_BODY_BYTES} from '../../../../supabase/functions/suji-chat/handler.mjs';
const rows=JSON.parse(await readFile('/tmp/suji-d5-native-capacity-final.json','utf8'));
for(const row of rows){
  const encoded=JSON.parse(await readFile(`/tmp/suji-d5-capacity-request-${row.index}.json`,'utf8'));
  // Mirrors ChatClient.chatMessage: Codable storage keys are not the wire schema.
  const messages=encoded.map(m=>({role:m.role,content:m.content??null,
    ...(m.toolCallID?{tool_call_id:m.toolCallID}:{}),
    ...(m.toolCalls?{tool_calls:m.toolCalls.map(c=>({id:c.id,type:'function',function:{name:c.name,arguments:JSON.stringify(c.arguments)}}))}:{})}));
  providerRequest({stream:false,messages});
  row.wireBodyBytes=Buffer.byteLength(JSON.stringify({stream:false,messages}))+1024;
  if(row.wireBodyBytes>MAX_BODY_BYTES)throw Error(`Body size ${row.index}`);
  row.backendStatus='pass';
  row.withArgumentsUTF16=messages.reduce((sum,m)=>sum+(m.content?.length??0)+(m.tool_calls??[]).reduce((n,c)=>n+c.function.arguments.length,0),0);
  if(!row.replayEqualsLive || !row.factValuesPreserved || row.liveErrorCount || row.referenceErrors || row.unauthenticatedReceipts || row.acceptedAfterSourceRemoval) throw Error(`Fidelity failure ${row.index}`);
}
await writeFile('/tmp/suji-d5-native-capacity-provider-report.json',JSON.stringify(rows,null,2)+'\n');
console.log(JSON.stringify({cases:rows.length,maxLiveBytes:Math.max(...rows.map(r=>r.liveBytes)),maxReviewWithArgumentsUTF16:Math.max(...rows.map(r=>r.withArgumentsUTF16)),referenceCount:rows.reduce((s,r)=>s+r.referenceCount,0)}));
