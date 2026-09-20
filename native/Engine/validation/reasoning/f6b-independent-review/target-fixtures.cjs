const fs=require('node:fs'),vm=require('node:vm');const ctx=vm.createContext({});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),ctx);
const run=input=>new Promise((res,rej)=>ctx.SujiNative.run(JSON.stringify(input),v=>res(JSON.parse(v)),rej));
(async()=>{
 const found={},out=[],args={question:'核对自身情况',questionType:'health',subject:'self',event:'身体情况',timeHorizon:'near'};
 for(const now of ['2024-02-05T04:00:00Z','2024-03-06T04:00:00Z','2026-09-20T04:00:00Z'])for(let mask=0;mask<64&&!['hidden','day','month'].every(k=>found[k]);mask++) {
  const values=Array.from({length:6},(_,i)=>mask&(1<<i)?7:8);
  ctx.rolls=values.flatMap(v=>v===7?[0.4,0.4,0.6]:[0.4,0.6,0.6]);vm.runInContext('Math.random=()=>rolls.shift()',ctx);
  const source=(await run({command:'tool',name:'cast_liuyao',arguments:args,now})).result;
  for(const subject of ['parent','child','sibling','wife','husband']) {
   const revisedArgs={...args,subject,question:'补充亲属情况'};
   const revised=(await run({command:'reassess-question',name:'cast_liuyao',sourceCallID:'original',original:source,arguments:revisedArgs})).result;
   for(const layer of ['hidden','day','month'])if(!found[layer]&&revised.yongShen.candidates.some(c=>c.layer===layer)) {found[layer]={layer,source,args,revisedArgs};}
  }
 }
 if(!['hidden','day','month'].every(k=>found[k]))throw Error('target layer missing: '+Object.keys(found).join(','));
 for(const f of Object.values(found))for(const timeHorizon of ['near','far','unspecified'])for(const refOnly of [false,true]) {
  const revisedArgs={...f.revisedArgs,timeHorizon};if(refOnly)delete revisedArgs.event;
  const revised=(await run({command:'reassess-question',name:'cast_liuyao',sourceCallID:'original',original:f.source,arguments:revisedArgs})).result;
  out.push({...f,revisedArgs,revised,refOnly});
 }
 fs.writeFileSync('/tmp/suji-f6b-independent-review/target-fixtures.json',JSON.stringify(out));console.log(JSON.stringify({cases:out.length,targets:Object.values(found).map(f=>({layer:f.layer,gua:f.source.benGua.name,subject:f.revisedArgs.subject,values:f.source.lineValues}))},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
