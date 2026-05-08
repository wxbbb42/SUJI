#!/usr/bin/env python3
"""
Extract 渊海子平（徐升）epub xhtml -> markdown.
Source: /tmp/淵海子平-epub/OPS/c0_yuan_hai_zi_ping.xhtml (Wikisource zh)
Output: docs/mingli/source-texts/bazi/yuanhai-ziping/*.md
73 headings (72 h2 + 1 h3) clustered into 7 topical files.
"""

import re
from pathlib import Path
from html import unescape

SRC = Path("/tmp/淵海子平-epub/OPS/c0_yuan_hai_zi_ping.xhtml")
OUT_BASE = Path(
    "/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/yuanhai-ziping"
)

# {filename: (label, role, [chapter_titles_in_order])}
CLUSTERS = {
    "01-foundations.md": (
        "论天干地支暗藏总诀 / 又地支藏遁歌 / 论日为主 / 论月令 / 论太岁吉凶 / 论征太岁 / 论大运",
        "命理基础（藏干 / 日主 / 月令 / 太岁 / 大运）— P1 交叉印证 RiZhuStructure / 月令藏干表 / 大运 trend",
        [
            "论天干地支暗藏总诀",
            "又地支藏遁歌",
            "论日为主",
            "论月令",
            "论太岁吉凶",
            "论征太岁",
            "论大运",
        ],
    ),
    "02-shishen-geju.md": (
        "十神 / 格局：论性情 / 伤官 / 食神 / 正财 / 正官 / 七杀 / 印绶 / 倒食 / 劫财 / 阳刃 / 日刃 / 日贵 / 日德 / 魁罡 / 金神",
        "十神 / 格局基础 — P1 交叉印证 GeJuV2 各格 chengBai/xiangShen/jiuYing 规则",
        [
            "论性情",
            "论伤官",
            "伤官说",
            "论食神",
            "论正财",
            "正官论",
            "论七杀",
            "论官星太过",
            "论官杀混杂要制伏",
            "论印綬",
            "论倒食",
            "论劫财",
            "论阳刃",
            "论日刃",
            "论日贵",
            "论日德",
            "论魁罡",
            "论金神",
        ],
    ),
    "03-liuqin.md": (
        "六亲：论疾病 / 六亲总篇 / 论父 / 论母 / 论兄弟姊妹 / 论妻妾 / 论子息 / 论小儿 / 论小儿关煞",
        "六亲 / 健康 — MarriageEngine + InsightEngine 六亲匹配交叉印证",
        [
            "论疾病",
            "六亲总篇",
            "论父",
            "论母",
            "论兄弟姊妹",
            "论妻妾",
            "论子息",
            "论小儿",
            "论小儿关煞",
        ],
    ),
    "04-funv.md": (
        "妇人 / 女命：论妇人总诀 / 阴命赋 / 女命总断歌 / 女命富贵贫贱篇 / 滚浪桃花 / 女命贵格 / 女命贱格",
        '女命 — 产品文案禁忌（避免"贱"等贬义古语，需中性化）',
        [
            "论妇人总诀",
            "阴命赋",
            "女命总断歌",
            "女命富贵贫贱篇",
            "滚浪桃花",
            "女命贵格",
            "女命贱格",
        ],
    ),
    "05-zonglun-fuwen.md": (
        "总论 / 赋文：子平举要歌 / 详解定真论 / 喜忌篇 / 看命入式 / 神趣八法 / 杂论口诀 / 群兴论 / 论兴亡 / 论命细法 / 心镜歌 / 妖祥赋 / 相心赋 / 玄机赋 / 幽微赋 / 五行元理消息赋 / 造微论 / 人鑑论 / 爱憎赋 / 万金赋 / 挈要捷驰玄妙诀 / 渊源集说 / 子平百章论科甲歌",
        "命理总论 / 赋文 — Phase 2 算法之外的语义印证库（性情 / 富贵贫贱 / 应期口诀）",
        [
            "子平举要歌",
            "详解定真论",
            "喜忌篇",
            "看命入式",
            "神趣八法",
            "杂论口诀",
            "群兴论",
            "论兴亡",
            "论命细法",
            "心镜歌",
            "妖祥赋",
            "相心赋",
            "玄机赋",
            "幽微赋",
            "五行元理消息赋",
            "造微论",
            "人鑑论",
            "爱憎赋",
            "万金赋",
            "挈要捷驰玄妙诀",
            "渊源集说",
            "子平百章论科甲歌",
        ],
    ),
    "06-dubu-shenruo.md": (
        "独步 / 身弱：四言独步 / 身弱论 / 弃命从杀论 / 五言独步 / 五行生克赋",
        '独步口诀 + 弃命从杀 — 与《子平真诠》"杂格"交叉印证 + 从格判定补强',
        [
            "四言獨步",
            "先看月令，次看淺深。",
            "身弱论",
            "弃命从杀论",
            "五言独步",
            "五行生剋赋",
        ],
    ),
    "07-luolu-zage.md": (
        "珞琭子 / 杂格：珞琭子消息赋 / 论八字撮要法 / 格局生死引用 / 会要命书说",
        "珞琭子赋 + 杂格生死 — DayunEngine.ts 杂格大运 trend 交叉印证",
        ["珞琭子消息赋", "论八字撮要法", "格局生死引用", "会要命书说"],
    ),
}


