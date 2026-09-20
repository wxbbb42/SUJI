import type { HexagramLine, RelatedLine } from './types';
import type { tombExtinction } from './tombExtinction';
import type { RuleSource } from '../rules/provenance';

export const TRIAD_SOURCE:RuleSource = {
  id:'liuyao-triad-selected-v1',version:'1',title:'六爻三合：限定范围成员与条件参照',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'四组三支表的原爻可见结构、单一实际动爻与日月、内初三及外四六实际动变范围；完整成员与中字在场分列，不裁定成局效力',
  references:[
    {url:'https://zh.wikisource.org/wiki/增刪卜易/19',locator:'三合四表、内初三与外四六动变、离之坤；空破入墓条件及动爻数量冲突',sha256:'087c35339f209c6d1359c01d8a918a535eb6151729973fc09ef960c1195f3fdf',quote:'申子辰合成水局、巳酉丑合成金局、寅午戌合成火局、亥卯未合成木局。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易',locator:'正文复之谦、革之家人、颐之无妄的动变及日月世例；虚一和当前与后来逢冲分辨',sha256:'897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07'},
    {url:'https://zh.wikisource.org/wiki/易林補遺/1',locator:'三合中字为主、前字生后字墓；有中字的两支成局说与完整成员标准不同',sha256:'abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967',quote:'三合之局取中字爲主，前一字生而主發，後一字墓而主藏'},
  ],
  limitations:[
    '电子转录未校印本；/19一爻动、两爻动与三爻若有两爻动不成局并存，不选定或修补统一动爻数量门槛，暗动仍未决',
    '可见原爻范围包括全静卦，仅为支表观察，不断古法成局；不借伏神、静位变卦投影或跨内外任意变爻补成员',
    '日月世古例支持单动爻与日月范围；非世实际动爻为明示结构推广，不是古法效力裁决；各动爻分开，不合池',
    '内初三、外四六均须两端实际动；同支保留每个对象身份但不能补缺支，完整成员不等于易林有中字的两支成局，不采半吉或自动吉凶',
    '生中字墓为三合表角色；墓参照不是已经入墓。各成员空破、日月生克冲合和回头克等条件照原对象保留，不相抵消',
    '空破填实、墓与冲的效力、合绊或合化、用神、综合强弱及事件结果未决；不推出应期日期、功效或普遍合化',
  ],
};

type Scope='visible-originals'|'calendar-moving-anchor'|'inner-change'|'outer-change';
type Element='水'|'金'|'火'|'木';
interface Member { branch:string; role:'birth'|'center'|'tomb'; objectPaths:string[] }
interface Group {
  scope:Scope; anchorPath:string|null; element:Element; members:Member[];
  missingBranches:string[]; complete:boolean; centerPresent:boolean;
  contextPaths:string[]; tombReferencePaths:string[]; dayClashRulePaths:string[];
}
interface Actor {path:string; branch:string; object?:HexagramLine|RelatedLine; original?:HexagramLine}
const TABLES:ReadonlyArray<readonly [Element,string,string,string]>=[
  ['水','申','子','辰'],['金','巳','酉','丑'],['火','寅','午','戌'],['木','亥','卯','未'],
];
const ROLES=['birth','center','tomb'] as const;
const unique=(paths:string[])=>[...new Set(paths)];

/** Reference existing object identities and conditions, without recalculating any of them. */
export function triads(lines:HexagramLine[],calendar:{month:string;day:string},tombs:ReturnType<typeof tombExtinction>) {
  const groups:Group[]=[];
  const originals:Actor[]=lines.map((line,index)=>({path:`/lines/${index}`,branch:line.ganZhi.slice(-1),object:line,original:line}));
  const tombPaths=new Map(tombs.objects.map((object,index)=>[object.objectPath,`/tombExtinction/objects/${index}`]));
  const emit=(scope:Scope,pool:Actor[],anchorPath:string|null=null)=>{
    for(const [element,...branches] of TABLES) {
      if(anchorPath&&!branches.includes(pool[0].branch))continue;
      const members:Member[]=branches.map((branch,index)=>({branch,role:ROLES[index],objectPaths:pool.filter(a=>a.branch===branch).map(a=>a.path)}));
      const missingBranches=members.filter(m=>!m.objectPaths.length).map(m=>m.branch);
      if(missingBranches.length>1)continue;
      const objects=members.flatMap(m=>m.objectPaths).map(path=>pool.find(a=>a.path===path)!);
      groups.push({scope,anchorPath,element,members,missingBranches,complete:missingBranches.length===0,centerPresent:members[1].objectPaths.length>0,
        contextPaths:unique(objects.filter(a=>a.object?.context).map(a=>a.path+'/context')),
        tombReferencePaths:unique(objects.flatMap(a=>tombPaths.has(a.path)?[tombPaths.get(a.path)!]:[])),
        dayClashRulePaths:unique(objects.filter(a=>a.original?.rules?.dayClash).map(a=>a.path+'/rules/dayClash')),
      });
    }
  };
  emit('visible-originals',originals);
  for(const actor of originals)if(actor.original!.isChanging) {
    emit('calendar-moving-anchor',[actor,
      {path:'/castGanZhi/month',branch:calendar.month.slice(-1)},
      {path:'/castGanZhi/day',branch:calendar.day.slice(-1)},
    ],actor.path);
  }
  for(const [scope,start,end] of [['inner-change',0,2],['outer-change',3,5]] as const) {
    if(!lines[start].isChanging||!lines[end].isChanging||!lines[start].changed||!lines[end].changed)continue;
    const pool=[start,end].flatMap(index=>{
      const changed=lines[index].changed!;
      return [originals[index],{path:`/lines/${index}/changed`,branch:changed.ganZhi.slice(-1),object:changed}];
    });
    emit(scope,pool);
  }
  return {sourceId:TRIAD_SOURCE.id,assessmentStatus:'structural-only' as const,efficacyEstablished:false as const,groups,
    unresolved:['motion-threshold','dark-movement','member-strength','void-break-effectiveness','tomb-effectiveness','clash-effectiveness','binding-or-transformation','selected-object','event-outcome']};
}
