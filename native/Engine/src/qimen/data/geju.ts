/** Selected, explicit conditions for the existing rotating-plate school.
 * Classical pairings are tied to the consulted Yanbo Diaosou Ge transcription;
 * the full tomb table is separately attributed to the selected Qimen reference.
 * uncertain MVP approximations are not emitted as established named patterns.
 * See docs/mingli/validation/qimen-geju-audit.md for the full disposition table.
 */
import type { QimenChart, GeJu, Palace, TianGan, BamenName, JiuxingName } from '../types';
import { computeXunShou } from '../helpers/tianPan';

export interface GeJuRule {
  name: string;
  type: GeJu['type'];
  description: string;
  sourceQuote?: string;
  source?: GeJu['source'];
  /** null=no match; []=a time-level condition without an invented palace. */
  match: (chart: QimenChart) => number[] | null;
}

const OUTER = [1, 2, 3, 4, 6, 7, 8, 9];
const OPPOSITE: Record<number, number> = {1:9, 9:1, 2:8, 8:2, 3:7, 7:3, 4:6, 6:4};
const HOME_STAR: Record<number, JiuxingName> = {1:'天蓬', 2:'天芮', 3:'天冲', 4:'天辅', 6:'天心', 7:'天柱', 8:'天任', 9:'天英'};
const HOME_DOOR: Record<number, BamenName> = {1:'休门', 2:'死门', 3:'伤门', 4:'杜门', 6:'开门', 7:'惊门', 8:'生门', 9:'景门'};
const GOOD_DOORS: BamenName[] = ['开门', '休门', '生门'];
const STEMS = '甲乙丙丁戊己庚辛壬癸';
const BRANCHES = '子丑寅卯辰巳午未申酉戌亥';
const TOMB: Partial<Record<TianGan, number>> = {乙:6, 丙:6, 丁:8, 戊:6, 己:8, 庚:8, 辛:4, 壬:4, 癸:2};
const TOMB_SOURCE: NonNullable<GeJu['source']> = {
  title: 'qimen-go QMTomb（所选奇门墓库表）',
  url: 'https://github.com/deminzhang/qimen-go/blob/4d3f58fa0f401b5b3a337f119138e99e90685dda/xuan/qimen_defs.go#L221',
  quote: '"甲": "未", "乙": "戌", "丙": "戌", "丁": "丑", "戊": "戌",\n"己": "丑", "庚": "丑", "辛": "辰", "壬": "辰", "癸": "未"',
  editionStatus: 'selected-implementation-table-not-classical-edition',
};

function outer(chart: QimenChart): Palace[] { return chart.palaces.filter(p => p.id !== 5); }
function sky(p: Palace): TianGan[] {
  return [...new Set([p.tianPanGan, p.hostedTianPanGan].filter((value): value is TianGan => Boolean(value)))];
}
function earth(chart: QimenChart, p: Palace): TianGan[] {
  const center = p.id === 2 && chart.method.centerPolicy?.startsWith('fixed-kun-2')
    ? chart.palaces.find(item => item.id === 5)?.diPanGan : null;
  return [...new Set([p.diPanGan, center].filter((value): value is TianGan => Boolean(value)))];
}
function matching(chart: QimenChart, predicate: (p: Palace) => boolean): number[] | null {
  const ids = outer(chart).filter(predicate).map(p => p.id);
  return ids.length ? ids : null;
}
function pair(chart: QimenChart, above: TianGan, below: TianGan): number[] | null {
  return matching(chart, p => sky(p).includes(above) && earth(chart, p).includes(below));
}
function fieldPattern(chart: QimenChart, field: 'jiuxing' | 'bamen', homes: Record<number, string>, opposite: boolean): number[] | null {
  // A few matching stems or the static middle palace cannot establish a full-plate pattern.
  return OUTER.every(id => chart.palaces.find(p => p.id === id)?.[field] === homes[opposite ? OPPOSITE[id] : id]) ? OUTER : null;
}
function stemOf(ganzhi?: string): TianGan | undefined {
  if (!ganzhi || ganzhi.length !== 2) return undefined;
  const stem = STEMS.indexOf(ganzhi[0]), branch = BRANCHES.indexOf(ganzhi[1]);
  return stem >= 0 && branch >= 0 && stem % 2 === branch % 2 ? ganzhi[0] as TianGan : undefined;
}
function carrier(ganzhi?: string): TianGan | undefined {
  const stem = stemOf(ganzhi);
  return stem === '甲' ? computeXunShou(stem, ganzhi![1] as Parameters<typeof computeXunShou>[1]) : stem;
}
function pairRule(name: string, above: TianGan, below: TianGan, type: GeJu['type'], quote: string): GeJuRule {
  return {name, type, description:`天盘${above}加地盘${below}；仅为传统叠盘条件，不据此推定现实事件`, sourceQuote:quote, match: chart => pair(chart, above, below)};
}

