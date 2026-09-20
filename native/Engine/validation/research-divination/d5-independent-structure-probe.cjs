const fs=require('node:fs'),vm=require('node:vm');
const ctx=vm.createContext({console});vm.runInContext(fs.readFileSync('native/Resources/mingli.js','utf8'),ctx);
const dispatch=async request=>JSON.parse(JSON.stringify(await ctx.SujiNative.dispatch(request)));
const oracle=JSON.parse(fs.readFileSync('native/Engine/validation/research-divination/ziwei-monthly-independent-oracle.json','utf8'));
const root='/tmp/suji-d5-structure';fs.mkdirSync(root,{recursive:true});
const birth={year:2023,month:1,day:22,hour:0,minute:0,gender:'男',longitude:120};
const at=(date)=>date+'T12:00:00+08:00';
(async()=>{
 const natal=await dispatch({command:'natal',birth}),before=JSON.stringify(natal),rows=[];
 async function query(n,b,now){return (await dispatch({command:'tool',name:'get_ziwei_timing',birth:b,natal:n,now,arguments:{withMonthly:true}})).result;}
 for(const expected of [...oracle.ordinaryMonths2025,...oracle.queryLeapCases]){
  const a=await query(natal,birth,at(expected.date)),m=a.monthly;
  rows.push({case:'ordinary-query',date:expected.date,pass:m.ganZhi===expected.monthGanZhi&&m.mingGong.position===expected.ming&&m.douJun.position===expected.douJun,actual:{ganZhi:m.ganZhi,ming:m.mingGong.position,douJun:m.douJun.position},expected});
 }
 for(const expected of oracle.birthLeapCases){
  const parts=expected.birthSolarDate.split('-').map(Number),b={...birth,year:parts[0],month:parts[1],day:parts[2],hour:12};
  const n=await dispatch({command:'natal',birth:b}),m=(await query(n,b,at(expected.queryDate))).monthly;
  rows.push({case:'birth-leap',pass:m.ganZhi===expected.monthGanZhi&&m.mingGong.position===expected.ming&&m.douJun.position===expected.douJun,actual:{basis:n.ziweiPan.monthlyBasis,ganZhi:m.ganZhi,ming:m.mingGong.position,douJun:m.douJun.position},expected});
 }
 for(const expected of oracle.rolloverCases){
  const a=await query(natal,birth,expected.reference),m=a.monthly;
  rows.push({case:'rollover',pass:a.calculationDate===expected.calculationDate&&m.ganZhi===expected.monthGanZhi&&m.mingGong.position===expected.ming&&m.calendar.lunarYear===expected.lunarYear&&m.calendar.day===expected.lunarDay&&m.douJun.position===expected.douJun,actual:{calculationDate:a.calculationDate,calendar:m.calendar,ganZhi:m.ganZhi,ming:m.mingGong.position,douJun:m.douJun.position},expected});
 }
 // Handwritten late-zi birth equivalence at the same canonical chart date.
 for(const [date1,date2,expectedMonth,expectedHour] of [['2023-04-05','2023-04-06',3,'子'],['2024-02-09','2024-02-10',1,'子']]){
  const make=(date,hour)=>{const [year,month,day]=date.split('-').map(Number);return {...birth,year,month,day,hour};};
  const b1=make(date1,23),b2=make(date2,0),n1=await dispatch({command:'natal',birth:b1}),n2=await dispatch({command:'natal',birth:b2});
  const m1=(await query(n1,b1,at('2025-01-29'))).monthly,m2=(await query(n2,b2,at('2025-01-29'))).monthly;
  rows.push({case:'canonical-birth-equivalence',dates:[date1,date2],pass:JSON.stringify(m1)===JSON.stringify(m2)&&n1.ziweiPan.monthlyBasis.effectiveMonth===expectedMonth&&n1.ziweiPan.monthlyBasis.hourBranch===expectedHour});
 }
 const first=(await query(natal,birth,at('2025-01-29'))).monthly;
 rows.push({case:'month-stem-target',pass:first.ganZhi==='戊寅'&&natal.ziweiPan.palaces.find(p=>p.position===first.mingGong.position).ganZhi==='丁巳'&&oracle.criticalScopeCounterexample.transformations.every(e=>first.transformations.some(t=>t.star===e.star&&t.transformation==='化'+e.hua&&t.targetPosition===e.position&&t.scope==='monthly-month-stem'))});
 const sourceSnapshot=JSON.stringify(natal);
 rows.push({case:'natal-unchanged',pass:sourceSnapshot===before});
 fs.writeFileSync(root+'/structural-results.json',JSON.stringify({passed:rows.filter(x=>x.pass).length,total:rows.length,rows},null,2)+'\n');
 fs.writeFileSync(root+'/real-monthly-output.json',JSON.stringify(await query(natal,birth,at('2025-01-29')),null,2)+'\n');
 console.log(JSON.stringify({passed:rows.filter(x=>x.pass).length,total:rows.length,failed:rows.filter(x=>!x.pass)},null,2));
 if(rows.some(x=>!x.pass))process.exitCode=1;
})();
