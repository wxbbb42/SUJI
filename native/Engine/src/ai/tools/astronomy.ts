import type { ToolDefinition,ToolHandler } from './types';
import { SEVEN_BODIES } from '../../astronomy/natal';

export const astronomyTools:ToolDefinition[]=[{type:'function',function:{name:'get_natal_astronomy',
  description:'读取已验证出生资料的地心七曜坐标和已核定中国二十八宿参考；可选一颗天体。只读固定本命，不提供行运、四余、命度、吉凶或宿曜关系。',
  parameters:{type:'object',additionalProperties:false,properties:{body:{type:'string',enum:['all',...SEVEN_BODIES],description:'all为七曜；Moon为出生月亮。默认all。'}}}}}];
export const astronomyHandlers:Record<string,ToolHandler>={get_natal_astronomy:({body='all'},ctx)=>{
  const n=ctx.astronomy;
  if(!n)throw new Error('请先建立本命天文档案');
  const positions=n.sevenBodies.positions.filter(p=>body==='all'||p.body===body);
  const mansions=n.mansions?{...n.mansions,positions:n.mansions.positions.filter(p=>body==='all'||p.body===body),
    boundaries:n.mansions.boundaries.filter((_,index)=>n.mansions!.positions.some(p=>(body==='all'||p.body===body)&&p.index===index))}:null;
  return {schemaVersion:n.schemaVersion,engineRevision:n.engineRevision,birthKey:n.birthKey,time:n.time,
    sevenBodies:{...n.sevenBodies,positions},mansions,unsupported:n.unsupported,limitations:n.limitations};
}};
