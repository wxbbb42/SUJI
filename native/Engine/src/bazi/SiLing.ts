/**
 * 人元司令分野
 *
 * 来源：《三命通会》·人元司令
 *
 * 月令藏干不是全月平均作用，而是按节气后天数分段"当值"。
 * 每个月令分为三段（部分月份两段），每段由不同藏干"司令"。
 *
 * 格式：[藏干, 司令天数]
 * 天数从月节（非中气）开始计算
 */

import type { TianGan, DiZhi } from './types';

/** 人元司令分段 */
export interface SiLingSegment {
  gan: TianGan;    // 司令天干
  days: number;    // 司令天数
  label: string;   // 描述（如"前7天"）
}

/**
 * 月令人元司令表（《三命通会》）
 *
 * 每个月令（地支）的藏干分段当值时间
 * 注意：这里的"天数"是从节气开始计算的
 */
const SILING_TABLE: Record<DiZhi, SiLingSegment[]> = {
  // 寅月（立春后）：戊7天→丙7天→甲16天
  寅: [
    { gan: '戊', days: 7,  label: '前7天戊土司令' },
    { gan: '丙', days: 7,  label: '中7天丙火司令' },
    { gan: '甲', days: 16, label: '后16天甲木司令' },
  ],
  // 卯月（惊蛰后）：甲10天→乙20天
  卯: [
    { gan: '甲', days: 10, label: '前10天甲木司令' },
    { gan: '乙', days: 20, label: '后20天乙木司令' },
  ],
  // 辰月（清明后）：乙9天→癸3天→戊18天
  辰: [
    { gan: '乙', days: 9,  label: '前9天乙木司令' },
    { gan: '癸', days: 3,  label: '中3天癸水司令' },
    { gan: '戊', days: 18, label: '后18天戊土司令' },
  ],
  // 巳月（立夏后）：戊5天→庚9天→丙16天
  巳: [
    { gan: '戊', days: 5,  label: '前5天戊土司令' },
    { gan: '庚', days: 9,  label: '中9天庚金司令' },
    { gan: '丙', days: 16, label: '后16天丙火司令' },
  ],
  // 午月（芒种后）：丙10天→己9天→丁11天
  午: [
    { gan: '丙', days: 10, label: '前10天丙火司令' },
    { gan: '己', days: 9,  label: '中9天己土司令' },
    { gan: '丁', days: 11, label: '后11天丁火司令' },
  ],
  // 未月（小暑后）：丁9天→乙3天→己18天
  未: [
    { gan: '丁', days: 9,  label: '前9天丁火司令' },
    { gan: '乙', days: 3,  label: '中3天乙木司令' },
    { gan: '己', days: 18, label: '后18天己土司令' },
  ],
  // 申月（立秋后）：己7天→壬7天→庚16天
  申: [
    { gan: '己', days: 7,  label: '前7天己土司令' },
    { gan: '壬', days: 7,  label: '中7天壬水司令' },
    { gan: '庚', days: 16, label: '后16天庚金司令' },
  ],
  // 酉月（白露后）：庚10天→辛20天
  酉: [
    { gan: '庚', days: 10, label: '前10天庚金司令' },
    { gan: '辛', days: 20, label: '后20天辛金司令' },
  ],
  // 戌月（寒露后）：辛9天→丁3天→戊18天
  戌: [
    { gan: '辛', days: 9,  label: '前9天辛金司令' },
    { gan: '丁', days: 3,  label: '中3天丁火司令' },
    { gan: '戊', days: 18, label: '后18天戊土司令' },
  ],
  // 亥月（立冬后）：戊7天→甲5天→壬18天
  亥: [
    { gan: '戊', days: 7,  label: '前7天戊土司令' },
    { gan: '甲', days: 5,  label: '中5天甲木司令' },
    { gan: '壬', days: 18, label: '后18天壬水司令' },
  ],
  // 子月（大雪后）：壬10天→癸20天
  子: [
    { gan: '壬', days: 10, label: '前10天壬水司令' },
    { gan: '癸', days: 20, label: '后20天癸水司令' },
  ],
  // 丑月（小寒后）：癸9天→辛3天→己18天
  丑: [
    { gan: '癸', days: 9,  label: '前9天癸水司令' },
    { gan: '辛', days: 3,  label: '中3天辛金司令' },
    { gan: '己', days: 18, label: '后18天己土司令' },
  ],
};

/**
 * 获取月令人元司令分段表
 *
 * @param monthZhi 月令地支
 * @returns 该月令的人元司令分段列表
 */
export function getSiLingSegments(monthZhi: DiZhi): SiLingSegment[] {
  return SILING_TABLE[monthZhi];
}

/**
 * 根据节气后天数，确定当前司令天干
 *
 * @param monthZhi 月令地支
 * @param daysAfterJie 从月节（立春/惊蛰/清明...）后经过的天数
 * @returns 当前司令天干及描述
 */
export function getCurrentSiLing(
  monthZhi: DiZhi,
  daysAfterJie: number,
): { gan: TianGan; label: string } {
  const segments = SILING_TABLE[monthZhi];
  let accumulated = 0;

  for (const seg of segments) {
    accumulated += seg.days;
    if (daysAfterJie <= accumulated) {
      return { gan: seg.gan, label: seg.label };
    }
  }

  // 超出范围则返回最后一段
  const last = segments[segments.length - 1];
  return { gan: last.gan, label: last.label };
}

/**
 * 获取月令默认司令（本气，即占时最长的藏干）
 * 用于简化场景，不需要精确天数时
 *
 * @param monthZhi 月令地支
 * @returns 本气天干
 */
export function getDefaultSiLing(monthZhi: DiZhi): TianGan {
  const segments = SILING_TABLE[monthZhi];
  // 取占时最长的段
  let max = segments[0];
  for (const seg of segments) {
    if (seg.days > max.days) max = seg;
  }
  return max.gan;
}
