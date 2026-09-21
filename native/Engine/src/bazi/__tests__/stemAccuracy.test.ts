import { BaziEngine } from '../BaziEngine';
import { DayunEngine } from '../DayunEngine';
import { assessStemCombination, computeGeJuV2, computeShiShenRelations, detectCongGe, detectHuaQi } from '../structural';

describe('position-aware combinations and exact ten-god identities', () => {
  it('does not turn the 1990 remote Yi/Geng pair into transformed metal or a broken resource configuration', () => {
    const p = new BaziEngine().calculate(new Date('1990-08-15T10:00:00+08:00'), '女', 120);
    expect(Object.values(p.siZhu).map(z => z.ganZhi.gan + z.ganZhi.zhi)).toEqual(['庚午', '甲申', '壬子', '乙巳']);
    const pair = p.stemRelations.find(r => r.type === '天干五合')!;
    expect(pair.heHua).toBeUndefined();
    expect(pair.combinationAssessments?.[0]).toMatchObject({
      positions: [0, 3], adjacent: false, monthSupportsTransformation: true,
      status: 'unresolved', transformationEstablished: false,
    });
    expect(p.geJuV2).toMatchObject({ name: '偏印格', assessmentStatus: 'heuristic-candidate', yongShenGan: '庚', yongShenShiShen: '偏印' });
    expect(p.geJuV2?.chengBai).not.toBe('po');
    expect(p.shiShenRelations).toContainEqual({
      source: { gan: '庚', shiShen: '偏印', position: 0 },
      target: { gan: '甲', shiShen: '食神', position: 1 },
      relation: '克', adjacent: true, pattern: '偏印制食神', outcomeEstablished: false,
    });
    expect(p.shiShenRelations?.filter(r => r.pattern === '偏印制食神').map(r => r.target.gan)).toEqual(['甲']);
    expect(p.shiShenRelations?.find(r => r.target.gan === '乙')).toMatchObject({ pattern: '印制伤官', adjacent: false });
  });

  it('distinguishes an adjacent candidate from remote and adjacent competing pairs', () => {
    expect(assessStemCombination(['庚', '乙', '壬', '丁'], '申', 0, 1)).toMatchObject({ status: 'candidate', competingAdjacentPartner: false });
    expect(assessStemCombination(['庚', '乙', '庚', '丁'], '申', 0, 1)).toMatchObject({ status: 'unresolved', competingAdjacentPartner: true });
    // A duplicate at a remote column is not automatically the same as 夹合.
    expect(assessStemCombination(['庚', '乙', '壬', '乙'], '申', 0, 1)).toMatchObject({ competingAdjacentPartner: false });
    expect(assessStemCombination(['庚', '乙', '壬', '丁'], '卯', 0, 1)).toMatchObject({ status: 'unresolved', monthSupportsTransformation: false });
  });

  it('keeps resource/food and resource/hurting-officer patterns separate across opposite yin-yang day stems', () => {
    const ren = computeShiShenRelations('壬', ['庚', '乙', '壬', '丙']);
    expect(ren.some(r => r.pattern === '偏印制食神')).toBe(false);
    const gui = computeShiShenRelations('癸', ['辛', '乙', '癸', '丁']);
    expect(gui.find(r => r.pattern === '偏印制食神')).toMatchObject({
      source: { gan: '辛', shiShen: '偏印' }, target: { gan: '乙', shiShen: '食神' },
    });
  });

  it('does not erase a remaining exposed useful stem when one copy combines', () => {
    const g = computeGeJuV2('甲', ['丙', '辛', '甲', '辛'], ['午', '酉', '子', '酉']);
    expect(g.name).toBe('正官格');
    expect(g.chengBai).not.toBe('po');
  });

  it('rejects the former Hua-Qi false positive with a small real root and exposed resource', () => {
    expect(detectHuaQi('甲', ['癸', '辛', '甲', '己'], ['午', '戌', '巳', '未'], '无根').isHuaQi).toBe(false);
    expect(computeGeJuV2('甲', ['癸', '辛', '甲', '己'], ['午', '戌', '巳', '未']).category).not.toBe('huaqi');
    expect(detectHuaQi('甲', ['己', '丙', '甲', '戊'], ['午', '戌', '巳', '午'], '无根').isHuaQi).toBe(false);
    expect(detectHuaQi('甲', ['戊', '己', '甲', '己'], ['午', '戌', '巳', '午'], '无根').isHuaQi).toBe(false);
    expect(detectHuaQi('甲', ['戊', '丙', '甲', '己'], ['午', '戌', '巳', '午'], '无根').isHuaQi).toBe(true);
  });

  it('does not discard a same-name day-master peer or exposed resource from a following-chart screen', () => {
    expect(detectCongGe('壬', ['壬', '丙', '壬', '丁'], ['午', '午', '午', '未'], '无根').isCong).toBe(false);
    expect(detectCongGe('壬', ['庚', '丙', '壬', '丁'], ['午', '午', '午', '未'], '无根').isCong).toBe(false);
  });

  it('does not let an arbitrary resource rescue wealth in a killing configuration', () => {
    // 庚日: 丙七杀、乙正财、己正印；乙木克己土, 己 cannot be said to 化乙.
    const g = computeGeJuV2('庚', ['乙', '己', '庚', '丙'], ['卯', '巳', '申', '午']);
    expect(g.name).toBe('七杀格');
    expect(g.jiuYing?.some(r => r.path === 'yin-hua')).not.toBe(true);
    expect(g.chengBai).toBe('po');
  });

  it('requires an actual adjacent control path before assigning resource rescue', () => {
    const remote = computeGeJuV2('甲', ['癸', '辛', '甲', '丁'], ['酉', '酉', '子', '卯']);
    const adjacent = computeGeJuV2('甲', ['癸', '丁', '甲', '辛'], ['酉', '酉', '子', '卯']);
    expect(remote.jiuYing).toBeNull();
    expect(adjacent.jiuYing).toEqual(expect.arrayContaining([expect.objectContaining({ path: 'yin-hua', triggerGan: '丁' })]));
  });

  it('requires the actual month branch before calling a peer a monthly blade or a Lu configuration', () => {
    // 甲's monthly blade is 卯. 乙 emerging from 未 is 劫财, not a 卯月刃.
    const nonBlade = computeGeJuV2('甲', ['乙', '丙', '甲', '庚'], ['亥', '未', '子', '申']);
    expect(nonBlade.name).toBe('劫财透干（格局待辨）');
    expect(nonBlade.phaseId).not.toBe('yueren-ge');
    const blade = computeGeJuV2('甲', ['乙', '庚', '甲', '丁'], ['子', '卯', '申', '午']);
    expect(blade.name).toBe('月刃格');
    const yinPeerMonth = computeGeJuV2('乙', ['甲', '丙', '乙', '庚'], ['子', '寅', '酉', '午']);
    expect(yinPeerMonth.name).toBe('月劫格');
    expect(yinPeerMonth.phaseId).not.toBe('yueren-ge');
    expect(computeGeJuV2('甲', ['甲', '庚', '甲', '丁'], ['子', '寅', '申', '午']).name).toBe('建禄格');
  });

  it('keeps two-branch candidates distinct from complete triples and names the missing branch', () => {
    const p = new BaziEngine().calculate(new Date('1990-08-15T10:00:00+08:00'), '女', 120);
    expect(p.branchRelations).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: '半合候选', branches: ['申', '子'], requiredBranches: ['申', '子', '辰'], missingBranches: ['辰'], completeness: 'partial', outcomeEstablished: false }),
      expect.objectContaining({ type: '三会候选', branches: ['巳', '午'], requiredBranches: ['巳', '午', '未'], missingBranches: ['未'], completeness: 'partial', outcomeEstablished: false }),
    ]));
    expect(p.branchRelations.some(r => (r.type === '三合' || r.type === '三会') && r.branches.length !== 3)).toBe(false);
    const complete = new BaziEngine().calculate(new Date('2024-08-16T08:00:00+08:00'), '男');
    expect(complete.branchRelations).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: '三合', branches: ['申', '子', '辰'], missingBranches: [], completeness: 'complete', outcomeEstablished: false }),
    ]));
    const arch = new BaziEngine().calculate(new Date('2024-08-17T08:00:00+08:00'), '男');
    expect(arch.branchRelations).toEqual(expect.arrayContaining([
      expect.objectContaining({ type: '拱合候选', branches: ['申', '辰'], missingBranches: ['子'], completeness: 'partial' }),
    ]));
  });

  it('does not attribute unapplied tiaohou candidates to timing interactions', () => {
    const p = new BaziEngine().calculate(new Date('1990-08-15T10:00:00+08:00'), '女');
    const dy = new DayunEngine(p);
    const descriptions = Array.from({ length: 10 }, (_, i) => dy.getCurrentLiuNian(2020 + i).interactions).flat().join('');
    expect(descriptions).toContain('扶抑参考');
    expect(descriptions).not.toContain('调候');
  });
});
