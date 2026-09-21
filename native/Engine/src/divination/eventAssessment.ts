import type { HexagramLine, YongShenAnalysis, WuXing } from './types';
import type { RuleSource } from '../rules/provenance';
import { efficacy, efficacyDecisionView } from './efficacy';

export const EVENT_SOURCE:RuleSource={
  id:'liuyao-event-zengshan-v1',version:'1',title:'增删卜易：事件方向与元忌传递的充分条件',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'明确取用后，逐候选检查无根、无伤月建与有效元忌传递；事件方向限于本条文剖面，不是现实结果或日期',
  references:[
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy11.html',locator:'元神忌神衰旺章：有力无力全条件、元忌同动、无根反例',sha256:'74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb',quote:'上论元神、忌神之有力、无力者，亦要用神有气。倘若用神无根，谓之元神有力亦难生，忌神无力亦休喜。'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy18.html',locator:'月将章：无伤月建、日月相敌与增生克',sha256:'4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018',quote:'此言用神临月建，并无他爻以伤克者，凡占皆吉。忌神临月建，而用神休囚无救者，诸占大凶。'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy40.html',locator:'两现章：小畜的事件与应期对象；豫之归妹须结合前占',sha256:'e74764848deb4fd0ffe5e3bd16d696701dd5b06de034a085d74f24a35f0f2c2f',quote:'应临月建之财以克世，许之必得。彼问：何日到手？'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy11.html',locator:'元神有力第一条；effective-yuan-supports-viable-target 的前提',sha256:'74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb',quote:'元神旺相，或临日月，或得日月动爻生扶者，一也。'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy11.html',locator:'大过之鼎；元忌传递与目标能否承接必须合读',sha256:'74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb',quote:'幸得元神酉金亦动，忌神未土反生元神之酉金，金生亥水，接续相生，化凶而为吉矣。岂知亥水月冲日克，值月破而被克，虽有生扶，奈何生之不起'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy18.html',locator:'balanced-calendar-receives-moving-support；生克相敌后的额外生扶',sha256:'4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018',quote:'月克日生，遇帮扶而愈旺，月生日克，逢克制而亦衰。'},
    {url:'https://www.quanxue.cn/qt_mingxiang/zengshanpy/zengshanpy11.html',locator:'元神生用的旺相总前提；与有力第一条分段核对',sha256:'74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb',quote:'元神虽生用神，须要旺相，方能生得用神。'},
  ],
  limitations:['电子转录未校印本；现代按语不参与','条文方向成立不代表现实事件已经成立；不输出概率、医疗结论或日期','元忌仅用实际原动爻；元神须有独立日月支持且无未决伤克、空破墓绝；保留所有残余攻击','多候选逐一检查；全部同向只表示对象选择不改变本剖面方向，不替代具体定用或应期定用','合冲、复杂三合、伏神出伏、多占与专门事类反向取用不在充分条件范围'],
};
const GENERATES:Record<WuXing,WuXing>={木:'火',火:'土',土:'金',金:'水',水:'木'};
const CONTROLS:Record<WuXing,WuXing>={木:'土',土:'水',水:'火',火:'金',金:'木'};
interface Evidence {ruleId:string;factPaths:string[]}
const ev=(ruleId:string,...factPaths:string[]):Evidence=>({ruleId,factPaths});
const LIMITS=['source-profile-not-realized-outcome','no-date-verdict','no-fixed-two-appearance-ranking','unmodeled-special-event-semantics'];

