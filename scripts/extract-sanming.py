#!/usr/bin/env python3
"""
Extract 三命通會（万民英）epub xhtml -> per-juan markdown.
Source: /tmp/三命通會-epub/OPS/c{1..9}_*.xhtml (Wikisource zh)
Output: docs/mingli/source-texts/bazi/sanming-tonghui/juan-{1..9}.md

三命通會 is large (~386 sections across 12 juan, but epub only ships 9 here).
Strategy: one md per 卷, dump all h2/h3 in original order.
"""

import re
import os
from pathlib import Path
from html import unescape

SRC_DIR = Path("/tmp/三命通會-epub/OPS")
OUT_BASE = Path(
    "/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/sanming-tonghui"
)

# Per-juan metadata
JUAN_META = {
    1: (
        "卷一：五行 / 干支源流",
        "五行生成、生克、支干源流、十干十二支体性 — RiZhuStructure 干支语义底座 P1 印证",
    ),
    2: (
        "卷二：天干 / 地支 / 十干分配天文",
        "天干阴阳生死、地支、十干天文分野 — TongGenInfo 干支强弱判定 P1 印证",
    ),
    3: (
        "卷三：神煞（禄 / 金舆 / 驿马 等）",
        '神煞门类 — Phase 2 反"神煞驱动"立场的对照参考；不直接进算法',
    ),
    4: (
        "卷四：十干坐支 / 月支得日干 / 五行时地分野",
        "十干坐支吉凶 / 月支得日干 — 月令调候 + 坐支判定 P1 印证",
    ),
    5: (
        "卷五：十神 / 印食官财名义 / 正官 等",
        "十神立法本义 / 正官章 — GeJuV2 正官格 P1 印证",
    ),
    6: (
        "卷六：杂格（壬骑龙背 / 子遥巳禄 等 73 格）",
        "杂格大全 — Phase 2 杂格判定 + 反伪辨别 P1 印证",
    ),
    7: (
        "卷七：性情相貌 / 疾病 / 女命",
        "性情 / 健康 / 女命 — InsightEngine 中性化解读 + 健康类必须中性化的来源印证",
    ),
    8: (
        "卷八：六甲日时辰断（甲子-甲日全时辰）",
        "日时配对断辞 — 时辰 fixture 候选库（需印刷版核校后再入 fixture）",
    ),
    9: (
        "卷九：六己日时辰断 + 续",
        "日时配对断辞续 — 时辰 fixture 候选库（需印刷版核校后再入 fixture）",
    ),
}


def strip_tags(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    return unescape(s).strip()


def parse_juan(filepath: Path) -> list:
    """Returns list of (level, title, body_html) in document order."""
    text = filepath.read_text(encoding="utf-8")
    pieces = re.split(r"(<h[23][^>]*>.*?</h[23]>)", text, flags=re.DOTALL)
    result = []
    last = None  # (level, title)
    buf = []
    for piece in pieces:
        m = re.match(r"<h([23])[^>]*>(.*?)</h\1>", piece, re.DOTALL)
        if m:
            if last:
                result.append((last[0], last[1], "".join(buf)))
                buf = []
            last = (int(m.group(1)), strip_tags(m.group(2)))
        else:
            if last:
                buf.append(piece)
    if last:
        result.append((last[0], last[1], "".join(buf)))
    return result


def section_to_md(level: int, title: str, raw_html: str) -> str:
    paragraphs = re.findall(r"<p[^>]*>(.*?)</p>", raw_html, re.DOTALL)
    prefix = "##" if level == 2 else "###"
    out = [f"{prefix} {title}", ""]
    for p in paragraphs:
        text = strip_tags(p)
        if text:
            out.append(text)
            out.append("")
    return "\n".join(out)


def build_juan_file(juan_num: int, label: str, role: str, sections: list) -> str:
    parts = []
    parts.append("---")
    parts.append("book: 三命通会")
    parts.append(f"chapter: {label}")
    parts.append(
        'edition: "Wikisource zh epub (https://zh.wikisource.org/wiki/三命通會) — 万民英辑（明万历）。本电子版未注明底本，待与中华书局点校本印刷版核校"'
    )
    parts.append("fillStatus: filled-from-epub")
    parts.append('filledBy: "extracted from epub via scripts/extract-sanming.py"')
    parts.append("filledAt: 2026-05-07")
    parts.append("priority: P1")
    parts.append(f'algorithmRole: "{role}"')
    parts.append("---")
    parts.append("")
    parts.append(f"# 三命通会 · {label}")
    parts.append("")
    parts.append(f"> 卷次：第 {juan_num} 卷")
    parts.append(
        "> 来源：epub `三命通會.epub`（Wikisource zh-Hans 转出），未提供印刷底本。"
    )
    parts.append(
        "> 进入 fixture 校验前需与中华书局陆致极点校本（或同等 A-tier 印刷本）逐字核校。"
    )
    parts.append("> 本文件为 P1 交叉印证用，**不直接驱动 Phase 2 BaziEngine 重写**。")
    parts.append(f"> 本卷共 {len(sections)} 节，按 epub 原序输出。")
    parts.append("")
    for level, title, body in sections:
        parts.append(section_to_md(level, title, body))
    parts.append("---")
    parts.append("")
    parts.append("## 录入备注")
    parts.append("")
    parts.append("- epub 自动提取，未做语义校对；段落顺序保持 epub 原序。")
    parts.append(
        "- 三命通会原本卷六 73 神煞 / 杂格、卷八-九日时辰断量大，命例与论述混排，需人工分块。"
    )
    parts.append(
        '- 简繁混排（"通會/通会"、"剋/克"、"財/财"）未 normalize；下游用 `lib/utils/text.ts` 转换。'
    )
    parts.append(
        "- epub 仅含 9 卷，原书 12 卷的卷十-卷十二（神峰本附录 / 婚姻 / 选时等）需另行补录。"
    )
    parts.append("")
    return "\n".join(parts)


if __name__ == "__main__":
    OUT_BASE.mkdir(parents=True, exist_ok=True)
    files = sorted(
        [f for f in os.listdir(SRC_DIR) if re.match(r"c[1-9]_san_ming.*\.xhtml$", f)]
    )
    for fname in files:
        m = re.match(r"c(\d+)_", fname)
        if not m:
            continue
        juan = int(m.group(1))
        if juan not in JUAN_META:
            continue
        label, role = JUAN_META[juan]
        sections = parse_juan(SRC_DIR / fname)
        out_path = OUT_BASE / f"juan-{juan}.md"
        content = build_juan_file(juan, label, role, sections)
        out_path.write_text(content, encoding="utf-8")
        print(
            f"  wrote juan-{juan}.md: {len(content)} chars, {len(sections)} sections from {fname}"
        )
