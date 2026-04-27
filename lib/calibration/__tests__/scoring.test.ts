import { applyAnswer, checkTermination } from '../scoring';
import type { CalibrationSessionState } from '../types';

function makeSession(overrides: Partial<CalibrationSessionState> = {}): CalibrationSessionState {
  return {
    candidates: [{} as any, {} as any, {} as any],
    scores: { before: 0, origin: 0, after: 0 },
    history: [],
    bifurcations: [],
    consumedKeys: new Set(),
    round: 0,
    consecutiveUncertain: 0,
    status: 'asking',
    ...overrides,
  };
}

describe('applyAnswer', () => {
  it('updates scores by delta and increments round', () => {
    const s = makeSession();
    const next = applyAnswer(s, {
      templateId: 'qisha_role_shift', year: 2014, ageThen: 19,
      questionText: 'q', userAnswer: 'yes', classified: 'yes',
      delta: { before: 1, origin: -1, after: -1 },
    });
    expect(next.scores).toEqual({ before: 1, origin: -1, after: -1 });
    expect(next.round).toBe(1);
    expect(next.history).toHaveLength(1);
    expect(next.consecutiveUncertain).toBe(0);
  });

  it('increments consecutiveUncertain on uncertain', () => {
    const s = makeSession({ consecutiveUncertain: 1 });
    const next = applyAnswer(s, {
      templateId: 't', year: 2010, ageThen: 15, questionText: 'q',
      userAnswer: 'idk', classified: 'uncertain',
      delta: { before: 0, origin: 0, after: 0 },
    });
    expect(next.consecutiveUncertain).toBe(2);
  });

  it('resets consecutiveUncertain on yes', () => {
    const s = makeSession({ consecutiveUncertain: 1 });
    const next = applyAnswer(s, {
      templateId: 't', year: 2010, ageThen: 15, questionText: 'q',
      userAnswer: 'yes', classified: 'yes',
      delta: { before: 1, origin: 0, after: 0 },
    });
    expect(next.consecutiveUncertain).toBe(0);
  });
});

describe('checkTermination', () => {
  it('locks when max - second >= 2', () => {
    const s = makeSession({ scores: { before: 3, origin: 0, after: 0 }, round: 3 });
    const r = checkTermination(s);
    expect(r.status).toBe('locked');
    expect(r.lockedCandidate).toBe('before');
  });

  it('locks at round 5 with current top, ties break to origin', () => {
    const s = makeSession({ scores: { before: 1, origin: 1, after: 1 }, round: 5 });
    const r = checkTermination(s);
    expect(r.status).toBe('locked');
    expect(r.lockedCandidate).toBe('origin');
  });

  it('gives up on 2 consecutive uncertain', () => {
    const s = makeSession({ consecutiveUncertain: 2, round: 2 });
    const r = checkTermination(s);
    expect(r.status).toBe('gave_up');
  });

  it('continues asking otherwise', () => {
    const s = makeSession({ scores: { before: 1, origin: 0, after: 0 }, round: 2 });
    const r = checkTermination(s);
    expect(r.status).toBe('asking');
  });
});
