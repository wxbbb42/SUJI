import type { HexagramLine, RelatedLine, WuXing } from './types';
import type { RuleSource } from '../rules/provenance';

export const TOMB_EXTINCTION_SOURCE:RuleSource = {
  id:'liuyao-tomb-extinction-v1',version:'1',title:'六爻五行墓绝：对象参照与条件',
  editionStatus:'electronic-transcription-not-print-collated',
  scope:'选用木未申、火戌亥、土水辰巳、金丑寅的墓绝表；原爻、实际变爻、伏神各自绑定日月和限定来源，效力待断',
  references:[
    {url:'https://zh.wikisource.org/wiki/增刪卜易/26又1',locator:'生旺墓絕章第又二十六；五行表及金丑、土巳条件',sha256:'630f38b037ae720e90e55faff10a1c044f7edf9e3a85ce7dc645b8693ada2008',quote:'土水長生在申，旺在子，墓在辰，絕在巳。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/26又3',locator:'各門類應期總注；仅取火墓戌和冲墓条件，不推出日期',sha256:'dc529f9dc18f3620c1975fe3463f744fd8732000c4f9d01eecf318d45528eea4',quote:'入三墓俱喜沖開：如主事爻臨午火，假使火墓於戌'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易/15',locator:'動變生克沖合章第十五；变爻仅本位回头、日月作用范围',sha256:'0df8223b0c65616826c8caf86b592526b46b1dee51332e0c2707486f2d7ee4e5',quote:'夫變出之爻能生克沖合本位之動爻，不能生克他爻，而他爻與本位之動爻，亦不能生克變爻。'},
    {url:'https://zh.wikisource.org/wiki/增刪卜易',locator:'正文飛伏神章第二十八、隨鬼入墓章第三十，非目录或现代增订表',sha256:'897f963b938ec4582bc892465301b831a6439216f317841f44b888117704ca07',quote:'伏神墓絕於日月飛爻者四也。'},
    {url:'https://zh.wikisource.org/wiki/易林補遺/1',locator:'卦之墓絕非宜；仅取兼容的火墓戌绝亥表项',sha256:'abf77e78f3fbf77e33c2520e2a3525898894e5f5b0863fb5fa2c44619daab967',quote:'离火墓于戌、絕于亥'},
  ],
  limitations:[
    '土随水为所选六爻五行约定，不套八字阴阳干十二长生；增删此电子转录漏列完整火行，火墓戌见26又3，火绝亥以易林明确兼容表项补足，非增删逐字完整表',
    '只取易林火墓绝表项，不采其土逢巳绝不可言生、卦变方位或必然吉凶规则；电子文本未校印本',
    '变爻只列其自身日月参照；伏神另列本位飞神，跨位墓绝仅列原爻目标与其他实际原动爻；动绝是选表的结构投影，非完整效力条文',
    '土遇巳仍保留火生土；金遇丑仍保留土生金和冲墓条件。动爻生扶含同类或相生，不裁定施力，也不以土多设任意数量门槛',
    '目标日月生扶与各墓源的空破冲分别读取原对象context；旺相、休囚无气、墓破或填实均须结合条件，不能一律解除或判真墓真绝',
    '未定用、综合强弱、作用者效力及事件结果仍未决；不推出吉凶、医疗结论或公历应期',
  ],
};

type Reference = '墓' | '绝' | 'neither';
interface ObjectReference {
  objectPath:string;
  month:Reference;
  day:Reference;
  ownChange?:Reference;
  flying?:Reference;
  movingTombPositions:number[];
  movingExtinctionPositions:number[];
  supportingMovingPositions:number[];
}
const PLACES:Record<WuXing,readonly [string,string]> = {
  木:['未','申'],火:['戌','亥'],土:['辰','巳'],金:['丑','寅'],水:['辰','巳'],
};
const GENERATES:Record<WuXing,WuXing> = {木:'火',火:'土',土:'金',金:'水',水:'木'};
function reference(element:WuXing,branch:string):Reference {
  const [tomb,extinction]=PLACES[element];
  return branch===tomb?'墓':branch===extinction?'绝':'neither';
}

/** Project existing objects and contexts only; no selection, strength verdict or new calendar. */
export function tombExtinction(lines:HexagramLine[]) {
  const objects:ObjectReference[]=[];
  lines.forEach((line,index) => {
    const path=`/lines/${index}`;
    const others=lines.filter(actor => actor.isChanging && actor.position!==line.position);
    const objectRow=(object:HexagramLine|RelatedLine,objectPath:string,layer:'original'|'changed'|'hidden'):ObjectReference => ({
      objectPath,
      month:reference(object.wuXing,object.context.month.branch),
      day:reference(object.wuXing,object.context.day.branch),
      ...(layer==='original' && line.isChanging && line.changed ? {ownChange:reference(object.wuXing,line.changed.ganZhi[1])} : {}),
      ...(layer==='hidden' ? {flying:reference(object.wuXing,line.ganZhi[1])} : {}),
      movingTombPositions:layer==='original'?others.filter(actor => reference(object.wuXing,actor.ganZhi[1])==='墓').map(actor=>actor.position):[],
      movingExtinctionPositions:layer==='original'?others.filter(actor => reference(object.wuXing,actor.ganZhi[1])==='绝').map(actor=>actor.position):[],
      supportingMovingPositions:layer==='changed'?[]:others.filter(actor => actor.wuXing===object.wuXing || GENERATES[actor.wuXing]===object.wuXing).map(actor=>actor.position),
    });
    objects.push(objectRow(line,path,'original'));
    if(line.isChanging && line.changed)objects.push(objectRow(line.changed,path+'/changed','changed'));
    if(line.hidden)objects.push(objectRow(line.hidden,path+'/hidden','hidden'));
  });
  return {sourceId:TOMB_EXTINCTION_SOURCE.id,assessmentStatus:'conditional-structure' as const,efficacyEstablished:false as const,
    objects,unresolved:['selected-object','target-strength','actor-effectiveness','event-outcome']};
}
