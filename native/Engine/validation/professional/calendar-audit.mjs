/** Research-only independent astronomy/JDN checks. No reference library enters the app. */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url), here=path.dirname(fileURLToPath(import.meta.url));
const engine=path.resolve(here,'../..');
const ref=process.env.SUJI_ASTRONOMY_REFERENCE || '/tmp/suji-professional-reference/node_modules/astronomy-engine';
const A=require(ref), {build}=require(path.join(engine,'node_modules/esbuild'));
const bundle=path.join(fs.mkdtempSync(path.join(os.tmpdir(),'suji-professional-calendar-')),'engine.cjs');
await build({stdin:{contents:"export {BaziEngine} from './src/bazi/BaziEngine'; export {getCalendarPillars,getSolarTerms} from './src/calendar/precision'; export {equationOfTime} from './src/bazi/TrueSolarTime';",resolveDir:engine},bundle:true,platform:'node',format:'cjs',outfile:bundle,tsconfig:path.join(engine,'tsconfig.json'),logLevel:'silent'});
const P=require(bundle), bazi=new P.BaziEngine();
const mod=(x,n)=>((x%n)+n)%n, stems='甲乙丙丁戊己庚辛壬癸', branches='子丑寅卯辰巳午未申酉戌亥';
const gz=n=>stems[mod(n,10)]+branches[mod(n,12)];
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function eot(date) {
  const sun=A.EquatorFromVector(A.RotateVector(A.Rotation_EQJ_EQD(date),A.GeoVector(A.Body.Sun,date,true)));
  const utc=mod(date.getTime()/3600000,24);
  return (mod(A.SiderealTime(date)-sun.ra+12-utc+12,24)-12)*60;
}
function dayJDN(y,m,d) {
  const a=Math.floor((14-m)/12), yy=y+4800-a, mm=m+12*a-3;
  return d+Math.floor((153*mm+2)/5)+365*yy+Math.floor(yy/4)-Math.floor(yy/100)+Math.floor(yy/400)-32045;
}
const termCache=new Map();
function independentTerms(year) {
  if(!termCache.has(year)) termCache.set(year,Array.from({length:12},(_,i)=>{
    const month=i+1, angle=mod(285+i*30,360);
    return {angle,instant:A.SearchSunLongitude(angle,new Date(Date.UTC(year,month-1,1)),12).date};
  }));
  return termCache.get(year);
}
function oracle(instant,longitude) {
  const civil=new Date(instant.getTime()+8*3600000);
  let year=civil.getUTCFullYear();
  if(instant<independentTerms(year)[1].instant) year--;
  const yi=mod(year-4,60), sun=A.SunPosition(instant).elon;
  const month= Math.floor(mod(sun-315,360)/30);
  const correction=longitude===undefined?0:(longitude-120)*4+eot(instant);
  const local=new Date(civil.getTime()+correction*60000);
  const di=mod(dayJDN(local.getUTCFullYear(),local.getUTCMonth()+1,local.getUTCDate())+49+(local.getUTCHours()>=23?1:0),60);
  const hi=Math.floor(mod(local.getUTCHours()+1,24)/2);
  return {pillars:[gz(yi),stems[mod((yi%10)%5*2+2+month,10)]+branches[mod(month+2,12)],gz(di),stems[mod(di%10%5*2+hi,10)]+branches[hi]], projectedClock:local.toISOString().replace('Z',' (wall-clock projection)'),solarLongitude:sun,equationOfTimeMinutes:eot(instant)};
}
const chars=p=>['year','month','day','hour'].map(k=>p.siZhu[k].ganZhi.gan+p.siZhu[k].ganZhi.zhi);
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const source=JSON.parse(fs.readFileSync(path.join(here,'public-birth-cases.json'),'utf8'));
const results={method:{reference:'astronomy-engine@2.1.19 apparent solar longitude and geocentric apparent RA/GAST; independent Gregorian JDN+49 and stem/branch cycles',policy:'Year/month use physical instant; day/hour use fixed UTC+8 or explicitly requested apparent solar projection; 23:00 day boundary.',limits:'Astronomy Engine is an independent approximate ephemeris, not a second official calendar or an oracle for interpretation. Birth records are secondary compilations. No biographies enter scoring.'},sourceSHA256:{},publicCases:[],calendarGrid:{},summary:{}};
for(const f of ['src/calendar/precision.ts','src/bazi/TrueSolarTime.ts','src/bazi/BaziEngine.ts']) results.sourceSHA256[f]=sha(path.join(engine,f));
for(const c of source.cases) {
  const instant=new Date(c.instant), clockRows=[];
  for(const longitude of [undefined,c.longitude]) {
    const actual=bazi.calculate(instant,c.gender,longitude), expected=oracle(instant,longitude);
    clockRows.push({policy:longitude===undefined?'beijing-standard':'apparent-solar',actual:chars(actual),expected:expected.pillars,matches:same(chars(actual),expected.pillars),projectedClock:expected.projectedClock,eotDifferenceSeconds:longitude===undefined?null:(P.equationOfTime(instant)-expected.equationOfTimeMinutes)*60,qiYun:actual.qiYun});
  }
  const variants=[];
  for(let offset=-30;offset<=30;offset+=5) {
    const d=new Date(instant.getTime()+offset*60000), actual=chars(bazi.calculate(d,c.gender,c.longitude)), expected=oracle(d,c.longitude).pillars;
    variants.push({offsetMinutes:offset,actual,expected,matches:same(actual,expected)});
  }
  const alternatives=(c.alternateLocalTimes||[]).map(wall=>{
    const date=new Date(new Date(wall+'Z').getTime()-c.utcOffsetHours*3600000),actual=chars(bazi.calculate(date,c.gender,c.longitude)),expected=oracle(date,c.longitude).pillars;
    return {wall,instant:date.toISOString(),actual,expected,matches:same(actual,expected)};
  });
  const naive=new Date(c.localDateTime+'+08:00');
  results.publicCases.push({id:c.id,sourceRating:c.sourceRating,clockRows,apparentSolarSensitivity:variants,reportedAlternatives:alternatives,wallClockMistakenForBeijing:chars(bazi.calculate(naive,c.gender,c.longitude)),sensitivityDistinctPillars:[...new Set(variants.map(x=>x.actual.join(' ')))]});
}
const termRows=[],mismatches=[];
let total=0,maxTermDifference=0;
for(let y=1901;y<=2100;y++) {
  const production=P.getSolarTerms(y);
  for(let i=0;i<12;i++) {
    const independent=independentTerms(y)[i],actual=production[i*2];
    const seconds=(actual.instant-independent.instant)/1000;
    maxTermDifference=Math.max(maxTermDifference,Math.abs(seconds));
    termRows.push({year:y,name:actual.name,production:actual.instant.toISOString(),independent:independent.instant.toISOString(),differenceSeconds:seconds});
    for(const offset of [-120,120]) {
      const d=new Date(independent.instant.getTime()+offset*1000),p=P.getCalendarPillars(d),actualPillars=[p.year,p.month,p.day,p.hour],expected=oracle(d).pillars;
      total++;
      if(!same(actualPillars,expected)) mismatches.push({instant:d.toISOString(),offsetSeconds:offset,actual:actualPillars,expected,term:actual.name});
    }
  }
}
results.calendarGrid={years:[1901,2100],jieTerms:termRows.length,pillarChecks:total,offsetSeconds:[-120,120],maxTermDisagreementSeconds:maxTermDifference,pillarMismatches:mismatches,termRows};
const checks=results.publicCases.flatMap(c=>[...c.clockRows,...c.apparentSolarSensitivity,...c.reportedAlternatives]);
results.summary={publicPeople:source.cases.length,recordRatings:{AA:2,A:2},publicPillarComparisons:checks.length,publicMismatches:checks.filter(x=>!x.matches).length,jieTerms:termRows.length,gridPillarComparisons:total,gridMismatches:mismatches.length,maxTermDisagreementSeconds:maxTermDifference,maxPublicEOTDifferenceSeconds:Math.max(...results.publicCases.flatMap(c=>c.clockRows.filter(x=>x.eotDifferenceSeconds!==null).map(x=>Math.abs(x.eotDifferenceSeconds))))};
const output=process.argv[2]||path.join(here,'calendar-audit-results.json');
fs.writeFileSync(output,JSON.stringify(results,null,2)+'\n');
console.log(JSON.stringify(results.summary,null,2));
if(results.summary.publicMismatches||mismatches.length) process.exitCode=1;
