import { buildCandidates } from './buildCandidates';
import { extractEventsForCandidate } from './extractEvents';
import { extractZiweiEventsForCandidate } from './extractZiweiEvents';
import type { Candidate, CandidateId, EventType, NextStep } from './types';

export type { NextStep } from './types';

/**
 * 信号表：每个候选盘在某年应该发生什么类型的事件。
 * LLM 只读，由 session 程序化生成。
 *
 * byCandidate[candidateId][year] = EventType
 *   - 紫微大限信号优先（更具判别力，因为依赖时辰）
 *   - 其余年份 fall through 到八字大运 / 流年
 *   - 'none' 表示该年份没有显著事件信号
 */
export interface SignalTable {
  byCandidate: Record<CandidateId, Record<number, EventType>>;
  candidatesMeta: Array<{
    id: CandidateId;
    /** ISO 串便于 LLM 在 prompt 里直接引用 */
    birthDate: string;
    /** 例如 "戌时(19-21)"——给 LLM 也方便后端 lock 后写日志 */
    birthHourLabel: string;
  }>;
  /** 当前公历年份，用于 LLM 算"X 年前" framing */
  currentYear: number;
}

export interface AIRunner {
  runRound(input: {
    /** 候选盘信号表（程序生成，LLM 只读） */
    signalTable: SignalTable;
    /** 完整 chat history（含用户答案 + AI 之前问句） */
    history: Array<{ role: 'ai' | 'user'; text: string }>;
    /** 第几轮（1-indexed），AI 决定何时收口 */
    round: number;
    /** 用户当前年龄，用于过滤"年龄不可达"事件 */
    userAge: number;
  }): Promise<{
    /** 'asking' 继续问；'locked' 锁定某候选；'gave_up' 放弃 */
    decision: 'asking' | 'locked' | 'gave_up';
    /** 当 decision='asking' 时的下一题；'locked'/'gave_up' 时的总结语 */
    text: string;
    /** 当 decision='locked' 时必填，AI 选哪个候选 */
    lockedCandidate?: CandidateId;
  }>;
}

export interface StartOptions {
  birthDate: Date;
  gender: '男' | '女';
  longitude: number;
}

export class CalibrationSession {
  private signalTable: SignalTable | null = null;
  private candidates: Candidate[] | null = null;
  private history: Array<{ role: 'ai' | 'user'; text: string }> = [];
  private round = 0;
  private userAge = 0;

  constructor(private ai: AIRunner) {}

  async start(opts: StartOptions): Promise<{ firstQuestion: string }> {
    const candidates = buildCandidates(opts.birthDate, opts.gender, opts.longitude);
    const currentYear = new Date().getFullYear();
    this.candidates = candidates;
    this.userAge = currentYear - opts.birthDate.getFullYear();
    this.signalTable = buildSignalTable(candidates, currentYear);

    // 信号空 → 三盘事件向量在 [birthYear+1, currentYear] 全为 'none'。
    // 未成年用户大限/大运转入次数太少；其余情况说明引擎信号还不够，统一抛 LOW_SIGNAL。
    const hasSignal = Object.values(this.signalTable.byCandidate).some(
      m => Object.values(m).some(e => e !== 'none'),
    );
    if (!hasSignal) {
      throw new Error(this.userAge < 18 ? 'TOO_YOUNG' : 'LOW_SIGNAL');
    }

    this.round = 1;
    const out = await this.ai.runRound({
      signalTable: this.signalTable,
      history: [],
      round: 1,
      userAge: this.userAge,
    });
    if (out.decision !== 'asking') {
      throw new Error('AI 首轮不应该直接 lock/give_up');
    }
    this.history.push({ role: 'ai', text: out.text });
    return { firstQuestion: out.text };
  }

  async submitAnswer(userText: string): Promise<{ nextStep: NextStep }> {
    if (!this.signalTable || !this.candidates) {
      throw new Error('CalibrationSession: call start() first');
    }
    this.history.push({ role: 'user', text: userText });
    this.round += 1;
    const out = await this.ai.runRound({
      signalTable: this.signalTable,
      history: this.history,
      round: this.round,
      userAge: this.userAge,
    });
    this.history.push({ role: 'ai', text: out.text });

    if (out.decision === 'locked') {
      if (!out.lockedCandidate) {
        throw new Error('AI 说 locked 但没给 candidateId');
      }
      const cand = this.candidates.find(c => c.id === out.lockedCandidate);
      if (!cand) throw new Error('未知 candidateId');
      return {
        nextStep: {
          type: 'locked',
          correctedDate: cand.birthDate,
          candidateId: cand.id,
          summary: out.text,
        },
      };
    }
    if (out.decision === 'gave_up') {
      return { nextStep: { type: 'gave_up', reason: out.text } };
    }
    return { nextStep: { type: 'next_question', question: out.text } };
  }
}

function buildSignalTable(candidates: Candidate[], currentYear: number): SignalTable {
  // 把每个候选的 baziEvents + ziweiEvents 合并成 year → eventType 字典。
  // 紫微优先（更具判别力 → 后写覆盖前写）。
  const byCandidate = {
    before: {} as Record<number, EventType>,
    origin: {} as Record<number, EventType>,
    after: {} as Record<number, EventType>,
  } satisfies Record<CandidateId, Record<number, EventType>>;

  for (const c of candidates) {
    const bazi = extractEventsForCandidate(c, currentYear);
    const ziwei = extractZiweiEventsForCandidate(c, currentYear);
    byCandidate[c.id] = { ...bazi, ...ziwei };
  }

  const candidatesMeta = candidates.map(c => ({
    id: c.id,
    birthDate: c.birthDate.toISOString(),
    birthHourLabel: shichenLabel(c.birthDate.getHours()),
  }));

  return { byCandidate, candidatesMeta, currentYear };
}

function shichenLabel(hour: number): string {
  const map: Record<number, string> = {
    0: '子时(23-01)', 2: '丑时(01-03)', 4: '寅时(03-05)', 6: '卯时(05-07)',
    8: '辰时(07-09)', 10: '巳时(09-11)', 12: '午时(11-13)', 14: '未时(13-15)',
    16: '申时(15-17)', 18: '酉时(17-19)', 20: '戌时(19-21)', 22: '亥时(21-23)',
  };
  return map[hour] ?? `${hour}时`;
}
