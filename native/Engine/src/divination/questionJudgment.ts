import type {HexagramLine,LiuQin,QuestionType,WuXing} from './types';
import {relationToMe} from './data/liuqin';
import type {RuleSource} from '../rules/provenance';

export interface QuestionContext {
  /** Relationship to the querent, never inferred from gender. */
  subject?:'self'|'parent'|'child'|'sibling'|'wife'|'husband'|'other'|'unknown';
  event?:string;
  timeHorizon?:'near'|'far'|'unspecified';
}
interface Candidate {
  id:string;layer:'original'|'hidden'|'month'|'day'|'changed';objectPath:string;
  position?:number;contextPath?:string;reason:string;
}
export const QUESTION_RULE_SOURCE:RuleSource={
 id:'liuyao-question-timing-v1',version:'1',title:'增删卜易：取用、两现、飞伏与条件应期',
 editionStatus:'electronic-transcription-not-print-collated',scope:'类别与明确亲属角色仅产生候选；月日与伏神另列；应期触发支不等于具体日期',
 references:[
  {url:'https://zh.wikisource.org/wiki/增刪卜易/8',locator:'用神章第八；职业/财物为现代问题类别的有限映射',sha256:'da83c3e47c04bb4813040e6cf5c3e43f8775e2293da3b32c9a8e2fb542e72a90'},
  {url:'https://zh.wikisource.org/wiki/增刪卜易',locator:'飛伏神章第二十八；兩現章第三十二',sha256:'897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07',quote:'捨其不空﹐而用旬空﹐捨其不破﹐而用月破。'},
  {url:'https://zh.wikisource.org/wiki/增刪卜易/26又3',locator:'各門類應期總注',sha256:'dc529f9dc18f3620c1975fe3463f744fd8732000c4f9d01eecf318d45528eea4',quote:'靜而逢值逢沖'},
 ],limitations:['不按首爻、动静或空破固定排序裁定用神；代占的所问人及事体不能混淆','世爻保留求问者参考；模糊问题不默认以世爻代替事件用神','应期只列条件触发支；藏伏能否出、暗动/合住效力、综合吉凶与远近单位仍需判断；不重起卦'],
};
const BRANCHES='子丑寅卯辰巳午未申酉戌亥';
const ELEMENTS:WuXing[]=['水','土','木','木','土','火','火','土','金','金','土','水'];
const clash=(b:string)=>BRANCHES[(BRANCHES.indexOf(b)+6)%12];
const combine=(b:string)=>BRANCHES[(13-BRANCHES.indexOf(b))%12];
const people:Partial<Record<NonNullable<QuestionContext['subject']>,LiuQin>>={parent:'父母',child:'子孙',sibling:'兄弟',wife:'妻财',husband:'官鬼'};

