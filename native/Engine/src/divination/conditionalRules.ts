import type { HexagramLine, LineContextFacts, WuXing } from './types';
import type { RuleSource } from '../rules/provenance';
import { returningBranch } from './guaRelations';

const SHENG:Record<WuXing,WuXing> = {木:'火',火:'土',土:'金',金:'水',水:'木'};
const KE:Record<WuXing,WuXing> = {木:'土',土:'水',水:'火',火:'金',金:'木'};
const BRANCHES='子丑寅卯辰巳午未申酉戌亥';
const ADVANCE=['亥子','寅卯','巳午','申酉','丑辰','辰未','未戌'];
const ROOT='https://zh.wikisource.org/wiki/增刪卜易';
const ROOT_SHA='897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07';

export const CONDITIONAL_RULE_SOURCES:RuleSource[] = [
  {id:'liuyao-changing-relations-v1',version:'1',title:'增删卜易：回头生克与所选七组进退',editionStatus:'electronic-transcription-not-print-collated',
    scope:'变爻只回头作用于同位本爻；进退保留结构匹配，空破、取用及效力另审',
    references:[{url:ROOT+'/17',locator:'日辰章第十七，申月戊午遯之姤',sha256:'e70bfbed847449facf08d1801c5cfe37c3655761ad635b484d7c24e5a4361623',quote:'世爻午火臨日辰，本主旺相，不宜申金月建生亥水回頭克世'},
      {url:ROOT,locator:'進神退神章第二十九',sha256:ROOT_SHA,quote:'亥化子，寅化卯，巳化午，申化酉，丑化辰，辰化未，未化戌。'}],
    limitations:['所读本列七组，不含戌丑循环；not-listed仅表示此表未列','进退及回头生克不是吉凶结论；明动、空破和日月帮助并不直接证明最终效力']},
  {id:'liuyao-flying-hidden-v1',version:'1',title:'增删卜易：飞伏生克及有用/不得出条件',editionStatus:'electronic-transcription-not-print-collated',
    scope:'本位飞神到纯宫伏神的方向；生扶、冲克飞神、伏神受制各自保留',
    references:[{url:ROOT,locator:'飛伏神章第二十八；实际正文，非目录',sha256:ROOT_SHA,quote:'伏神得日月生者一也；伏神旺相者二也；伏神得飛神生者三也；伏神得動爻生者四'}],
    limitations:['日月、明动五行关系是条件证据，明动爻本身效力未由此定案','综合旺衰、墓绝、旺飞克伏及伏衰空破尚需裁定；不把月建标签冒充综合条件，不自动判伏出']},
  {id:'liuyao-day-clash-v1',version:'1',title:'增删卜易：暗动与日破的条件分歧',editionStatus:'electronic-transcription-not-print-collated',
    scope:'静爻日冲才进入暗动/日破候选；分别保留日月扶克、明动生克及冲空',
    references:[{url:ROOT+'/22',locator:'暗動章第二十二，寅月己未坤之师',sha256:'c8d2e339a0bf86b1e09e290ff191eac06c6c0bfce190c3d1e7942cc3fab874d5',quote:'靜爻旺相日辰沖之爲暗動，靜爻休囚日辰沖之爲破'}],
    limitations:['候选表示有对应生扶或月衰条件，仍须综合旺衰；不把候选写成已暗动或已日破','日冲月弱不自动判破：所读寅月己未例丑土受月克，仍有日扶及动火生','冲空单列待审，不一律作真空或自动填实；不由古例叙述推出现实疾病或应期']},
];

export interface RuleCondition {
  id:string;
  state:'matched'|'not-matched'|'unresolved';
  factPaths:string[];
}
const check=(id:string,value:boolean|undefined,...factPaths:string[]):RuleCondition=>({id,state:value===undefined?'unresolved':value?'matched':'not-matched',factPaths});
const supported=(relation:string)=>relation==='同类'||relation==='生爻';
const clash=(a:string,b:string)=>(BRANCHES.indexOf(a)-BRANCHES.indexOf(b)+12)%12===6;
const base=(lines:HexagramLine[],line:HexagramLine)=>`/lines/${lines.indexOf(line)}`;

