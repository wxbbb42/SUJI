/**
 * 扫描原文，把 "宜: ... / 忌: ..." 配对替换为三反引号 fence（语言标记 yiji）
 *
 * 触发条件：
 *   - 一行形如 `(**)?宜(**)?[：:] 正文`
 *   - 紧接着（允许中间有空行）一行形如 `(**)?忌(**)?[：:] 正文`
 *
 * 不匹配单独出现的 宜 或 忌，也不匹配句中嵌套的 "宜"。
 */
const YI_RE = /^(?:\*\*)?宜(?:\*\*)?[:：]\s*(.+)$/;
const JI_RE = /^(?:\*\*)?忌(?:\*\*)?[:：]\s*(.+)$/;

export function preprocessYiji(input: string): string {
  const lines = input.split('\n');
  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const yiMatch = lines[i].match(YI_RE);
    if (yiMatch) {
      let j = i + 1;
      while (j < lines.length && lines[j].trim() === '') j++;
      const jiMatch = j < lines.length ? lines[j].match(JI_RE) : null;

      if (jiMatch) {
        out.push('```yiji');
        out.push(`yi: ${yiMatch[1].trim()}`);
        out.push(`ji: ${jiMatch[1].trim()}`);
        out.push('```');
        i = j + 1;
        continue;
      }
    }
    out.push(lines[i]);
    i++;
  }

  return out.join('\n');
}
