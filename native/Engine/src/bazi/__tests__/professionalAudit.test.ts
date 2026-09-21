import { BaziEngine } from '../BaziEngine';
import { computeGeJuV2 } from '../structural';
import type { DiZhi, TianGan } from '../types';

/** Independent non-calendar audit. These assert the declared candidate rules,
 * not an empirical forecast or a complete traditional 成败 judgment.
 * Source: 子平真诠评注 /00-abstract-chapters.md:108,152 (财逢劫 / 财忌比劫).
 */
describe('professional audit: the day pillar is a position, not every same-named stem', () => {
  const branches: [DiZhi, DiZhi, DiZhi, DiZhi] = ['子', '辰', '申', '子'];

  it('does not delete the two exposed peers in a real 1984 wealth candidate', () => {
    const p = new BaziEngine().calculate(new Date('1984-04-20T00:30:00+08:00'), '男');
    expect(Object.values(p.siZhu).map(v => v.ganZhi.gan + v.ganZhi.zhi)).toEqual(['甲子', '戊辰', '甲申', '甲子']);
    expect(p.geJuV2).toMatchObject({ name: '偏财格', yongShenShiShen: '偏财', assessmentStatus: 'heuristic-candidate' });
    // The local matrix lists 比肩 as a wealth threat. 年/时甲 cannot vanish
    // merely because the day stem is also 甲. This fixture has no scanned rescue.
    expect(p.geJuV2?.chengBai).toBe('po');
    expect(p.geJuV2?.jiuYing).toBeNull();
  });

  it.each([
    ['year', ['甲', '戊', '甲', '壬']],
    ['month', ['戊', '甲', '甲', '壬']],
    ['hour', ['壬', '戊', '甲', '甲']],
  ] as [string, [TianGan, TianGan, TianGan, TianGan]][])('retains a peer at the %s position', (_, stems) => {
    const g = computeGeJuV2('甲', stems, branches);
    expect(g.name).toBe('偏财格');
    expect(g.chengBai).toBe('po');
  });

  it('still excludes the day master itself when no other peer or robber is exposed', () => {
    const g = computeGeJuV2('甲', ['壬', '戊', '甲', '丙'], branches);
    expect(g.name).toBe('偏财格');
    expect(g.chengBai).toBe('cheng');
    expect(g.jiuYing).toBeNull();
  });

  it('retains the adjacent candidate but does not remove the peer rooted in Chen', () => {
    const g = computeGeJuV2('甲', ['乙', '庚', '甲', '戊'], branches);
    expect(g.name).toBe('偏财格');
    expect(g.chengBai).toBe('po');
    expect(g.jiuYing).toEqual(expect.arrayContaining([expect.objectContaining({ triggerGan: '乙', path: 'qu-qing',
      adjudication:{status:'rooted-role-retained',outcomeEstablished:false} })]));
  });
});

describe('professional audit: rescue candidates bind to each exposed occurrence', () => {
  const branches: [DiZhi, DiZhi, DiZhi, DiZhi] = ['酉', '午', '申', '未'];

  it('does not copy a year-stem rescue onto the remote same-named hour stem', () => {
    const p = new BaziEngine().calculate(new Date('1993-06-08T13:30:00+08:00'), '男');
    expect(Object.values(p.siZhu).map(v => v.ganZhi.gan + v.ganZhi.zhi)).toEqual(['癸酉', '戊午', '庚申', '癸未']);
    const g = p.geJuV2!;
    expect(g.name).toBe('正官格');
    // Under this engine's explicit adjacency rule, 月戊 may address 年癸.
    // 时癸 is two positions away and has no scanned remedy of its own.
    expect(g.chengBai).toBe('po');
    expect(g.jiuYing).toHaveLength(2);
    expect(g.jiuYing).toEqual(expect.arrayContaining([
      expect.objectContaining({ triggerGan: '癸', triggerPosition: 0, remedyPosition: 1, path: 'qu-qing' }),
      expect.objectContaining({ triggerGan: '癸', triggerPosition: 0, remedyPosition: 1, path: 'yin-hua' }),
    ]));
  });

  it('retains both applicable candidate rules for the single adjacent occurrence', () => {
    const g = computeGeJuV2('庚', ['癸', '戊', '庚', '壬'], branches);
    expect(g.chengBai).toBe('jiuying');
    expect(g.jiuYing).toHaveLength(2);
    expect(g.jiuYing).toEqual(expect.arrayContaining([
      expect.objectContaining({ triggerGan: '癸', triggerPosition: 0, remedyPosition: 1, path: 'qu-qing' }),
      expect.objectContaining({ triggerGan: '癸', triggerPosition: 0, remedyPosition: 1, path: 'yin-hua' }),
    ]));
  });

  it('does not invent a rescue when only the remote hour occurrence remains', () => {
    const g = computeGeJuV2('庚', ['壬', '戊', '庚', '癸'], branches);
    expect(g.chengBai).toBe('po');
    expect(g.jiuYing).toBeNull();
  });
});
