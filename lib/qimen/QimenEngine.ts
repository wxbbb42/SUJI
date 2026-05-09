/**
 * 奇门遁甲起局引擎
 *
 * - 真太阳时校正
 * - lunisolar 节气计算
 * - 阴/阳遁 + 上中下元定局
 * - 起 9 宫地盘（自然数序流转）+ 真旋天盘 + 排八门 / 九星 / 八神
 *
 * 关键修复（2026-04-26，原 ADR-7 关停项）：
 *   C1：真旋天盘 — 见 helpers/tianPan.ts
 *   C2：三奇六仪按自然数序流转（非后天八卦顺时针）— 见 helpers/diPan.ts
 *
 * 仍简化的项（标 TODO）：
 *   - 上中下元用日干索引近似（未严格按"节气交接日的甲子日"算上元起点）
 *   - 用神 / 应期为 MVP 简化
 */
import { toTrueSolarTime } from '@/lib/bazi/TrueSolarTime';
import type {
  QimenChart, Palace, SetupOptions, YinYangDun, JuNumber, Yuan,
  TianGan, BamenName, BashenName, JiuxingName, GeJu,
  QuestionType, YongShenAnalysis, YingQiAnalysis, QimenMethodMeta,
} from './types';
import { PALACES_BASE } from './data/palaces';
import { BAMEN_ORDER } from './data/bamen';
import { JIUXING_DI_PAN_FIXED } from './data/jiuxing';
import { BASHEN_ORDER } from './data/bashen';
import { findJieqiJu } from './data/jieqi-ju';
import { YONGSHEN_RULES } from './data/yongshen-rules';
import { detectGeJu } from './data/geju';
import { buildDiPan } from './helpers/diPan';
import { rotateTianPan, computeXunShou, PALACE_CLOCKWISE_8 } from './helpers/tianPan';
import { computeTimePillars } from './helpers/timeGanZhi';
import { currentSolarTerm } from './helpers/solarTerms';

const QIMEN_METHOD: QimenMethodMeta = {
  level: 'mvp',
  caveats: [
    '上中下元使用日序近似，尚未按节气交接后的甲子日严格起上元',
    '用神选择与应期为产品 MVP 简化规则',
    '格局识别只覆盖当前数据表可判定的常用格局',
  ],
};

const GAN_WUXING: Record<TianGan, '金' | '木' | '水' | '火' | '土'> = {
  甲: '木', 乙: '木',
  丙: '火', 丁: '火',
  戊: '土', 己: '土',
  庚: '金', 辛: '金',
  壬: '水', 癸: '水',
};

const SHENG: Record<'金' | '木' | '水' | '火' | '土', '金' | '木' | '水' | '火' | '土'> = {
  木: '火', 火: '土', 土: '金', 金: '水', 水: '木',
};

const KE: Record<'金' | '木' | '水' | '火' | '土', '金' | '木' | '水' | '火' | '土'> = {
  木: '土', 土: '水', 水: '火', 火: '金', 金: '木',
};

export class QimenEngine {
  setup(opts: SetupOptions): QimenChart {
    const setupTime = opts.setupTime ?? new Date();
    const longitude = opts.longitude ?? 116.4;

    // 1. 真太阳时
    const trueSolar = toTrueSolarTime(setupTime, longitude);

    // 2. 节气
    const jieqi = currentSolarTerm(trueSolar);

    // 3. 阴阳遁 + 局数 + 元
    const jieqiJu = findJieqiJu(jieqi);
    if (!jieqiJu) {
      throw new Error(`unknown jieqi: ${jieqi}`);
    }
    const yinYangDun: YinYangDun = jieqiJu.dun;
    const yuan: Yuan = this.computeYuan(trueSolar);
    const juNumber: JuNumber = yuan === '上' ? jieqiJu.upper :
                                yuan === '中' ? jieqiJu.middle :
                                jieqiJu.lower;

    // 4. 起 9 宫地盘干（自然数序流转）
    const diPan = buildDiPan(yinYangDun, juNumber);

    // 5. 计算时干 / 旬首
    const pillars = computeTimePillars(trueSolar);
    const timeGan = pillars.hourGan;
    const xunShou = computeXunShou(pillars.hourGan, pillars.hourZhi);

    // 6. 旋天盘
    const { tianPan, tianJiuxing, zhiFuPalaceId } = rotateTianPan(diPan, xunShou, timeGan, yinYangDun);

    // 7. 排八门 / 九星 / 八神
    const palaces = this.buildPalaces(diPan, tianPan, tianJiuxing, zhiFuPalaceId, yinYangDun);

    // 8. 用神 + 应期
    const yongShen = this.selectYongShen(opts.questionType, opts.gender, palaces, timeGan);
    const yingQi = this.computeYingQi(yongShen);

    // 9. 格局识别
    const partialChart: QimenChart = {
      question: opts.question,
      questionType: opts.questionType,
      setupTime: setupTime.toISOString(),
      trueSolarTime: trueSolar.toISOString(),
      jieqi,
      yinYangDun,
      juNumber,
      yuan,
      palaces,
      yongShen,
      geJu: [] as GeJu[],
      yingQi,
      method: QIMEN_METHOD,
    };
    const geJu = detectGeJu(partialChart);

    return { ...partialChart, geJu };
  }

