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

function pickWinner(scores: CalibrationSessionState['scores']): CandidateId {
  const sorted = (Object.entries(scores) as [CandidateId, number][])
    .sort((a, b) => b[1] - a[1]);
  const top = sorted[0];
  // 平手时 origin 优先（保守），其次 before、after
  const tieBreak: CandidateId[] = ['origin', 'before', 'after'];
  const winners = sorted.filter(([, sc]) => sc === top[1]).map(([id]) => id);
  return tieBreak.find(t => winners.includes(t)) ?? top[0];
}

export function checkTermination(
  session: CalibrationSessionState,
  options?: { force?: boolean },
): { status: CalibrationSessionState['status']; lockedCandidate?: CandidateId } {
  // 优先 1：连续 2 轮 uncertain（force 不覆盖此路径）
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

  // 优先 3：force=true（题库用尽等场景）跳过 round 阈值，直接取最高分
  if (options?.force === true) {
    return { status: 'locked', lockedCandidate: pickWinner(session.scores) };
  }

  // 优先 4：满 5 轮强制 lock。平手时 origin 优先（保守），其次 before
  if (session.round >= 5) {
    return { status: 'locked', lockedCandidate: pickWinner(session.scores) };
  }

  return { status: 'asking' };
}
