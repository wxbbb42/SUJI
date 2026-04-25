/**
 * 紫微斗数类型定义（在 iztro 之上的精简层）
 */

export type PalaceName =
  | '命宫' | '兄弟宫' | '夫妻宫' | '子女宫'
  | '财帛宫' | '疾厄宫' | '迁移宫' | '仆役宫'
  | '官禄宫' | '田宅宫' | '福德宫' | '父母宫';

export type StarBrightness = '庙' | '旺' | '得' | '利' | '平' | '闲' | '陷';
export type SiHua = '化禄' | '化权' | '化科' | '化忌';

export interface Star {
  name: string;
  brightness?: StarBrightness;
  type: 'major' | 'soft' | 'tough' | 'lucky' | 'unlucky' | 'flower' | 'helper' | 'other';
  sihua?: SiHua[];
}

export interface Palace {
  name: PalaceName;
  position: string;          // 地支位（子/丑/寅...）
  ganZhi: string;            // 宫位干支
  mainStars: Star[];
  minorStars: Star[];
  isShenGong: boolean;       // 是否为身宫所在
}

export interface ZiweiPan {
  birthDateTime: Date;
  gender: '男' | '女';
  palaces: Palace[];
  mingGongPosition: string;  // 命宫地支位
  shenGongPosition: string;  // 身宫地支位
  fiveElementsClass: string; // 五行局（水二局/木三局/...）
}

export interface ZiweiBirthInput {
  year: number;
  month: number;
  day: number;
  hour: number;       // 0-23
  minute?: number;    // 0-59
  gender: '男' | '女';
  isLunar?: boolean;  // 默认 false 阳历
}
