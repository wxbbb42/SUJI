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
});
