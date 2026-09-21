import type { GuaInfo, HexagramLine, TrigramName } from './types';
import type { guaRelations } from './guaRelations';
import type { RuleSource } from '../rules/provenance';

export const FANFU_SOURCE:RuleSource = {
  id:'liuyao-fanfu-selected-v1',version:'1',title:'六爻反伏：动爻、卦支投影与所选方位对照',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'实际动爻与本位变爻同支或六冲；变动内外卦的三支重复或相冲；另选易林乾巽、坎离、震兑、艮坤方位对照，三层分列',
  references:[
    {url:'https://zh.wikisource.org/wiki/增刪卜易/25',locator:'反伏章第二十五；比之井、临之中孚、姤之恒实际动变例',sha256:'10c6f672b4b68ea46217d8f053a8668034a757d5899447fda3f0934b82537fa2',quote:'內卦動變伏吟，內則呻吟，外卦動變伏吟，外則憂鬱。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易',locator:'正文塋葬章第一百十八；卯月戊子巽之升及卦变异说，非原剑增订',sha256:'897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07',quote:'但不宜外卦反吟﹐世被酉金沖克﹐子孫被亥水沖克'},
    {url:'https://zh.wikisource.org/wiki/易林補遺/1',locator:'卦犯与爻犯分列；仅选动变方位对照及同支、冲支结构',sha256:'abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967',quote:'以上坎见离、震逢兑、艮配坤，皆是彼我相冲反吟之卦。'},
  ],
  limitations:[
    '所读电子转录未校印本；增删开头乾变坤、正文坤变震与所选易林方位表不一致，保留异说，不冒称统一原典定义',
    '只取实际动爻及本位变爻；同支不要求同干，姤之恒为壬申戌变庚申戌；伏神、静爻的结果投影不是实际动变',
    '变卦三支对照读取完整纳甲投影，另列真实动位；未变内外卦标unchanged，不套易林静态八纯卦伏吟或内外对冲卦反吟称呼',
    '易林方位对照与支冲分开，艮坤同土仍属所选方位相对；不得合成一个全卦反吟或伏吟裁决',
    '同支、支冲及卦象结构不能覆盖日月生扶或回头克；用神、强弱、作用效力及结果未决，不采用无条件吉凶、病断或应期',
  ],
};

const OPPOSITE_BRANCH:Record<string,string> = {子:'午',午:'子',丑:'未',未:'丑',寅:'申',申:'寅',卯:'酉',酉:'卯',辰:'戌',戌:'辰',巳:'亥',亥:'巳'};
const OPPOSITE_TRIGRAM:Record<TrigramName,TrigramName> = {乾:'巽',巽:'乾',坎:'离',离:'坎',震:'兑',兑:'震',艮:'坤',坤:'艮'};
type BranchRelation = 'unchanged' | 'repeated' | 'opposed' | 'neither';

/** Three distinct observations over saved chart facts; never an aggregate fanfu verdict. */
export function fanfu(benGua:GuaInfo,bianGua:GuaInfo,chartLines:HexagramLine[],projection:ReturnType<typeof guaRelations>) {
  const moving=chartLines.flatMap((line,index)=>line.isChanging && line.changed ? [{line,index,changed:line.changed}] : []);
  const lines=moving.map(({line,index,changed})=>({
    originalPath:`/lines/${index}`,changedPath:`/lines/${index}/changed`,
    sameStem:line.ganZhi[0]===changed.ganZhi[0],sameBranch:line.ganZhi[1]===changed.ganZhi[1],
    branchClash:OPPOSITE_BRANCH[line.ganZhi[1]]===changed.ganZhi[1],
  }));
  const trigrams=(['lower','upper'] as const).map((side,i)=>{
    const from=benGua[side],to=bianGua[side];
    const positions=[i*3,i*3+1,i*3+2];
    const original=positions.map(p=>projection.original.ganZhi[p][1]);
    const resulting=positions.map(p=>projection.resulting.ganZhi[p][1]);
    const branchRelation:BranchRelation=from===to?'unchanged':
      original.every((branch,p)=>branch===resulting[p])?'repeated':
      original.every((branch,p)=>OPPOSITE_BRANCH[branch]===resulting[p])?'opposed':'neither';
    return {side,from,to,movingPositions:moving.filter(({line})=>side==='lower'?line.position<=3:line.position>=4).map(({line})=>line.position),
      branchRelation,directionalOpposition:OPPOSITE_TRIGRAM[from]===to};
  });
  return {sourceId:FANFU_SOURCE.id,assessmentStatus:'structural-only' as const,efficacyEstablished:false as const,
    lines,trigrams,unresolved:['selected-object','target-strength','actor-effectiveness','event-outcome']};
}
