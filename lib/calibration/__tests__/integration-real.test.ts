/**
 * end-to-end 设计验证：成年用户 + ±1 时辰 → bifurcation 必须非空。
 *
 * 用真实 BaziEngine + ZiweiEngine + iztro，不 mock 任何引擎。
 * 这条测试如果回到 0，说明紫微大限信号没真接入，必须迭代到非零。
 *
 * 历史背景：八字大运由「年柱+月柱+性别」决定，不依赖时辰，
 * 三盘的八字事件序列完全相同 → bifurcation 永远空。
 * 紫微大限由命宫位置决定，时辰平移 1 → 命宫平移 1 宫 → 大限干支序列变化
 * → 同年份不同盘转出不同十神 → bifurcation 非空。
 */
import { buildCandidates } from '../buildCandidates';
import { detectBifurcations } from '../bifurcation';

describe('CalibrationSession real-engines integration', () => {
  it('produces non-empty bifurcations for adult user (real engines)', () => {
    // 1995 年生（2026 年时 31 岁），戌时（19:30）出生
    const cands = buildCandidates(new Date('1995-08-15T19:30:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
  });

  it('produces non-empty bifurcations for female adult born 1990 (real engines)', () => {
    const cands = buildCandidates(new Date('1990-03-12T14:00:00+08:00'), '女', 121.5);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
  });

  it('produces non-empty bifurcations for male adult born 2000 (real engines)', () => {
    const cands = buildCandidates(new Date('2000-11-23T09:00:00+08:00'), '男', 116.4);
    const bifs = detectBifurcations(cands, 2026);
    expect(bifs.length).toBeGreaterThan(0);
  });
});
