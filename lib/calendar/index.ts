/**
 * 农历/干支/节气 工具
 * TODO: 集成 paipan 库
 */

// 天干
export const TIAN_GAN = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'] as const;

// 地支
export const DI_ZHI = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'] as const;

// 五行
export const WU_XING = ['金', '木', '水', '火', '土'] as const;

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
 * 获取今日信息（占位实现）
 * TODO: 接入 paipan 库的真实算法
 */
export function getTodayInfo(): DailyInfo {
  return {
    solarDate: new Date().toLocaleDateString('zh-CN'),
    lunarDate: '三月十四',  // TODO: 真实农历转换
    ganZhi: '辛巳',         // TODO: 真实日干支
    yearGanZhi: '乙巳',
    monthGanZhi: '庚辰',
    wuxingBalance: { '金': 2, '木': 1, '水': 1, '火': 3, '土': 1 },
  };
}