export function selectQuestionObjects(qt:QuestionType,context:QuestionContext,lines:HexagramLine[],palaceElement:WuXing,calendar:{month:string;day:string}) {
 const subject=context.subject??'unknown',missingContext:string[]=[];
 if(subject==='unknown')missingContext.push('subject');
 if(!context.event?.trim())missingContext.push('event');
 if(!context.timeHorizon||context.timeHorizon==='unspecified')missingContext.push('time-horizon');
 let target:LiuQin|undefined,self=false,reason='category-role';
 if(qt==='health') {target=people[subject];self=subject==='self';reason='explicit-person-role';}
 else if(qt==='marriage') {target=subject==='wife'?'妻财':subject==='husband'?'官鬼':undefined;reason='explicit-partner-role';}
 else if(qt==='parents'||qt==='kids') {
  const expected=qt==='parents'?'parent':'child';
  if(subject==='unknown'||subject===expected)target=qt==='parents'?'父母':'子孙';
  else missingContext.push('category-subject-conflict');
 } else if(qt==='career'||qt==='wealth') {
  if(subject==='self'||subject==='unknown')target=qt==='career'?'官鬼':'妻财';
  else missingContext.push('proxy-perspective');
 }
 // General/event does not establish whether self, an object, or another person is the actual focus.
 if(!target&&!self)missingContext.push('question-object');
 const matches=(l:HexagramLine)=>self?l.isShi:target!==undefined&&l.liuQin===target;
 const originals=lines.filter(matches),candidates:Candidate[]=[],related:Candidate[]=[],excluded:{objectPath:string;reason:string}[]=[];
 for(const line of originals){const path=`/lines/${lines.indexOf(line)}`;candidates.push({id:`original-${line.position}`,layer:'original',position:line.position,objectPath:path,contextPath:path+'/context',reason:self?'querent-self-reference':reason});}
 if(!originals.length&&target){
  // The read chapter explicitly consults day/month before pure-palace hidden alternatives.
  for(const scope of ['month','day'] as const)if(relationToMe(palaceElement,ELEMENTS[BRANCHES.indexOf(calendar[scope][1])])===target){
   candidates.push({id:scope,layer:scope,objectPath:`/castGanZhi/${scope}`,reason:'absent-visible-calendar-role'});
  }
  for(const line of lines)if(line.hidden?.liuQin===target){const path=`/lines/${lines.indexOf(line)}/hidden`;candidates.push({id:`hidden-${line.position}`,layer:'hidden',position:line.position,objectPath:path,contextPath:path+'/context',reason:'absent-visible-pure-palace-role'});}
 }
 if(target||self)for(const line of lines){
  const path=`/lines/${lines.indexOf(line)}`;
  if(!matches(line))excluded.push({objectPath:path,reason:self?'not-querent-line':'different-role'});
  if(line.changed&&((self&&line.isShi)||(!self&&line.changed.liuQin===target)))related.push({id:`changed-${line.position}`,layer:'changed',position:line.position,objectPath:path+'/changed',contextPath:path+'/changed/context',reason:'dependent-changing-reference-only'});
 }
 return {type:target??(self?originals[0]?.liuQin:undefined),selectionStatus:target||self?'candidates-only':'requires-clarification',selectedCandidateId:null,selectionEstablished:false,
  candidateYaoIndices:originals.map(l=>l.position),candidates,related,excluded,missingContext,
  querentReference:`/lines/${lines.findIndex(l=>l.isShi)}`,sourceId:QUESTION_RULE_SOURCE.id,
  interactions:['所有候选均未定用；原爻与变伏、月日身份分开','空破或月令标签不能单独排除候选，变爻只作依附本爻的参考']};
}
interface TimingRule {id:string;branches:string[];factPaths:string[]}
export function conditionalTiming(selection:ReturnType<typeof selectQuestionObjects>,lines:HexagramLine[],context:QuestionContext) {
 const branchesByCandidate=selection.candidates.map(candidate=>{
  const rules:TimingRule[]=[];
  const line=candidate.position?lines.find(l=>l.position===candidate.position):undefined;
  const object=candidate.layer==='original'?line:candidate.layer==='hidden'?line?.hidden:undefined;
  const p=candidate.objectPath;
  if(object){
   const branch=object.ganZhi[1];
   if(candidate.layer==='original'&&line){
    rules.push({id:line.isChanging?'moving-value-combine':'static-value-clash',branches:[branch,line.isChanging?combine(branch):clash(branch)],factPaths:[p+'/ganZhi',p+'/isChanging']});
    if(line.isChanging&&line.changed&&combine(branch)===line.changed.ganZhi[1])rules.push({id:'changed-combination-open',branches:[clash(branch),clash(line.changed.ganZhi[1])],factPaths:[p+'/ganZhi',p+'/changed/ganZhi']});
   }
   if(object.context.month.clash)rules.push({id:'month-break-fill-combine',branches:[branch,combine(branch)],factPaths:[p+'/ganZhi',p+'/context/month/clash']});
   if(object.context.isVoid)rules.push({id:'void-fill-clash',branches:[branch,clash(branch)],factPaths:[p+'/ganZhi',p+'/context/isVoid']});
   if(object.context.month.combination)rules.push({id:'month-combination-open',branches:[clash(branch),clash(object.context.month.branch)],factPaths:[p+'/context/month/combination','/castGanZhi/month']});
  }
  return {candidateId:candidate.id,objectPath:p,rules,
   ...(object?{conditionsPath:p+'/context'}:{}),
   unresolved:candidate.layer==='hidden'?['hidden-emergence','combined-efficacy']:candidate.layer==='original'?['combined-efficacy','binding',...(!line?.isChanging&&line?.context.day.clash?['dark-movement']:[])]:['calendar-object-timing']};
 });
 return {description:'未推定具体应期；以下只列候选对象的条件触发支，不能当作事件必然发生的日期',
  factors:['静值冲、动值合、空破填实与合待冲开可以同时存在；先裁定所问对象、效力和事件方向'],
  assessmentStatus:'conditional-triggers-only',outcomeEstablished:false,sourceId:QUESTION_RULE_SOURCE.id,
  timeScale:context.timeHorizon==='near'?'day-hour-reference':context.timeHorizon==='far'?'year-month-reference':'unresolved',
  unresolved:['selected-object','combined-strength','event-outcome',...selection.missingContext],branchesByCandidate};
}
