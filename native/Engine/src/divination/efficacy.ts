import type { HexagramLine, RelatedLine, WuXing, YongShenAnalysis } from './types';
import type { QuestionContext } from './questionJudgment';
import type { triads } from './triads';
import type { tombExtinction } from './tombExtinction';
import type { RuleSource } from '../rules/provenance';

const BASE='https://www.quanxue.cn/qt_mingxiang/zengshanpy/';
export const EFFICACY_SOURCE:RuleSource={
  id:'liuyao-efficacy-zengshan-v1',version:'1',title:'增删卜易选定条文：取用与有条件效力',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'明确所问的唯一对象、日月局部条件、无根与无竞争生扶、逐对象墓绝、限定三合范围；结论仅表示所选条文前提满足',
  references:[
    {url:BASE+'zengshanpy09.html',locator:'用神章；明确人事角色',sha256:'f3ea262ad33a465dc5e1213c1474bcd5e4998c9e10545a60c6a7ebae0ef2a5ea'},
    {url:BASE+'zengshanpy11.html',locator:'元神忌神衰旺；大过之鼎无根反例',sha256:'74c82f8be5c04265049119a9383c6bfd1556ad117c9818fc8828feae684873cb',quote:'值月破而被克，虽有生扶，奈何生之不起'},
    {url:BASE+'zengshanpy18.html',locator:'月将章；生克相敌、增克制及旬内仍空',sha256:'4f74faf658faf94f8cd8bda42691a86a77e0aca4b48bcd86af738d6a16349018',quote:'月克日生，遇帮扶而愈旺，月生日克，逢克制而亦衰。'},
    {url:BASE+'zengshanpy22.html',locator:'三合章；四范围、动静竞争、空破墓待成',sha256:'af41ab6a4f2c336c4f6452acd2cd1e4762bf187bd4d14c7f42c1fe207190b739',quote:'三合局中，有一值空破者，待填实之日月成之。有一爻入墓者，待冲开之日成之。'},
    {url:BASE+'zengshanpy31.html',locator:'生旺墓绝；完整火行及土巳例外',sha256:'7ed19e9471c398c386a04fb195a1a752469a5e5d307b5eeaca490fcb727affa6',quote:'土爻虽绝于巳，必须休囚无气，又逢巳者，方谓之绝。'},
    {url:BASE+'zengshanpy38.html',locator:'随鬼入墓；旺者非真、墓破易出及小过之艮日月官局',sha256:'dda2b500d22d6d43979dae3339ce90cb21289de61aef82a0f8cb17ca11205da5',quote:'墓神被日月动爻冲破者，亦不为真。'},
    {url:BASE+'zengshanpy40.html',locator:'两现章；用空破的应期反例与多占前提',sha256:'e74764848deb4fd0ffe5e3bd16d696701dd5b06de034a085d74f24a35f0f2c2f'},
  ],
  limitations:[
    '劝学电子本目录自述底本为民国三十年锦章书局；未取得影印校勘，现代乾按与居士按不作原典',
    '唯一候选定用以明确关系与事件、既有类别映射为前提；两现不按空破动静固定排序，月日与伏神不混选',
    '日月支持只作局部证据；有动克、合、回头克、未决日冲等竞争即不据此宣称综合旺相，未使用积分',
    '墓源被冲与目标旺而待开分开；结构墓绝不等于真墓真绝，动爻冲墓须另审作用者',
    '三合两动一静保留同章竞争；非世的日月单动锚点尚无选定效力依据；不混入易林缺中字半局法',
    '决定的是规则当前适用/受阻/待条件，非现实吉凶、医疗结论、完整合化或公历应期；复杂救应链仍具体列为竞争条件',
  ],
};
interface Evidence {id:string;factPaths:string[]}
interface Decision {status:string;conditions:Evidence[];blockers:Evidence[]}
interface ObjectEntry {objectPath:string;object:HexagramLine|RelatedLine;line:HexagramLine;layer:'original'|'changed'|'hidden'}
interface ReferenceDecision extends Decision {scope:'month'|'day'|'own-change'|'flying'|'moving';sourcePath:string}
const GENERATES:Record<WuXing,WuXing>={木:'火',火:'土',土:'金',金:'水',水:'木'};
const CONTROLS:Record<WuXing,WuXing>={木:'土',土:'水',水:'火',火:'金',金:'木'};
const BRANCHES='子丑寅卯辰巳午未申酉戌亥';
const clash=(a:string,b:string)=>(BRANCHES.indexOf(a)+6)%12===BRANCHES.indexOf(b);
const combine=(a:string,b:string)=>(13-BRANCHES.indexOf(a))%12===BRANCHES.indexOf(b);
const branch=(o:HexagramLine|RelatedLine)=>o.ganZhi.slice(-1);
const ev=(id:string,...factPaths:string[]):Evidence=>({id,factPaths});
const decision=(status:string,conditions:Evidence[]=[],blockers:Evidence[]=[]):Decision=>({status,conditions,blockers});
const supports=(relation:string)=>relation==='同类'||relation==='生爻';

