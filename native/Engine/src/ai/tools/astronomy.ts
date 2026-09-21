import type { ToolDefinition,ToolHandler } from './types';
import { SEVEN_BODIES } from '../../astronomy/natal';
import { RESIDUAL_BODIES } from '../../astronomy/residuals';

export const astronomyTools:ToolDefinition[]=[{type:'function',function:{name:'get_natal_astronomy',
  description:'读取固定本命七曜、现代中国二十八宿、平轨道四余及遇卯命度十二宫。各模块流派/时间/参考系分列；不提供古度、行运、吉凶或宿曜关系。',
  parameters:{type:'object',additionalProperties:false,properties:{body:{type:'string',enum:['all',...SEVEN_BODIES,...RESIDUAL_BODIES,'LifeDegree'],description:'all为全部模块；Moon为出生月亮；Rahu罗喉/Ketu计都/Apogee月孛/PurpleQi紫炁/LifeDegree遇卯命度。默认all。'}}}}}];
export const astronomyHandlers:Record<string,ToolHandler>={get_natal_astronomy:({body='all'},ctx)=>{
  const n=ctx.astronomy;
  if(!n)throw new Error('请先建立本命天文档案');
  const positions=n.sevenBodies.positions.filter(p=>body==='all'||p.body===body);
  const mansions=n.mansions?{...n.mansions,positions:n.mansions.positions.filter(p=>body==='all'||p.body===body),
    boundaries:n.mansions.boundaries.filter((_,index)=>n.mansions!.positions.some(p=>(body==='all'||p.body===body)&&p.index===index))}:null;
  return {schemaVersion:n.schemaVersion,engineRevision:n.engineRevision,birthKey:n.birthKey,time:n.time,
    sevenBodies:{...n.sevenBodies,positions},mansions,
    ...(body==='all'||RESIDUAL_BODIES.includes(body as any)?{fourResiduals:{...n.fourResiduals,positions:n.fourResiduals.positions.filter(p=>body==='all'||p.body===body)}}:{}),
    ...(body==='all'||body==='LifeDegree'?{lifeDegree:n.lifeDegree}:{}),unsupported:n.unsupported,limitations:n.limitations};
}};