const BASE: GeJuRule[] = [
  {name:'伏吟', type:'中性', description:'九星在八个外宫均回到本宫（星伏吟）；八门另列，不由少数干同宫推定', sourceQuote:'就中伏吟最為凶，天蓬加著地天蓬。', match:chart=>fieldPattern(chart,'jiuxing',HOME_STAR,false)},
  {name:'反吟', type:'中性', description:'九星在八个外宫均临本宫的对宫（星反吟）；不是天干相冲的数量阈值', sourceQuote:'天蓬若到天英上，須知即是返吟宮。', match:chart=>fieldPattern(chart,'jiuxing',HOME_STAR,true)},
  {name:'八门伏吟', type:'中性', description:'八门均回到本门原宫；与九星伏吟分别核对', sourceQuote:'八門返伏皆如此，生在生兮死在死。', match:chart=>fieldPattern(chart,'bamen',HOME_DOOR,false)},
  {name:'八门反吟', type:'中性', description:'八门均临本门原宫的对宫；与九星反吟分别核对', sourceQuote:'八門返伏皆如此，生在生兮死在死。', match:chart=>fieldPattern(chart,'bamen',HOME_DOOR,true)},
  {name:'值符临三吉门', type:'中性', description:'八神值符与开、休、生之一同宫；仅列同宫事实', match:chart=>matching(chart,p=>p.bashen==='值符'&&p.bamen!==null&&GOOD_DOORS.includes(p.bamen))},
  {name:'值使为三吉门', type:'中性', description:'实际值使门为开、休、生之一；只标实际值使宫，不把所有吉门都称为值使', match:chart=>matching(chart,p=>p.id===chart.zhiShiPalaceId&&p.bamen===chart.zhiShiMen&&p.bamen!==null&&GOOD_DOORS.includes(p.bamen))},
  {name:'入墓', type:'中性', description:'按本版奇门墓库表核对天盘及其寄干：乙丙戊在乾六、丁己庚在艮八、辛壬在巽四、癸在坤二；不以地盘占位代替天盘临宫', source:TOMB_SOURCE, match:chart=>matching(chart,p=>sky(p).some(gan=>TOMB[gan]===p.id))},
  pairRule('大格','庚','癸','凶','庚加癸兮為大格，加己為刑最不宜。'),
  pairRule('上格','庚','壬','凶','加壬之時為上格，又嫌歲月日時逢。'),
  pairRule('刑格','庚','己','凶','庚加癸兮為大格，加己為刑最不宜。'),
  pairRule('白虎猖狂','辛','乙','凶','六乙加辛龍逃走，六辛加乙虎猖狂。'),
];

const QI_TARGET = {乙:3, 丙:9, 丁:7} as const;
const QI_POSITION = {乙:'震三', 丙:'离九', 丁:'兑七'} as const;
const QI_DE_SHI = {乙:['己','辛'], 丙:['戊','庚'], 丁:['壬','癸']} as const;
const THREE_QI: GeJuRule[] = (['乙','丙','丁'] as const).flatMap(qi=>[
  {name:`${qi}奇临${QI_POSITION[qi]}`, type:'中性' as const, description:`天盘${qi}临${QI_TARGET[qi]}宫；此项只报告位置，不把未校勘的升殿解释当作事件依据`, match:(chart:QimenChart)=>matching(chart,p=>p.id===QI_TARGET[qi]&&sky(p).includes(qi))},
  {name:`${qi}奇得使`, type:'吉' as const, description:`天盘${qi}加地盘${QI_DE_SHI[qi].join('或')}，为指定六甲配对；并非任一三奇加戊都得使`, sourceQuote:'乙逢犬馬丙鼠猴，六丁玉女騎龍虎。', match:(chart:QimenChart)=>matching(chart,p=>sky(p).includes(qi)&&earth(chart,p).some(gan=>(QI_DE_SHI[qi] as readonly TianGan[]).includes(gan)))},
  {name:`${qi}奇遇吉门`, type:'吉' as const, description:`天盘${qi}与开、休、生之一同宫；只成立此局部配合，不代表现实结果有利`, sourceQuote:'吉門偶合爾三奇……更合從旁加檢點，餘宮不可有微疵。', match:(chart:QimenChart)=>matching(chart,p=>sky(p).includes(qi)&&p.bamen!==null&&GOOD_DOORS.includes(p.bamen))},
  {name:`${qi}奇入墓`, type:'中性' as const, description:`天盘${qi}临${TOMB[qi]}宫；采用本版奇门墓库口径`, sourceQuote:'丙奇屬火火墓戌……更兼乙奇來臨六，丁奇臨八亦同時。', match:(chart:QimenChart)=>matching(chart,p=>p.id===TOMB[qi]&&sky(p).includes(qi))},
  {name:`${qi}与庚叠盘`, type:'中性' as const, description:`${qi}与庚分居同宫天地盘；只报告叠盘，不统一称庚克三奇（丙丁为火，不是庚金所克）`, match:(chart:QimenChart)=>matching(chart,p=>(sky(p).includes(qi)&&earth(chart,p).includes('庚'))||(sky(p).includes('庚')&&earth(chart,p).includes(qi)))},
]);

