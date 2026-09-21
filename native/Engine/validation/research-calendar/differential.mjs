/** Research-only independent differential; install refs in a scratch directory, never production. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const engine = path.resolve(here, '../..');
const require = createRequire(import.meta.url);
const referenceRoot = process.env.SUJI_CALENDAR_REFS || '/tmp/suji-calendar-research/node_modules';
const { Solar } = require(path.join(referenceRoot, 'lunar-javascript'));
const Astronomy = require(path.join(referenceRoot, 'astronomy-engine'));
const { build } = require(path.join(engine, 'node_modules/esbuild'));
process.env.TZ = 'Asia/Shanghai';
const bundle = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'suji-calendar-diff-')), 'engine.cjs');
await build({stdin:{contents:`export { BaziEngine } from './src/bazi/BaziEngine'; export { DayunEngine } from './src/bazi/DayunEngine'; export { getTrueSolarTimeInfo } from './src/bazi/TrueSolarTime'; export { currentSolarTerm } from './src/qimen/helpers/solarTerms'; export { getTodayInfo } from './src/calendar';`,resolveDir:engine},bundle:true,platform:'node',format:'cjs',outfile:bundle,tsconfig:path.join(engine,'tsconfig.json')});
const {BaziEngine,DayunEngine,getTrueSolarTimeInfo,currentSolarTerm,getTodayInfo}=require(bundle);
const bazi = new BaziEngine();
const refSolar = d => Solar.fromYmdHms(d.getFullYear(),d.getMonth()+1,d.getDate(),d.getHours(),d.getMinutes(),d.getSeconds());
const local = d => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}:${String(d.getSeconds()).padStart(2,'0')}`;
const chars = p => ['year','month','day','hour'].map(k=>p.siZhu[k].ganZhi.gan+p.siZhu[k].ganZhi.zhi);
const refChars = d => {const e=refSolar(d).getLunar().getEightChar();e.setSect(1);return [e.getYear(),e.getMonth(),e.getDay(),e.getTime()]};
const results={versions:{lunarJavascript:require(path.join(referenceRoot,'lunar-javascript/package.json')).version,astronomyEngine:require(path.join(referenceRoot,'astronomy-engine/package.json')).version,productionProvider:require(path.join(engine,'package.json')).dependencies['lunar-javascript']},policy:{timezone:'Asia/Shanghai',longitude:'omitted unless stated',lateZi:'lunar-javascript sect=1, day at 23:00; matches lunisolar default'},cases:[]};
for(const [date,gender] of [['1990-08-15T10:00:00','女'],['1990-08-15T10:00:00','男'],['2000-01-01T12:00:00','男'],['2000-01-01T12:00:00','女'],['2024-02-04T12:00:00','男'],['2024-02-04T18:00:00','男'],['2026-09-19T12:00:00','男']]){
 const d=new Date(date),p=bazi.calculate(d,gender),r=refSolar(d).getLunar().getEightChar();r.setSect(1);const y=r.getYun(gender==='男'?1:0,2);const day=new DayunEngine(p).getLiuRi(d);
 results.cases.push({date,gender,actualPillars:chars(p),referencePillars:refChars(d),actualDayun:{direction:p.daYunDirection,startAge:p.daYunStartAge,first:p.daYunList[0].ganZhi.gan+p.daYunList[0].ganZhi.zhi},referenceDayun:{forward:y.isForward(),years:y.getStartYear(),months:y.getStartMonth(),days:y.getStartDay(),hours:y.getStartHour(),startSolar:y.getStartSolar().toYmdHms()},actualLiuRi:day.ganZhi.gan+day.ganZhi.zhi,referenceLiuRi:refSolar(d).getLunar().getDayInGanZhi()});
}
const terms=['小寒','大寒','立春','雨水','惊蛰','春分','清明','谷雨','立夏','小满','芒种','夏至','小暑','大暑','立秋','处暑','白露','秋分','寒露','霜降','立冬','小雪','大雪','冬至'];
const termBoundaries=[];
for(let year=2020;year<=2030;year++){
 const jt=Solar.fromYmdHms(year,6,1,12,0,0).getLunar().getJieQiTable();
 for(let i=0;i<terms.length;i++){
  const name=terms[i],s=jt[name==='冬至'?'DONG_ZHI':name],d=new Date(s.toYmdHms().replace(' ','T')),target=(285+15*i)%360;
  const ast=Astronomy.SearchSunLongitude(target,new Date(d.getTime()-86400000),2).date;
  const row={year,name,referenceCST:local(d),astronomyCST:local(ast),referenceMinusAstronomySeconds:Math.round((d-ast)/1000),samples:[]};
  for(const minutes of [-60,-5,5,60]){
   const sample=new Date(d.getTime()+minutes*60000),actual=chars(bazi.calculate(sample,'男')),expected=refChars(sample);
   row.samples.push({offsetMinutes:minutes,actual,expected,match:JSON.stringify(actual)===JSON.stringify(expected),actualTerm:currentSolarTerm(sample),expectedTerm:minutes<0?terms[(i+23)%24]:name});
  }
  termBoundaries.push(row);
 }
}
results.termBoundaries={count:termBoundaries.length,pillarMismatchCount:termBoundaries.flatMap(r=>r.samples).filter(s=>!s.match).length,currentTermMismatchCount:termBoundaries.flatMap(r=>r.samples).filter(s=>s.actualTerm!==s.expectedTerm).length,maxReferenceAstronomyDisagreementSeconds:Math.max(...termBoundaries.map(t=>Math.abs(t.referenceMinusAstronomySeconds))),rows:termBoundaries};
// Noon avoids the known difference between civil-date and late-Zi rollover policies.
const lunarMismatch=[],pillarMismatch=[],liuRiMismatch=[],errors=[];let daySamples=0;
for(let year=1901;year<=2099;year+=3) for(let month=1;month<=12;month++){
 const d=new Date(year,month-1,15,12,0,0);daySamples++;
 try {const p=bazi.calculate(d,'男'),r=refSolar(d).getLunar(),expected=refChars(d),actual=chars(p);if(JSON.stringify(actual)!==JSON.stringify(expected))pillarMismatch.push({date:local(d),actual,expected});const dy=new DayunEngine(p).getLiuRi(d),dr=dy.ganZhi.gan+dy.ganZhi.zhi;if(dr!==r.getDayInGanZhi())liuRiMismatch.push({date:local(d),actual:dr,expected:r.getDayInGanZhi()});const actualLunar=getTodayInfo(d).lunarDate;const expectedLunar=`${r.getMonthInChinese()}月${r.getDayInChinese()}`;if(actualLunar!==expectedLunar)lunarMismatch.push({date:local(d),actual:actualLunar,expected:expectedLunar});}catch(e){errors.push({date:local(d),error:e.message})}
}
results.broadSample={count:daySamples,lunarMismatches:lunarMismatch,pillarMismatches:pillarMismatch,liuRiMismatches:liuRiMismatch,errors};
// NOAA's published fractional-year equation, independently implemented for a reproducible approximation comparison.
function noaaEOT(d){const year=d.getFullYear(),days=(year%4===0&&(year%100!==0||year%400===0))?366:365;const n=Math.floor((Date.UTC(year,d.getMonth(),d.getDate())-Date.UTC(year,0,0))/86400000);const g=2*Math.PI/days*(n-1+(d.getHours()-12)/24);return 229.18*(0.000075+0.001868*Math.cos(g)-0.032077*Math.sin(g)-0.014615*Math.cos(2*g)-0.040849*Math.sin(2*g));}
const eot=[];for(let i=0;i<365;i++){const d=new Date(2025,0,i+1,12);const actual=getTrueSolarTimeInfo(d,120).eot,expected=noaaEOT(d);eot.push({date:local(d),actualMinutes:actual,noaaApproxMinutes:expected,differenceSeconds:(actual-expected)*60});}
results.equationOfTime={comparison:'NOAA fractional-year approximation, not a precision astronomical ground truth',maxDifferenceSeconds:Math.max(...eot.map(x=>Math.abs(x.differenceSeconds))),worst:eot.sort((a,b)=>Math.abs(b.differenceSeconds)-Math.abs(a.differenceSeconds)).slice(0,5)};
results.summary={pillarBoundaryMismatches:results.termBoundaries.pillarMismatchCount,currentTermBoundaryMismatches:results.termBoundaries.currentTermMismatchCount,interiorPillarMismatches:pillarMismatch.length,liuRiMismatches:liuRiMismatch.length,lunarMismatches:lunarMismatch.length,errors:errors.length};
const output=process.argv[2]||path.join(here,'current-differential.json');fs.writeFileSync(output,JSON.stringify(results)+'\n');console.log(JSON.stringify({versions:results.versions,summary:results.summary,cases:results.cases,equationOfTime:results.equationOfTime,termReferenceMaxDiffSeconds:results.termBoundaries.maxReferenceAstronomyDisagreementSeconds},null,2));
