import type { YinYangDun, JuNumber } from '../types';

/**
 * 单个节气的起局 entry
 *
 * - jieqi : 节气名（中文，如 "冬至"）
 * - dun   : 阴遁 / 阳遁
 * - upper : 上元局数 (1-9)
 * - middle: 中元局数 (1-9)
 * - lower : 下元局数 (1-9)
 */
export interface JieqiJuEntry {
  jieqi: string;
  dun: YinYangDun;
  upper: JuNumber;
  middle: JuNumber;
  lower: JuNumber;
}

/**
 * 24 节气起局表（24 节气 × 上中下三元 = 72 起局）
 *
 * 数据来源（按 ADR-6 三重验证流程）：
 *   - 来源 A: 道音文化 — 《奇门遁甲用局表》/《奇门遁甲——定局概说》
 *     https://www.daoisms.com.cn/2010/01/12/22941/
 *     https://www.daoisms.com.cn/2010/01/12/23112/
 *   - 来源 B: 国易堂周易算命网《二十四节气与奇门遁甲的阴阳二遁》
 *     https://www.guoyi360.com/qmdj/jz/396.html
 *   - 来源 C: 知乎《节气、三元与奇门局》《梓元奇门遁甲基础13定局数阳遁阴遁》
 *     https://zhuanlan.zhihu.com/p/606125566
 *     https://zhuanlan.zhihu.com/p/648135351
 *
 * 三个来源完整提供《阴阳二遁三元定局歌》：
 *   阳遁顺局：冬至惊蛰一七四，小寒二八五相随，大寒春分三九六，
 *           芒种六三九是仪，谷雨小满五二八，立春八五二相宜，
 *           清明立夏四一七，雨水九六三为期。
 *   阴遁逆局：夏至白露九三六，小暑八二五之间，大暑秋分七一四，
 *           立秋处暑二五八／一四七，霜降小雪五八二，
 *           大雪四七一相关，立冬寒露六九三。
 *
 * 三源一致，无分歧条目。
 *
 * 顺序约定：
 *   - 先排阳遁 12 节气（冬至 → 芒种），再排阴遁 12 节气（夏至 → 大雪）
 *   - 与 chartType.yinYangDun 设计、测试断言一致
 */
export const JIEQI_JU: JieqiJuEntry[] = [
  // ───── 阳遁 12 节气（冬至 ~ 芒种）─────
  { jieqi: '冬至', dun: '阳', upper: 1, middle: 7, lower: 4 },
  { jieqi: '小寒', dun: '阳', upper: 2, middle: 8, lower: 5 },
  { jieqi: '大寒', dun: '阳', upper: 3, middle: 9, lower: 6 },
  { jieqi: '立春', dun: '阳', upper: 8, middle: 5, lower: 2 },
  { jieqi: '雨水', dun: '阳', upper: 9, middle: 6, lower: 3 },
  { jieqi: '惊蛰', dun: '阳', upper: 1, middle: 7, lower: 4 },
  { jieqi: '春分', dun: '阳', upper: 3, middle: 9, lower: 6 },
  { jieqi: '清明', dun: '阳', upper: 4, middle: 1, lower: 7 },
  { jieqi: '谷雨', dun: '阳', upper: 5, middle: 2, lower: 8 },
  { jieqi: '立夏', dun: '阳', upper: 4, middle: 1, lower: 7 },
  { jieqi: '小满', dun: '阳', upper: 5, middle: 2, lower: 8 },
  { jieqi: '芒种', dun: '阳', upper: 6, middle: 3, lower: 9 },

  // ───── 阴遁 12 节气（夏至 ~ 大雪）─────
  { jieqi: '夏至', dun: '阴', upper: 9, middle: 3, lower: 6 },
  { jieqi: '小暑', dun: '阴', upper: 8, middle: 2, lower: 5 },
  { jieqi: '大暑', dun: '阴', upper: 7, middle: 1, lower: 4 },
  { jieqi: '立秋', dun: '阴', upper: 2, middle: 5, lower: 8 },
  { jieqi: '处暑', dun: '阴', upper: 1, middle: 4, lower: 7 },
  { jieqi: '白露', dun: '阴', upper: 9, middle: 3, lower: 6 },
  { jieqi: '秋分', dun: '阴', upper: 7, middle: 1, lower: 4 },
  { jieqi: '寒露', dun: '阴', upper: 6, middle: 9, lower: 3 },
  { jieqi: '霜降', dun: '阴', upper: 5, middle: 8, lower: 2 },
  { jieqi: '立冬', dun: '阴', upper: 6, middle: 9, lower: 3 },
  { jieqi: '小雪', dun: '阴', upper: 5, middle: 8, lower: 2 },
  { jieqi: '大雪', dun: '阴', upper: 4, middle: 7, lower: 1 },
];

/**
 * 按节气名查找起局 entry。
 * 找不到时返回 undefined。
 */
export function findJieqiJu(jieqi: string): JieqiJuEntry | undefined {
  return JIEQI_JU.find((j) => j.jieqi === jieqi);
}
