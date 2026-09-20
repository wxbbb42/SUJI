/**
 * 六爻卜卦类型定义
 */
import type { RuleSource } from '../rules/provenance';
import type { lineRules } from './conditionalRules';
import type { guaRelations } from './guaRelations';
import type { roleRelations } from './roleRelations';
import type { tombExtinction } from './tombExtinction';
import type { fanfu } from './fanfu';
import type {QuestionContext,selectQuestionObjects,conditionalTiming} from './questionJudgment';

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
  gender?: '男' | '女';      // Legacy input; never determines relationship role
  questionContext?: QuestionContext;
  castTime?: Date;            // 默认 now
  /** 初爻到上爻，保存后可重放同一卦；6老阴/7少阳/8少阴/9老阳。 */
  lineValues?: (6 | 7 | 8 | 9)[];
}

export type YongShenAnalysis = ReturnType<typeof selectQuestionObjects>;
export type YingQiAnalysis = ReturnType<typeof conditionalTiming>;

export interface HexagramReading {
  question: string;
  questionType: QuestionType;
  questionContext: QuestionContext;
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
  lineValues: (6 | 7 | 8 | 9)[];
  shiYao: number;
  yingYao: number;
  xunKong: string[];
  lines: HexagramLine[];
  /** Shared only by original/changed/hidden context facts, not rule effectiveness. */
  lineContextPolicy: { assessmentStatus:'calendar-relations-only'; sourceIds:string[] };
  guaRelations: ReturnType<typeof guaRelations>;
  roleRelations: ReturnType<typeof roleRelations>;
  tombExtinction: ReturnType<typeof tombExtinction>;
  fanfu: ReturnType<typeof fanfu>;
  ruleSources: RuleSource[];
  method: { algorithm: string; calendar: string; dayBoundary: string; caveats: string[] };
}

export interface CalendarInfluence {
  ganZhi: string;
  branch: string;
  element: WuXing;
  /** Direction is always calendar -> line. */
  elementRelation: '同类' | '生爻' | '克爻' | '爻生' | '爻克';
  sameBranch: boolean;
  clash: boolean;
  combination: boolean;
}

export interface LineContext {
  isVoid: boolean;
  month: CalendarInfluence;
  day: CalendarInfluence;
  monthState: '旺' | '相' | '休' | '囚' | '死';
  assessmentStatus: 'calendar-relations-only';
  sourceIds: string[];
}

export interface RelatedLine {
  ganZhi: string;
  wuXing: WuXing;
  liuQin: LiuQin;
  context: LineContextFacts;
}

export interface HexagramLine {
  rules?: ReturnType<typeof lineRules>;
  position: number;
  value: 6 | 7 | 8 | 9;
  ganZhi: string;
  wuXing: WuXing;
  liuQin: LiuQin;
  liuShen: string;
  isShi: boolean;
  isYing: boolean;
  isChanging: boolean;
  isVoid: boolean;
  monthClash: boolean;
  dayClash: boolean;
  dayCombination: boolean;
  context: LineContextFacts;
  changed?: RelatedLine;
  hidden?: RelatedLine;
}

export type LineContextFacts = Omit<LineContext, 'assessmentStatus' | 'sourceIds'>;
