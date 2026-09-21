// Maintainer-only generator; source-rule coordinates are not historical birth claims.
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { computePatternConditions } from '../structural';
import { adjudicateRescue } from '../rescueAdjudication';
const output=resolve('validation/research-bazi/dependencies-2026-09-21');
mkdirSync(output,{recursive:true});
for(const [name,s,b,yong] of [
  ['protected','丁癸乙戊','巳酉卯戌','七杀'],['rooted-attacker','丁癸乙戊','巳酉卯辰','七杀'],
  ['blocked','丁癸甲戊','未酉寅戌','正官'],['co-supported','壬丁甲癸','申酉子亥','正官'],
  ['selected','丙辛甲辛','寅卯子午','比肩'],['selected-rooted','丙辛甲辛','酉卯子午','比肩'],
  ['lin','戊甲丁戊','辰寅卯申','正印'],['conflict','丙辛戊甲','午卯寅寅','正官'],
] as const){
  const stems=[...s],branches=[...b];
  const conditionalEvidence=computePatternConditions(stems[2] as any,stems as any,branches as any,yong);
  const rescue=adjudicateRescue(conditionalEvidence);
  const root={bazi:{pillars:Object.fromEntries(['year','month','day','hour'].map((col,i)=>[col,{ganZhi:{gan:stems[i],zhi:branches[i]}}])),
    patternAnalysis:{yongShenShiShen:yong,conditionalEvidence,rescueEvidence:rescue}}};
  writeFileSync(resolve(output,name+'.json'),JSON.stringify(root,null,2)+'\n');
}
