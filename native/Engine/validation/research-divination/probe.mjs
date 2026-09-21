/**
 * Read-only baseline audit. External oracle is explicitly installed outside the
 * application: npm i --prefix /tmp/suji-divination-oracles lunar-javascript@1.7.7
 * Run: TZ=Asia/Shanghai node native/Engine/validation/research-divination/probe.mjs
 * This reports discrepancies; it deliberately does not treat legacy snapshots
 * or iztro wrapper parity as an independent mathematical oracle.
 */
import { build } from '../../node_modules/esbuild/lib/main.js';
import { createRequire } from 'node:module';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const require = createRequire(import.meta.url);
const { Solar, Lunar } = require(process.env.SUJI_LUNAR_ORACLE || '/tmp/suji-divination-oracles/node_modules/lunar-javascript');
const root = process.env.SUJI_ENGINE_ROOT || fileURLToPath(new URL('../../', import.meta.url));
const target = '/tmp/suji-divination-probe.cjs';
await build({ stdin: { contents: `
export {HexagramEngine} from './src/divination/HexagramEngine';
export {GUA_64} from './src/divination/data/gua64';
export {yaoWuXingForGua,liuQinForGua} from './src/divination/data/liuqin';
export {buildDiPan} from './src/qimen/helpers/diPan';
export {rotateTianPan,computeXunShou} from './src/qimen/helpers/tianPan';
export {QimenEngine} from './src/qimen/QimenEngine';
export {currentSolarTerm} from './src/qimen/helpers/solarTerms';
export {computeTimePillars} from './src/qimen/helpers/timeGanZhi';
export {ZiweiEngine} from './src/ziwei/ZiweiEngine';
export {astro} from 'iztro';
`,resolveDir:root,loader:'ts'}, bundle:true, platform:'node', format:'cjs', outfile:target, tsconfig:path.join(root,'tsconfig.json') });
const e=require(target), results={baseline:'df1a7c9',timezone:process.env.TZ,oracle:'lunar-javascript@1.7.7',checks:{}};
const stems=[...'甲乙丙丁戊己庚辛壬癸'],branches=[...'子丑寅卯辰巳午未申酉戌亥'];
const sexagenary=Array.from({length:60},(_,n)=>stems[n%10]+branches[n%12]);
const obj=m=>Object.fromEntries([...m.entries()].sort((a,b)=>a[0]-b[0]));
const hex=new e.HexagramEngine();
results.checks.liuyaoCalendar=['1900-01-01T12:00:00+08:00','2024-02-04T12:00:00+08:00','2026-06-05T16:52:00+08:00','2026-09-19T10:00:00+08:00'].map(s=>{
 const d=new Date(s),l=Solar.fromDate(d).getLunar();
 return {input:s,actual:hex.castTimeToGanZhi(d),expected:{day:l.getDayInGanZhiExact(),month:l.getMonthInGanZhiExact(),hour:l.getTimeInGanZhi()}};
});
const dp=[];
for(const dun of ['阳','阴']) for(let ju=1;ju<=9;ju++){
 const actual=obj(e.buildDiPan(dun,ju)),expected={};
 [...'戊己庚辛壬癸丁丙乙'].forEach((g,i)=>expected[((ju-1+(dun==='阳'?i:-i))%9+9)%9+1]=g);
 if(JSON.stringify(actual)!==JSON.stringify(expected)) dp.push({dun,ju,actual,expected});
}
results.checks.dipan={cases:18,mismatches:dp.length,examples:dp.slice(0,2)};
const jia=[];
for(const dun of ['阳','阴']) for(let ju=1;ju<=9;ju++) for(const xun of [...'戊己庚辛壬癸']){
 const dp=e.buildDiPan(dun,ju),r=e.rotateTianPan(dp,xun,'甲',dun);
 if(JSON.stringify(obj(r.tianPan))!==JSON.stringify(obj(dp))) jia.push({dun,ju,xun,expected:'甲时天盘地盘伏吟',actual:obj(r.tianPan),dipan:obj(dp)});
}
results.checks.jiaHourFuyin={cases:108,mismatches:jia.length,examples:jia.slice(0,2)};
const engine=new e.QimenEngine();
const yuan=[];
for(let i=0;i<60;i++){
 const d=new Date('2026-03-01T12:00:00+08:00');d.setDate(d.getDate()+i);
 const gz=Solar.fromDate(d).getLunar().getDayInGanZhi(),idx=sexagenary.indexOf(gz),fuTou=sexagenary[idx-idx%5];
 const expected='子午卯酉'.includes(fuTou[1])?'上':'寅申巳亥'.includes(fuTou[1])?'中':'下';
 const actual=engine.computeYuan(d);if(actual!==expected)yuan.push({date:d.toISOString(),day:gz,fuTou,actual,expected});
}
results.checks.yuan={cases:60,mismatches:yuan.length,examples:yuan.slice(0,8)};
const doors=[];
const fixed={1:'休门',8:'生门',3:'伤门',4:'杜门',9:'景门',2:'死门',7:'惊门',6:'开门'};
const dp1=e.buildDiPan('阳',1),tp1=e.rotateTianPan(dp1,'戊','戊','阳');
const ps=engine.buildPalaces(dp1,tp1.tianPan,tp1.tianJiuxing,1,'阳');
results.checks.bamenJiaZi={input:'阳遁一局甲子时；旬首戊在坎1；值使休门不移动',expected:fixed,actual:Object.fromEntries(ps.filter(p=>p.id!==5).map(p=>[p.id,p.bamen]))};
const lichun=Lunar.fromYmd(2026,1,1).getJieQiTable()['立春'];
const instant=new Date(lichun.toYmdHms().replace(' ','T')+'+08:00');instant.setMinutes(instant.getMinutes()+40);
results.checks.solarTermInstant={boundary:lichun.toYmdHms()+' +08:00',input:instant.toISOString(),expected:e.currentSolarTerm(instant),byLongitude:[87.6,116.4,135].map(longitude=>{const r=engine.setup({question:'test',questionType:'general',setupTime:instant,longitude});return {longitude,jieqi:r.jieqi,trueSolarTime:r.trueSolarTime};})};
const z=new e.ZiweiEngine();
const major=p=>Object.fromEntries(p.palaces.map(p=>[p.earthlyBranch??p.position,(p.majorStars??p.mainStars).map(s=>s.name)]));
const ziInput={year:1990,month:8,day:15,hour:23,gender:'男'};
results.checks.ziweiLateZi={input:ziInput,actual:major(z.compute(ziInput)),expectedIzTroContract:major(e.astro.bySolar('1990-8-15',12,'男',true,'zh-CN')),config:e.astro.getConfig()};
const lunarInput={year:2023,month:2,day:1,hour:10,gender:'女',isLunar:true,isLeapMonth:true};
const lr=z.computeWithAstrolabe(lunarInput);
results.checks.lunarBirthIdentity={input:lunarInput,actualDate:lr.pan.birthDateTime.toISOString(),actualChartSolar:lr.astrolabe.solarDate,expectedSolar:Lunar.fromYmd(2023,-2,1).getSolar().toYmd()};
results.checks.guaNumbering=e.GUA_64.filter(g=>['乾为天','坤为地','天风姤'].includes(g.name)).map(g=>({name:g.name,actual:g.code,expected:{乾为天:1,坤为地:2,天风姤:44}[g.name]}));
if (process.env.SUJI_RESEARCH_OUTPUT) writeFileSync(process.env.SUJI_RESEARCH_OUTPUT,JSON.stringify(results,null,2)+'\n');
console.log(JSON.stringify(results,null,2));
