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

import { beijingDateParts } from '../calendar/precision';

/**
 * NOAA solar-calculator / Meeus equation of time, minutes (apparent minus mean).
 * Julian centuries use the unshifted UTC instant. This is an astronomical model,
 * not an accuracy guarantee about an imprecise recorded birth time.
 * https://gml.noaa.gov/grad/solcalc/calcdetails.html
 */
export function equationOfTime(date: Date): number {
  if (!Number.isFinite(date.getTime())) throw new RangeError('日期无效');
  const t = (date.getTime() / 86400000 + 2440587.5 - 2451545.0) / 36525;
  const rad = Math.PI / 180;
  const l0 = ((280.46646 + t * (36000.76983 + t * 0.0003032)) % 360 + 360) % 360;
  const m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  const seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813));
  const epsilon = 23 + (26 + seconds / 60) / 60 + 0.00256 * Math.cos((125.04 - 1934.136 * t) * rad);
  const y = Math.tan(epsilon * rad / 2) ** 2;
  const value = y * Math.sin(2 * l0 * rad) - 2 * e * Math.sin(m * rad)
    + 4 * e * y * Math.sin(m * rad) * Math.cos(2 * l0 * rad)
    - 0.5 * y * y * Math.sin(4 * l0 * rad) - 1.25 * e * e * Math.sin(2 * m * rad);
  return value / rad * 4;
}

function validateLongitude(longitude: number): void {
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) throw new RangeError('经度须在 -180 至 180 度之间');
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
  validateLongitude(longitude);
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
  validateLongitude(longitude);
  const longitudeCorrection = (longitude - 120) * 4;
  const eot = equationOfTime(date);
  const totalCorrection = longitudeCorrection + eot;
  const trueSolarTime = new Date(date.getTime() + totalCorrection * 60 * 1000);

  // 判断是否跨时辰（每个时辰2小时）
  const getShiChen = (d: Date): number => Math.floor(((beijingDateParts(d).hour + 1) % 24) / 2);
  const shiChenChanged = getShiChen(date) !== getShiChen(trueSolarTime);

  const sign = totalCorrection >= 0 ? '快' : '慢';
  const absMin = Math.abs(totalCorrection);
  const seconds = Math.round(absMin * 60);
  const min = Math.floor(seconds / 60);
  const sec = seconds % 60;

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
