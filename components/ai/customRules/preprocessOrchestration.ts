/**
 * 把 LLM 的 [interpretation] + [evidence] 双段输出拆开
 *
 * 容错：
 * - 缺少 [evidence] → evidence 返回空数组
 * - 完全无标签 → 整段作为 interpretation
 * - 流式中间态（只有 [interpretation] 半截）→ interpretation 取已到部分
 */

export interface OrchestrationParts {
  interpretation: string;
  evidence: string[];
}

const TAG_INTERP = '[interpretation]';
const TAG_EVID = '[evidence]';

export function splitOrchestrationOutput(input: string): OrchestrationParts {
  const interpIdx = input.indexOf(TAG_INTERP);
  const evidIdx = input.indexOf(TAG_EVID);

  if (interpIdx < 0) {
    return { interpretation: input.trim(), evidence: [] };
  }

  const after = input.slice(interpIdx + TAG_INTERP.length);
  if (evidIdx < 0 || evidIdx < interpIdx) {
    return { interpretation: after.trim(), evidence: [] };
  }

  const interpretation = input.slice(interpIdx + TAG_INTERP.length, evidIdx).trim();
  const evidenceRaw = input.slice(evidIdx + TAG_EVID.length).trim();
  const evidence = evidenceRaw
    .split('\n')
    .map(line => line.trim())
    .filter(Boolean);

  return { interpretation, evidence };
}
