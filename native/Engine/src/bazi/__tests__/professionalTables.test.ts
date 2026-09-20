import { BaziEngine } from '../BaziEngine';
import { DayunEngine } from '../DayunEngine';
import { computeShiShenOf } from '../structural';
import type { DiZhi, ShiErChangSheng, ShiShen, TianGan } from '../types';

// Literal oracles independently transcribed for this audit; do not derive expected
// values from production constants. Scope: conventional ten-god identities and
// the explicitly selected 阳顺阴逆 / 土随火 twelve-stage table, not force/fortune.
const stems = [...'甲乙丙丁戊己庚辛壬癸'] as TianGan[];
const branches = [...'子丑寅卯辰巳午未申酉戌亥'] as DiZhi[];
const gods = [
  '比肩 劫财 食神 伤官 偏财 正财 七杀 正官 偏印 正印',
  '劫财 比肩 伤官 食神 正财 偏财 正官 七杀 正印 偏印',
  '偏印 正印 比肩 劫财 食神 伤官 偏财 正财 七杀 正官',
  '正印 偏印 劫财 比肩 伤官 食神 正财 偏财 正官 七杀',
  '七杀 正官 偏印 正印 比肩 劫财 食神 伤官 偏财 正财',
  '正官 七杀 正印 偏印 劫财 比肩 伤官 食神 正财 偏财',
  '偏财 正财 七杀 正官 偏印 正印 比肩 劫财 食神 伤官',
  '正财 偏财 正官 七杀 正印 偏印 劫财 比肩 伤官 食神',
  '食神 伤官 偏财 正财 七杀 正官 偏印 正印 比肩 劫财',
  '伤官 食神 正财 偏财 正官 七杀 正印 偏印 劫财 比肩',
].map(row => row.split(' ') as ShiShen[]);
const stages = [
  '沐浴 冠带 临官 帝旺 衰 病 死 墓 绝 胎 养 长生',
  '病 衰 帝旺 临官 冠带 沐浴 长生 养 胎 绝 墓 死',
  '胎 养 长生 沐浴 冠带 临官 帝旺 衰 病 死 墓 绝',
  '绝 墓 死 病 衰 帝旺 临官 冠带 沐浴 长生 养 胎',
  '胎 养 长生 沐浴 冠带 临官 帝旺 衰 病 死 墓 绝',
  '绝 墓 死 病 衰 帝旺 临官 冠带 沐浴 长生 养 胎',
  '死 墓 绝 胎 养 长生 沐浴 冠带 临官 帝旺 衰 病',
  '长生 养 胎 绝 墓 死 病 衰 帝旺 临官 冠带 沐浴',
  '帝旺 衰 病 死 墓 绝 胎 养 长生 沐浴 冠带 临官',
  '临官 冠带 沐浴 长生 养 胎 绝 墓 死 病 衰 帝旺',
].map(row => row.split(' ') as ShiErChangSheng[]);

// Test-only access to the existing implementation, without changing production API.
const tableAPI = BaziEngine as unknown as {
  computeShiShen(day: TianGan, target: TianGan): ShiShen;
  computeChangSheng(stem: TianGan, branch: DiZhi): ShiErChangSheng;
  CANG_GAN: Record<DiZhi, { gan: TianGan; weight: number }[]>;
};

describe('independent professional table audit', () => {
  it('checks all 100 ten-god pairs in all three production implementations', () => {
    stems.forEach((day, row) => stems.forEach((target, column) => {
      const expected = gods[row][column];
      expect({ day, target, value: tableAPI.computeShiShen(day, target) }).toEqual({ day, target, value: expected });
      expect(DayunEngine.computeShiShen(day, target)).toBe(expected);
      expect(computeShiShenOf(day, target)).toBe(expected);
    }));
  });

  it('checks all 120 twelve-stage labels under the declared ten-stem convention', () => {
    stems.forEach((stem, row) => branches.forEach((branch, column) => {
      expect({ stem, branch, value: tableAPI.computeChangSheng(stem, branch) })
        .toEqual({ stem, branch, value: stages[row][column] });
    }));
  });

  it('matches the identities in 渊海子平 又地支藏遁歌 without attributing numeric weights to it', () => {
    // docs/mingli/source-texts/bazi/yuanhai-ziping/01-foundations.md:48.
    const hidden = ['癸', '癸辛己', '甲丙戊', '乙', '乙戊癸', '庚丙戊', '丁己', '乙己丁', '庚壬戊', '辛', '辛丁戊', '壬甲'];
    branches.forEach((branch, index) => {
      expect(tableAPI.CANG_GAN[branch].map(v => v.gan).sort()).toEqual([...hidden[index]].sort());
    });
  });
});
