import type { AIRunner, SignalTable } from './CalibrationSession';
import type { CandidateId, EventType } from './types';
import { getChatConfig, sendChatNonStream, type ChatConfig } from '@/lib/ai/chat';

/**
 * LLM-driven calibration prompt.
 *
 * 设计思路（与旧的"模板库"完全相反）：
 * - 程序只生成信号表；不挑题、不算分、不判定。
 * - LLM 拿到 3 个候选盘的"年份 → 事件类型"信号，自己挑分歧最大的年份提问。
 * - LLM 多轮后自己决定 lock 或 give_up；session 只是个 controller。
 */
export const CALIBRATION_SYSTEM_PROMPT = `你是命理师，正在用过去事件帮用户校准出生时辰（±1 时辰）。

我会给你 3 个候选盘的事件信号表：每个候选盘在某年应该发生什么类型的事件（八字大运转入十神 / 紫微大限转入十神 / 流年关键事件）。事件类型说明：
- 七杀临 → 外部压力、被动突破、压力性转折
- 正官临 → 进入需要克制规则的位置（升学、入职、新岗位）
- 伤官临 → 对抗权威、突破常规、表达冲突
- 食神临 → 表达、生活情趣放开、轻松创作
- 比肩劫财 → 同辈合作 / 资源被分 / 兄弟朋友牵连
- 正偏印 → 学习、依赖长辈、思考内化
- 正偏财 → 钱财相关重大事件、感情/资产变动

你的任务：

1. 看信号表，挑 3-5 个 在不同候选盘里 事件类型分歧最大 的年份（candidate_a 显示"七杀"但 candidate_b 显示"食神"，这种年份最有鉴别力）。
2. 一次只问一个问题，问句要具体到事件类型（比如"那年是不是经历过 X 类的事"），不要程式化、不要列表、不要解释命盘原理。温和、自然。
3. 用户回答后判断他描述的是哪个事件类型 → 哪个候选最匹配。
4. 至少 3 轮、最多 5 轮后必须收口：
   - 如果某候选明显匹配 ≥ 60% 的回答 → decision='locked' + lockedCandidate=对应 id
   - 否则 decision='gave_up' + 解释一句"信号不足/三盘混合"
5. 如果用户连续 2 轮说"不记得" → decision='gave_up'
6. 如果没到 5 轮但已经能 lock → 提前 lock

返回严格的 JSON 格式：
{
  "decision": "asking" | "locked" | "gave_up",
  "text": "<对用户说的话>",
  "lockedCandidate": "before" | "origin" | "after"
}

decision='locked' 时 lockedCandidate 必填；decision='asking' 或 'gave_up' 时不要给 lockedCandidate。
text 永远是给用户看的话——asking 时是问句，locked 时是温和的总结（"看起来你出生在 XX 时"），gave_up 时是道歉句。`;

interface AIOutput {
  decision: 'asking' | 'locked' | 'gave_up';
  text: string;
  lockedCandidate?: CandidateId;
}

export function parseAIResponse(raw: string, fallbackText: string): AIOutput {
  try {
    const obj = JSON.parse(raw) as Partial<AIOutput>;
    const decision = obj.decision;
    const text = typeof obj.text === 'string' && obj.text.length > 0 ? obj.text : fallbackText;
    if (decision === 'asking' || decision === 'locked' || decision === 'gave_up') {
      const out: AIOutput = { decision, text };
      if (decision === 'locked' && isCandidateId(obj.lockedCandidate)) {
        out.lockedCandidate = obj.lockedCandidate;
      }
      // locked 但缺 candidateId → 退化为 asking（让 session 进入下一轮兜底）
      if (decision === 'locked' && !out.lockedCandidate) {
        return { decision: 'asking', text };
      }
      return out;
    }
    return { decision: 'asking', text };
  } catch {
    return { decision: 'asking', text: fallbackText };
  }
}

function isCandidateId(v: unknown): v is CandidateId {
  return v === 'before' || v === 'origin' || v === 'after';
}

/** 把 signalTable 渲染成 LLM user content 里的可读片段。 */
export function renderSignalTable(table: SignalTable): string {
  const parts: string[] = ['信号表：'];
  for (const meta of table.candidatesMeta) {
    parts.push(`candidate_${meta.id} (${meta.birthHourLabel})：`);
    const events = table.byCandidate[meta.id];
    const years = Object.keys(events)
      .map(Number)
      .filter(y => events[y] !== 'none')
      .sort((a, b) => a - b);
    if (years.length === 0) {
      parts.push('  （无显著事件信号）');
      continue;
    }
    for (const y of years) {
      parts.push(`  ${y}: ${events[y]}`);
    }
  }
  return parts.join('\n');
}

export function renderHistory(history: Array<{ role: 'ai' | 'user'; text: string }>): string {
  if (history.length === 0) return '历史对话：（无，本轮是首轮）';
  const lines = ['历史对话：'];
  for (const h of history) {
    lines.push(`${h.role === 'ai' ? 'AI' : 'User'}: ${h.text}`);
  }
  return lines.join('\n');
}

export function buildUserMessage(input: {
  signalTable: SignalTable;
  history: Array<{ role: 'ai' | 'user'; text: string }>;
  round: number;
  userAge: number;
}): string {
  return [
    renderSignalTable(input.signalTable),
    '',
    `用户当前年龄：${input.userAge}`,
    '',
    renderHistory(input.history),
    '',
    `第 ${input.round} 轮，请决定：继续问、locked、还是 give_up。`,
  ].join('\n');
}

function readProviderConfig(): ChatConfig | null {
  // 懒加载 userStore：模块加载需要 RN 的 AsyncStorage，jest 单测不进入 runRound 即不触发
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { useUserStore } = require('@/lib/store/userStore') as typeof import('@/lib/store/userStore');
  return getChatConfig(useUserStore.getState());
}

async function callOnce(cfg: ChatConfig, userMsg: string): Promise<string> {
  return sendChatNonStream(
    [{ role: 'user', content: userMsg, timestamp: Date.now() }],
    CALIBRATION_SYSTEM_PROMPT,
    cfg,
    { maxTokens: 1024, temperature: 0.3, responseFormat: { type: 'json_object' } },
  );
}

/** AI 不可用时的兜底问句——尽量自然、不暴露兜底状态。 */
function fallbackQuestion(round: number): string {
  if (round === 1) return '能不能说一件你印象很深、改变了你生活轨迹的过去事件？大致哪一年发生的？';
  return '再说一件——大约几岁那年，发生了让你状态明显变化的事？';
}

export const calibrationAI: AIRunner = {
  async runRound(input) {
    const cfg = readProviderConfig();
    if (!cfg) {
      // 没配 AI：退化成"程序兜底问"，多轮后 give_up，避免死循环
      if (input.round >= 4) {
        return { decision: 'gave_up', text: '当前没有可用的 AI，无法判断。可在设置里配置后再试。' };
      }
      return { decision: 'asking', text: fallbackQuestion(input.round) };
    }
    const userMsg = buildUserMessage(input);
    let lastErr: unknown;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const raw = await callOnce(cfg, userMsg);
        return parseAIResponse(raw, fallbackQuestion(input.round));
      } catch (e) {
        lastErr = e;
      }
    }
    console.warn('[CalibrationAI] all retries failed:', lastErr);
    if (input.round < 4) {
      return { decision: 'asking', text: fallbackQuestion(input.round) };
    }
    return { decision: 'gave_up', text: '网络异常，校准被中断。可稍后再试。' };
  },
};
