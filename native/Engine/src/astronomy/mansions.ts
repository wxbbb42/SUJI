import { EquatorFromVector, MakeTime, RotateVector, Rotation_EQJ_EQD, Vector } from 'astronomy-engine';
import type { FlexibleDateTime } from 'astronomy-engine';
import type { MansionBoundary,MansionPosition,SevenBody } from './natal';

type BoundaryStar=Pick<MansionBoundary,'name'|'designation'|'hip'|'rightAscensionDegrees'>;
/** Reject repeated/reversed ordering BEFORE converting the single wrap into a positive width. */
export function buildMansionBoundaries(stars:BoundaryStar[]):MansionBoundary[] {
  if(stars.length!==28)throw new Error('距星必须完整包含28宿');
  if(new Set(stars.map(s=>s.name)).size!==28||new Set(stars.map(s=>s.hip)).size!==28||
    stars.some(s=>!s.name||!s.designation||!Number.isInteger(s.hip)||s.hip<1||!Number.isFinite(s.rightAscensionDegrees)||s.rightAscensionDegrees<0||s.rightAscensionDegrees>=360)) {
    throw new Error('距星身份或赤经无效');
  }
  const differences=stars.map((star,i)=>stars[(i+1)%28].rightAscensionDegrees-star.rightAscensionDegrees);
  if(differences.some(d=>d===0)||differences.filter(d=>d<0).length!==1)throw new Error('距星顺序必须沿赤经覆盖恰好一周');
  const widths=differences.map(d=>d<0?d+360:d);
  if(Math.abs(widths.reduce((a,b)=>a+b,0)-360)>1e-9)throw new Error('距星宿界不能覆盖恰好一周');
  return stars.map((star,i)=>({...star,nextRightAscensionDegrees:stars[(i+1)%28].rightAscensionDegrees,widthDegrees:widths[i]}));
}

export function assignMansion(body:SevenBody|'LifeDegree',rightAscensionDegrees:number,boundaries:MansionBoundary[]):MansionPosition {
  if(!Number.isFinite(rightAscensionDegrees)||rightAscensionDegrees<0||rightAscensionDegrees>=360)throw new Error('天体赤经超出范围');
  const index=boundaries.findIndex(b=>b.nextRightAscensionDegrees>b.rightAscensionDegrees
    ? rightAscensionDegrees>=b.rightAscensionDegrees&&rightAscensionDegrees<b.nextRightAscensionDegrees
    : rightAscensionDegrees>=b.rightAscensionDegrees||rightAscensionDegrees<b.nextRightAscensionDegrees);
  if(index<0)throw new Error('宿界不完整');
  const boundary=boundaries[index],difference=rightAscensionDegrees-boundary.rightAscensionDegrees,entryDegrees=difference<0?difference+360:difference;
  return {body,mansion:boundary.name,index,entryDegrees,widthDegrees:boundary.widthDegrees,
    distanceToBoundaryDegrees:Math.min(entryDegrees,boundary.widthDegrees-entryDegrees),boundaryStatus:'uncertain-time-precision'};
}


export interface DistanceStar {
  name:string;designation:string;hip:number;raDegrees:number;decDegrees:number;
  pmRaMasYear:number;pmDecMasYear:number;epochYear:number;sourceIDs:string[];
}
/**
 * Hipparcos mu_alpha*cos(delta), mas/Julian year, at ICRS catalogue epoch.
 * Tangent-vector motion to target TT; EQJ->EQD precession/nutation afterwards.
 * Astronomy2.1.19 uses five leading nutation terms (not complete IAU2000B).
 * ICRS is approximated as J2000 mean (frame bias omitted). No annual aberration,
 * parallax, radial velocity/perspective, gravitational deflection or refraction:
 * these are reference-star boundaries, not apparent star observations.
 */
