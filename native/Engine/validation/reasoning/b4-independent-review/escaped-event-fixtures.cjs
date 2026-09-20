const fs=require('node:fs'),vm=require('node:vm');
const ctx=vm.createContext({});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),ctx);
const folder='native/Engine/validation/reasoning/b4-independent-review/';
(async()=>{const base=JSON.parse(fs.readFileSync(folder+'expanded-capacity-fixtures.json','utf8'))[0],fixtures=[];
for(const [label,event] of [['plain','事'.repeat(200)],['quote','"'.repeat(200)],['backslash',String.fromCharCode(92).repeat(200)],['emoji','🚀'.repeat(200)],['control','事'+String.fromCharCode(1).repeat(199)]]){
 const rows=[];for(const b of base.rows){const args={...b.arguments,event};ctx.draws=base.rows[0].output.lineValues.flatMap(v=>Array(v-6).fill(.75).concat(Array(9-v).fill(0)));vm.runInContext('var idx=0;Math.random=()=>draws[idx++];',ctx);
 const envelope=await ctx.SujiNative.dispatch({command:'tool',name:b.name,arguments:args,now:base.date});if(!envelope.result)throw Error(JSON.stringify(envelope));rows.push({name:b.name,arguments:args,output:envelope.result})}
 fixtures.push({date:base.date,label,rows})}
fs.writeFileSync(folder+'escaped-event-fixtures.json',JSON.stringify(fixtures));console.log('Actual engine accepted '+fixtures.length+' escaped event variants, 200 code points each')})().catch(e=>{console.error(e);process.exitCode=1});
