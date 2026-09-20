import type { Palace, HourVoid, HourHorse, DoorRelation, StarSeason, WuXing, JiuxingName } from './types';
import type { RuleSource } from '../rules/provenance';
import { BAMEN } from './data/bamen';
import { JIUXING } from './data/jiuxing';

const BRANCHES=[...'子丑寅卯辰巳午未申酉戌亥'];
const STEMS=[...'甲乙丙丁戊己庚辛壬癸'];
const BRANCH_ELEMENTS:WuXing[]=['水','土','木','木','土','火','火','土','金','金','土','水'];
const BRANCH_PALACES=[1,8,8,3,4,4,9,2,2,7,6,6];
const SHENG:Record<WuXing,WuXing>={木:'火',火:'土',土:'金',金:'水',水:'木'};
const KE:Record<WuXing,WuXing>={木:'土',土:'水',水:'火',火:'金',金:'木'};
const engineeringURL='https://github.com/deminzhang/qimen-go/blob/4d3f58fa0f401b5b3a337f119138e99e90685dda/xuan/';
const yanboURL='https://zh.wikisource.org/w/index.php?title=煙波釣叟歌&oldid=1336835';

export const QIMEN_FACT_SOURCES:RuleSource[]=[
  {id:'qimen-hour-void-horse-v1',version:'1',title:'时家旬空与时支驿马固定表',editionStatus:'pinned-engineering-reference',
    scope:'时干支定旬空，时支定马；保留具体空支及所属宫的支位覆盖',
    references:[{url:engineeringURL+'ganzhi.go',locator:'KongWang / ZhiGong9 / Horse',sha256:'0dd04c5c2f290e87822ff85770f203467c1a7a69ced56990d808c718aa14b401'},
      {url:engineeringURL+'qimen.go',locator:'时家盘时旬空、时支马选择'}],
    limitations:['这是明确的时家工程约定，不冒充古籍定本','partial/full只说明本宫一支或全部支位落空，不裁定宫中事物效力，不混入日马']},
  {id:'qimen-door-controls-palace-v1',version:'1',title:'烟波钓叟歌：门克宫为门迫',editionStatus:'electronic-transcription-not-print-collated',
    scope:'门五行克所落宫五行为门迫；宫克门另列，不称门迫',
    references:[{url:yanboURL,locator:'门迫句',quote:'宮制其門不迫門，門制其宮是迫雄。'}],
    limitations:['电子本记有「为迫」异文，本版选门克宫方向','命中五行结构不是现实结局']},
  {id:'qimen-star-month-v1',version:'1',title:'烟波钓叟歌：九星月令旺相休囚废',editionStatus:'electronic-transcription-not-print-collated',
    scope:'节月支五行；星同月相、星生月旺、月生星废、星克月休、月克星囚；中禽只在实际寄宫计一次',
    references:[{url:yanboURL,locator:'九星月令及天蓬例',quote:'我生之月誠為旺。廢於父母休於財，囚於鬼兮真不妄。假令水宿號天蓬，相在初冬與仲冬。旺於正二休四五。'}],
    limitations:['同行句正文作「我」，本版采所注「相」，并以随后的天蓬例互校','土月按辰戌丑未节月支，不另混入四季土王分日；不是宫干生克或综合吉凶']},
];

export function hourVoid(ganZhi:string):HourVoid {
  const stem=STEMS.indexOf(ganZhi[0]),branch=BRANCHES.indexOf(ganZhi[1]);
  const start=(branch-stem+12)%12;
  const branches=[BRANCHES[(start+10)%12],BRANCHES[(start+11)%12]];
  const ids=[...new Set(branches.map(b=>BRANCH_PALACES[BRANCHES.indexOf(b)]))].sort((a,b)=>a-b);
  return {scope:'hour',ganZhi,xun:'甲'+BRANCHES[start],branches,sourceId:'qimen-hour-void-horse-v1',
    palaces:ids.map(palaceId=>{
      const palaceBranches=BRANCHES.filter((_,i)=>BRANCH_PALACES[i]===palaceId);
      const empty=palaceBranches.filter(b=>branches.includes(b));
      return {palaceId,branches:empty,palaceBranches,coverage:empty.length===palaceBranches.length?'full':'partial'};
    })};
}

export function hourHorse(ganZhi:string):HourHorse {
  const branch=['寅','亥','申','巳'][BRANCHES.indexOf(ganZhi[1])%4];
  return {scope:'hour',ganZhi,branch,palaceId:BRANCH_PALACES[BRANCHES.indexOf(branch)],sourceId:'qimen-hour-void-horse-v1'};
}

function doorRelation(palace:Palace):DoorRelation|undefined {
  if(palace.id===5||!palace.bamen)return undefined;
  const doorElement=BAMEN[palace.bamen].wuXing,palaceElement=palace.wuXing;
  const relation=doorElement===palaceElement?'比和':KE[doorElement]===palaceElement?'门克宫':KE[palaceElement]===doorElement?'宫克门':SHENG[doorElement]===palaceElement?'门生宫':'宫生门';
  return {door:palace.bamen,doorElement,palaceElement,relation,isPressure:relation==='门克宫',sourceId:'qimen-door-controls-palace-v1',assessmentStatus:'structural-fact-only'};
}

function starSeason(star:JiuxingName,monthGanZhi:string):StarSeason {
  const element=JIUXING[star].wuXing,monthBranch=monthGanZhi[1],monthElement=BRANCH_ELEMENTS[BRANCHES.indexOf(monthBranch)];
  const state=element===monthElement?'相':SHENG[element]===monthElement?'旺':SHENG[monthElement]===element?'废':KE[element]===monthElement?'休':'囚';
  return {scope:'solar-term-month',star,element,monthGanZhi,monthBranch,monthElement,state,sourceId:'qimen-star-month-v1',assessmentStatus:'season-relation-only'};
}

export function qimenFacts(hourGanZhi:string,monthGanZhi:string,palaces:Palace[]):{hourVoid:HourVoid;horse:HourHorse;palaces:Palace[];ruleSources:RuleSource[]} {
  return {hourVoid:hourVoid(hourGanZhi),horse:hourHorse(hourGanZhi),ruleSources:QIMEN_FACT_SOURCES,
    palaces:palaces.map(p=>({...p,
      ...(p.id!==5&&p.bamen?{doorRelation:doorRelation(p)}:{}),
      ...(p.id!==5&&p.jiuxing?{starSeason:starSeason(p.jiuxing,monthGanZhi)}:{}),
      ...(p.id!==5&&p.hostsTianQin?{hostedStarSeason:starSeason('天禽',monthGanZhi)}:{}),
    }))};
}