/** A sufficient-condition profile, not a numerical global strength/fortune model. */
export function efficacy(lines:HexagramLine[],selection:YongShenAnalysis,context:QuestionContext,
  tombFacts:ReturnType<typeof tombExtinction>,triadFacts:ReturnType<typeof triads>) {
  const entries:ObjectEntry[]=lines.flatMap((line,i)=>[
    {objectPath:`/lines/${i}`,object:line,line,layer:'original' as const},
    ...(line.changed?[{objectPath:`/lines/${i}/changed`,object:line.changed,line,layer:'changed' as const}]:[]),
    ...(line.hidden?[{objectPath:`/lines/${i}/hidden`,object:line.hidden,line,layer:'hidden' as const}]:[]),
  ]);
  const candidateIds=selection.candidates.map(c=>c.id);
  const calendarCandidates=selection.candidates.filter(c=>c.layer==='day'||c.layer==='month');
  const explicit=!!context.subject&&context.subject!=='unknown'&&!!context.event?.trim()&&
    !selection.missingContext.some(x=>['category-subject-conflict','proxy-perspective','question-object'].includes(x));
  const eligible=calendarCandidates.length?calendarCandidates:selection.candidates;
  const selected=explicit&&eligible.length===1?eligible[0]:undefined;
  const objectSelection={status:!explicit?'requires-context':!eligible.length?'absent':eligible.length>1?'multiple-candidates':
    selected?.layer==='month'||selected?.layer==='day'?'calendar-reference':'selected',
    selectedCandidateId:selected?.id??null,candidateIds,eligibleCandidateIds:eligible.map(c=>c.id),
    factPaths:['/questionContext','/yongShen/candidates','/yongShen/missingContext']};

  const basic=entries.map(entry=>{
    const {objectPath:p,object:o,line,layer}=entry,c=o.context;
    const supportPaths=(['month','day'] as const).filter(s=>supports(c[s].elementRelation)).map(s=>`${p}/context/${s}/elementRelation`);
    const restraintPaths=(['month','day'] as const).filter(s=>c[s].elementRelation==='克爻').map(s=>`${p}/context/${s}/elementRelation`);
    if(c.month.clash)restraintPaths.push(p+'/context/month/clash');
    const rootless=c.month.clash&&c.day.elementRelation==='克爻';
    const calendarStrength={status:rootless?'rootless-condition':supportPaths.length&&restraintPaths.length?'balanced':
      supportPaths.length?'supported':restraintPaths.length?'opposed':'neutral',supportPaths,restraintPaths};
    const conditions=supportPaths.map(path=>ev('calendar-support',path));
    const blockers:Evidence[]=restraintPaths.map(path=>ev('calendar-restraint',path));
    const rescue:Evidence[]=[];
    if(layer!=='changed')lines.forEach((actor,i)=>{
      if(!actor.isChanging||actor.position===line.position)return;
      if(CONTROLS[actor.wuXing]===o.wuXing)blockers.push(ev('moving-control',`/lines/${i}/isChanging`,`/lines/${i}/wuXing`,p+'/wuXing'));
      if(combine(branch(actor),branch(o)))blockers.push(ev('moving-combination',`/lines/${i}/isChanging`,`/lines/${i}/ganZhi`,p+'/ganZhi'));
      if(clash(branch(actor),branch(o)))blockers.push(ev('moving-clash',`/lines/${i}/isChanging`,`/lines/${i}/ganZhi`,p+'/ganZhi'));
      if(actor.wuXing===o.wuXing||GENERATES[actor.wuXing]===o.wuXing)rescue.push(ev('moving-support-requires-actor',`/lines/${i}/isChanging`,`/lines/${i}/wuXing`,p+'/wuXing'));
    });
    if(layer==='original'&&line.changed){
      const change=line.changed,cp=p+'/changed';
      if(CONTROLS[change.wuXing]===o.wuXing)blockers.push(ev('return-control',cp+'/wuXing',p+'/wuXing'));
      if(combine(branch(o),branch(change)))blockers.push(ev('return-combination',p+'/ganZhi',cp+'/ganZhi'));
      if(clash(branch(o),branch(change)))blockers.push(ev('return-clash',p+'/ganZhi',cp+'/ganZhi'));
      if(GENERATES[change.wuXing]===o.wuXing)rescue.push(ev('return-generation',cp+'/wuXing',p+'/wuXing'));
    }
    if(layer==='hidden'){
      const fp=`/lines/${line.position-1}`;
      if(CONTROLS[line.wuXing]===o.wuXing)blockers.push(ev('flying-control',fp+'/wuXing',p+'/wuXing'));
      if(GENERATES[line.wuXing]===o.wuXing)rescue.push(ev('flying-generation',fp+'/wuXing',p+'/wuXing'));
    }
    for(const s of ['month','day'] as const)if(c[s].combination)blockers.push(ev('calendar-combination',`${p}/context/${s}/combination`));
    if(layer==='original'&&!line.isChanging&&c.day.clash)blockers.push(ev('day-clash-needs-strength',p+'/isChanging',p+'/context/day/clash'));
    const exceptionalRescue=rescue.some(x=>x.id==='return-generation'||x.id==='flying-generation');
    const vitality=decision(rootless&&!exceptionalRescue?'rootless':supportPaths.length&&!blockers.length?'supported-unopposed':
      !supportPaths.length&&restraintPaths.length&&!rescue.length?'opposed-unrescued':blockers.length||rescue.length?'contested':'neutral',
      [...conditions,...rescue],blockers);
    const activity=decision(layer==='changed'?'dependent':layer==='hidden'?'hidden':line.isChanging?'explicit-moving':
      c.day.clash?'requires-dark-movement':'static',layer==='original'?[ev('motion-fact',p+'/isChanging')]:[]);
    const availability=decision(c.isVoid?'awaiting-void-fill':c.month.clash&&!c.day.sameBranch?'awaiting-break-fill':
      layer==='hidden'?'requires-emergence':'present',[
        ...(c.isVoid?[ev('current-void',p+'/context/isVoid')]:[]),
        ...(c.month.clash?[ev('month-break',p+'/context/month/clash',p+'/context/day/sameBranch')]:[]),
      ]);
    return {...entry,calendarStrength,vitality,activity,availability};
  });
  const objects=basic.map(row=>{
    const {objectPath:p,object:o,layer}=row;
    const ti=tombFacts.objects.findIndex(x=>x.objectPath===p),struct=tombFacts.objects[ti];
    const refs:{scope:ReferenceDecision['scope'];sourcePath:string;branch:string;factPath:string;kind:string}[]=[];
    for(const scope of ['month','day'] as const)if(struct[scope]!=='neither')refs.push({scope,sourcePath:'/castGanZhi/'+scope,
      branch:o.context[scope].branch,factPath:`/tombExtinction/objects/${ti}/${scope}`,kind:struct[scope]});
    if(struct.ownChange&&struct.ownChange!=='neither')refs.push({scope:'own-change',sourcePath:p+'/changed',branch:branch(row.line.changed!),factPath:`/tombExtinction/objects/${ti}/ownChange`,kind:struct.ownChange});
    if(struct.flying&&struct.flying!=='neither')refs.push({scope:'flying',sourcePath:`/lines/${row.line.position-1}`,branch:branch(row.line),factPath:`/tombExtinction/objects/${ti}/flying`,kind:struct.flying});
    for(const [key,kind] of [['movingTombPositions','墓'],['movingExtinctionPositions','绝']] as const)for(const position of struct[key]){
      const i=lines.findIndex(l=>l.position===position);refs.push({scope:'moving',sourcePath:`/lines/${i}`,branch:branch(lines[i]),factPath:`/tombExtinction/objects/${ti}/${key}`,kind});
    }
    const tombs:ReferenceDecision[]=[],extinctions:ReferenceDecision[]=[];
    for(const ref of refs){
      const conditions=[ev('structural-reference',ref.factPath)];const blockers:Evidence[]=[];
      let status='conditional';
      if(ref.kind==='墓'){
        const opening=(['month','day'] as const).filter(s=>clash(o.context[s].branch,ref.branch));
        if(opening.length){status='opened';conditions.push(...opening.map(s=>ev('calendar-opens-tomb','/castGanZhi/'+s,ref.factPath)));}
        else if(row.vitality.status==='supported-unopposed'){status='nonbinding-strength';conditions.push(...row.vitality.conditions);}
        else if(row.vitality.status==='opposed-unrescued'||row.vitality.status==='rootless'){status='binding';conditions.push(...row.vitality.blockers);}
        else blockers.push(...row.vitality.blockers, ...row.vitality.conditions.filter(c=>c.id.includes('requires-actor')));
        // A potential moving clash is not equivalent to an effective tomb-opening actor.
        lines.forEach((actor,i)=>{
          if(!actor.isChanging||!clash(branch(actor),ref.branch)||ref.sourcePath===`/lines/${i}`)return;
          blockers.push(ev('moving-tomb-opening-requires-actor',`/lines/${i}/isChanging`,`/lines/${i}/ganZhi`,ref.factPath));
          if(status==='binding')status='conditional';
        });
        if(ref.scope==='moving'||ref.scope==='own-change'||ref.scope==='flying'){
          const source=basic.find(x=>x.objectPath===ref.sourcePath)!;
          if(source.availability.status!=='present'&&status==='binding'){status='conditional';blockers.push(...source.availability.conditions);}
        }
        tombs.push({scope:ref.scope,sourcePath:ref.sourcePath,...decision(status,conditions,blockers)});
      } else {
        // The disputed 巳 reference cannot itself prove the prior earth-strength premise.
        const independentSupport=row.calendarStrength.supportPaths.some(path=>
          !(['month','day'].includes(ref.scope)&&path===`${p}/context/${ref.scope}/elementRelation`));
        const supported=row.vitality.status==='supported-unopposed'&&independentSupport;
        if(o.wuXing==='土'&&ref.branch==='巳'&&supported){status='overridden-by-generation';conditions.push(...row.vitality.conditions);}
        else if(row.vitality.status==='opposed-unrescued'||row.vitality.status==='rootless'){
          status='effective';conditions.push(...row.vitality.blockers);
          if(ref.scope==='moving'||ref.scope==='flying'){
            status='conditional';blockers.push(ev('extinction-actor-requires-effectiveness',ref.sourcePath+'/context',ref.factPath));
          }
        } else blockers.push(...row.vitality.blockers);
        if(ref.scope==='own-change'&&status==='effective'){
          const source=basic.find(x=>x.objectPath===ref.sourcePath)!;
          if(source.availability.status!=='present'){status='conditional';blockers.push(...source.availability.conditions);}
        }
        extinctions.push({scope:ref.scope,sourcePath:ref.sourcePath,...decision(status,conditions,blockers)});
      }
    }
    return {objectPath:p,calendarStrength:row.calendarStrength,vitality:row.vitality,activity:row.activity,availability:row.availability,tombs,extinctions};
  });
  const assessedTriads=triadFacts.groups.map((g,i)=>{
    const gp=`/triads/groups/${i}`,paths=g.members.flatMap(m=>m.objectPaths);
    const moving=lines.filter((l,j)=>l.isChanging&&paths.includes(`/lines/${j}`));
    const movingBranches=new Set(moving.map(branch));
    let formationStatus:string;
    if(g.scope==='calendar-moving-anchor')formationStatus=lines.find((_,j)=>`/lines/${j}`===g.anchorPath)?.isShi?
      (g.complete?'formed':'awaiting-member'):'requires-scope-evidence';
    else if(g.scope==='inner-change'||g.scope==='outer-change')formationStatus=g.complete?'formed':'awaiting-member';
    else if(!moving.length)formationStatus='not-formed';
    else if(!g.complete)formationStatus='awaiting-member';
    else if(movingBranches.size===3)formationStatus='formed';
    else formationStatus='competing-text';
    const formation=decision(formationStatus,[ev('scoped-members',gp+'/scope',gp+'/members',gp+'/missingBranches'),
      ...moving.map(l=>ev('actual-moving-member',`/lines/${l.position-1}/isChanging`))],
      formationStatus==='competing-text'?[ev('motion-text-competition',gp+'/scope',gp+'/members')]:[]);
    const members=objects.filter(x=>paths.includes(x.objectPath));
    const conditions:Evidence[]=[],blockers:Evidence[]=[];
    let effectStatus=formationStatus;
    if(formationStatus==='formed'){
      const pending=members.filter(x=>x.availability.status==='awaiting-void-fill'||x.availability.status==='awaiting-break-fill');
      const bound=members.flatMap(x=>x.tombs.filter(t=>t.status==='binding'));
      for(const m of members){
        blockers.push(...m.vitality.blockers);
        for(const t of [...m.tombs,...m.extinctions])if(t.status==='conditional'||t.status==='effective')blockers.push(ev('member-lifecycle-condition',m.objectPath+'/context',...t.conditions.flatMap(c=>c.factPaths)));
      }
      if(pending.length){effectStatus='awaiting-void-break';conditions.push(...pending.flatMap(x=>x.availability.conditions));}
      else if(bound.length){effectStatus='awaiting-tomb-open';conditions.push(...bound.flatMap(x=>x.conditions));}
      else if(blockers.length)effectStatus='conditional';
      else effectStatus='effective-under-selected-rule';
    }
    return {groupPath:gp,formation,efficacy:decision(effectStatus,conditions,blockers)};
  });
  const target=selected?objects.find(x=>x.objectPath===selected.objectPath):undefined;
  let selectedEffect:Decision=decision('requires-selection',[],[ev('selection-prerequisite','/questionContext','/yongShen/candidates')]);
  if(target){
    const bound=target.tombs.some(x=>x.status==='binding')||target.extinctions.some(x=>x.status==='effective');
    const pending=target.availability.status!=='present'||target.tombs.some(x=>x.status==='nonbinding-strength');
    const ambiguous=[...target.tombs,...target.extinctions].some(x=>x.status==='conditional');
    selectedEffect=decision(target.vitality.status==='rootless'||bound?'blocked':pending?'awaiting-condition':
      target.vitality.status==='supported-unopposed'&&!ambiguous?'effective-under-selected-rule':'conditional',
      [...target.vitality.conditions,...target.availability.conditions,...target.tombs.flatMap(x=>x.conditions),...target.extinctions.flatMap(x=>x.conditions)],target.vitality.blockers);
  } else if(selected)selectedEffect=decision('calendar-reference',[ev('selected-calendar',selected.objectPath)]);
  const report={methodVersion:'zengshan-sufficient-conditions-v1',sourceId:EFFICACY_SOURCE.id,assessmentStatus:'source-selected-conditional' as const,
    selection:objectSelection,objects,triads:assessedTriads,selectedEffect,outcomeEstablished:false as const,
    limitations:['current-rule-effects-only','no-event-or-date-verdict','competing-actors-not-automatically-resolved','two-appearance-selection-not-fixed-ranking']};
  const packed=internEvidence(report);
  const decisions:[number,number[],number[]][]=[],decisionIndices=new Map<string,number>(),states:string[]=[];
  const state=(s:string)=>{if(!states.includes(s))states.push(s);return states.indexOf(s);};
  const internDecision=(d:{status:string;conditions:number[];blockers:number[]})=>{
    const row:[number,number[],number[]]=[state(d.status),d.conditions,d.blockers],key=JSON.stringify(row);
    if(!decisionIndices.has(key)){decisionIndices.set(key,decisions.length);decisions.push(row);}
    return decisionIndices.get(key)!;
  };
  const referenceRow=(r:{scope:string;sourcePath:string;status:string;conditions:number[];blockers:number[]}):[string,string,number]=>[r.scope,r.sourcePath,internDecision(r)];
  const objectRows=packed.data.objects.map(o=>[o.objectPath,[state(o.calendarStrength.status),o.calendarStrength.supportPaths,o.calendarStrength.restraintPaths],
    internDecision(o.vitality),internDecision(o.activity),internDecision(o.availability),o.tombs.map(referenceRow),o.extinctions.map(referenceRow)] as const);
  const triadRows=packed.data.triads.map(g=>[g.groupPath,internDecision(g.formation),internDecision(g.efficacy)] as const);
  const selectedEffectIndex=internDecision(packed.data.selectedEffect);
  const ruleIDs:string[]=[],pathRoots:string[]=[],pathSuffixes:string[]=[];
  const intern=(items:string[],value:string)=>{if(!items.includes(value))items.push(value);return items.indexOf(value);};
  const evidenceRows=packed.evidence.map(([id,paths])=>[intern(ruleIDs,id),paths] as const);
  const pathRows=packed.factPaths.map(path=>{
    const root=path.match(/^\/(?:lines\/\d+(?:\/(?:changed|hidden))?|tombExtinction\/objects\/\d+|triads\/groups\/\d+|[^/]+)/)![0];
    return [intern(pathRoots,root),intern(pathSuffixes,path.slice(root.length))] as const;
  });
  return {...packed.data,objects:objectRows,triads:triadRows,selectedEffect:selectedEffectIndex,
    evidenceLayout:'indexed-object-decision-evidence-tuples-v2' as const,indexBase:0 as const,
    objectColumns:['objectPath','calendarStrength','vitality','activity','availability','tombs','extinctions'] as const,
    calendarStrengthColumns:['statusIndex','supportPaths','restraintPaths'] as const,
    referenceColumns:['scope','sourcePath','decisionIndex'] as const,triadColumns:['groupPath','formation','efficacy'] as const,
    decisionColumns:['statusIndex','conditions','blockers'] as const,decisions,states,ruleIDs,
    evidenceColumns:['ruleIndex','factPathIndices'] as const,evidence:evidenceRows,
    factPathColumns:['rootIndex','suffixIndex'] as const,factPaths:pathRows,pathRoots,pathSuffixes};
}