/** Sufficient conditions, never a score or an unconditional interpretation of a moving pair. */
export function eventAssessment(lines:HexagramLine[],selection:YongShenAnalysis,report:ReturnType<typeof efficacy>) {
  const view=efficacyDecisionView(report);
  const candidates=selection.candidates.map(candidate=>{
    const p=candidate.objectPath,entry=view.objects.find(x=>x.objectPath===p);
    const target=candidate.layer==='original'?lines[candidate.position!-1]:undefined;
    const conditions:Evidence[]=[],blockers:Evidence[]=[];
    const yuan=target?lines.filter(l=>l.isChanging&&GENERATES[l.wuXing]===target.wuXing):[];
    const ji=target?lines.filter(l=>l.isChanging&&CONTROLS[l.wuXing]===target.wuXing):[];
    const rootless=!!target&&entry?.vitality.status==='rootless';
    const unpack=(indices:number[])=>indices.map(index=>{
      const [ruleId,paths]=view.evidence[index];return ev(ruleId,...paths.map(i=>view.factPaths[i]));
    });
    const gate=(actor:HexagramLine)=>{
      const ap=`/lines/${actor.position-1}`,row=view.objects.find(x=>x.objectPath===ap)!;
      const reasons:Evidence[]=unpack(row.vitality.blockers);
      if(row.vitality.status!=='supported-unopposed')reasons.push(ev('actor-needs-unopposed-calendar-support',ap+'/context'));
      if(row.availability.status!=='present')reasons.push(ev('actor-awaiting-availability',ap+'/context'));
      for(const ref of [...row.tombs,...row.extinctions])if(!['opened','overridden-by-generation'].includes(ref.status))
        reasons.push(ev('actor-lifecycle-unresolved',ap,ref.sourcePath));
      if(actor.changed&&(actor.changed.context.isVoid||(actor.changed.context.month.clash&&!actor.changed.context.day.sameBranch)))
        reasons.push(ev('changed-object-awaiting-availability',ap+'/changed/context'));
      return {effective:reasons.length===0,reasons};
    };
    const effectiveYuan=yuan.filter(y=>gate(y).effective);
    const transmissions=ji.flatMap(j=>yuan.map(y=>{
      const yp=`/lines/${y.position-1}`,jp=`/lines/${j.position-1}`,yg=gate(y),jg=gate(j);
      const receiving=!!target&&!!entry&&['supported','balanced'].includes(entry.calendarStrength.status)&&!target.context.month.clash;
      const reasons=[...jg.reasons,...yg.reasons,...(receiving?[]:[ev('target-reception-unresolved',p)])];
      const g={effective:reasons.length===0,reasons};
      return {jiPath:jp,yuanPath:yp,
        status:rootless?'target-cannot-receive':g.effective?'redirected-through-yuan':'conditional',
        conditions:[ev('ji-yuan-both-moving',jp+'/isChanging',jp+'/wuXing',yp+'/isChanging',yp+'/wuXing',p+'/wuXing'),
          ...(g.effective?[ev('yuan-can-transmit',yp,'/efficacy')]:[])],
        blockers:rootless?[ev('month-break-day-control-no-root',p+'/context/month/clash',p+'/context/day/elementRelation')]:g.reasons};
    }));
    let outcome='unresolved';
    if(!target||!entry)blockers.push(ev('original-target-required','/yongShen/candidates'));
    else if(rootless){
      outcome='adverse-under-selected-rule';
      conditions.push(ev('month-break-day-control-no-root',p+'/context/month/clash',p+'/context/day/elementRelation',p));
    } else {
      const redirected=new Set(transmissions.filter(t=>t.status==='redirected-through-yuan').map(t=>t.jiPath));
      const balancedWithRescue=entry.calendarStrength.status==='balanced'&&!target.context.month.clash&&effectiveYuan.length>0;
      for(const evidence of unpack(entry.vitality.blockers)) {
        if(evidence.ruleId==='moving-control'&&redirected.has(evidence.factPaths[0].replace('/isChanging','')))continue;
        if(evidence.ruleId==='calendar-restraint'&&balancedWithRescue)continue;
        blockers.push(evidence);
      }
      for(const ref of [...entry.tombs,...entry.extinctions])if(!['opened','overridden-by-generation'].includes(ref.status))
        blockers.push(ev('target-lifecycle-unresolved',p,ref.sourcePath));
      if(target.changed&&(target.changed.context.isVoid||(target.changed.context.month.clash&&!target.changed.context.day.sameBranch)))
        blockers.push(ev('changed-target-awaiting-availability',p+'/changed/context'));
      const monthly=target.context.month.sameBranch;
      const viable=['supported','balanced'].includes(entry.calendarStrength.status)&&!target.context.month.clash;
      if(!blockers.length&&viable&&(monthly||effectiveYuan.length)){
        conditions.push(ev(monthly?'uninjured-monthly-target':'effective-yuan-supports-viable-target',p+'/context',p,'/lines'));
        if(balancedWithRescue)conditions.push(ev('balanced-calendar-receives-moving-support',p+'/context',...effectiveYuan.map(y=>`/lines/${y.position-1}`)));
        outcome=entry.availability.status==='present'?'favorable-under-selected-rule':'awaiting-condition';
        if(outcome==='awaiting-condition')blockers.push(ev('target-awaiting-availability',p+'/context'));
      } else if(entry.vitality.status==='opposed-unrescued'&&ji.some(j=>j.context.month.sameBranch&&gate(j).effective)){
        outcome='adverse-under-selected-rule';conditions.push(ev('monthly-ji-unrescued-target',p,'/lines'));
      } else {
        outcome=blockers.length?'contested':'unresolved';
        if(!blockers.length)blockers.push(ev('event-sufficient-conditions-not-met',p,'/efficacy'));
      }
    }
    return {candidateId:candidate.id,objectPath:p,outcome,conditions,blockers,transmissions};
  });
  const ready=['selected','multiple-candidates'].includes(view.selection.status)&&candidates.length>0&&candidates.every(c=>/^\/lines\/\d$/.test(c.objectPath));
  const unanimous=ready&&candidates.every(c=>c.outcome===candidates[0].outcome);
  const outcome=unanimous?candidates[0].outcome:'unresolved';
  return packEvidence({methodVersion:'zengshan-event-sufficient-v1',sourceId:EVENT_SOURCE.id,assessmentStatus:'source-profile-event-direction',
    outcome,ruleOutcomeEstablished:['favorable-under-selected-rule','adverse-under-selected-rule'].includes(outcome),outcomeEstablished:false,
    selectionStatus:!ready?'requires-selection':candidates.length===1?'unique-object':unanimous&&['favorable-under-selected-rule','adverse-under-selected-rule'].includes(outcome)?'candidate-invariant-direction':'multiple-object-ambiguity',
    eventObjectPaths:candidates.map(c=>c.objectPath),timingObjectStatus:'not-selected',
    conditions:[ev('selection-prerequisites','/questionContext','/yongShen/candidates','/yongShen/missingContext')],
    candidates,limitations:LIMITS});
}


