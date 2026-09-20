import type { QuestionContext } from '../divination/questionJudgment';
import type { RuleSource } from '../rules/provenance';
import type { Palace, QuestionType, TianGan, WuXing } from './types';
import { YONGSHEN_RULES } from './data/yongshen-rules';
import { computeXunShou } from './helpers/tianPan';

export const QIMEN_QUESTION_SOURCE:RuleSource = {
  id:'qimen-question-references-v1',version:'1',title:'SUJI奇门问题参考点约定',editionStatus:'product-policy',
  scope:'日时干及类别候选分盘层；未定用',
  references:[{url:'https://github.com/wxbbb42/SUJI/blob/10ab339a21ecef69211b3a8c53189362c75f1a72/native/Engine/src/qimen/data/yongshen-rules.ts',locator:'产品映射，非古籍'}],
  limitations:['不由代占或性别自动取用','甲按本柱旬仪定位，生克用原干；中宫非有效天盘','不选首项；不由远近或宫数定应期'],
};

const ELEMENTS:Record<TianGan,WuXing>={甲:'木',乙:'木',丙:'火',丁:'火',戊:'土',己:'土',庚:'金',辛:'金',壬:'水',癸:'水'};
const SHENG:Record<WuXing,WuXing>={木:'火',火:'土',土:'金',金:'水',水:'木'};
const KE:Record<WuXing,WuXing>={木:'土',土:'水',水:'火',火:'金',金:'木'};

export interface QimenOccurrence {
  palaceId:number;
  plate:'earth'|'hosted-earth'|'sky'|'hosted-sky'|'center-record'|'door'|'deity'|'star';
  objectPath:string;
  isEffectiveSky?:boolean;
  elementRelation?:{stemElement:WuXing;palaceElement:WuXing;relation:'比和'|'干生宫'|'宫生干'|'干克宫'|'宫克干';assessmentStatus:'stem-palace-only'};
}
export interface QimenCandidate {
  id:string;role:'day-reference'|'hour-reference'|'category-reference';symbol:string;
  calendarPath?:string;carrierStem?:TianGan;carrierMethod?:'direct-stem'|'own-pillar-xun';
  occurrences:QimenOccurrence[];
}

/** Pure projection of one existing receipt. Never re-casts or adjudicates an event. */
export function qimenQuestionObjects(qt:QuestionType,context:QuestionContext,palaces:Palace[],calendar:{day:string;hour:string}) {
  const missingContext:string[]=[],subject=context.subject??'unknown';
  if(subject==='unknown')missingContext.push('subject');
  if(!context.event?.trim())missingContext.push('event');
  if(!context.timeHorizon||context.timeHorizon==='unspecified')missingContext.push('time-horizon');
  if(subject!=='self'&&subject!=='unknown')missingContext.push('proxy-perspective');
  if((qt==='kids'||qt==='parents')&&subject!=='unknown'&&subject!==(qt==='kids'?'child':'parent'))missingContext.push('category-subject-conflict');
  const candidates:QimenCandidate[]=[];
  for(const scope of ['day','hour'] as const){
    const symbol=calendar[scope][0] as TianGan;
    const carrierStem=symbol==='甲'?computeXunShou(symbol,calendar[scope][1]):symbol;
    const occurrences:QimenOccurrence[]=[];
    for(const [index,palace] of palaces.entries())for(const field of ['diPanGan','hostedDiPanGan','tianPanGan','hostedTianPanGan'] as const){
      if(palace[field]!==carrierStem)continue;
      const plate=field==='diPanGan'?'earth':field==='hostedDiPanGan'?'hosted-earth':palace.id===5?'center-record':field==='tianPanGan'?'sky':'hosted-sky';
      const stemElement=ELEMENTS[symbol],palaceElement=palace.wuXing;
      occurrences.push({palaceId:palace.id,plate,objectPath:`/palaces/${index}/${field}`,isEffectiveSky:plate==='sky'||plate==='hosted-sky',
        ...(plate==='center-record'?{}:{elementRelation:{stemElement,palaceElement,
          relation:stemElement===palaceElement?'比和':SHENG[stemElement]===palaceElement?'干生宫':SHENG[palaceElement]===stemElement?'宫生干':KE[stemElement]===palaceElement?'干克宫':'宫克干',assessmentStatus:'stem-palace-only' as const}})});
    }
    candidates.push({id:`${scope}-stem`,role:`${scope}-reference`,symbol,calendarPath:scope==='day'?'/dayGanZhi':'/hourGanZhi',carrierStem,carrierMethod:symbol==='甲'?'own-pillar-xun':'direct-stem',occurrences});
    if(!occurrences.some(o=>o.isEffectiveSky))missingContext.push(`${scope}-sky-reference`);
  }
  const rule=YONGSHEN_RULES[qt];
  for(const [field,plate,symbol] of [['bamen','door',rule.secondaryMen],['bashen','deity',rule.secondaryShen],['jiuxing','star',rule.secondaryStar]] as const){
    if(!symbol)continue;
    const occurrences=palaces.flatMap((palace,index)=>palace.id!==5&&palace[field]===symbol?[{palaceId:palace.id,plate,objectPath:`/palaces/${index}/${field}`}]:[]);
    candidates.push({id:`category-${plate}-${symbol}`,role:'category-reference',symbol,occurrences});
  }
  return {selectionStatus:missingContext.length?'requires-clarification' as const:'candidates-only' as const,
    selectionEstablished:false as const,selectedCandidateId:null,candidates,missingContext,sourceId:QIMEN_QUESTION_SOURCE.id};
}

export function unresolvedQimenTiming(selection:ReturnType<typeof qimenQuestionObjects>) {
  return {description:'尚不能确定应期；对象、事件成败及奇门应期规则待定',
    factors:['不以宫数定天数，不套用六爻应期'],
    assessmentStatus:'unresolved' as const,outcomeEstablished:false as const,sourceId:QIMEN_QUESTION_SOURCE.id,
    timeScale:'unresolved' as const,triggers:[],dates:[],
    unresolved:['selected-object','event-outcome','qimen-timing-convention','time-unit',...selection.missingContext],
    observedFactPaths:['/hourVoid','/horse']};
}
