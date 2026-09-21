import fs from 'node:fs';import assert from 'node:assert/strict';import {providerRequest} from '../../../../../supabase/functions/suji-chat/handler.mjs';
const folder='native/Engine/validation/reasoning/b5a-independent-review/',plain='事'.repeat(200),control='事'+'\u0001'.repeat(199);const reports=[];
for(const i of [0,6,26,40]){
 const body=JSON.parse(fs.readFileSync(folder+`initial-wire-request-${i}.json`,'utf8'));
 let replacements=0;for(const m of body.messages){if(m.role==='tool'){assert.ok(m.content.includes(plain));m.content=m.content.replace(plain,JSON.stringify(control).slice(1,-1));replacements++}for(const c of m.tool_calls??[]){assert.ok(c.function.arguments.includes(plain));c.function.arguments=c.function.arguments.replace(plain,JSON.stringify(control).slice(1,-1));replacements++}}
 assert.equal(replacements,4);let validator='accepted';try{providerRequest(body)}catch(e){validator=e.message}
 reports.push({seedIndex:i,replacements,maxToolUTF16:Math.max(...body.messages.filter(m=>m.role==='tool').map(m=>m.content.length)),backendTotalUTF16:body.messages.reduce((s,m)=>s+(m.content?.length??0)+(m.tool_calls??[]).reduce((t,c)=>t+c.function.arguments.length,0),0),providerValidator:validator});
 fs.writeFileSync(folder+`initial-constructed-control-request-${i}.json`,JSON.stringify(body));
}
fs.writeFileSync(folder+'initial-escaped-budget-report.json',JSON.stringify({scope:'Exact string replacement of the event in two existing actual native chart outputs and two argument strings; fanfu/calendar/facts do not depend on event. This is a constructed pre-fix payload, not a delivered capacity-fallback request.',cases:reports},null,2));console.log(reports);
