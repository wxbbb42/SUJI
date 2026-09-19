import {
  aggregate,
  decidePhase,
  DEFAULT_SCHOOL_WEIGHTS,
  OPEN_PHASE_THRESHOLDS,
} from '../multiSchoolVote';
import type { SchoolVote } from '../types';

const vote = (
  school: SchoolVote['school'],
  weight: number,
  candidates: { phaseId: string; confidence: number }[],
): SchoolVote => ({
  school,
  weight,
  candidates: candidates.map((c) => ({
    phaseId: c.phaseId,
    confidence: c.confidence,
    source: '《子平真诠》',
  })),
});

describe('multiSchoolVote (Phase 0.5)', () => {
  describe('default constants', () => {
    it('weights match leverage report (25/40/30/0)', () => {
      expect(DEFAULT_SCHOOL_WEIGHTS.ziping).toBe(0.25);
      expect(DEFAULT_SCHOOL_WEIGHTS.tiaohou).toBe(0.40);
      expect(DEFAULT_SCHOOL_WEIGHTS.geju).toBe(0.30);
      expect(DEFAULT_SCHOOL_WEIGHTS.mangpai).toBe(0);
    });
    it('open_phase thresholds match (0.55 / 0.10)', () => {
      expect(OPEN_PHASE_THRESHOLDS.minTop1).toBe(0.55);
      expect(OPEN_PHASE_THRESHOLDS.minGap).toBe(0.10);
    });
  });

  describe('aggregate', () => {
    it('weighted normalization across schools', () => {
      const ranked = aggregate([
        vote('ziping', 0.25, [{ phaseId: 'A', confidence: 1.0 }]),
        vote('tiaohou', 0.40, [{ phaseId: 'A', confidence: 1.0 }]),
        vote('geju', 0.30, [{ phaseId: 'B', confidence: 1.0 }]),
      ]);
      expect(ranked[0].phaseId).toBe('A');
      // A 后验 = (0.25 + 0.40) / 0.95 ≈ 0.684
      expect(ranked[0].posterior).toBeCloseTo(0.65 / 0.95, 5);
      expect(ranked[0].contributingSchools.sort()).toEqual(['tiaohou', 'ziping']);
      expect(ranked[1].phaseId).toBe('B');
    });

    it('zero-weight schools ignored', () => {
      const ranked = aggregate([
        vote('mangpai', 0, [{ phaseId: 'X', confidence: 1.0 }]),
        vote('ziping', 0.25, [{ phaseId: 'Y', confidence: 1.0 }]),
      ]);
      expect(ranked.length).toBe(1);
      expect(ranked[0].phaseId).toBe('Y');
    });
  });

  describe('decidePhase', () => {
    it('clear winner → decided', () => {
      const decision = decidePhase([
        vote('ziping', 0.25, [{ phaseId: 'WIN', confidence: 1.0 }]),
        vote('tiaohou', 0.40, [{ phaseId: 'WIN', confidence: 1.0 }]),
        vote('geju', 0.30, [{ phaseId: 'WIN', confidence: 1.0 }]),
      ]);
      expect(decision.status).toBe('decided');
      expect(decision.phaseId).toBe('WIN');
      expect(decision.confidence).toBeCloseTo(1.0, 5);
      expect(decision.reason).toBeNull();
    });

    it('top1 < minTop1 → open_phase / low_top1', () => {
      // 三派各推一格，每个 confidence 都低 → top1 后验也低
      const decision = decidePhase([
        vote('ziping', 0.25, [{ phaseId: 'A', confidence: 0.5 }]),
        vote('tiaohou', 0.40, [{ phaseId: 'B', confidence: 0.5 }]),
        vote('geju', 0.30, [{ phaseId: 'C', confidence: 0.5 }]),
      ]);
      expect(decision.status).toBe('open_phase');
      expect(decision.reason).toBe('low_top1');
      expect(decision.topCandidates.length).toBe(3);
    });

    it('narrow gap (top1 - top2 < 0.10) → open_phase / narrow_gap', () => {
      // A 和 B 后验非常接近
      const decision = decidePhase([
        vote('ziping', 0.5, [
          { phaseId: 'A', confidence: 1.0 },
          { phaseId: 'B', confidence: 0.95 },
        ]),
        vote('tiaohou', 0.5, [
          { phaseId: 'A', confidence: 1.0 },
          { phaseId: 'B', confidence: 0.95 },
        ]),
      ]);
      // A=1.0, B=0.95 → gap 0.05 < 0.10
      expect(decision.status).toBe('open_phase');
      expect(decision.reason).toBe('narrow_gap');
    });

    it('empty votes → open_phase', () => {
      const decision = decidePhase([]);
      expect(decision.status).toBe('open_phase');
      expect(decision.phaseId).toBeNull();
      expect(decision.topCandidates).toEqual([]);
    });

    it('custom thresholds override default', () => {
      // 同一组 input，默认会 narrow_gap，但放宽阈值后 decided
      const votes = [
        vote('ziping', 1.0, [
          { phaseId: 'A', confidence: 1.0 },
          { phaseId: 'B', confidence: 0.95 },
        ]),
      ];
      const strict = decidePhase(votes);
      expect(strict.status).toBe('open_phase');
      const loose = decidePhase(votes, { minTop1: 0.4, minGap: 0.01 });
      expect(loose.status).toBe('decided');
      expect(loose.phaseId).toBe('A');
    });
  });
});
