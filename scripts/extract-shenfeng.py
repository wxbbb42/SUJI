#!/usr/bin/env python3
"""
Extract 神峰通考（张神峰）epub xhtml -> markdown.
Source: /tmp/神峰通考-epub/OPS/c0_shen_feng_tong_kao.xhtml (Wikisource zh)
Output: docs/mingli/source-texts/bazi/shenfeng-tongkao/*.md

CHALLENGE: epub has NO heading tags, only <p>. Chapter titles are short
paragraphs (≤15 chars, no spaces, ending in 说/类/格/篇/论/歌/赋/诀/...).
We treat such short paragraphs as chapter starts; rest are body content.

108 chapter candidates → grouped into 9 topical clusters by paragraph index.
"""

import re
from pathlib import Path
from html import unescape

SRC = Path("/tmp/神峰通考-epub/OPS/c0_shen_feng_tong_kao.xhtml")
OUT_BASE = Path(
    "/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/shenfeng-tongkao"
)

# Chapter title heuristic: short, no whitespace, ending in classical-section keyword
CHAPTER_TITLE_RE = re.compile(
    r"^[\u4e00-\u9fff]{2,15}(说|类|格|篇|论|歌|赋|诀|总诀|附|序|叙|记|引|断|考|经|要|集|断辞|总论|总断|提要|题辞|考述|附录)$"
)
ADDITIONAL_TITLES = {"叙", "序", "题辞", "凡例", "又补岁德扶财格", "又地支藏遁歌"}

# Cluster ranges by paragraph index (inclusive lower, exclusive upper).
# Boundaries chosen to align with detected chapter starts shown in inspection.
CLUSTERS = [
    (
        "01-zonglun.md",
        "总论：五星正/谬说类 / 男女合婚说 / 总论子平谬说类 / 动静说 / 盖头说 / 六亲说",
        '神峰子平总论 — 反"五星俗法" + 提倡"动静配合" — 立场印证（避免 D-tier 民间法）',
        0,
        48,
    ),
    (
        "02-bingyao.md",
        "病药 / 雕枯旺弱 / 损益生长：病药四病四药说类",
        '病药法 — 张神峰核心原创：用神 = 病药关系（与《子平真诠》"用神成败救应"互补）— Phase 2 救应判定 P1 印证',
        48,
        95,
    ),
    (
        "03-zhengge-shishen.md",
        "十神格局：正官格 / 偏官格附弃命从杀 / 古纯杂有有制类 / 近时纯杂有制类 / 时上一位贵格 / 附官杀去留杂格 / 伤官食神格 / 伤官十论 / 印绶格",
        "十神主格局 — GeJuV2 各格 chengBai/xiangShen 规则 P1 印证（重点：伤官十论是伤官格分类圣经）",
        95,
        594,
    ),
    (
        "04-zage-zhuanlu.md",
        "杂格：专禄格 / 金神格 / 子遥巳/丑遥巳格 / 壬骑龙背格 / 井栏叉格 / 六乙鼠贵 / 六阴朝阳 / 刑合 / 合禄 / 曲直仁寿 / 稼穑 / 炎上 / 年时官星 / 从化 / 来兵拱财 / 岁德扶杀 / 专财 / 日德 / 日贵 / 魁罡 / 六壬趋艮 / 六甲趋乾 / 勾陈得位 / 玄武当权 / 财官双美 / 拱禄拱贵 / 日禄归时 / 四位纯全 / 天元一气 / 三合聚集 / 福德格",
        "杂格大全 — Phase 2 杂格判定（专旺 / 化气 / 拱合）P1 印证",
        594,
        985,
    ),
    (
        "05-shixing-jinbuhuan.md",
        "认格局生死之歌 / 五星论 / 金不换骨髓歌断 / 十天干体象全编论",
        "格局生死歌 + 金不换 — 大运 trend 判定 + 十干体象（DayunEngine + RiZhuStructure）P1 印证",
        985,
        1197,
    ),
    (
        "06-jixiongshen-fenjie.md",
        "吉神类 / 凶神类 / 起八字诀 / 子平举要 / 阴阳通变妙诀 / 定格局诀 / 子平泛论 / 十干从化 / 五阴歌 / 天元一字歌 / 运晦/运通/刑克/刑妻/克子/带疾/寿元/飘荡/女命歌 等",
        '吉凶神 + 各类应期歌诀 — 与《子平真诠》"论星辰无关格局"对照（神煞应避雷的来源印证）+ 应期口诀候选',
        1197,
        1683,
    ),
    (
        "07-jiejie-pufu.md",
        "看命捷歌 / 取格指诀歌断 / 节气歌断 / 万尚书琼玑三盘赋 / 崖泉男命赋 / 崖泉女命赋 / 讲命捷径赋 / 身弱论 / 弃命从杀格",
        "节气 + 男女命赋 + 身弱论 — 与渊海子平身弱论交叉印证 + 节气调候补强",
        1683,
        1800,
    ),
    (
        "08-fupian.md",
        "喜忌篇 / 继善篇 / 六神篇 / 气象篇 / 渭泾论 / 定真篇",
        "六大经典命理篇 — 与渊海子平喜忌篇 / 定真论交叉对校（不同传本异同）",
        1800,
        2465,
    ),
    (
        "09-fuwen.md",
        "五行元理消息赋 / 五行生克赋 / 一行禅师天元赋 / 捷驰千里马赋 / 络绎赋 / 玄机赋 / 憎爱赋 / 万金赋 / 相心赋 / 仙机赋 / 金玉赋 / 人鉴论 / 渊源集说 / 妖祥赋 / 幽微天干赋 / 人元消息赋 / 地支赋 / 病源赋",
        "赋文集 — 命理文学 / 应期 / 病源（健康类必须中性化）— 与渊海子平赋文交叉对校",
        2465,
        99999,
    ),
]


