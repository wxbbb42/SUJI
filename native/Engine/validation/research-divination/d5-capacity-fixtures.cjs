// Repeat the twelve archived D4 high-volume inputs with the new monthly layer.
// This is delivery/capacity evidence, not an independent calculation oracle.
const fs=require('node:fs'),vm=require('node:vm');
const root=process.cwd(),dir=root+'/native/Engine/validation/research-divination/';
const ctx=vm.createContext({console});vm.runInContext(fs.readFileSync(root+'/native/Resources/mingli.js','utf8'),ctx);
const dispatch=async request=>JSON.parse(JSON.stringify(await ctx.SujiNative.dispatch(request)));
(async()=>{
 const fixtures=[];
 for(const old of JSON.parse(fs.readFileSync(dir+'d4-independent-capacity-report.json','utf8'))){
  const birth=JSON.parse(old.birth),natal=await dispatch({command:'natal',birth}),now='2025-01-29T04:00:00Z';
  const rows=[];
  for(const domain of ['事业','婚姻']){const args={domain},r=await dispatch({command:'tool',name:'get_domain',arguments:args,birth,natal,now});rows.push({name:'get_domain',arguments:args,output:r.result});}
  const palaces=[];
  for(const p of natal.ziweiPan.palaces){const args={palace:p.name,withPalaceFlights:true},r=await dispatch({command:'tool',name:'get_ziwei_palace',arguments:args,birth,natal,now});palaces.push({name:'get_ziwei_palace',arguments:args,output:r.result});}
  palaces.sort((a,b)=>Buffer.byteLength(JSON.stringify(b.output))-Buffer.byteLength(JSON.stringify(a.output)));rows.push(...palaces.slice(0,2));
  const args={date:'2025-01-29',withMonthly:true},r=await dispatch({command:'tool',name:'get_ziwei_timing',arguments:args,birth,natal,now});rows.push({name:'get_ziwei_timing',arguments:args,output:r.result});
  fixtures.push({birth,rows,rawBytes:rows.reduce((n,r)=>n+Buffer.byteLength(JSON.stringify(r.output)),0)});
 }
 fs.writeFileSync('/tmp/suji-d5-capacity-fixtures.json',JSON.stringify(fixtures));console.log(`Wrote ${fixtures.length} monthly+flight fixtures`);
})().catch(error=>{console.error(error);process.exit(1)});