export function advanceRetreat(from:string,to:string):'进神'|'退神'|'not-listed' {
  return ADVANCE.includes(from+to)?'进神':ADVANCE.includes(to+from)?'退神':'not-listed';
}

function relation(from:WuXing,to:WuXing,labels:readonly string[]) {
  return labels[from===to?0:SHENG[from]===to?1:KE[from]===to?2:SHENG[to]===from?3:4];
}
function actors(lines:HexagramLine[],target:HexagramLine,element:WuXing) {
  const moving=lines.filter(l=>l!==target&&l.isChanging);
  return {generating:moving.filter(l=>SHENG[l.wuXing]===element),controlling:moving.filter(l=>KE[l.wuXing]===element)};
}
function actorPaths(lines:HexagramLine[],actors:HexagramLine[]) {
  return actors.flatMap(l=>[base(lines,l)+'/isChanging',base(lines,l)+'/wuXing']);
}
function inspectedPaths(lines:HexagramLine[],target:HexagramLine,matches:HexagramLine[]) {
  // A negative condition needs the inspected set, not just the empty match set.
  return ['/changingYao',...actorPaths(lines,matches.length?matches:lines.filter(l=>l!==target&&l.isChanging))];
}

/** Structural directions and explicit conditions; never a strength score or verdict. */
export function lineRules(line:HexagramLine,lines:HexagramLine[]) {
  const path=base(lines,line),ctx=line.context;
  const changing=line.isChanging&&line.changed?line.changed:undefined;
  const changedPath=path+'/changed';
  const changedConditions=changing?[
    check('changed-void',changing.context.isVoid,changedPath+'/context/isVoid'),
    check('changed-month-break',changing.context.month.clash,changedPath+'/context/month/clash'),
    check('changed-day-clash',changing.context.day.clash,changedPath+'/context/day/clash'),
    check('combined-effectiveness',undefined),
  ]:[];
  const returning=changing?{
    ...returningBranch(line),
    relation:relation(changing.wuXing,line.wuXing,['比和','回头生','回头克','本爻生变','本爻克变']),
    from:changedPath,to:path,assessmentStatus:'structural-relation',sourceId:'liuyao-changing-relations-v1',
    conditionsFrom:path+'/rules/advanceRetreat/conditions',
    conditions:[
      check('changed-month-generation',changing.context.month.elementRelation==='生爻',changedPath+'/context/month/elementRelation'),
      check('changed-day-support',supported(changing.context.day.elementRelation),changedPath+'/context/day/elementRelation'),
      check('original-day-presence',ctx.day.sameBranch,path+'/context/day/sameBranch'),
    ],
  }:undefined;
  const advance=changing?{
    kind:advanceRetreat(line.ganZhi[1],changing.ganZhi[1]),fromBranch:line.ganZhi[1],toBranch:changing.ganZhi[1],
    from:path,to:changedPath,assessmentStatus:advanceRetreat(line.ganZhi[1],changing.ganZhi[1])==='not-listed'?'not-listed':'structural-match',
    effectiveness:'conditional',sourceId:'liuyao-changing-relations-v1',conditions:changedConditions,
  }:undefined;
  const flyingHidden=line.hidden?hiddenRules(line,lines,path):undefined;
  const dayClash=ctx.day.clash?dayClashRules(line,lines,path):undefined;
  return {...(returning?{returning}:{}),...(advance?{advanceRetreat:advance}:{}),...(flyingHidden?{flyingHidden}:{}),...(dayClash?{dayClash}:{})};
}

