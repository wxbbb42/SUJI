import type { LineContext, CalendarInfluence, WuXing } from './types';
import type { RuleSource } from '../rules/provenance';

const BRANCHES = [...'子丑寅卯辰巳午未申酉戌亥'];
const ELEMENTS: WuXing[] = ['水','土','木','木','土','火','火','土','金','金','土','水'];
const SHENG: Record<WuXing,WuXing> = {木:'火',火:'土',土:'金',金:'水',水:'木'};
const KE: Record<WuXing,WuXing> = {木:'土',土:'水',水:'火',火:'金',金:'木'};

export const LINE_CONTEXT_SOURCE: RuleSource = {
  id:'liuyao-calendar-relations-v1',version:'2',title:'增删卜易：日月、逐爻及整卦六合六冲、旬空',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'本爻、实际变爻、伏神各算日月；整卦按初四/二五/三上纳支，完整变卦投影不当作静爻发动；支冲不等于回头克',
  references:[
    {url:'https://zh.wikisource.org/wiki/增刪卜易/17',locator:'日辰章第十七',sha256:'e70bfbed847449facf08d1801c5cfe37c3655761ad635b484d7c24e5a4361623',quote:'生多克少錦上添花，生少克多，寡不敵眾。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/19',locator:'六合章第十九',sha256:'087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/20',locator:'六沖章第二十',sha256:'8aec9b6625a18b4c487e45e92c9de662929597fa74a3653ce9ed9dd2d0b7e49b'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/26',locator:'旬空章第二十六',sha256:'29213289bfd323be3206860ee2904f61c05f6f9941313745ae5e8b2bc6620d41'},
  ],
  limitations:['月建五行标签不是综合旺衰；临日与月破、合与克可同时保留','空、冲、合不自动认定失效、暗动、合化或现实吉凶','十九章六冲变六合不看用神的例外未编码为通用吉断；静卦不是合变合或冲变冲'],
};

function influence(ganZhi:string, targetBranch:string, target:WuXing):CalendarInfluence {
  const branch=ganZhi[1],index=BRANCHES.indexOf(branch),targetIndex=BRANCHES.indexOf(targetBranch);
  const element=ELEMENTS[index];
  const elementRelation=element===target?'同类':SHENG[element]===target?'生爻':KE[element]===target?'克爻':SHENG[target]===element?'爻生':'爻克';
  return {ganZhi,branch,element,elementRelation,sameBranch:branch===targetBranch,
    clash:(index-targetIndex+12)%12===6,combination:(index+targetIndex)%12===1};
}

export function lineContext(ganZhi:string,element:WuXing,month:string,day:string,voidBranches:string[]):LineContext {
  const monthRelation=influence(month,ganZhi[1],element);
  const state:Record<CalendarInfluence['elementRelation'],LineContext['monthState']>={同类:'旺',生爻:'相',爻生:'休',爻克:'囚',克爻:'死'};
  return {isVoid:voidBranches.includes(ganZhi[1]),month:monthRelation,day:influence(day,ganZhi[1],element),
    monthState:state[monthRelation.elementRelation],assessmentStatus:'calendar-relations-only',sourceIds:[LINE_CONTEXT_SOURCE.id]};
}
