/**
 * 命盘关键词扫描，支持徽章化显示
 */

const SHI_SHEN = [
  '日主', '正官', '七杀', '正印', '偏印',
  '正财', '偏财', '食神', '伤官', '比肩', '劫财',
];

const MING_LI = ['用神', '喜神', '忌神', '格局'];

const WU_XING = ['木', '火', '土', '金', '水'];

/**
 * 五行单字前置屏蔽字符：
 *  - 天干（甲乙丙丁戊己庚辛壬癸）：天干 + 五行 构成复合词（如"庚金"）不应匹配
 *  - 常见系词/介词（为是有）：如"为水"/"是金"等谓语用法不应匹配
 */
const WU_XING_LOOKBEHIND_BLOCK = '甲乙丙丁戊己庚辛壬癸为是有';

export type Segment = { text: string; isKeyword: boolean };

/**
 * 把一段文本分成若干片段，每个片段要么是关键词，要么不是
 *
 * 规则：
 *  - 十神 / 命理 术语直接匹配（它们几乎不会误中）
 *  - 五行单字满足以下条件才匹配：
 *    1. 前一字不是天干或系词/介词（避免"庚金"/"为水"等假阳性）
 *    2. 后一字不是汉字（避免"金色"/"水果"/"木匠"等假阳性）
 */
export function splitIntoKeywordSegments(text: string): Segment[] {
  const regex = buildKeywordRegex();
  const result: Segment[] = [];
  let lastIndex = 0;

  for (const match of text.matchAll(regex)) {
    const idx = match.index!;
    if (idx > lastIndex) {
      result.push({ text: text.slice(lastIndex, idx), isKeyword: false });
    }
    result.push({ text: match[0], isKeyword: true });
    lastIndex = idx + match[0].length;
  }

  if (lastIndex < text.length) {
    result.push({ text: text.slice(lastIndex), isKeyword: false });
  }

  return result.length ? result : [{ text, isKeyword: false }];
}

function buildKeywordRegex(): RegExp {
  const phrases = [...SHI_SHEN, ...MING_LI];
  const phrasePart = phrases.join('|');

  // Build lookbehind char class from the block list
  const blockPart = [...WU_XING_LOOKBEHIND_BLOCK]
    .map(c => `\\u${c.codePointAt(0)!.toString(16).padStart(4, '0')}`)
    .join('');

  // Five-element chars match only when:
  //  - NOT preceded by a Heavenly Stem or copula/prep char
  //  - NOT followed by another CJK character
  const wuxingPart =
    `(?<![${blockPart}])(?:${WU_XING.join('|')})(?![\\u4e00-\\u9fff])`;

  return new RegExp(`${phrasePart}|${wuxingPart}`, 'g');
}
