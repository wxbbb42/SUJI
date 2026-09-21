import type { QimenChart, TianGan } from './types';
import type { QimenOccurrence } from './questionObjects';
import { computeXunShou } from './helpers/tianPan';
import { qimenSelectionSource } from './selectionSources';

export const QIMEN_SELECTION_FOCUSES=[
 'weather-rain','weather-snow','weather-wind','weather-river-level',
 'dwelling-residence','dwelling-entrance','dwelling-stove','dwelling-tap-water','dwelling-utensils',
 'dwelling-courtyard','dwelling-skywell','dwelling-living-room',
] as const;
export type QimenSelectionFocus=typeof QIMEN_SELECTION_FOCUSES[number];
export interface QimenSelectionRequest {focus:QimenSelectionFocus}
type Field='jiuxing'|'bamen'|'bashen'|'stem'|'hour'|'duty-door';
interface Role {id:string;label:string;field:Field;symbol?:string}
const roles:Record<QimenSelectionFocus,Role[]>={
 'weather-rain':[{id:'rain-master',label:'雨师参考',field:'jiuxing',symbol:'天柱'},{id:'water-spirit',label:'水神参考',field:'jiuxing',symbol:'天蓬'}],
 'weather-snow':[{id:'snow-heart',label:'占雪天心参考',field:'jiuxing',symbol:'天心'},{id:'snow-pillar',label:'占雪天柱参考',field:'jiuxing',symbol:'天柱'}],
 'weather-wind':[{id:'wind-star',label:'占风参考',field:'jiuxing',symbol:'天辅'}],
 'weather-river-level':[{id:'river-star',label:'河水天蓬参考',field:'jiuxing',symbol:'天蓬'},{id:'river-door',label:'河水休门参考',field:'bamen',symbol:'休门'}],
 'dwelling-residence':[{id:'residence-hour',label:'住宅时干参考',field:'hour'},{id:'residence-door',label:'住宅生门参考',field:'bamen',symbol:'生门'}],
 'dwelling-entrance':[{id:'entrance-duty-door',label:'住宅大门参考',field:'duty-door'}],
 'dwelling-stove':[{id:'stove-stem',label:'灶具、燃火参考',field:'stem',symbol:'丙'}],
 'dwelling-tap-water':[{id:'tap-water-stem',label:'饮用自来水参考',field:'stem',symbol:'壬'}],
 'dwelling-utensils':[{id:'utensils-stem',label:'锅碗瓢盆参考',field:'stem',symbol:'辛'}],
 'dwelling-courtyard':[{id:'courtyard-deity',label:'院落九天参考',field:'bashen',symbol:'九天'},{id:'courtyard-star',label:'院落天芮参考',field:'jiuxing',symbol:'天芮'}],
 'dwelling-skywell':[{id:'skywell-stem',label:'天井参考',field:'stem',symbol:'己'}],
 'dwelling-living-room':[{id:'living-room-deity',label:'客厅参考',field:'bashen',symbol:'六合'}],
};
export interface QimenSelectionReference {
 id:string;label:string;symbol:string;factPaths:string[];occurrences:QimenOccurrence[];
 carrierStem?:TianGan;carrierMethod?:'own-pillar-xun'|'direct-stem';
 resolution:'single-object'|'multiple-plate-references'|'missing-object'|'conflicting-object';selectedObjectPath:string|null;
}
export interface QimenSpecializedSelection {
 methodVersion:'qimen-xdyy-selection-v1';sourceId:string;request:QimenSelectionRequest;event:string;
 assessmentStatus:'role-references-established'|'requires-clarification';roleMappingEstablished:boolean;outcomeEstablished:false;
 references:QimenSelectionReference[];conditions:{id:string;met:boolean;factPaths:string[]}[];
 missingContext:string[];conflicts:{id:string;factPaths:string[]}[];unresolved:string[];
}
/** Source-backed role projection only. No weather, building or event adjudication. */
export function analyzeQimenSelection(chart:QimenChart,request:QimenSelectionRequest):QimenSpecializedSelection {
 if(!request||Array.isArray(request)||Object.keys(request).length!==1||!QIMEN_SELECTION_FOCUSES.includes(request.focus))throw new Error('奇门专门取用请求无效');
 const event=typeof chart.questionContext?.event==='string'?chart.questionContext.event.trim():'';
 const conditions=[
  {id:'single-event',met:event.length>0&&event.length<=200,factPaths:['/questionContext']},
  {id:'event-question-category',met:['event','general'].includes(chart.questionType),factPaths:['/questionType']},
  {id:'compatible-chart-method',met:chart.method?.algorithm==='zhuanpan-qimen-chai-bu-v1'&&chart.method.centerPolicy==='fixed-kun-2; tian-qin-follows-tian-rui',factPaths:['/method']},
  {id:'original-nine-palaces',met:Array.isArray(chart.palaces)&&chart.palaces.length===9&&new Set(chart.palaces.map(p=>p.id)).size===9&&chart.palaces.every(p=>Number.isInteger(p.id)&&p.id>=1&&p.id<=9),factPaths:['/palaces']},
 ];
 const missingContext=conditions.filter(c=>!c.met&&c.id!=='event-question-category').map(c=>c.id);
 const conflicts:QimenSpecializedSelection['conflicts']=conditions[1].met?[]:[{id:'question-category-conflict',factPaths:['/questionType']}];
 const palaces=Array.isArray(chart.palaces)?chart.palaces:[];
 const references=roles[request.focus].map((role):QimenSelectionReference=>{
  const isStem=role.field==='stem'||role.field==='hour';
  const symbol=role.field==='hour'?chart.hourGanZhi?.[0]??'':role.field==='duty-door'?chart.zhiShiMen??'':role.symbol!;
  let carrierStem=isStem?symbol as TianGan:undefined;
  const factPaths=role.field==='hour'?['/hourGanZhi']:role.field==='duty-door'?['/zhiShiMen','/zhiShiPalaceId']:[];
  if(role.field==='hour'){
   const pillar=chart.hourGanZhi??'',si='甲乙丙丁戊己庚辛壬癸'.indexOf(pillar[0]),bi='子丑寅卯辰巳午未申酉戌亥'.indexOf(pillar[1]);
   if(pillar.length!==2||si<0||bi<0||(bi-si+12)%2!==0){missingContext.push('original-hour-pillar');carrierStem=undefined;}
   else if(symbol==='甲')carrierStem=computeXunShou('甲',pillar[1]);
  }
  const fields=isStem?['diPanGan','hostedDiPanGan','tianPanGan','hostedTianPanGan'] as const:[role.field==='duty-door'?'bamen':role.field] as ('jiuxing'|'bamen'|'bashen')[];
  const occurrences:QimenOccurrence[]=[];
  for(const [index,p] of palaces.entries())for(const field of fields){
   if(!symbol||(isStem&&!carrierStem)||p[field] !== (isStem?carrierStem:symbol)||(p.id===5&&!isStem))continue;
   const plate=field==='diPanGan'?'earth':field==='hostedDiPanGan'?'hosted-earth':field==='tianPanGan'?(p.id===5?'center-record':'sky'):field==='hostedTianPanGan'?'hosted-sky':field==='jiuxing'?'star':field==='bamen'?'door':'deity';
   occurrences.push({palaceId:p.id,plate,objectPath:`/palaces/${index}/${field}`,...(isStem?{isEffectiveSky:plate==='sky'||plate==='hosted-sky'}:{})});
  }
  const effective=isStem?occurrences.filter(o=>o.isEffectiveSky):occurrences;
  let resolution:QimenSelectionReference['resolution']=isStem?'multiple-plate-references':'single-object';
  if(effective.length===0){resolution='missing-object';missingContext.push('role-object:'+role.id);}
  else if(effective.length>1){resolution='conflicting-object';conflicts.push({id:'duplicate-role-object',factPaths:effective.map(o=>o.objectPath)});}
  if(role.field==='duty-door'&&(effective.length!==1||effective[0].palaceId!==chart.zhiShiPalaceId)){
   resolution='conflicting-object';conflicts.push({id:'duty-door-palace-conflict',factPaths});
  }
  return {id:role.id,label:role.label,symbol,factPaths,occurrences,...(isStem&&carrierStem?{carrierStem,carrierMethod:symbol==='甲'?'own-pillar-xun' as const:'direct-stem' as const}:{}),resolution,
   selectedObjectPath:resolution==='single-object'?effective[0].objectPath:null};
 });
 const roleMappingEstablished=missingContext.length===0&&conflicts.length===0;
 return {methodVersion:'qimen-xdyy-selection-v1',sourceId:qimenSelectionSource(request.focus).id,request:{focus:request.focus},event,
  assessmentStatus:roleMappingEstablished?'role-references-established':'requires-clarification',roleMappingEstablished,outcomeEstablished:false,
  references,conditions,missingContext,conflicts,unresolved:['event-outcome-not-adjudicated',...(references.some(r=>r.resolution==='multiple-plate-references')?['stem-plate-not-uniquely-selected']:[])]};
}
