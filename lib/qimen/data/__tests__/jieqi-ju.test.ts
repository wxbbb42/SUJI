import { JIEQI_JU, findJieqiJu } from '../jieqi-ju';

describe('JIEQI_JU', () => {
  it('has exactly 24 entries', () => {
    expect(JIEQI_JU).toHaveLength(24);
  });

  it('first 12 are 阳遁', () => {
    for (let i = 0; i < 12; i++) {
      expect(JIEQI_JU[i].dun).toBe('阳');
    }
  });

  it('last 12 are 阴遁', () => {
    for (let i = 12; i < 24; i++) {
      expect(JIEQI_JU[i].dun).toBe('阴');
    }
  });

  it('all 局 are in 1-9', () => {
    for (const j of JIEQI_JU) {
      expect(j.upper).toBeGreaterThanOrEqual(1);
      expect(j.upper).toBeLessThanOrEqual(9);
      expect(j.middle).toBeGreaterThanOrEqual(1);
      expect(j.middle).toBeLessThanOrEqual(9);
      expect(j.lower).toBeGreaterThanOrEqual(1);
      expect(j.lower).toBeLessThanOrEqual(9);
    }
  });

  it('findJieqiJu can lookup by name', () => {
    const dongzhi = findJieqiJu('冬至');
    expect(dongzhi).toBeDefined();
    expect(dongzhi!.dun).toBe('阳');

    const xiazhi = findJieqiJu('夏至');
    expect(xiazhi).toBeDefined();
    expect(xiazhi!.dun).toBe('阴');
  });

  // 5 个 known-correct fixture（来自《阴阳二遁三元定局歌》三源 cross-reference）
  it('冬至 上元 1, 中元 7, 下元 4', () => {
    const j = findJieqiJu('冬至')!;
    expect(j.upper).toBe(1);
    expect(j.middle).toBe(7);
    expect(j.lower).toBe(4);
  });

  it('夏至 上元 9, 中元 3, 下元 6', () => {
    const j = findJieqiJu('夏至')!;
    expect(j.upper).toBe(9);
    expect(j.middle).toBe(3);
    expect(j.lower).toBe(6);
  });

  it('谷雨 上元 5, 中元 2, 下元 8', () => {
    const j = findJieqiJu('谷雨')!;
    expect(j.upper).toBe(5);
    expect(j.middle).toBe(2);
    expect(j.lower).toBe(8);
  });

  it('立春 上元 8, 中元 5, 下元 2', () => {
    const j = findJieqiJu('立春')!;
    expect(j.upper).toBe(8);
    expect(j.middle).toBe(5);
    expect(j.lower).toBe(2);
  });

  it('立秋 上元 2, 中元 5, 下元 8', () => {
    const j = findJieqiJu('立秋')!;
    expect(j.upper).toBe(2);
    expect(j.middle).toBe(5);
    expect(j.lower).toBe(8);
  });
});
