import { buildCandidates } from './buildCandidates';
import { detectBifurcations } from './bifurcation';
import { findTemplate, fillTemplate, deltaFromAnswer } from './templates';
import { PERSONALITY_TEMPLATES } from './templates/personality';
import { applyAnswer, checkTermination } from './scoring';
import type {
  CalibrationSessionState, CandidateId, AskedQuestion, BifurcatedYear,
} from './types';
import type { QuestionTemplate } from './templates/types';

export interface AIRunner {
  runRound(input: {
    templateRaw: string;
    lastUserAnswer?: string;
  }): Promise<{ lastClassification?: 'yes' | 'no' | 'uncertain'; question: string }>;
}

export interface StartOptions {
  birthDate: Date;
  gender: '男' | '女';
  longitude: number;
}

export type NextStep =
  | { type: 'next_question'; question: string }
  | { type: 'locked'; correctedDate: Date; candidateId: CandidateId }
  | { type: 'gave_up'; reason: string };

export class CalibrationSession {
  private state!: CalibrationSessionState;
  private pendingTemplate: QuestionTemplate | null = null;
  private pendingBifurcation: BifurcatedYear | null = null;
  private pendingAge = 0;

  constructor(private ai: AIRunner) {}

  async start(opts: StartOptions): Promise<{ firstQuestion: string; state: CalibrationSessionState }> {
    const candidates = buildCandidates(opts.birthDate, opts.gender, opts.longitude);
    const bifurcations = detectBifurcations(candidates, new Date().getFullYear());

    this.state = {
      candidates,
      scores: { before: 0, origin: 0, after: 0 },
      history: [],
      bifurcations,
      consumedKeys: new Set(),
      round: 0,
      consecutiveUncertain: 0,
      status: 'asking',
    };

    const firstQuestion = await this.prepareNextQuestion();
    return { firstQuestion, state: this.state };
  }

  private pickNext(): { template: QuestionTemplate; bif: BifurcatedYear; age: number } | null {
    for (const bif of this.state.bifurcations) {
      const tpl = findTemplate(bif);
      if (!tpl) continue;
      const key = `${tpl.id}:${bif.year}`;
      if (this.state.consumedKeys.has(key)) continue;
      return { template: tpl, bif, age: bif.ageAt.origin };
    }
    // fallback: 性格模板（无年份）
    for (const tpl of PERSONALITY_TEMPLATES) {
      if (this.state.consumedKeys.has(`${tpl.id}:0`)) continue;
      return {
        template: tpl,
        bif: { year: 0, ageAt: { before: 0, origin: 0, after: 0 }, events: { before: 'none', origin: 'none', after: 'none' }, diversity: 0 },
        age: 0,
      };
    }
    return null;
  }

  private async prepareNextQuestion(lastUserAnswer?: string): Promise<string> {
    const next = this.pickNext();
    if (!next) {
      // 模板用尽——按当前 scores 强制 lock
      const verdict = checkTermination({ ...this.state, round: 5 });
      this.state = { ...this.state, status: verdict.status, lockedCandidate: verdict.lockedCandidate };
      return '';
    }
    this.pendingTemplate = next.template;
    this.pendingBifurcation = next.bif;
    this.pendingAge = next.age;
    const raw = fillTemplate(next.template, next.bif.year, next.age);
    const aiOut = await this.ai.runRound({ templateRaw: raw, lastUserAnswer });
    return aiOut.question;
  }

  async submitAnswer(userText: string): Promise<{ classified: 'yes'|'no'|'uncertain'; nextStep: NextStep }> {
    if (!this.pendingTemplate || !this.pendingBifurcation) {
      throw new Error('CalibrationSession: no pending question');
    }
    const tpl = this.pendingTemplate;
    const bif = this.pendingBifurcation;

    const raw = fillTemplate(tpl, bif.year, this.pendingAge);
    const aiOut = await this.ai.runRound({ templateRaw: raw, lastUserAnswer: userText });
    const classified = aiOut.lastClassification ?? 'uncertain';

    return this.consume(classified, userText, aiOut.question);
  }

  /** 测试专用：跳过 AI 直接注入分类 + delta */
  async submitAnswerWithForcedDelta(
    userText: string,
    forcedDelta: Record<CandidateId, number>,
  ): Promise<{ classified: 'yes'|'no'|'uncertain'; nextStep: NextStep }> {
    if (!this.pendingTemplate || !this.pendingBifurcation) {
      throw new Error('CalibrationSession: no pending question');
    }
    // 任一候选有非零 delta 就视为有效分类（yes/no 都会动 score）；
    // 三者全 0 才算 uncertain。这里不区分 yes/no，统一记 'yes'，因为真正的判定来自 delta 本身。
    const allZero = forcedDelta.before === 0 && forcedDelta.origin === 0 && forcedDelta.after === 0;
    const classified: 'yes'|'no'|'uncertain' = allZero ? 'uncertain' : 'yes';
    return this.consumeWithDelta(classified, userText, forcedDelta, '');
  }

  private async consume(classified: 'yes'|'no'|'uncertain', userText: string, nextQuestionText: string): Promise<{ classified: typeof classified; nextStep: NextStep }> {
    const tpl = this.pendingTemplate!;
    const bif = this.pendingBifurcation!;
    const delta = deltaFromAnswer(tpl, bif.events, classified);
    return this.consumeWithDelta(classified, userText, delta, nextQuestionText);
  }

  private async consumeWithDelta(
    classified: 'yes'|'no'|'uncertain',
    userText: string,
    delta: Record<CandidateId, number>,
    nextQuestionText: string,
  ): Promise<{ classified: typeof classified; nextStep: NextStep }> {
    const tpl = this.pendingTemplate!;
    const bif = this.pendingBifurcation!;
    const q: AskedQuestion = {
      templateId: tpl.id,
      year: bif.year,
      ageThen: this.pendingAge,
      questionText: fillTemplate(tpl, bif.year, this.pendingAge),
      userAnswer: userText,
      classified,
      delta,
    };
    this.state = applyAnswer(this.state, q);
    const verdict = checkTermination(this.state);
    this.state = { ...this.state, status: verdict.status, lockedCandidate: verdict.lockedCandidate };

    if (verdict.status === 'locked') {
      const winner = this.state.candidates.find(c => c.id === verdict.lockedCandidate)!;
      return { classified, nextStep: { type: 'locked', correctedDate: winner.birthDate, candidateId: winner.id } };
    }
    if (verdict.status === 'gave_up') {
      return { classified, nextStep: { type: 'gave_up', reason: '连续 2 轮无法判断' } };
    }
    const question = nextQuestionText || (await this.prepareNextQuestion(userText));
    if (this.state.status !== 'asking') {
      const winner = this.state.candidates.find(c => c.id === this.state.lockedCandidate);
      if (winner) return { classified, nextStep: { type: 'locked', correctedDate: winner.birthDate, candidateId: winner.id } };
      return { classified, nextStep: { type: 'gave_up', reason: '题库用尽' } };
    }
    return { classified, nextStep: { type: 'next_question', question } };
  }

  getState(): CalibrationSessionState {
    return this.state;
  }
}
