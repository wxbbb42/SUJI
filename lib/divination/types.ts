/**
 * 六爻卜卦类型定义
 */

export type Yao = '阴' | '阳';
export type WuXing = '金' | '木' | '水' | '火' | '土';

/** 六亲 */
export type LiuQin = '父母' | '兄弟' | '子孙' | '妻财' | '官鬼';

/** 八卦（trigram） */
export type TrigramName = '乾' | '兑' | '离' | '震' | '巽' | '坎' | '艮' | '坤';

export interface Trigram {
  name: TrigramName;
  symbol: string;          // ☰ ☱ ☲ ☳ ☴ ☵ ☶ ☷
  yao: Yao[];              // 3 爻，由下到上
  wuXing: WuXing;
  nature: string;          // 天/泽/火/雷/风/水/山/地
}

/** 六十四卦的一卦 */
export interface GuaInfo {
  name: string;            // 卦名，如 "水山蹇"
  code: number;            // 1-64（按通行顺序）
  upper: TrigramName;      // 上卦
  lower: TrigramName;      // 下卦
  yao: Yao[];              // 6 爻，初爻→上爻（自下而上）
  palace: TrigramName;     // 所属八宫
}

/** 用户问题类型，用于选用神 */
export type QuestionType =
  | 'career'
  | 'wealth'
  | 'marriage'
  | 'kids'
  | 'parents'
  | 'health'
  | 'event'
  | 'general';

export interface CastOptions {
  question: string;
  questionType?: QuestionType;
  gender?: '男' | '女';      // marriage 时区分用神
  castTime?: Date;            // 默认 now
}

export interface YongShenAnalysis {
  type: LiuQin;
  yaoIndex: number;         // 1-6
  wuXing: WuXing;
  state: '旺' | '相' | '休' | '囚' | '死';
  interactions: string[];
}

export interface YingQiAnalysis {
  description: string;
  factors: string[];
}

export interface HexagramReading {
  question: string;
  questionType: QuestionType;
  castTime: string;         // ISO
  castGanZhi: {
    day: string;
    month: string;
    hour: string;
  };
  benGua: GuaInfo;
  bianGua: GuaInfo;
  changingYao: number[];    // 1-6
  yongShen: YongShenAnalysis;
  yingQi: YingQiAnalysis;
  liuQin: Record<1 | 2 | 3 | 4 | 5 | 6, LiuQin>;
}
