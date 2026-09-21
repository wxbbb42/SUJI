/**
 * 多派加权投票 + open_phase 逃逸阀（Phase 0.5 骨架）
 *
 * 借鉴：bazi-life-curves `multi_school_vote.py` + `phase_posterior.py:80–120`
 *   仓库：https://github.com/XiaoChu-1208/bazi-life-curves
 *   License: MIT
 *
 * 学理：扶抑 / 调候 / 格局 三派各持一端，单派独断易偏。
 * 让派别在后验层加权竞争；当 top1 信心不足或 top1/top2 太接近时，
 * 主动落 open_phase（坦白说"不知道"），不强行独断。
 *
 * 工程注意：
 *  - 默认权重 ziping 0.25 / tiaohou 0.40 / geju 0.30 / mangpai 0
 *    来自 bazi-life-curves calibration/dataset.yaml 5 人 15 事件回测；
 *  - open_phase 阈值 minTop1 0.55 / minGap 0.10 同样为经验值。
 *  - 标 `engineering_threshold_borrowed_from_open_source`，
 *    见 docs/mingli/claims.json `bazi.school-vote.weights-borrowed`
 *    与 `bazi.open-phase.thresholds-borrowed`。
 *
 * 当前未被 BaziEngine 调用；Phase 2 才接管 determineGeJu。
 */

import type {
  AggregatedCandidate,
  PhaseDecision,
  SchoolName,
  SchoolVote,
} from './types';

/** 默认派权重（adapted from bazi-life-curves `_school_registry.py:157–194`） */
export const DEFAULT_SCHOOL_WEIGHTS: Record<SchoolName, number> = {
  ziping: 0.25,    // 子平真诠：扶抑
  tiaohou: 0.40,   // 穷通宝鉴：调候
  geju: 0.30,      // 滴天髓：格局
  mangpai: 0,      // 盲派：仅事件反向，不进格局融合
};

/** open_phase 阈值（adapted from bazi-life-curves `phase_posterior.py:80–120`） */
export const OPEN_PHASE_THRESHOLDS = {
  /** top1 后验低于此 → open_phase */
  minTop1: 0.55,
  /** top1 与 top2 差距小于此 → open_phase */
  minGap: 0.10,
};

/**
 * 聚合多派候选，按派权重加权后归一化
 */
export function aggregate(votes: SchoolVote[]): AggregatedCandidate[] {
  const totalWeight = votes.reduce((s, v) => s + Math.max(v.weight, 0), 0);
  if (totalWeight <= 0) return [];

  const bucket = new Map<string, { score: number; schools: Set<SchoolName> }>();
  for (const vote of votes) {
    if (vote.weight <= 0) continue;
    for (const cand of vote.candidates) {
      const entry = bucket.get(cand.phaseId) ?? { score: 0, schools: new Set<SchoolName>() };
      entry.score += (vote.weight / totalWeight) * cand.confidence;
      entry.schools.add(vote.school);
      bucket.set(cand.phaseId, entry);
    }
  }

  return Array.from(bucket.entries())
    .map(([phaseId, { score, schools }]) => ({
      phaseId,
      posterior: score,
      contributingSchools: Array.from(schools),
    }))
    .sort((a, b) => b.posterior - a.posterior);
}

/**
 * 多派加权投票 → 决策
 *
 * 决策规则（任一触发 open_phase）：
 *  1. 无候选；
 *  2. top1.posterior < minTop1；
 *  3. (top1 - top2) < minGap。
 *
 * @param votes 各派候选输出
 * @param thresholds 可覆盖默认阈值
 */
export function decidePhase(
  votes: SchoolVote[],
  thresholds = OPEN_PHASE_THRESHOLDS,
): PhaseDecision {
  const ranked = aggregate(votes);
  const topCandidates = ranked.slice(0, 3);

  if (ranked.length === 0) {
    return {
      status: 'open_phase',
      phaseId: null,
      confidence: 0,
      topCandidates: [],
      reason: 'low_top1',
    };
  }

  const [top1, top2] = ranked;

  if (top1.posterior < thresholds.minTop1) {
    return {
      status: 'open_phase',
      phaseId: null,
      confidence: top1.posterior,
      topCandidates,
      reason: 'low_top1',
    };
  }

  if (top2 && top1.posterior - top2.posterior < thresholds.minGap) {
    return {
      status: 'open_phase',
      phaseId: null,
      confidence: top1.posterior,
      topCandidates,
      reason: 'narrow_gap',
    };
  }

  return {
    status: 'decided',
    phaseId: top1.phaseId,
    confidence: top1.posterior,
    topCandidates,
    reason: null,
  };
}