type Interned<T> = T extends Evidence ? number : T extends Array<infer Item> ? Interned<Item>[] :
  T extends object ? {[K in keyof T]:Interned<T[K]>} : T;
/** Evidence order, duplicates at use sites and empty conditions are preserved. */
function packEvidence<T>(report:T) {
  const ruleIDs:string[]=[],factPaths:string[]=[],evidence:[number,number[]][]=[];
  const index=(values:string[],s:string)=>{let i=values.indexOf(s);if(i<0){i=values.length;values.push(s);}return i;};
  const evidenceIndex=new Map<string,number>();
  const visit=(value:any):any=>{
    if(Array.isArray(value))return value.map(visit);
    if(!value||typeof value!=='object')return value;
    if(typeof value.ruleId==='string'&&Array.isArray(value.factPaths)){
      const row:[number,number[]]=[index(ruleIDs,value.ruleId),value.factPaths.map((p:string)=>index(factPaths,p))],key=JSON.stringify(row);
      let i=evidenceIndex.get(key);if(i===undefined){i=evidence.length;evidence.push(row);evidenceIndex.set(key,i);}return i;
    }
    return Object.fromEntries(Object.entries(value).map(([key,v])=>[key,visit(v)]));
  };
  const data=visit(report) as Interned<T>;
  return {...data,evidenceLayout:'indexed-event-evidence-v1' as const,indexBase:0 as const,
    evidenceColumns:['ruleIndex','factPathIndices'] as const,ruleIDs,factPaths,evidence};
}
