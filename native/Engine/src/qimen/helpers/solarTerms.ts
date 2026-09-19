/**
 * 24 节气按太阳黄经切分。
 * 奇门定局必须按交节时刻，而不是只看交节日期。
 */

const SOLAR_TERM_BY_LONGITUDE: Record<number, string> = {
  285: '小寒',
  300: '大寒',
  315: '立春',
  330: '雨水',
  345: '惊蛰',
  0: '春分',
  15: '清明',
  30: '谷雨',
  45: '立夏',
  60: '小满',
  75: '芒种',
  90: '夏至',
  105: '小暑',
  120: '大暑',
  135: '立秋',
  150: '处暑',
  165: '白露',
  180: '秋分',
  195: '寒露',
  210: '霜降',
  225: '立冬',
  240: '小雪',
  255: '大雪',
  270: '冬至',
};

function normalizeDegrees(deg: number): number {
  return ((deg % 360) + 360) % 360;
}

function julianDay(date: Date): number {
  return date.getTime() / 86400000 + 2440587.5;
}

function solarLongitude(date: Date): number {
  const t = (julianDay(date) - 2451545.0) / 36525;
  const l0 = normalizeDegrees(280.46646 + 36000.76983 * t + 0.0003032 * t * t);
  const m = normalizeDegrees(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
  const omega = 125.04 - 1934.136 * t;
  const mr = (m * Math.PI) / 180;
  const center =
    Math.sin(mr) * (1.914602 - 0.004817 * t - 0.000014 * t * t) +
    Math.sin(2 * mr) * (0.019993 - 0.000101 * t) +
    Math.sin(3 * mr) * 0.000289;
  const trueLong = l0 + center;
  return normalizeDegrees(trueLong - 0.00569 - 0.00478 * Math.sin((omega * Math.PI) / 180));
}

export function currentSolarTerm(date: Date): string {
  const longitude = solarLongitude(date);
  const termLongitude = Math.floor(longitude / 15) * 15;
  return SOLAR_TERM_BY_LONGITUDE[termLongitude] ?? '冬至';
}

