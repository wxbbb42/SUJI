import { EquatorFromVector,MakeTime,RotateVector,Rotation_ECT_EQD,Vector } from 'astronomy-engine';
import { beijingDateParts,assertCalendarRange } from '../calendar/precision';
import { assignMansion } from './mansions';
import type { MansionBoundary } from './natal';
import { wrap } from './residuals';

const BRANCHES=[...'子丑寅卯辰巳午未申酉戌亥'];
export const ZODIAC_BRANCHES=[...'戌酉申未午巳辰卯寅丑子亥'];
export const HOUSE_NAMES=['命宫','财帛','兄弟','田宅','男女','奴仆','夫妻','疾厄','迁移','官禄','福德','相貌'];
const PALACE_RULERS:Record<string,string>={子:'Saturn',丑:'Saturn',寅:'Jupiter',亥:'Jupiter',卯:'Mars',戌:'Mars',辰:'Venus',酉:'Venus',巳:'Mercury',申:'Mercury',午:'Sun',未:'Moon'};
const DEGREE_RULERS:Record<string,string>={角:'Jupiter',斗:'Jupiter',奎:'Jupiter',井:'Jupiter',亢:'Venus',牛:'Venus',娄:'Venus',鬼:'Venus',氐:'Saturn',女:'Saturn',胃:'Saturn',柳:'Saturn',房:'Sun',虚:'Sun',昴:'Sun',星:'Sun',心:'Moon',危:'Moon',毕:'Moon',张:'Moon',尾:'Mars',室:'Mars',觜:'Mars',翼:'Mars',箕:'Mercury',壁:'Mercury',参:'Mercury',轸:'Mercury'};
export const LIFE_SOURCES=['tushu567-mao-life-degree-rev1942530','suji-mao-modern-coordinate-policy-v1'];

/** Classical branch counting with an explicit modern tropical degree policy. Not an ascendant. */
export function maoLifeGeometry(sunLongitudeDegrees:number,hour:number,minute:number) {
  if(!Number.isFinite(sunLongitudeDegrees)||sunLongitudeDegrees<0||sunLongitudeDegrees>=360||!Number.isInteger(hour)||hour<0||hour>23||!Number.isInteger(minute)||minute<0||minute>59)throw new Error('安命输入无效');
  const hourIndex=Math.floor((hour+1)/2)%12,sunIndex=Math.floor(sunLongitudeDegrees/30);
  const lifeIndex=(sunIndex+hourIndex-3+12)%12;
  const longitudeDegrees=lifeIndex*30+sunLongitudeDegrees%30;
  const palaceBranch=ZODIAC_BRANCHES[lifeIndex];
  return {sunLongitudeDegrees,birthHourBranch:BRANCHES[hourIndex],sunPalaceBranch:ZODIAC_BRANCHES[sunIndex],
    palaceBranch,palaceRuler:PALACE_RULERS[palaceBranch],palaceDegree:sunLongitudeDegrees%30,longitudeDegrees,
    hoursUntilBranchChange:(120-((hour*60+minute+60)%120))/60,
    houses:HOUSE_NAMES.map((name,i)=>{const index=(lifeIndex+i)%12,branch=ZODIAC_BRANCHES[index];
      return {name,branch,ruler:PALACE_RULERS[branch],startLongitudeDegrees:index*30,endLongitudeDegrees:wrap((index+1)*30)};})};
}

export function createLifeDegreeModule(instant:Date,inputFingerprint:string,sunLongitudeDegrees:number,boundaries:MansionBoundary[]) {
  assertCalendarRange(instant);
  const p=beijingDateParts(instant),geometry=maoLifeGeometry(sunLongitudeDegrees,p.hour,p.minute),time=MakeTime(instant),r=geometry.longitudeDegrees*Math.PI/180;
  const equator=EquatorFromVector(RotateVector(Rotation_ECT_EQD(time),new Vector(Math.cos(r),Math.sin(r),0,time)));
  const mansion=assignMansion('LifeDegree',equator.ra*15,boundaries);
  return {moduleID:'life-degree',methodVersion:'mao-hour-tropical-solar-degree-v1',inputFingerprint,
    sourceIDs:[...LIFE_SOURCES],clockPolicy:'fixed-utc-plus-8-hour-branch-v1',
    coordinatePolicy:'tropical-30-degree-palaces-true-ecliptic-date-v1',mansionPolicy:'modern-equatorial-reference-not-historical-degree',
    ...geometry,rightAscensionDegrees:equator.ra*15,declinationDegrees:equator.dec,mansion,degreeRuler:DEGREE_RULERS[mansion.mansion],
    limitations:['采用生时加太阳宫、顺数遇卯的时支法；固定UTC+8钟面，不是地平升点、地方日出或真太阳时法。',
      '太阳宫与宫内度采用现代热带黄道十二等宫；命度参考宿按现代距星赤经归属，不复原古宿度表或古度单位。',
      '命度宫内黄经与入宿赤经角度分别记录，不能直接当成同一度数。出生时刻精度未知，时支交界与宿界保留不确定性。',
      '十二宫、宫主和度主是所选排布规则，尚不据此推断吉凶或流限。']};
}
export type LifeDegreeModule=ReturnType<typeof createLifeDegreeModule>;
