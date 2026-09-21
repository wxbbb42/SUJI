import type { DiZhi, TianGan, WuXing } from './types';
import { getCurrentSiLing } from './SiLing';
import { ZHUAN_WANG_SOURCES } from './zhuanWangSources';
import { validateBirthMonthContext, type BirthMonthContext } from './birthMonthContext';

const ELEMENT: Record<TianGan,WuXing> = {甲:'木',乙:'木',丙:'火',丁:'火',戊:'土',己:'土',庚:'金',辛:'金',壬:'水',癸:'水'};
const GENERATES: Record<WuXing,WuXing> = {木:'火',火:'土',土:'金',金:'水',水:'木'};
const CONTROLLER: Record<WuXing,WuXing> = {木:'金',火:'水',土:'木',金:'火',水:'土'};
/** Same conventional branch identities as structural roots; no numeric weights. */
const HIDDEN: Record<DiZhi,TianGan[]> = {
  子:['癸'],丑:['己','癸','辛'],寅:['甲','丙','戊'],卯:['乙'],辰:['戊','乙','癸'],巳:['丙','戊','庚'],
  午:['丁','己'],未:['己','丁','乙'],申:['庚','壬','戊'],酉:['辛'],戌:['戊','辛','丁'],亥:['壬','甲'],
};
const NAMES: Record<WuXing,string> = {木:'曲直格',火:'炎上格',土:'稼穑格',金:'从革格',水:'润下格'};
const FORMATIONS: Record<WuXing,{kind:'direction'|'triad'|'four-stores';branches:DiZhi[]}[]> = {
  木:[{kind:'direction',branches:['寅','卯','辰']},{kind:'triad',branches:['亥','卯','未']}],
  火:[{kind:'direction',branches:['巳','午','未']},{kind:'triad',branches:['寅','午','戌']}],
  土:[{kind:'four-stores',branches:['辰','戌','丑','未']}],
  金:[{kind:'direction',branches:['申','酉','戌']},{kind:'triad',branches:['巳','酉','丑']}],
  水:[{kind:'direction',branches:['亥','子','丑']},{kind:'triad',branches:['申','子','辰']}],
};
const SEASONS: Record<WuXing,DiZhi[]> = {
  木:['寅','卯','辰'],火:['巳','午','未'],土:['辰','戌','丑','未'],金:['申','酉','戌'],水:['亥','子','丑'],
};
const EARTH_MONTHS: DiZhi[] = ['辰','戌','丑','未'];
export interface ZhuanWangOptions { daysAfterJie?: number; birthMonthContext?: BirthMonthContext }

/**
 * Recognizes a named full-formation subset of Ren's 独象 rules.
 * The earth transition uses the explicitly selected Xu commander table;
 * it is not an assertion that the two authors supplied one universal method.
 */
