import { MakeTime } from 'astronomy-engine';
import { assertCalendarRange } from '../calendar/precision';

export const RESIDUAL_BODIES=['Rahu','Ketu','Apogee','PurpleQi'] as const;
export const RESIDUAL_SOURCES=['iers2003-simon1994-mean-lunar','aa1996-mean-lunar-inclination','moira-purple-7474e5f'];
export const RESIDUAL_DEPENDENCIES={lunarElements:'iers2003-simon1994-tt-v1',inclination:'aa1996-5.1453964-degrees',
  purpleParameters:'moira-7474e5f-19750313-10227.1792',timePolicy:'utc-as-ut1-espenak-meeus-v1'};
export const PURPLE_EPOCH='1975-03-13T16:00:00.000Z';
export const PURPLE_PERIOD_DAYS=10227.1792;
export const wrap=(v:number)=>((v%360)+360)%360;
const rad=Math.PI/180;

/** IERS 2003 / Simon 1994 fundamental arguments, polynomial coefficients in arcseconds.
 * TT substitutes for TDB as allowed by ERFA's documented argument convention.
 * See the archived ERFA reference and distributed attribution; these are mean elements.
 */
export function meanLunarPoints(julianDayTT:number) {
  if(!Number.isFinite(julianDayTT))throw new Error('TT无效');
  const t=(julianDayTT-2451545)/36525;
  const arc=(coefficients:number[])=>coefficients.reduceRight((v,c)=>v*t+c,0)/3600;
  const node=wrap(arc([450160.398036,-6962890.5431,7.4722,0.007702,-0.00005939]));
  const f=arc([335779.526232,1739527262.8478,-12.7512,-0.001037,0.00000417]);
  const anomaly=arc([485868.249036,1717915923.2178,31.8792,0.051635,-0.00024470]);
  const argument=wrap(f-anomaly+180)*rad,inclination=5.1453964*rad;
  // Project the mean lunar plane onto the mean ecliptic. Omega+omega alone is NOT the longitude.
  const longitude=wrap(node+Math.atan2(Math.sin(argument)*Math.cos(inclination),Math.cos(argument))/rad);
  const latitude=Math.asin(Math.sin(inclination)*Math.sin(argument))/rad;
  return {ascendingNodeDegrees:node,descendingNodeDegrees:wrap(node+180),apogeeLongitudeDegrees:longitude,apogeeLatitudeDegrees:latitude};
}

export function purpleLongitude(julianDayUT:number) {
  if(!Number.isFinite(julianDayUT))throw new Error('UT无效');
  const epoch=Date.parse(PURPLE_EPOCH)/86400000+2440587.5;
  return wrap(230.5+360*(julianDayUT-epoch)/PURPLE_PERIOD_DAYS);
}

export function createResidualModule(instant:Date,inputFingerprint:string) {
  assertCalendarRange(instant);
  const time=MakeTime(instant),m=meanLunarPoints(time.tt+2451545);
  return {moduleID:'four-residuals',methodVersion:'mean-lunar-moira-purple-v1',inputFingerprint,
    nodeConvention:'rahu-ascending-ketu-descending',dependencyVersions:{...RESIDUAL_DEPENDENCIES},sourceIDs:[...RESIDUAL_SOURCES],
    positions:[
      {body:'Rahu',definition:'mean-ascending-node',longitudeDegrees:m.ascendingNodeDegrees,latitudeDegrees:0,framePolicy:'mean-ecliptic-of-date',timeScale:'TT'},
      {body:'Ketu',definition:'mean-descending-node',longitudeDegrees:m.descendingNodeDegrees,latitudeDegrees:0,framePolicy:'mean-ecliptic-of-date',timeScale:'TT'},
      {body:'Apogee',definition:'mean-lunar-apogee',longitudeDegrees:m.apogeeLongitudeDegrees,latitudeDegrees:m.apogeeLatitudeDegrees,framePolicy:'mean-ecliptic-of-date',timeScale:'TT'},
      {body:'PurpleQi',definition:'uniform-symbolic-point',longitudeDegrees:purpleLongitude(time.ut+2451545),latitudeDegrees:0,framePolicy:'tropical-ecliptic-parameter',timeScale:'UT'},
    ],
    purpleParameters:{epochUTC:PURPLE_EPOCH,periodDays:PURPLE_PERIOD_DAYS,epochLongitudeDegrees:230.5},
    limitations:['罗北计南为本方法所选对应，采用平交点而非真交点；其他流派不能不改标签直接替换。',
      '月孛取平均月球轨道远地点；紫炁为约定均速推算点，均不是肉眼可见的独立行星。',
      '平交点与月孛使用日期平黄道，不能与七曜真黄道视位置混称同一参考系；这里不据此计算四余入宿或吉凶。',
      '现代平轨道与紫炁参数不声称复原古历四余；抽样星历复算不构成所有时刻的误差上界。']};
}
export type ResidualModule=ReturnType<typeof createResidualModule>;
