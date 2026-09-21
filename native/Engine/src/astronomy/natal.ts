import { createMansionModule, validateMansionStructure } from './mansions';
import { Body, Ecliptic, EquatorFromVector, GeoVector, MakeTime, RotateVector, Rotation_EQJ_EQD } from 'astronomy-engine';
import { assertCalendarRange, beijingDateParts } from '../calendar/precision';
import { createResidualModule, type ResidualModule } from './residuals';
import { createLifeDegreeModule, type LifeDegreeModule } from './lifeDegree';

export const SEVEN_BODIES = ['Sun','Moon','Mercury','Venus','Mars','Jupiter','Saturn'] as const;
export type SevenBody = typeof SEVEN_BODIES[number];
export const SEVEN_BODY_DEPENDENCIES = {
  ephemeris:'astronomy-engine@2.1.19',timePolicy:'utc-as-ut1-espenak-meeus-v1',framePolicy:'true-ecliptic-equator-of-date-v1',
} as const;
export const ASTRONOMY_SOURCE_IDS = ['astronomy-engine-2.1.19','astronomy-time-policy-v1'];
export const ASTRONOMY_LIMITATIONS = [
  '出生钟面固定按UTC+8解释，不应用历史夏令时、经度或真太阳时偏移；UTC出现前的日期是前推公历钟面标签。',
  'UTC近似UT1，TT采用Espenak/Meeus ΔT模型；未来ΔT为预测，不能宣称物理时刻或所有日期的角秒级准确度。',
  '黄经黄纬为真黄道春分点当日坐标，赤经赤纬为真赤道春分点当日坐标，均为地心现代角度；不是古度或地面观测视差位置。',
  '日及五大行星使用GeoVector的光行时和光行差修正；月亮走GeoMoon分支，无另加光行时/光行差修正，不能统一称同一视位置修正。',
  '独立星历季度样本比较不能保证所有时刻或宿界精度；出生时间精度未知时不得断言归宿不会跨界。',
  '二十八宿采用现代星名首星参照，非古法唯一距星表；奎取ηAnd而非旧ζAnd，斗取φSgr，明确区别另说μSgr。',
  '距星按ICRS切向自行与当日岁差章动变换；不加周年光行差、视差、引力偏折或透视加速度，省略ICRS框架偏差；这是参照星宿界，不是统一视位置。',
  '四余采用独立的现代平轨道与均速紫炁方法；遇卯命度采用现代热带宫度与距星参照。各模块参考系、时间和流派政策分别列明，不提供古度、流限或事件吉凶。',
];
export interface BodyPosition {
  body:SevenBody; longitudeDegrees:number; latitudeDegrees:number; rightAscensionDegrees:number; declinationDegrees:number;
  correctionPolicy:'light-time-aberration'|'geomoon-no-separate-light-time-aberration';
}
export interface MansionBoundary {
  name:string; designation:string; hip:number; rightAscensionDegrees:number; nextRightAscensionDegrees:number; widthDegrees:number;
}
export interface MansionPosition {
  body:SevenBody|'LifeDegree'; mansion:string; index:number; entryDegrees:number; widthDegrees:number; distanceToBoundaryDegrees:number;
  boundaryStatus:'uncertain-time-precision';
}
export interface MansionModule {
  moduleID:'chinese-28-mansions'; methodVersion:'contemporary-first-star28-equatorial-v1'; inputFingerprint:string;
  dependencyVersions:{catalog:string;transformation:'icrs-tangent-motion-precession-nutation-v1';boundary:'left-closed-right-open-equatorial-v1'};
  sourceIDs:string[]; boundaries:MansionBoundary[]; positions:MansionPosition[];
  uncertainty:{birthTimePrecision:'unknown';ephemerisErrorBoundDegrees:null;catalogErrorBoundDegrees:null};
}
export interface NatalAstronomy {
  schemaVersion:1;engineRevision:string;birthKey:string;time:ReturnType<typeof astronomyTime>;
  sevenBodies:{moduleID:'geocentric-seven-bodies';methodVersion:'astronomy-engine-2.1.19-geocentric-v1';inputFingerprint:string;
    dependencyVersions:typeof SEVEN_BODY_DEPENDENCIES;sourceIDs:string[];positions:BodyPosition[]};
  mansions:MansionModule|null;
  fourResiduals:ResidualModule;lifeDegree:LifeDegreeModule;
  unsupported:string[];limitations:string[];
}

export function astronomyTime(instant:Date) {
  assertCalendarRange(instant);
  const p=beijingDateParts(instant),pad=(v:number)=>String(v).padStart(2,'0'),time=MakeTime(instant);
  return {wallClock:`${p.year}-${pad(p.month)}-${pad(p.day)}T${pad(p.hour)}:${pad(p.minute)}`,instantUTC:instant.toISOString(),
    interpretation:'fixed-utc-plus-8-v1' as const,utPolicy:'utc-as-ut1-v1' as const,deltaTModel:'espenak-meeus-v1' as const,
    julianDayUT:time.ut+2451545,julianDayTT:time.tt+2451545,deltaTSeconds:(time.tt-time.ut)*86400};
}

/** Same verified geocentric calls as research sample.cjs; never solar-time-shift the instant. */
export function sevenBodyPositions(instant:Date):BodyPosition[] {
  assertCalendarRange(instant);
  const time=MakeTime(instant),rotation=Rotation_EQJ_EQD(time);
  return SEVEN_BODIES.map(body=>{
    const vector=GeoVector(Body[body],time,true),ecliptic=Ecliptic(vector),equator=EquatorFromVector(RotateVector(rotation,vector));
    return {body,longitudeDegrees:ecliptic.elon,latitudeDegrees:ecliptic.elat,rightAscensionDegrees:equator.ra*15,declinationDegrees:equator.dec,
      correctionPolicy:body==='Moon'?'geomoon-no-separate-light-time-aberration':'light-time-aberration'};
  });
}