export function transformDistanceStar(star:DistanceStar,date:FlexibleDateTime) {
  if(![star.raDegrees,star.decDegrees,star.pmRaMasYear,star.pmDecMasYear,star.epochYear].every(Number.isFinite)||
    star.raDegrees<0||star.raDegrees>=360||Math.abs(star.decDegrees)>90||star.epochYear<1800||star.epochYear>2200)throw new Error('距星坐标历元或自行无效');
  const time=MakeTime(date),radians=Math.PI/180,alpha=star.raDegrees*radians,delta=star.decDegrees*radians;
  const elapsedYears=(time.tt-(star.epochYear-2000)*365.25)/365.25;
  const raMotion=star.pmRaMasYear*radians/3600000,decMotion=star.pmDecMasYear*radians/3600000;
  const x=Math.cos(delta)*Math.cos(alpha),y=Math.cos(delta)*Math.sin(alpha),z=Math.sin(delta);
  const vx=-raMotion*Math.sin(alpha)-decMotion*Math.sin(delta)*Math.cos(alpha);
  const vy=raMotion*Math.cos(alpha)-decMotion*Math.sin(delta)*Math.sin(alpha),vz=decMotion*Math.cos(delta);
  const vector=new Vector(x+elapsedYears*vx,y+elapsedYears*vy,z+elapsedYears*vz,time);
  const equator=EquatorFromVector(RotateVector(Rotation_EQJ_EQD(time),vector));
  return {name:star.name,designation:star.designation,hip:star.hip,rightAscensionDegrees:equator.ra*15,declinationDegrees:equator.dec};
}

const catalog = require('./mansion-catalog.json') as {
  id:string;version:string;sourceIDs:string[];stars:DistanceStar[];
};
export const MANSION_DEPENDENCIES = {catalog:catalog.id+'@'+catalog.version,
  transformation:'icrs-tangent-motion-precession-nutation-v1' as const,boundary:'left-closed-right-open-equatorial-v1' as const};
export const MANSION_SOURCE_IDS = [...catalog.sourceIDs];
export function createMansionModule(positions:import('./natal').BodyPosition[],instant:Date,inputFingerprint:string):import('./natal').MansionModule {
  const boundaries=buildMansionBoundaries(catalog.stars.map(star=>{
    const {declinationDegrees:_declination,...boundary}=transformDistanceStar(star,instant);return boundary;
  }));
  return {moduleID:'chinese-28-mansions',methodVersion:'contemporary-first-star28-equatorial-v1',inputFingerprint,
    dependencyVersions:{...MANSION_DEPENDENCIES},sourceIDs:[...MANSION_SOURCE_IDS],boundaries,
    positions:positions.map(p=>assignMansion(p.body,p.rightAscensionDegrees,boundaries)),
    uncertainty:{birthTimePrecision:'unknown',ephemerisErrorBoundDegrees:null,catalogErrorBoundDegrees:null}};
}
export function validateMansionStructure(module:import('./natal').MansionModule|null,positions:import('./natal').BodyPosition[],key:string,
  same:(a:unknown,b:unknown)=>boolean):boolean {
  if(!module||module.moduleID!=='chinese-28-mansions'||module.methodVersion!=='contemporary-first-star28-equatorial-v1'||module.inputFingerprint!==key||
    !same(module.dependencyVersions,MANSION_DEPENDENCIES)||!same(module.sourceIDs,MANSION_SOURCE_IDS)||
    !same(module.uncertainty,{birthTimePrecision:'unknown',ephemerisErrorBoundDegrees:null,catalogErrorBoundDegrees:null})||!Array.isArray(module.boundaries)||module.boundaries.length!==28)return false;
  try {
    const base=module.boundaries.map((b,i)=>{
      const star=catalog.stars[i];
      if(b.name!==star.name||b.designation!==star.designation||b.hip!==star.hip)throw new Error('距星身份变化');
      return {name:b.name,designation:b.designation,hip:b.hip,rightAscensionDegrees:b.rightAscensionDegrees};
    });
    const boundaries=buildMansionBoundaries(base);
    return same(module.boundaries,boundaries)&&same(module.positions,positions.map(p=>assignMansion(p.body,p.rightAscensionDegrees,boundaries)));
  } catch {return false;}
}