type Interned<T> = T extends Evidence ? number : T extends Array<infer Item> ? Interned<Item>[] :
  T extends object ? {[Key in keyof T]:Key extends 'factPaths'|'supportPaths'|'restraintPaths' ? number[] : Interned<T[Key]>} : T;
/** Both dictionaries are local and self-contained; order and empty arrays are preserved. */
function internEvidence<T>(report:T):{data:Interned<T>;evidence:[string,number[]][];factPaths:string[]} {
  const evidence:[string,number[]][]=[];
  const factPaths:string[]=[];
  const indices=new Map<string,number>();
  const pathIndices=new Map<string,number>();
  const internPath=(path:string)=>{
    if(!pathIndices.has(path)){pathIndices.set(path,factPaths.length);factPaths.push(path);}
    return pathIndices.get(path)!;
  };
  const visit=(value:unknown):unknown=>{
    if(Array.isArray(value))return value.map(visit);
    if(!value||typeof value!=='object')return value;
    const row=value as Record<string,unknown>;
    if(typeof row.id==='string'&&Array.isArray(row.factPaths)){
      const key=JSON.stringify(row);
      if(!indices.has(key)){
        indices.set(key,evidence.length);
        evidence.push([row.id,(row.factPaths as string[]).map(internPath)]);
      }
      return indices.get(key)!;
    }
    return Object.fromEntries(Object.entries(row).map(([key,v])=>[key,
      ['factPaths','supportPaths','restraintPaths'].includes(key)&&Array.isArray(v)?v.map(internPath):visit(v)]));
  };
  return {data:visit(report) as Interned<T>,evidence,factPaths};
}

/** Lossless view of the fixed row layout; evidence and path indices stay receipt-local. */
export function efficacyDecisionView(report:ReturnType<typeof efficacy>) {
  const d=(i:number)=>{const [status,conditions,blockers]=report.decisions[i];return {status:report.states[status],conditions,blockers};};
  const refs=(rows:readonly [string,string,number][])=>rows.map(([scope,sourcePath,i])=>({scope,sourcePath,...d(i)}));
  return {...report,objects:report.objects.map(([objectPath,[status,supportPaths,restraintPaths],v,a,b,tombs,extinctions])=>({
    objectPath,calendarStrength:{status:report.states[status],supportPaths,restraintPaths},vitality:d(v),activity:d(a),availability:d(b),tombs:refs(tombs),extinctions:refs(extinctions)})),
    triads:report.triads.map(([groupPath,f,e])=>({groupPath,formation:d(f),efficacy:d(e)})),selectedEffect:d(report.selectedEffect),
    evidence:report.evidence.map(([id,paths])=>[report.ruleIDs[id],paths] as const),factPaths:report.factPaths.map(([root,suffix])=>report.pathRoots[root]+report.pathSuffixes[suffix])};
}