export function createNatalAstronomy(birthKey:string,instant:Date,engineRevision:string):NatalAstronomy {
  const positions=sevenBodyPositions(instant);
  const mansions=createMansionModule(positions,instant,birthKey);
  return {schemaVersion:1,engineRevision,birthKey,time:astronomyTime(instant),
    sevenBodies:{moduleID:'geocentric-seven-bodies',methodVersion:'astronomy-engine-2.1.19-geocentric-v1',inputFingerprint:birthKey,
      dependencyVersions:{...SEVEN_BODY_DEPENDENCIES},sourceIDs:[...ASTRONOMY_SOURCE_IDS],positions},
    mansions,fourResiduals:createResidualModule(instant,birthKey),
    lifeDegree:createLifeDegreeModule(instant,birthKey,positions[0].longitudeDegrees,mansions.boundaries),
    unsupported:['traditional-angle-units','qizheng-event-judgment','qizheng-directions'],limitations:[...ASTRONOMY_LIMITATIONS]};
}

function same(a:unknown,b:unknown):boolean {
  if(a===b)return true;
  if(Array.isArray(a)||Array.isArray(b))return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((value,i)=>same(value,b[i]));
  if(!a||!b||typeof a!=='object'||typeof b!=='object')return false;
  const left=a as Record<string,unknown>,right=b as Record<string,unknown>,keys=Object.keys(left);
  return keys.length===Object.keys(right).length&&keys.every(key=>Object.prototype.hasOwnProperty.call(right,key)&&same(left[key],right[key]));
}
// Known transcendental angular values may differ in the last bits between JSC and Node.
// Never loosen identity, source metadata, clock values, indices or parameter constants.
const derivedAngle=/^(fourResiduals\.positions\.\d+\.(longitudeDegrees|latitudeDegrees)|lifeDegree\.(sunLongitudeDegrees|palaceDegree|longitudeDegrees|rightAscensionDegrees|declinationDegrees|mansion\.(entryDegrees|widthDegrees|distanceToBoundaryDegrees)))$/;
function sameDerived(a:unknown,b:unknown,path:string):boolean {
  if(a===b)return true;
  if(derivedAngle.test(path)&&typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=1e-9)return true;
  if(Array.isArray(a)||Array.isArray(b))return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((v,i)=>sameDerived(v,b[i],path+'.'+i));
  if(!a||!b||typeof a!=='object'||typeof b!=='object')return false;
  const left=a as Record<string,unknown>,right=b as Record<string,unknown>,keys=Object.keys(left);
  return keys.length===Object.keys(right).length&&keys.every(k=>Object.prototype.hasOwnProperty.call(right,k)&&sameDerived(left[k],right[k],path+'.'+k));
}
function coordinate(value:unknown,min:number,max:number,exclusive=false):boolean {
  return typeof value==='number'&&Number.isFinite(value)&&value>=min&&(exclusive?value<max:value<=max);
}
/** Native verifies owner, birth profile and digest. Bridge verifies version/schema; it never treats model args as cache. */
export function validateNatalAstronomy(value:unknown,birthKey:string,instant:Date,engineRevision:string):NatalAstronomy {
  const n=value as NatalAstronomy;
  if(!n||n.schemaVersion!==1||n.engineRevision!==engineRevision||n.birthKey!==birthKey||!same(n.time,astronomyTime(instant))||
    n.sevenBodies?.moduleID!=='geocentric-seven-bodies'||n.sevenBodies?.methodVersion!=='astronomy-engine-2.1.19-geocentric-v1'||
    n.sevenBodies?.inputFingerprint!==birthKey||!same(n.sevenBodies?.dependencyVersions,SEVEN_BODY_DEPENDENCIES)||
    !same(n.sevenBodies?.sourceIDs,ASTRONOMY_SOURCE_IDS)||!Array.isArray(n.sevenBodies?.positions)||n.sevenBodies.positions.length!==7||
    !n.sevenBodies.positions.every((p,i)=>p?.body===SEVEN_BODIES[i]&&coordinate(p.longitudeDegrees,0,360,true)&&coordinate(p.latitudeDegrees,-90,90)&&
      coordinate(p.rightAscensionDegrees,0,360,true)&&coordinate(p.declinationDegrees,-90,90)&&
      p.correctionPolicy===(p.body==='Moon'?'geomoon-no-separate-light-time-aberration':'light-time-aberration'))||
    !same(n.unsupported,['traditional-angle-units','qizheng-event-judgment','qizheng-directions'])||!same(n.limitations,ASTRONOMY_LIMITATIONS)||!validateMansionStructure(n.mansions,n.sevenBodies.positions,birthKey,same)) {
    throw new Error('本命天文档案已失效，请重新建立档案');
  }
  // Validate the inexpensive derived definitions using the cached Sun/boundaries;
  // no ephemeris or distance-star positions are recomputed on normal cache reads.
  if(!sameDerived(n.fourResiduals,createResidualModule(instant,birthKey),'fourResiduals')||
    !sameDerived(n.lifeDegree,createLifeDegreeModule(instant,birthKey,n.sevenBodies.positions[0].longitudeDegrees,n.mansions!.boundaries),'lifeDegree'))
    throw new Error('本命天文档案已失效，请重新建立档案');
  return JSON.parse(JSON.stringify(n));
}

export { buildMansionBoundaries, assignMansion, transformDistanceStar } from './mansions';
