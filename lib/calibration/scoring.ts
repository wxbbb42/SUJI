import type { CalibrationSessionState, CandidateId, AskedQuestion } from './types';

export function applyAnswer(
  session: CalibrationSessionState,
  q: AskedQuestion,
): CalibrationSessionState {
  return {
    ...session,
    scores: {
      before: session.scores.before + q.delta.before,
      origin: session.scores.origin + q.delta.origin,
      after: session.scores.after + q.delta.after,
    },
    history: [...session.history, q],
    round: session.round + 1,
    consecutiveUncertain: q.classified === 'uncertain'
      ? session.consecutiveUncertain + 1
      : 0,
    consumedKeys: new Set(session.consumedKeys).add(`${q.templateId}:${q.year}`),
  };
}

export function checkTermination(
  session: CalibrationSessionState,
): { status: CalibrationSessionState['status']; lockedCandidate?: CandidateId } {
  // 优先 1：连续 2 轮 uncertain
  if (session.consecutiveUncertain >= 2) {
    return { status: 'gave_up' };
  }

  const sorted = (Object.entries(session.scores) as [CandidateId, number][])
    .sort((a, b) => b[1] - a[1]);
  const [top, second] = sorted;

  // 优先 2：分差 ≥ 2 → lock
  if (top[1] - second[1] >= 2) {
    return { status: 'locked', lockedCandidate: top[0] };
  }

  // 优先 3：满 5 轮强制 lock。平手时 origin 优先（保守），其次 before
  if (session.round >= 5) {
    const tieBreak: CandidateId[] = ['origin', 'before', 'after'];
    const winners = sorted.filter(([, sc]) => sc === top[1]).map(([id]) => id);
    const winner = tieBreak.find(t => winners.includes(t)) ?? top[0];
    return { status: 'locked', lockedCandidate: winner };
  }

  return { status: 'asking' };
}