function hiddenRules(line:HexagramLine,lines:HexagramLine[],path:string) {
  const hidden=line.hidden!,ctx=hidden.context,hpath=path+'/hidden';
  const moving=actors(lines,line,hidden.wuXing);
  const flyingClashedOrControlled=lines.filter(l=>l!==line&&l.isChanging&&(clash(l.ganZhi[1],line.ganZhi[1])||KE[l.wuXing]===line.wuXing));
  return {
    relation:relation(line.wuXing,hidden.wuXing,['飞伏比和','飞生伏','飞克伏','伏生飞','伏克飞']),from:path,to:hpath,
    assessmentStatus:'conditions-only',sourceId:'liuyao-flying-hidden-v1',
    movingGenerationPositions:moving.generating.map(l=>l.position),movingControlPositions:moving.controlling.map(l=>l.position),
    flyingChallengedByPositions:flyingClashedOrControlled.map(l=>l.position),
    conditions:[
      check('hidden-month-generation',ctx.month.elementRelation==='生爻',hpath+'/context/month/elementRelation'),
      check('hidden-day-generation',ctx.day.elementRelation==='生爻',hpath+'/context/day/elementRelation'),
      check('flying-generates-hidden',SHENG[line.wuXing]===hidden.wuXing,path+'/wuXing',hpath+'/wuXing'),
      check('moving-generates-hidden',moving.generating.length>0,...inspectedPaths(lines,line,moving.generating),hpath+'/wuXing'),
      check('calendar-challenges-flying',[line.context.month,line.context.day].some(v=>v.clash||v.elementRelation==='克爻'),path+'/context/month/clash',path+'/context/day/clash',path+'/context/month/elementRelation',path+'/context/day/elementRelation'),
      check('moving-challenges-flying',flyingClashedOrControlled.length>0,'/changingYao',...(flyingClashedOrControlled.length?flyingClashedOrControlled:lines.filter(l=>l!==line&&l.isChanging)).flatMap(l=>[base(lines,l)+'/isChanging',base(lines,l)+'/ganZhi',base(lines,l)+'/wuXing']),path+'/ganZhi',path+'/wuXing'),
      check('flying-void',line.context.isVoid,path+'/context/isVoid'),
      check('flying-month-break',line.context.month.clash,path+'/context/month/clash'),
      check('hidden-month-clash',ctx.month.clash,hpath+'/context/month/clash'),
      check('hidden-day-clash',ctx.day.clash,hpath+'/context/day/clash'),
      check('hidden-month-control',ctx.month.elementRelation==='克爻',hpath+'/context/month/elementRelation'),
      check('hidden-day-control',ctx.day.elementRelation==='克爻',hpath+'/context/day/elementRelation'),
      check('flying-controls-hidden',KE[line.wuXing]===hidden.wuXing,path+'/wuXing',hpath+'/wuXing'),
      check('hidden-void',ctx.isVoid,hpath+'/context/isVoid'),
      check('hidden-combined-strength',undefined),check('flying-combined-strength',undefined),
      check('hidden-tomb-or-extinction',undefined),check('flying-tomb-or-extinction',undefined),
    ],
  };
}

function dayClashRules(line:HexagramLine,lines:HexagramLine[],path:string) {
  const ctx:LineContextFacts=line.context,moving=actors(lines,line,line.wuXing);
  const monthSupport=supported(ctx.month.elementRelation),daySupport=supported(ctx.day.elementRelation);
  const candidates:string[]=[];
  if (!line.isChanging) {
    if(monthSupport||daySupport||moving.generating.length) candidates.push('暗动');
    if(!monthSupport||moving.controlling.length) candidates.push('日破');
    if(ctx.isVoid) candidates.push('冲空待审');
  }
  return {
    kind:line.isChanging?'moving-day-clash':'static-day-clash',assessmentStatus:'conditional',candidates,voidClash:ctx.isVoid,
    sourceId:'liuyao-day-clash-v1',movingGenerationPositions:moving.generating.map(l=>l.position),movingControlPositions:moving.controlling.map(l=>l.position),
    conditions:[
      check('static-line',!line.isChanging,path+'/isChanging'),check('day-clash',ctx.day.clash,path+'/context/day/clash'),
      check('month-support',monthSupport,path+'/context/month/elementRelation'),check('day-support',daySupport,path+'/context/day/elementRelation'),
      check('month-control',ctx.month.elementRelation==='克爻',path+'/context/month/elementRelation'),
      check('moving-generation',moving.generating.length>0,...inspectedPaths(lines,line,moving.generating),path+'/wuXing'),
      check('moving-control',moving.controlling.length>0,...inspectedPaths(lines,line,moving.controlling),path+'/wuXing'),
      check('void-clash',ctx.isVoid,path+'/context/isVoid'),check('combined-strength',undefined),
      check('moving-actors-effectiveness',undefined),
    ],
  };
}
