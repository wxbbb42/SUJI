/**
 * 农历/干支/节气工具
 *
 * 该模块只提供通用日期信息，不负责个人命盘推演。
 * 命盘相关逻辑请使用 lib/bazi / lib/qimen 等专门引擎。
 */

import lunisolar from 'lunisolar';

// 天干
export const TIAN_GAN = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'] as const;

// 地支
export const DI_ZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'] as const;

// 五行
export const WU_XING = ['金', '木', '水', '火', '土'] as const;

const WUXING_KEYS = ['金', '木', '水', '火', '土'] as const;

// 天干对应五行
export const GAN_WUXING: Record<string, string> = {
  '甲': '木', '乙': '木',
  '丙': '火', '丁': '火',
  '戊': '土', '己': '土',
  '庚': '金', '辛': '金',
  '壬': '水', '癸': '水',
};

// 地支对应五行
export const ZHI_WUXING: Record<string, string> = {
  '子': '水', '丑': '土', '寅': '木', '卯': '木',
  '辰': '土', '巳': '火', '午': '火', '未': '土',
  '申': '金', '酉': '金', '戌': '土', '亥': '水',
};

// 二十四节气
export const SOLAR_TERMS = [
  '小寒', '大寒', '立春', '雨水', '惊蛰', '春分',
  '清明', '谷雨', '立夏', '小满', '芒种', '夏至',
  '小暑', '大暑', '立秋', '处暑', '白露', '秋分',
  '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
] as const;

export interface DailyInfo {
  solarDate: string;      // 公历日期
  lunarDate: string;      // 农历日期
  ganZhi: string;         // 日干支
  yearGanZhi: string;     // 年干支
  monthGanZhi: string;    // 月干支
  solarTerm?: string;     // 节气（如有）
  wuxingBalance: Record<string, number>;  // 五行分布
}

/**
 * 获取指定日期的通用历法信息。
 *
 * 说明：五行分布仅统计年月日三柱的天干地支，不等同于个人八字强弱。
 */
export function getTodayInfo(date: Date = new Date()): DailyInfo {
  const lsr = lunisolar(date);
  const lunar = lsr.lunar;
  const yearGanZhi = lsr.format('cY');
  const monthGanZhi = lsr.format('cM');
  const ganZhi = lsr.format('cD');
  const lunarDate = `${lunar.getMonthName()}${lunar.getDayName()}`;

  const wuxingBalance = Object.fromEntries(WUXING_KEYS.map(k => [k, 0])) as Record<string, number>;
  for (const char of `${yearGanZhi}${monthGanZhi}${ganZhi}`) {
    const wx = GAN_WUXING[char] ?? ZHI_WUXING[char];
    if (wx) wuxingBalance[wx] = (wuxingBalance[wx] ?? 0) + 1;
  }

  return {
    solarDate: date.toLocaleDateString('zh-CN'),
    lunarDate,
    ganZhi,
    yearGanZhi,
    monthGanZhi,
    solarTerm: lsr.solarTerm?.toString(),
    wuxingBalance,
  };
}
