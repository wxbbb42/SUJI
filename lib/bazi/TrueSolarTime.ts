/**
 * 真太阳时计算模块
 *
 * 真太阳时 = 北京时间 + 经度时差 + 均时差(EoT)
 *
 * 来源：
 * - 经度时差：(当地经度 - 120°) × 4分钟/度
 *   120° 是东八区中心经线
 * - 均时差（Equation of Time）：地球轨道偏心率 + 黄赤交角导致的
 *   真太阳日与平太阳日的偏差，全年在 -14~+16 分钟之间波动
 */

import { dayOfYear } from '@/lib/utils/date';

/**
 * 计算均时差（Equation of Time），单位：分钟
 *
 * 使用 Spencer(1971) 近似公式，精度约 ±30秒
 * @param date 日期
 * @returns 均时差（分钟），正值表示真太阳时快于平太阳时
 */
function equationOfTime(date: Date): number {
  const doy = dayOfYear(date);

  // B = (360/365) * (dayOfYear - 81) 度
  const B = ((2 * Math.PI) / 365) * (doy - 81);

  // Spencer 公式（分钟）
  const eot =
    9.87 * Math.sin(2 * B) -
    7.53 * Math.cos(B) -
    1.5 * Math.sin(B);

  return eot;
}

/**
 * 将北京时间（东八区标准时间）转换为真太阳时
 *
 * @param date 北京时间的 Date 对象
 * @param longitude 出生地经度（东经为正，西经为负）
 * @returns 修正后的 Date 对象（真太阳时）
 *
 * @example
 * ```ts
 * // 北京时间 1990-08-15 10:00，出生地天津（经度117.1°）
 * const trueSolar = toTrueSolarTime(new Date('1990-08-15T10:00:00+08:00'), 117.1);
 * // 结果约为 1990-08-15 09:44（比北京时间慢约16分钟）
 * ```
 */
export function toTrueSolarTime(date: Date, longitude: number): Date {
  // 1. 经度时差（分钟）：每度差4分钟，东八区中心经线120°
  const longitudeCorrection = (longitude - 120) * 4;

  // 2. 均时差（分钟）
  const eot = equationOfTime(date);

  // 3. 总修正量（分钟）
  const totalCorrectionMinutes = longitudeCorrection + eot;

  // 4. 应用修正
  const result = new Date(date.getTime() + totalCorrectionMinutes * 60 * 1000);

  return result;
}

/**
 * 获取真太阳时修正信息（用于 UI 展示）
 *
 * @param date 北京时间
 * @param longitude 出生地经度
 * @returns 修正详情
 */
export function getTrueSolarTimeInfo(date: Date, longitude: number): {
  /** 原始北京时间 */
  originalTime: Date;
  /** 真太阳时 */
  trueSolarTime: Date;
  /** 经度修正（分钟） */
  longitudeCorrection: number;
  /** 均时差（分钟） */
  eot: number;
  /** 总修正（分钟） */
  totalCorrection: number;
  /** 是否跨时辰（修正前后时辰不同） */
  shiChenChanged: boolean;
  /** 描述文字 */
  description: string;
} {
  const longitudeCorrection = (longitude - 120) * 4;
  const eot = equationOfTime(date);
  const totalCorrection = longitudeCorrection + eot;
  const trueSolarTime = new Date(date.getTime() + totalCorrection * 60 * 1000);

  // 判断是否跨时辰（每个时辰2小时）
  const getShiChen = (d: Date): number => Math.floor(((d.getHours() + 1) % 24) / 2);
  const shiChenChanged = getShiChen(date) !== getShiChen(trueSolarTime);

  const sign = totalCorrection >= 0 ? '快' : '慢';
  const absMin = Math.abs(totalCorrection);
  const min = Math.floor(absMin);
  const sec = Math.round((absMin - min) * 60);

  let description = `经度 ${longitude.toFixed(1)}°`;
  description += `，真太阳时比北京时间${sign} ${min}分${sec}秒`;
  if (shiChenChanged) {
    description += '（⚠️ 时辰已变）';
  }

  return {
    originalTime: date,
    trueSolarTime,
    longitudeCorrection: Math.round(longitudeCorrection * 10) / 10,
    eot: Math.round(eot * 10) / 10,
    totalCorrection: Math.round(totalCorrection * 10) / 10,
    shiChenChanged,
    description,
  };
}

/**
 * 中国主要城市经度表（用于快速选择）
 */
export const CITY_LONGITUDES: Record<string, number> = {
  // 直辖市
  北京: 116.4, 上海: 121.5, 天津: 117.2, 重庆: 106.6,
  // 省会
  石家庄: 114.5, 太原: 112.5, 呼和浩特: 111.7,
  沈阳: 123.4, 长春: 125.3, 哈尔滨: 126.6,
  南京: 118.8, 杭州: 120.2, 合肥: 117.3,
  福州: 119.3, 南昌: 115.9, 济南: 117.0,
  郑州: 113.6, 武汉: 114.3, 长沙: 113.0,
  广州: 113.3, 南宁: 108.4, 海口: 110.3,
  成都: 104.1, 贵阳: 106.7, 昆明: 102.7,
  拉萨: 91.1, 西安: 108.9, 兰州: 103.8,
  西宁: 101.8, 银川: 106.3, 乌鲁木齐: 87.6,
  // 其他重要城市
  深圳: 114.1, 苏州: 120.6, 无锡: 120.3,
  宁波: 121.6, 厦门: 118.1, 青岛: 120.4,
  大连: 121.6, 温州: 120.7, 佛山: 113.1,
  东莞: 113.8, 珠海: 113.6, 中山: 113.4,
  香港: 114.2, 澳门: 113.6, 台北: 121.5,
};