  /** 按 questionType 选用神，辅看 secondaryMen / Shen / Star 同宫加分 */
  private selectYongShen(
    qt: QuestionType,
    gender: '男' | '女' | undefined,
    palaces: Palace[],
    timeGan: TianGan,
  ): YongShenAnalysis {
    const rule = YONGSHEN_RULES[qt];
    let targetGan: string = rule.primaryGan === 'time' ? timeGan : rule.primaryGan;

    // marriage 场景：男看妻、女看夫，简化都看庚（plan 已说明）
    if (qt === 'marriage') {
      targetGan = '庚';
    }

    // 找 targetGan 所在宫（先找天盘，找不到再找地盘）
    const palace = palaces.find(p => p.tianPanGan === targetGan)
                ?? palaces.find(p => p.diPanGan === targetGan);

    if (!palace) {
      return {
        type: targetGan,
        palaceId: 1 as 1,
        state: '不上卦',
        summary: `用神 ${targetGan} 不上卦（伏神）`,
        interactions: ['用神不在 9 宫显现'],
      };
    }

    // 检查辅看的门 / 神 / 星是否同宫（加分）
    const interactions: string[] = [];
    if (rule.secondaryMen && palace.bamen === rule.secondaryMen) {
      interactions.push(`临${rule.secondaryMen}（吉门加分）`);
    }
    if (rule.secondaryShen && palace.bashen === rule.secondaryShen) {
      interactions.push(`临${rule.secondaryShen}（神助）`);
    }
    if (rule.secondaryStar && palace.jiuxing === rule.secondaryStar) {
      interactions.push(`临${rule.secondaryStar}星（星映）`);
    }
    const state = this.computeYongShenState(targetGan as TianGan, palace);
    interactions.unshift(`宫位五行判${state}`);

    return {
      type: targetGan,
      palaceId: palace.id,
      state,
      summary: `${targetGan}临${palace.name}，${state}（${palace.bamen ?? '无门'} · ${palace.jiuxing} · ${palace.bashen ?? '无神'}）`,
      interactions,
    };
  }

  private computeYongShenState(gan: TianGan, palace: Palace): YongShenAnalysis['state'] {
    const ganWx = GAN_WUXING[gan];
    const palaceWx = palace.wuXing;
    if (palaceWx === ganWx) return '旺';
    if (SHENG[palaceWx] === ganWx) return '相';
    if (SHENG[ganWx] === palaceWx) return '休';
    if (KE[ganWx] === palaceWx) return '囚';
    return '死';
  }

  /** 应期推算（MVP 简化） */
  private computeYingQi(yongShen: YongShenAnalysis): YingQiAnalysis {
    if (yongShen.state === '不上卦') {
      return {
        description: '用神不上卦，应期难定',
        factors: ['用神未在 9 宫显现'],
      };
    }
    return {
      description: '约 1-3 个月内见分晓',
      factors: [`用神：${yongShen.summary}`],
    };
  }

  /** 上中下元判定（MVP 简化：用日数 mod 10 近似） */
  private computeYuan(time: Date): Yuan {
    const day = Math.floor(time.getTime() / 86400000);
    const ganIdx = ((day % 10) + 10) % 10;
    if (ganIdx <= 3) return '上';
    if (ganIdx <= 6) return '中';
    return '下';
  }

  /** 排八门 / 九星 / 八神 */
  private buildPalaces(
    diPan: Map<number, TianGan>,
    tianPan: Map<number, TianGan>,
    tianJiuxing: Map<number, JiuxingName>,
    zhiFuPalaceId: number,
    dun: YinYangDun,
  ): Palace[] {
    // 直符宫已由 rotateTianPan 算出（= 时干所在地盘宫）。
    // 若直符宫落中 5（时干未上卦边缘场景），降级到坎宫。
    let zhiFuOuter = PALACE_CLOCKWISE_8.includes(zhiFuPalaceId) ? zhiFuPalaceId : 1;

    // 八门起点：开门起直符宫，阳遁顺时针、阴遁逆时针
    const menSequence = dun === '阳' ? [...PALACE_CLOCKWISE_8] : [...PALACE_CLOCKWISE_8].reverse();
    const zhiFuIdxInMen = menSequence.indexOf(zhiFuOuter);
    const bamenMap = new Map<number, BamenName>();
    for (let i = 0; i < 8; i++) {
      const pid = menSequence[(zhiFuIdxInMen + i) % 8];
      bamenMap.set(pid, BAMEN_ORDER[i]);
    }

    // 八神：值符神在直符宫，按 BASHEN_ORDER 顺/逆布
    const shenSequence = dun === '阳' ? [...PALACE_CLOCKWISE_8] : [...PALACE_CLOCKWISE_8].reverse();
    const zhiFuIdxInShen = shenSequence.indexOf(zhiFuOuter);
    const bashenMap = new Map<number, BashenName>();
    for (let i = 0; i < 8; i++) {
      const pid = shenSequence[(zhiFuIdxInShen + i) % 8];
      bashenMap.set(pid, BASHEN_ORDER[i]);
    }

    return PALACES_BASE.map(base => ({
      ...base,
      diPanGan: diPan.get(base.id) ?? null,
      tianPanGan: tianPan.get(base.id) ?? null,
      bamen: base.id === 5 ? null : (bamenMap.get(base.id) ?? null),
      // 天盘九星（旋后）；中 5 固定为天禽
      jiuxing: tianJiuxing.get(base.id) ?? JIUXING_DI_PAN_FIXED[base.id],
      bashen: base.id === 5 ? null : (bashenMap.get(base.id) ?? null),
    }));
  }
}
