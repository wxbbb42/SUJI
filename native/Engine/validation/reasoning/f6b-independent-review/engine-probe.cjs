const fs=require('node:fs'),vm=require('node:vm');
const ctx=vm.createContext({});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),ctx);
const run=input=>new Promise((res,rej)=>ctx.SujiNative.run(JSON.stringify(input),v=>res(JSON.parse(v)),rej));
(async()=>{
 const fixtures=[];
 for(const name of ['cast_liuyao','setup_qimen']) {
  vm.runInContext('Math.random=()=>0.4',ctx);
  const args={question:'核对自身情况',questionType:'health',subject:'self',event:'身体情况',timeHorizon:'near'};
  const source=(await run({command:'tool',name,arguments:args,now:'2024-02-04T04:00:00Z'})).result;
  fixtures.push({name,args,source});
 }
 vm.runInContext(`globalThis.guardCalls=[];const RealDate=Date;globalThis.Date=new Proxy(RealDate,{construct(target,args){guardCalls.push(['construct',args.length]);if(!args.length)throw Error('current date forbidden');return Reflect.construct(target,args)},apply(){throw Error('Date() forbidden')},get(target,key){if(key==='now')return ()=>{throw Error('Date.now forbidden')};return Reflect.get(target,key)}});Math.random=()=>{throw Error('random forbidden')}`,ctx);
 for(const f of fixtures) {
  const args={question:'补充父亲的情况',questionType:'health',subject:'parent',event:'父亲的情况',timeHorizon:'far'};
  const response=await run({command:'reassess-question',name:f.name,sourceCallID:'original',original:f.source,arguments:args});
  f.revised=response.result;f.revisedArgs=args;f.evidence=response.evidence;
 }
 fs.writeFileSync('/tmp/suji-f6b-independent-review/fixtures.json',JSON.stringify(fixtures));
 console.log(JSON.stringify({cases:fixtures.map(f=>({name:f.name,result:'passes-no-current-Date-or-random',evidence:f.evidence})),dateConstructions:ctx.guardCalls},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