def strip_tags(s: str) -> str:
    s = re.sub(r"<[^>]+>", "", s)
    return unescape(s).strip()


def parse_xhtml() -> dict:
    """Returns {chapter_title: chapter_body_html}."""
    text = SRC.read_text(encoding="utf-8")
    pieces = re.split(r"(<h[23][^>]*>.*?</h[23]>)", text, flags=re.DOTALL)
    result = {}
    last_title = None
    buf = []
    for piece in pieces:
        m = re.match(r"<h([23])[^>]*>(.*?)</h\1>", piece, re.DOTALL)
        if m:
            if last_title:
                result[last_title] = "".join(buf)
                buf = []
            last_title = strip_tags(m.group(2))
        else:
            if last_title:
                buf.append(piece)
    if last_title:
        result[last_title] = "".join(buf)
    return result


def chapter_to_md(title: str, raw_html: str) -> str:
    paragraphs = re.findall(r"<p[^>]*>(.*?)</p>", raw_html, re.DOTALL)
    out = [f"## {title}", ""]
    for p in paragraphs:
        text = strip_tags(p)
        if text:
            out.append(text)
            out.append("")
    out.append("---")
    out.append("")
    return "\n".join(out)


def build_file(
    filename: str, label: str, role: str, titles: list, chapters: dict
) -> str:
    parts = []
    parts.append("---")
    parts.append("book: 渊海子平")
    parts.append(f"chapter: {label}")
    parts.append(
        'edition: "Wikisource zh epub (https://zh.wikisource.org/wiki/淵海子平) — 徐升辑（明初本）。本电子版未注明底本，待与中州古籍出版社点校本印刷版核校"'
    )
    parts.append("fillStatus: filled-from-epub")
    parts.append('filledBy: "extracted from epub via scripts/extract-yuanhai.py"')
    parts.append("filledAt: 2026-05-07")
    parts.append("priority: P1")
    parts.append(f'algorithmRole: "{role}"')
    parts.append("---")
    parts.append("")
    parts.append(f"# 渊海子平 · {label}")
    parts.append("")
    parts.append(
        "> 来源：epub `淵海子平.epub`（Wikisource zh-Hans 转出），未提供印刷底本。"
    )
    parts.append(
        "> 进入 fixture 校验前需与印刷版（推荐：中州古籍出版社李峰整理本 / 海南出版社）逐字核校。"
    )
    parts.append("> 本文件为 P1 交叉印证用，**不直接驱动 Phase 2 BaziEngine 重写**。")
    parts.append("")
    for t in titles:
        if t not in chapters:
            parts.append(f"## {t}\n\n⚠ 提取失败：epub 中未找到该章节。\n\n---\n")
            continue
        parts.append(chapter_to_md(t, chapters[t]))
    parts.append("## 录入备注")
    parts.append("")
    parts.append("- epub 自动提取，未做语义校对；段落顺序保持 epub 原序。")
    parts.append(
        "- 渊海子平含大量赋文 / 歌诀，自动提取后文体段落混合，需人工标注 `> 原文：` `> 注：` 区分。"
    )
    parts.append(
        '- 简繁混排（"印綬/印绶"、"獨步/独步"、"剋/克"）未 normalize；下游用 `lib/utils/text.ts` 转换。'
    )
    parts.append(
        '- 命例多以"某人甲子年..."散见于赋文，非独立章节，需要人工抽取入 fixture。'
    )
    parts.append("")
    return "\n".join(parts)


if __name__ == "__main__":
    OUT_BASE.mkdir(parents=True, exist_ok=True)
    chapters = parse_xhtml()
    print(f"Parsed {len(chapters)} chapters from epub.")
    for fname, (label, role, titles) in CLUSTERS.items():
        out_path = OUT_BASE / fname
        content = build_file(fname, label, role, titles, chapters)
        out_path.write_text(content, encoding="utf-8")
        hit = sum(1 for t in titles if t in chapters)
        print(
            f"  wrote {fname}: {len(content)} chars, {hit}/{len(titles)} chapters resolved"
        )
