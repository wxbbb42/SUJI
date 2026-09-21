/** External source checkout required, see the research report. No upstream code is copied into SUJI. */
import vm from 'node:vm';
import fs from 'node:fs';
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
const require=createRequire(import.meta.url);
const {astro}=require('../../node_modules/iztro');
const {Solar}=require('/tmp/suji-divination-oracles/node_modules/lunar-javascript');
const ctx=vm.createContext({ziweiUI:{clearPalce(){}},console:{log(){}}});
for(const file of ['lunar.js','ziweistar.js','ziweicore.js']) vm.runInContext(fs.readFileSync(`/tmp/suji-research-ZiWeiDouShu/js/${file}`,'utf8'),ctx,{timeout:5000});
const replacements={'貞':'贞','機':'机','陽':'阳','貪':'贪','陰':'阴','門':'门','殺':'杀','軍':'军','祿':'禄','權':'权'};
const normalize=s=>s.replace(/化[祿禄權权科忌]/g,'').split('').map(c=>replacements[c]??c).join('');
const dates=['1984-8-15','1985-8-15','1986-8-15','1987-8-15','1988-8-15','1989-8-15','1990-8-15','1991-8-15','1992-8-15','1993-8-15'];
const failures=[],fixtures=[];let cases=0;
for(const date of dates) for(let h=0;h<12;h++){
 const [y,m,d]=date.split('-').map(Number),branch=[...'子丑寅卯辰巳午未申酉戌亥'][h];
 const p=vm.runInContext(`ziwei.computeZiWei(${y},${m},${d},'${branch}','M')`,ctx,{timeout:5000});
 const expected=Object.fromEntries(p.map((v,i)=>[[...'子丑寅卯辰巳午未申酉戌亥'][i],v.StarA.map(normalize).sort()]));
 const a=astro.bySolar(date,h,'男',true,'zh-CN');
 const actual=Object.fromEntries(a.palaces.map(p=>[p.earthlyBranch,p.majorStars.map(s=>s.name).sort()]));
 cases++;
 const lunar=Solar.fromYmd(y,m,d).getLunar();
 const calendar={year:lunar.getYear(),month:lunar.getMonth(),day:lunar.getDay()};
 if(calendar.month>0)fixtures.push({date,h,expected});
 if(Object.keys(expected).some(k=>JSON.stringify(expected[k])!==JSON.stringify(actual[k]))) failures.push({date,h,calendar,expected,actual});
}
const six=JSON.parse(execFileSync('python3',['-c',`
import sys,types,json,pathlib
r='/tmp/suji-research-najia/najia'
p=types.ModuleType('najia');p.__path__=[r];sys.modules['najia']=p
from najia import const,utils
out=[]
for binary,name in const.GUA64.items():
 shi,ying,index=utils.set_shi_yao(binary)
 palace=utils.palace(binary,shi)
 gzs=utils.get_najia(binary)
 out.append(dict(binary=binary,name=name,shi=shi,ying=ying,palace=const.GUAS[palace],ganzhi=gzs,liuqin=[utils.get_qin6(const.XING5[const.GUA5[palace]],const.ZHI5[const.ZHIS.index(gz[1])]) for gz in gzs]))
print(json.dumps(out,ensure_ascii=False))
`],{encoding:'utf8'}));
const out={provenance:{ziwei:{repo:'https://github.com/cubshuang/ZiWeiDouShu',commit:'2ec50ebf5149cbc90ecb7a2457bc1b9e7ea3c56e',scope:'14 major stars, 10 August dates × 12 double-hours; 108 ordinary-month cases plus 12 leap-month cases; excludes late Zi and new-year boundaries',license:'no license file; read-only research only'},najia:{repo:'https://github.com/bopo/najia',commit:'9cf119169d7eb8e48febc05274aebf3f7106d647',license:'MIT',scope:'all 64 gua palace/shi-ying/na-jia/liu-qin; no upstream calendar used'}},ziwei:{cases,mismatches:failures.length,failures,ordinaryMonthFixtures:fixtures},najia:six};
fs.writeFileSync(new URL('independent-results.json',import.meta.url),JSON.stringify(out,null,2)+'\n');
console.log(JSON.stringify({ziweiCases:cases,ziweiMismatches:failures.length,ziweiExamples:failures.slice(0,1),najiaCases:six.length,najiaExample:six[0]},null,2));
