/**
 * 六爻起卦引擎
 *
 * - 三币法：每爻 3 枚硬币（正面=2，反面=3），sum 6/7/8/9 → 老阴/少阳/少阴/老阳
 * - 主卦 + 变卦推导
 * - 用神选择 + 应期推算（基础规则）
 */
import type {
  CastOptions, HexagramReading, Yao, GuaInfo, LiuQin, YongShenAnalysis,
  YingQiAnalysis, QuestionType,
} from './types';
import { findGuaByYao } from './data/gua64';
import { liuQinForGua, PALACE_YAO_WUXING } from './data/liuqin';

export class HexagramEngine {
  cast(opts: CastOptions): HexagramReading {
    const castTime = opts.castTime ?? new Date();

    // ── 1. 起 6 爻
    const benYao: Yao[] = [];
    const bianYao: Yao[] = [];
    const changingYao: number[] = [];
    for (let i = 0; i < 6; i++) {
      const result = this.castSingleYao();
      benYao.push(result.value);
      bianYao.push(result.changing
        ? (result.value === '阴' ? '阳' : '阴')
        : result.value);
      if (result.changing) changingYao.push(i + 1);
    }

    // ── 2. 主/变 卦查表
    const benGua = findGuaByYao(benYao);
    const bianGua = changingYao.length > 0 ? findGuaByYao(bianYao) : benGua;

    // ── 3. 六亲分配
    const liuQin = liuQinForGua(benGua);

    // ── 4. 用神 + 应期
    const yongShen = this.selectYongShen(opts.questionType ?? 'general', opts.gender, liuQin, benGua);
    const yingQi = this.computeYingQi(yongShen, castTime);
    const castGanZhi = this.castTimeToGanZhi(castTime);

    return {
      question: opts.question,
      questionType: opts.questionType ?? 'general',
      castTime: castTime.toISOString(),
      castGanZhi,
      benGua,
      bianGua,
      changingYao,
      yongShen,
      yingQi,
      liuQin,
    };
  }

  /** 单爻起卦：三币法 */
  private castSingleYao(): { value: Yao; changing: boolean } {
    let sum = 0;
    for (let i = 0; i < 3; i++) {
      sum += Math.random() < 0.5 ? 2 : 3;
    }
    switch (sum) {
      case 6: return { value: '阴', changing: true };
      case 7: return { value: '阳', changing: false };
      case 8: return { value: '阴', changing: false };
      case 9: return { value: '阳', changing: true };
      default: throw new Error('unreachable');
    }
  }

  /** 用神选择规则 */
  private selectYongShen(
    qt: QuestionType,
    gender: '男' | '女' | undefined,
    liuQin: Record<1|2|3|4|5|6, LiuQin>,
    gua: GuaInfo,
  ): YongShenAnalysis {
    let target: LiuQin;
    switch (qt) {
      case 'career': target = '官鬼'; break;
      case 'wealth': target = '妻财'; break;
      case 'marriage': target = gender === '男' ? '妻财' : '官鬼'; break;
      case 'kids': target = '子孙'; break;
      case 'parents': target = '父母'; break;
      case 'health': target = '子孙'; break;
      default: target = '官鬼';
    }

    let yaoIndex: 1|2|3|4|5|6 = 1;
    for (let i = 1 as 1|2|3|4|5|6; i <= 6; i = (i + 1) as 1|2|3|4|5|6) {
      if (liuQin[i] === target) { yaoIndex = i; break; }
    }

    return {
      type: target,
      yaoIndex,
      wuXing: PALACE_YAO_WUXING[gua.palace][yaoIndex - 1],
      state: '相', // MVP 用相代默认；Phase 2.5 改为月令推算
      interactions: [],
    };
  }

  /** 应期：用神五行 → 对应地支 → 描述（MVP 用模糊语言） */
  private computeYingQi(yongShen: YongShenAnalysis, castTime: Date): YingQiAnalysis {
    const wxToZhi: Record<string, string> = {
      金: '申酉日或申酉月',
      木: '寅卯日或寅卯月',
      水: '亥子日或亥子月',
      火: '巳午日或巳午月',
      土: '辰戌丑未日或同月',
    };
    return {
      description: `约 1-2 周内，应于${wxToZhi[yongShen.wuXing]}`,
      factors: [`用神五行：${yongShen.wuXing}`, `临爻：${yongShen.yaoIndex}`],
    };
  }

  private castTimeToGanZhi(d: Date): { day: string; month: string; hour: string } {
    return {
      day: dateToGanZhi(d),
      month: monthToGanZhi(d.getFullYear(), d.getMonth() + 1),
      hour: '未',  // MVP 简化
    };
  }
}

// ────────────────────────────────────────────────────────
// 内部 helpers（与 lib/ai/tools/bazi.ts 简化版本一致）
// ────────────────────────────────────────────────────────

const TIANGAN = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
const DIZHI = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];

function dateToGanZhi(d: Date): string {
  const epoch = new Date(1900, 0, 1).getTime();
  const days = Math.floor((d.getTime() - epoch) / 86400000);
  const offset = (10 + days) % 60;
  const adj = offset < 0 ? offset + 60 : offset;
  return TIANGAN[adj % 10] + DIZHI[adj % 12];
}

function monthToGanZhi(year: number, month: number): string {
  const yearOffset = ((year - 1984) % 60 + 60) % 60;
  const yearGan = yearOffset % 10;
  const monthGanStart = (yearGan % 5) * 2 + 2;
  const gan = TIANGAN[(monthGanStart + month - 1) % 10];
  const zhi = DIZHI[(month + 1) % 12];
  return gan + zhi;
}
