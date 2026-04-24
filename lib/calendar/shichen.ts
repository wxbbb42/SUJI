/**
 * 时辰能量轴核心模块
 */
import { dayOfYear } from '@/lib/utils/date';

export type DiZhi = '子' | '丑' | '寅' | '卯' | '辰' | '巳' | '午' | '未' | '申' | '酉' | '戌' | '亥';
export type WuXing = '木' | '火' | '土' | '金' | '水';
export type EnergyLevel = '旺' | '平' | '弱';

export type ShichenEntry = {
  zhi: DiZhi;
  hours: string;
  image: string;
  poem: string;
  generalWuXing: WuXing;
  defaultSuitable: string;
};

export type MingPanSummary = {
  yongShen: WuXing;
  xiShen: WuXing;
  jiShen: WuXing;
};

export type ShichenVibe = {
  level: EnergyLevel;
  suitable: string;
};

export const SHICHEN_MAP: ShichenEntry[] = [
  { zhi: '子', hours: '23–01', image: '夜藏', poem: '万物归元', generalWuXing: '水', defaultSuitable: '入眠' },
  { zhi: '丑', hours: '01–03', image: '沉静', poem: '土凝寒气', generalWuXing: '土', defaultSuitable: '深睡' },
  { zhi: '寅', hours: '03–05', image: '苏醒', poem: '万物萌动', generalWuXing: '木', defaultSuitable: '静思' },
  { zhi: '卯', hours: '05–07', image: '日出', poem: '生气勃发', generalWuXing: '木', defaultSuitable: '晨起' },
  { zhi: '辰', hours: '07–09', image: '勤奋', poem: '日精正升', generalWuXing: '土', defaultSuitable: '专注' },
  { zhi: '巳', hours: '09–11', image: '昂扬', poem: '阳气渐盛', generalWuXing: '火', defaultSuitable: '行动' },
  { zhi: '午', hours: '11–13', image: '鼎沸', poem: '阳极将衰', generalWuXing: '火', defaultSuitable: '休整' },
  { zhi: '未', hours: '13–15', image: '和缓', poem: '土厚载物', generalWuXing: '土', defaultSuitable: '沟通' },
  { zhi: '申', hours: '15–17', image: '收敛', poem: '金气渐锋', generalWuXing: '金', defaultSuitable: '决断' },
  { zhi: '酉', hours: '17–19', image: '归栖', poem: '日落金收', generalWuXing: '金', defaultSuitable: '复盘' },
  { zhi: '戌', hours: '19–21', image: '安宁', poem: '暮土藏火', generalWuXing: '土', defaultSuitable: '陪伴' },
  { zhi: '亥', hours: '21–23', image: '归藏', poem: '水润归源', generalWuXing: '水', defaultSuitable: '静读' },
];

const STRONG_VERBS    = ['行动', '开启', '进取', '谈判'];
const NEUTRAL_VERBS   = ['沟通', '书写', '学习', '整理'];
const RECESSIVE_VERBS = ['静心', '休整', '独处', '观照'];

/** 结合命盘、日子计算某时辰的能量和建议 */
export function computeShichenVibe(
  entry: ShichenEntry,
  mingPan: MingPanSummary,
  date: Date,
): ShichenVibe {
  const wx = entry.generalWuXing;
  const doy = dayOfYear(date);

  if (wx === mingPan.yongShen) {
    return { level: '旺', suitable: STRONG_VERBS[doy % STRONG_VERBS.length] };
  }
  if (wx === mingPan.xiShen) {
    return { level: '旺', suitable: NEUTRAL_VERBS[doy % NEUTRAL_VERBS.length] };
  }
  if (wx === mingPan.jiShen) {
    return { level: '弱', suitable: RECESSIVE_VERBS[doy % RECESSIVE_VERBS.length] };
  }
  return { level: '平', suitable: entry.defaultSuitable };
}

/**
 * 返回当前时刻对应的 SHICHEN_MAP 索引（0–11）
 * 子时 = 23:00–01:00，跨日，统一映射到 index 0
 */
export function currentShichenIndex(date: Date): number {
  const h = date.getHours();
  if (h === 23 || h === 0) return 0;
  return Math.floor((h + 1) / 2);
}