export function adjudicateZhuanWang(
  stems:[TianGan,TianGan,TianGan,TianGan],
  branches:[DiZhi,DiZhi,DiZhi,DiZhi],
  options:ZhuanWangOptions = {},
) {
  if (stems.length !== 4 || branches.length !== 4 || stems.some(g=>!Object.prototype.hasOwnProperty.call(ELEMENT,g)) || branches.some(z=>!Object.prototype.hasOwnProperty.call(HIDDEN,z))) {
    throw new RangeError('Four valid stems and branches are required');
  }
  const element = ELEMENT[stems[2]], controller = CONTROLLER[element], monthBranch = branches[1];
  const birthMonthContext = options.birthMonthContext ? validateBirthMonthContext(options.birthMonthContext,monthBranch) : null;
  if (birthMonthContext && options.daysAfterJie !== undefined && options.daysAfterJie !== birthMonthContext.daysAfterJie) {
    throw new RangeError('Explicit elapsed days disagree with the source-bound birth month');
  }
  const elapsed = birthMonthContext?.daysAfterJie ?? options.daysAfterJie;
  const commander = elapsed === undefined ? null : getCurrentSiLing(monthBranch,elapsed);
  const formations = FORMATIONS[element].filter(f=>f.branches.every(z=>branches.includes(z))).map(f=>({
    kind:f.kind, branches:[...f.branches], positions:branches.flatMap((z,position)=>f.branches.includes(z)?[position]:[]),
  }));
  const participating = new Set(formations.flatMap(f=>f.positions));
  const exposedControllers = stems.flatMap((gan,position)=>ELEMENT[gan]===controller?[{position,gan,element:controller}]:[]);
  const externalControllerBranches = branches.flatMap((branch,position)=>!participating.has(position)&&ELEMENT[HIDDEN[branch][0]]===controller?[{position,branch,element:controller}]:[]);
  const hiddenControllerContext = branches.flatMap((branch,position)=>HIDDEN[branch].filter(gan=>ELEMENT[gan]===controller).map(gan=>({
    position,branch,gan,inFormation:participating.has(position),exposed:stems.includes(gan),
    handling:participating.has(position)?'retained-within-formation' as const:'outside-formation-needs-adjudication' as const,
  })));
  const outputStems = stems.flatMap((gan,position)=>ELEMENT[gan]===GENERATES[element]?[{position,gan}]:[]);
  const seasonalMonth = SEASONS[element].includes(monthBranch);
  // Earth does not own the entire four transition months. Other elements in
  // those months likewise need the selected commander before claiming 得时.
  const needsCommander = EARTH_MONTHS.includes(monthBranch);
  const seasonStatus = !seasonalMonth ? 'out-of-season' as const
    : needsCommander && !commander ? 'needs-month-commander' as const
    : needsCommander && commander?.element !== element ? 'out-of-season' as const
    : 'in-season' as const;
  const unmetConditions:string[] = [];
  if (!formations.length) unmetConditions.push('full-formation-missing');
  if (exposedControllers.length) unmetConditions.push('exposed-controller');
  if (externalControllerBranches.length) unmetConditions.push('external-controller-branch');
  if (hiddenControllerContext.some(v=>!v.inFormation)) unmetConditions.push('external-hidden-controller-unadjudicated');
  if (seasonStatus==='out-of-season') unmetConditions.push('not-in-selected-season');
  const status = unmetConditions.length ? 'not-established-in-selected-profile' as const
    : seasonStatus==='needs-month-commander' ? 'needs-month-commander' as const
    : 'established' as const;
  // Explicitly limited Xu alternative preserves the earlier pure peer/resource
  // candidate without reintroducing a score or making a full school verdict.
  const sameOrResource = (wx:WuXing)=>wx===element||GENERATES[wx]===element;
  const purePeerResource = formations.length===0 && seasonalMonth && stems.every(g=>sameOrResource(ELEMENT[g])) && branches.every(z=>sameOrResource(ELEMENT[HIDDEN[z][0]]));
  return {
    methodVersion:'zhuanwang-adjudication-v1' as const,
    profileId:'ditianshui-ren-full-formation-v1' as const,
    status,name:NAMES[element],dayElement:element,
    outcomeEstablished:false as const,
    formation:formations,
    season:{status:seasonStatus,monthBranch,method:'season-with-xu-commander-for-earth-transition-months' as const,commander,birthMonthContext},
    exposedControllers,externalControllerBranches,hiddenControllerContext,outputStems,
    unmetConditions,
    alternativeProfile:{id:'ziping-xu-pure-peer-resource' as const,status:purePeerResource?'candidate' as const:'not-evaluated' as const},
    sources:ZHUAN_WANG_SOURCES,
    limitations:[
      '成立仅指所选专旺形态、季节及无显见克神的规则子集，不裁定全局成败、高低或现实事件',
      '徐注另许方局不全而气势专一；本选法未成立不等于所有流派均否定专旺',
      '食伤作为泄秀条件保留，印不是专旺成立的强制门槛；方局参与支的藏干不逐个视为透干破神',
      '外围藏干克神及透出克神的合去、制化救应未在本子集求解',
      '土月得时使用明确选定的徐注司令表；未提供节后日数则不推定土已司令',
      '此字段不将既有chengBai/jibie候选升级为最终裁定',
    ],
  };
}
export type ZhuanWangAdjudication = ReturnType<typeof adjudicateZhuanWang>;