def strip_tags(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    return unescape(s).strip()


def parse_paragraphs() -> list:
    """Returns list of (idx, kind, text). kind in {'title', 'body'}."""
    text = SRC.read_text(encoding="utf-8")
    paras = re.findall(r"<p[^>]*>(.*?)</p>", text, re.DOTALL)
    out = []
    for i, p in enumerate(paras):
        plain = strip_tags(p)
        if not plain:
            continue
        is_title = False
        if 2 <= len(plain) <= 15 and " " not in plain and "\u3000" not in plain:
            if CHAPTER_TITLE_RE.match(plain) or plain in ADDITIONAL_TITLES:
                is_title = True
        out.append((i, "title" if is_title else "body", plain))
    return out


def cluster_to_md(
    filename: str, label: str, role: str, paragraphs_in_range: list
) -> str:
    parts = []
    parts.append("---")
    parts.append("book: 神峰通考")
    parts.append(f"chapter: {label}")
    parts.append(
        'edition: "Wikisource zh epub (https://zh.wikisource.org/wiki/神峰通考) — 张神峰辑（明嘉靖）。本电子版未注明底本，待与中华书局/华龄出版社点校本印刷版核校"'
    )
    parts.append("fillStatus: filled-from-epub")
    parts.append('filledBy: "extracted from epub via scripts/extract-shenfeng.py"')
    parts.append("filledAt: 2026-05-07")
    parts.append("priority: P1")
    parts.append(f'algorithmRole: "{role}"')
    parts.append("---")
    parts.append("")
    parts.append(f"# 神峰通考 · {label}")
    parts.append("")
    parts.append(
        "> 来源：epub `神峰通考.epub`（Wikisource zh-Hans 转出），未提供印刷底本。"
    )
    parts.append(
        "> 进入 fixture 校验前需与华龄出版社郑同点校本（或同等 A-tier 印刷本）逐字核校。"
    )
    parts.append("> 本文件为 P1 交叉印证用，**不直接驱动 Phase 2 BaziEngine 重写**。")
    parts.append(
        '> ⚠ 本 epub **无 h2/h3 标题标签**，章节边界由 `scripts/extract-shenfeng.py` 启发式判定（短段落 + 关键词后缀），可能误判（如把"造命"诗句末尾误为章节）。**校对印刷版时必须人工修正章节切分**。'
    )
    parts.append("")
    chapter_count = 0
    for idx, kind, text in paragraphs_in_range:
        if kind == "title":
            parts.append(f"## {text}")
            parts.append("")
            chapter_count += 1
        else:
            parts.append(text)
            parts.append("")
    parts.append("---")
    parts.append("")
    parts.append("## 录入备注")
    parts.append("")
    parts.append(
        f'- 本文件包含 {chapter_count} 个启发式识别的章节标题，源 epub 段落范围 [{paragraphs_in_range[0][0] if paragraphs_in_range else "-"}, {paragraphs_in_range[-1][0] if paragraphs_in_range else "-"}]。'
    )
    parts.append("- epub 自动提取，未做语义校对；段落顺序保持 epub 原序。")
    parts.append(
        '- ⚠ 章节边界（## 标题）由启发式生成（短句 + 后缀关键词），可能：(a) 漏识别"叙"类无后缀短段；(b) 误识别歌诀末句；(c) 命例八字四柱被识别为标题。**所有 ## 标题需人工核对**。'
    )
    parts.append(
        '- 简繁混排（"鑑/鉴"、"剋/克"、"財/财"）未 normalize；下游用 `lib/utils/text.ts` 转换。'
    )
    parts.append("")
    return "\n".join(parts)


if __name__ == "__main__":
    OUT_BASE.mkdir(parents=True, exist_ok=True)
    paras = parse_paragraphs()
    titles = [p for p in paras if p[1] == "title"]
    print(f"Parsed {len(paras)} paragraphs, {len(titles)} candidate chapter titles.")
    for fname, label, role, lo, hi in CLUSTERS:
        sub = [p for p in paras if lo <= p[0] < hi]
        out_path = OUT_BASE / fname
        content = cluster_to_md(fname, label, role, sub)
        out_path.write_text(content, encoding="utf-8")
        chap_count = sum(1 for p in sub if p[1] == "title")
        print(
            f"  wrote {fname}: {len(content)} chars, {chap_count} chapters, {len(sub)} paragraphs (idx {lo}-{hi})"
        )