const PUNISHMENT: GeJuRule[] = ([['戊',3,'甲子'],['己',2,'甲戌'],['庚',8,'甲申'],['辛',9,'甲午'],['壬',4,'甲辰'],['癸',4,'甲寅']] as const).map(([gan,id,hidden])=>({
  name:`${gan}击刑`, type:'凶', description:`天盘${gan}（${hidden}所遁，含寄干）临${id}宫的传统地支刑关系；地盘${gan}本身不触发`,
  sourceQuote:'六儀擊刑何太凶，甲子值符愁向東。戌刑未上申刑虎，寅巳辰辰午刑午。',
  match:chart=>matching(chart,p=>p.id===id&&sky(p).includes(gan)),
}));

const NAMED: GeJuRule[] = [
  pairRule('飞鸟跌穴','丙','戊','吉','丙加甲兮鳥跌穴，甲加丙兮龍返首。'),
  pairRule('青龙返首','戊','丙','吉','丙加甲兮鳥跌穴，甲加丙兮龍返首。'),
  {name:'值使临地盘丁', type:'中性', description:'实际值使门落地盘丁所在宫；只列条件，不把生门或任意天盘丁都当作玉女守门', match:chart=>matching(chart,p=>p.id===chart.zhiShiPalaceId&&p.bamen===chart.zhiShiMen&&p.bamen!==null&&earth(chart,p).includes('丁'))},
  {name:'天遁', type:'吉', description:'天盘丙加地盘丁并临生门；九天不替代地盘丁条件', sourceQuote:'生門六丙合六丁，此為天遁自分明。', match:chart=>matching(chart,p=>sky(p).includes('丙')&&earth(chart,p).includes('丁')&&p.bamen==='生门')},
  {name:'地遁', type:'吉', description:'天盘乙加地盘己并临开门；九地不替代地盘己条件', sourceQuote:'開門六乙合六己，地遁如斯而已矣。', match:chart=>matching(chart,p=>sky(p).includes('乙')&&earth(chart,p).includes('己')&&p.bamen==='开门')},
  {name:'人遁', type:'吉', description:'天盘丁、休门、太阴同宫；不以地盘丁替代天盘丁', sourceQuote:'休門六丁共太陰，欲求人遁無過此。', match:chart=>matching(chart,p=>sky(p).includes('丁')&&p.bamen==='休门'&&p.bashen==='太阴')},
  {name:'五不遇时', type:'凶', description:'时干克日干且阴阳相同；依据本盘实际日时干，不以值符宫庚代替', sourceQuote:'時干來剋日干上，甲日須知時忌庚。', match:chart=>{
    const day=stemOf(chart.dayGanZhi), hour=stemOf(chart.hourGanZhi);
    if(!day||!hour)return null;
    const d=STEMS.indexOf(day), h=STEMS.indexOf(hour);
    return d%2===h%2&&(Math.floor(h/2)+2)%5===Math.floor(d/2)?[]:null;
  }},
  pairRule('太白入荧','庚','丙','凶','六庚加丙白入熒，六丙加庚熒入白。'),
  pairRule('荧入太白','丙','庚','凶','六庚加丙白入熒，六丙加庚熒入白。'),
  pairRule('朱雀投江','丁','癸','凶','六癸加丁蛇夭矯，六丁加癸雀投江。'),
  pairRule('青龙逃走','乙','辛','凶','六乙加辛龍逃走，六辛加乙虎猖狂。'),
  {name:'伏干格', type:'凶', description:'天盘庚加地盘日干；甲日按本日旬首所遁六仪定位，不把任一三奇当日干', sourceQuote:'庚加日干為伏干，日干加庚飛干格。', match:chart=>{const day=carrier(chart.dayGanZhi);return day?pair(chart,'庚',day):null;}},
  {name:'飞干格', type:'凶', description:'天盘日干加地盘庚；甲日按本日旬首所遁六仪定位', sourceQuote:'庚加日干為伏干，日干加庚飛干格。', match:chart=>{const day=carrier(chart.dayGanZhi);return day?pair(chart,day,'庚'):null;}},
  {name:'庚加时干', type:'中性', description:'天盘庚加地盘实际时干；只列本时关系，不冒称已经检查岁月日时全部条件', match:chart=>{const hour=carrier(chart.hourGanZhi);return hour?pair(chart,'庚',hour):null;}},
];

export const ALL_GE_JU: GeJuRule[] = [...BASE, ...THREE_QI, ...PUNISHMENT, ...NAMED];

export function detectGeJu(chart: QimenChart): GeJu[] {
  return ALL_GE_JU.flatMap(rule=>{
    const palaceIds=rule.match(chart);
    if(palaceIds===null)return [];
    const source=rule.source??(rule.sourceQuote?{
      title:'烟波钓叟歌（在线转录）',url:'https://zh.wikisource.org/wiki/煙波釣叟歌',
      quote:rule.sourceQuote,editionStatus:'transcription-not-checked-against-print',
    }:undefined);
    return [{name:rule.name, type:rule.type, description:rule.description,
      ...(palaceIds.length?{palaceIds:[...new Set(palaceIds)]}:{}),
      assessmentStatus:source?'traditional-condition-only' as const:'structural-fact-only' as const,
      ...(source?{source}:{}),
    }];
  });
}
