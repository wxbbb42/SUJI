// BaziEngine 在 jest 环境下无法直接 instantiate（lunisolar fetalGod 插件加载问题），
// 这是项目级别已存在的限制；本测试只关心 buildCandidates 的时辰计算与候选盘装配逻辑，
// 因此用最小 stub 替代真实排盘。
jest.mock('@/lib/bazi/BaziEngine', () => ({
  BaziEngine: jest.fn().mockImplementation(() => ({
    calculate: (birthDate: Date, gender: '男' | '女') => ({
      birthDate,
      gender,
      __stub: true,
    }),
  })),
}));

import { buildCandidates, SHICHEN_ANCHORS } from '../buildCandidates';

describe('buildCandidates', () => {
  it('returns 3 candidates with ±1 时辰 around 戌时 anchor', () => {
    const birth = new Date('1995-08-15T19:30:00+08:00');
    const result = buildCandidates(birth, '男', 116.4);
    expect(result).toHaveLength(3);
    expect(result.map(c => c.id)).toEqual(['before', 'origin', 'after']);
    const hours = result.map(c => c.birthDate.getHours());
    expect(hours).toEqual([18, 20, 22]);
    expect(result[0].mingPan).toBeDefined();
    expect(result[1].mingPan.gender).toBe('男');
  });

  it('SHICHEN_ANCHORS covers all 12 时辰', () => {
    expect(Object.keys(SHICHEN_ANCHORS)).toHaveLength(12);
    expect(SHICHEN_ANCHORS['戌']).toBe(20);
  });

  it('uses next day for after when origin is 亥 and after is 子', () => {
    const birth = new Date('1995-08-15T22:30:00+08:00');
    const result = buildCandidates(birth, '男', 116.4);
    // origin = 亥(22) of 8/15, after = 子(0) of 8/16
    expect(result[2].id).toBe('after');
    expect(result[2].birthDate.getDate()).toBe(16);
    expect(result[2].birthDate.getHours()).toBe(0);
  });

  it('uses previous day for before when origin is 子 (early hours) and before is 亥', () => {
    const birth = new Date('1995-08-15T00:30:00+08:00');
    const result = buildCandidates(birth, '男', 116.4);
    // origin = 子(0) of 8/15, before = 亥(22) of 8/14
    expect(result[0].id).toBe('before');
    expect(result[0].birthDate.getDate()).toBe(14);
    expect(result[0].birthDate.getHours()).toBe(22);
  });

  it('keeps same day when origin is 寅 (no boundary)', () => {
    const birth = new Date('1995-08-15T04:30:00+08:00');
    const result = buildCandidates(birth, '男', 116.4);
    // origin = 寅(4) of 8/15
    expect(result.every(c => c.birthDate.getDate() === 15)).toBe(true);
  });

  it('throws NIGHT_ZISHI_UNSUPPORTED when hour is 23', () => {
    expect(() => buildCandidates(new Date('1995-08-15T23:30:00+08:00'), '男', 116.4))
      .toThrow('NIGHT_ZISHI_UNSUPPORTED');
  });
});
