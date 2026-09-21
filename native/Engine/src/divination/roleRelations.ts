import type { HexagramLine, WuXing } from './types';
import type { selectQuestionObjects } from './questionJudgment';
import type { RuleSource } from '../rules/provenance';

export const ROLE_RELATION_SOURCE:RuleSource = {
  id:'liuyao-candidate-roles-v1',version:'1',title:'增删卜易：候选对象的元忌仇结构',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'对本爻或伏神候选，按六个实际原爻列生用、克用、克元生忌的角色；明动组合只列结构',
  references:[
    {url:'https://zh.wikisource.org/wiki/增刪卜易/9',locator:'用神元神忌神仇神章第九；onlyinclude正文，不取后附编者按',sha256:'e84db11ae9a316ba00cb301e4e25c71496b32d9fcc495f16e09a575eb2159412',quote:'元神，生用神之神卽爲元神。忌神克用神之爻也。仇神者克元神而生忌神也。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/10',locator:'元神忌神衰旺章第十；大过之鼎反例',sha256:'3afc338a9c87a3df29583d36cf608abe381d44a5736e33641ca6d95c1cf387b9',quote:'以上論元神、忌神之有力、無力者，亦要用神有气'},
  ],
  limitations:[
    '角色相对于未定用的具体候选；静爻也有结构身份，不等于已经施力',
    '只检索六个实际原爻；变爻、伏神、日月不作为跨位自由作用者；日月候选不套原爻规则',
    '同五行候选仅共享角色位置，空破、飞伏与日月支持仍读各自context；同位动化合不自动裁定合住',
    '元忌或忌仇同明动只给可能作用链，不能消除目标月破日克或确定吉凶；未实现全文综合效力规则',
  ],
};
const GENERATES:Record<WuXing,WuXing>={木:'火',火:'土',土:'金',金:'水',水:'木'};
const CONTROLS:Record<WuXing,WuXing>={木:'土',土:'水',水:'火',火:'金',金:'木'};
const ELEMENTS=Object.keys(GENERATES) as WuXing[];
interface CandidateRef { id:string;objectPath:string;contextPath:string }
interface Group {
  targetElement:WuXing;candidateRefs:CandidateRef[];
  elements:{yuan:WuXing;ji:WuXing;chou:WuXing};
  yuanPositions:number[];jiPositions:number[];chouPositions:number[];
  jiYuanMovingPairs:{jiPosition:number;yuanPosition:number}[];
  chouJiMovingPairs:{chouPosition:number;jiPosition:number}[];
}

/** Names a relationship to each unselected candidate; never adjudicates efficacy. */
export function roleRelations(selection:ReturnType<typeof selectQuestionObjects>,lines:HexagramLine[]) {
  const groups:Group[]=[],unsupportedCandidates:{id:string;objectPath:string;reason:string}[]=[];
  for(const candidate of selection.candidates) {
    if(candidate.layer==='month'||candidate.layer==='day') {
      unsupportedCandidates.push({id:candidate.id,objectPath:candidate.objectPath,reason:'calendar-target-outside-line-role-scope'});
      continue;
    }
    const index=lines.findIndex(l=>l.position===candidate.position),line=lines[index];
    const object=candidate.layer==='original'?line:candidate.layer==='hidden'?line?.hidden:undefined;
    const path=`/lines/${index}`+(candidate.layer==='hidden'?'/hidden':'');
    if(!object||candidate.objectPath!==path||candidate.contextPath!==path+'/context')throw new Error('六爻候选与原盘对象不一致');
    let group=groups.find(g=>g.targetElement===object.wuXing);
    if(!group) {
      const yuan=ELEMENTS.find(e=>GENERATES[e]===object.wuXing)!;
      const ji=ELEMENTS.find(e=>CONTROLS[e]===object.wuXing)!;
      const chou=ELEMENTS.find(e=>CONTROLS[e]===yuan&&GENERATES[e]===ji)!;
      const actors=(element:WuXing)=>lines.filter(l=>l.wuXing===element);
      group={targetElement:object.wuXing,candidateRefs:[],elements:{yuan,ji,chou},
        yuanPositions:actors(yuan).map(l=>l.position),jiPositions:actors(ji).map(l=>l.position),chouPositions:actors(chou).map(l=>l.position),
        jiYuanMovingPairs:actors(ji).filter(l=>l.isChanging).flatMap(j=>actors(yuan).filter(l=>l.isChanging).map(y=>({jiPosition:j.position,yuanPosition:y.position}))),
        chouJiMovingPairs:actors(chou).filter(l=>l.isChanging).flatMap(c=>actors(ji).filter(l=>l.isChanging).map(j=>({chouPosition:c.position,jiPosition:j.position}))),
      };
      groups.push(group);
    }
    group.candidateRefs.push({id:candidate.id,objectPath:path,contextPath:path+'/context'});
  }
  return {assessmentStatus:'candidate-relative-structure',outcomeEstablished:false,sourceId:ROLE_RELATION_SOURCE.id,
    inspectedOriginalPaths:lines.map((_,i)=>`/lines/${i}`),groups,unsupportedCandidates,
    unresolved:['selected-object','actor-effectiveness','target-viability','binding','tomb-or-extinction','event-outcome',...(lines.some(l=>!l.isChanging&&l.context.day.clash)?['dark-movement']:[]),...(selection.candidates.some(c=>c.layer==='hidden')?['hidden-emergence']:[])],
  };
}
