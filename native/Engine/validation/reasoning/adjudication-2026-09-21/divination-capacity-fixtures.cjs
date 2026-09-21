// Recompute the existing 48 paired inputs and add five maximum-window Qimen pairs.
// Coin injection is test-only; these are capacity fixtures, not independent chart oracles.
const fs=require('node:fs'),vm=require('node:vm');
const folder=process.argv[2]??'/tmp/suji-adjudication-capacity/data';
const script=fs.readFileSync('native/Resources/mingli.js','utf8');
const old=JSON.parse(fs.readFileSync(folder+'/fixtures.json','utf8')).slice(0,48);
async function run(date,rows,values){
 const context=vm.createContext({console});vm.runInContext(script,context);
 const draws=values.flatMap(v=>Array(v-6).fill(.75).concat(Array(9-v).fill(0)));
 vm.runInContext('let di=0,ds='+JSON.stringify(draws)+'; Math.random=()=>ds[di++];',context);
 const outputs=[];for(const row of rows){const r=await context.SujiNative.dispatch({command:'tool',name:row.name,arguments:row.arguments,now:date});if(r.error||r.result?.error)throw Error(JSON.stringify(r));outputs.push({name:row.name,arguments:row.arguments,output:JSON.parse(JSON.stringify(r.result))});}return outputs;
}
(async()=>{
 const result=[];
 for(const input of old){const values=input.rows.find(r=>r.name==='cast_liuyao').output.lineValues;result.push({...input,rows:await run(input.date,input.rows,values)});}
 const event='事'+'\u0001'.repeat(199),question='问'.repeat(1600);
 for(const [date,focus,unit] of [['2004-05-09T04:00:00Z','self','day'],...['year','month','day','hour'].map(unit=>['2004-07-02T08:00:00Z','relationship',unit])]){
  const rows=[{name:'cast_liuyao',arguments:{question,questionType:'parents',subject:'parent',event,timeHorizon:'near'}},{name:'setup_qimen',arguments:{question,questionType:'career',subject:'self',event,timeHorizon:'far',timingRequest:{focus,event,timeUnit:unit,window:{end:'2100-12-31T23:59:59+08:00',maxCandidates:256}}}}];
  result.push({date,label:'maximum-window-'+focus+'-'+unit,rows:await run(date,rows,[6,6,6,6,9,9])});
 }
 fs.writeFileSync(folder+'/fixtures.json',JSON.stringify(result));console.log('Generated '+result.length+' actual-bundle paired inputs (48 original + five maximum-window cases)');
})().catch(e=>{console.error(e);process.exit(1)});
