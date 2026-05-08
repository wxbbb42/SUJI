#!/usr/bin/env python3
"""
Extract 子平真诠评注 (徐乐吾) PDF -> per-chapter markdown.
Source: /Users/xiaobenwang/Downloads/783164565-子平真诠评注-徐乐吾.pdf -> /tmp/ziping-zhenquan.txt
Output: docs/mingli/source-texts/bazi/ziping-zhenquan/{00-abstract,31-zhengguan,...}.md
"""

import re
from pathlib import Path

SRC = Path("/tmp/ziping-zhenquan.txt")
OUT_BASE = Path(
    "/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/ziping-zhenquan"
)

# Map output file -> list of (chapter_num_label, chapter_full_title)
CHAPTER_MAP = {
    "00-abstract-chapters.md": {
        "label": "论十神 / 论用神 / 论相神紧要 / 论用神成败救应 / 论用神变化 / 论用神格局高低（Phase 2 算法主框架来源）",
        "role": "GeJuV2.{name,category,yongShen,xiangShen,chengBai,jiuYing,jibie} 字段定义来源",
        "chapters": [
            "八、论用神",
            "九、论用神成败救应",
            "十、论用神变化",
            "十一、论用神纯杂",
            "十二、 论用神格局高低",
            "十三、论用神因成得败因败得成",
            "十四、论用神配气候得失",
            "十五、论相神紧要",
        ],
    },
    "31-zhengguan.md": {
        "label": "论正官 / 论正官取运",
        "role": "GeJuV2 正官格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["三十一、论正官", "三十二、论正官取运"],
    },
    "33-cai.md": {
        "label": "论财 / 论财取运",
        "role": "GeJuV2 财格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["三十三、论财", "三十四、论财取运"],
    },
    "35-yinshou.md": {
        "label": "论印绶 / 论印绶取运",
        "role": "GeJuV2 印绶格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["三十五、论印绶", "三十六、论印绶取运"],
    },
    "37-shishen.md": {
        "label": "论食神 / 论食神取运",
        "role": "GeJuV2 食神格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["三十七、论食神", "三十八、论食神取运"],
    },
    "38-shanguan.md": {
        "label": "论伤官 / 论伤官取运（注：徐乐吾本章序为四十一/四十二，模板沿用沈孝瞻原 39 篇编号惯例）",
        "role": "GeJuV2 伤官格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["四十一、论伤官", "四十二、论伤官取运"],
    },
    "39-qisha.md": {
        "label": "论偏官（七杀） / 论偏官取运",
        "role": "GeJuV2 七杀格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["三十九、论偏官", "四十、论偏官取运"],
    },
    "41-yangren.md": {
        "label": "论阳刃 / 论阳刃取运（注：徐乐吾本章序为四十三/四十四）",
        "role": "GeJuV2 阳刃格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["四十三、论阳刃", "四十四、论阳刃取运"],
    },
    "42-jianlu-yuejie.md": {
        "label": "论建禄月劫 / 论建禄月劫取运（注：徐乐吾本章序为四十五/四十六）",
        "role": "GeJuV2 建禄月劫格 chengBai/xiangShen/jiuYing 规则",
        "chapters": ["四十五、论建禄月劫", "四十六、论建禄月劫取运"],
    },
    "43-zage.md": {
        "label": "论杂格（注：徐乐吾本章序为四十七）",
        "role": "GeJuV2 杂格（从化、专旺、化气）补充规则",
        "chapters": ["四十七、论杂格"],
    },
    # ===== 完整覆盖：补全 PDF 全书 48 章中尚未抽取的部分 (2026-05-07) =====
    "01-foundations.md": {
        "label": "论十干十二支 / 论阴阳生克 / 论阴阳生死 / 论十干配合性情 / 论十干合而不合 / 论十干得时不旺失时不弱 / 论刑冲会合解法",
        "role": "命理基础（干支体性 / 阴阳生克 / 五行生死 / 合化 / 刑冲会合）— RiZhuStructure 与 TongGenInfo 的语义底座",
        "chapters": [
            "一．论十干十二支",
            "二、论阴阳生克",
            "三、论阴阳生死",
            "四、论十干配合性情",
            "五、论十干合而不合",
            "六、论十干得时不旺失时不弱",
            "七、论刑冲会合解法",
        ],
    },
    "16-zaji-mukukao.md": {
        "label": "论杂气如何取用 / 论墓库刑冲之说",
        "role": "杂气格 / 库地刑冲取用 — GeJuV2 杂气与库地用神判定",
        "chapters": ["十六、论杂气如何取用", "十七、论墓库刑冲之说"],
    },
    "18-jixiongshen-pojucheng.md": {
        "label": "论四吉神能破格 / 论四凶神能成格 / 论生克先后分吉凶",
        "role": "吉神 / 凶神成败救应判定 — chengBai/jiuYing 的反例规则",
        "chapters": [
            "十八、论四吉神能破格",
            "十九、论四凶神能成格",
            "二十、论生克先后分吉凶",
        ],
    },
    "21-xingchen-waige.md": {
        "label": "论星辰无关格局 / 论外格用舍",
        "role": '星辰避雷 + 外格取舍 — Phase 2 反对"神煞驱动"的依据 + 外格判定',
        "chapters": ["二十一、论星辰无关格局", "二十二、论外格用舍"],
    },
    "23-gongfen-qizi.md": {
        "label": "论宫分用神配六亲 / 论妻子",
        "role": "宫位 + 六亲匹配 — MarriageEngine.ts 与 InsightEngine.ts 六亲判定核心",
        "chapters": ["二十三、论宫分用神配六亲", "二十四、论妻子"],
    },
    "25-xingyun.md": {
        "label": "论行运 / 论行运成格变格 / 论喜忌干支有别 / 论支中喜忌逢运透清",
        "role": "大运 trend 判定 — DayunEngine.ts 用神/喜神/忌神 vs 大运字判定核心",
        "chapters": [
            "二十五、论行运",
            "二十六、论行运成格变格",
            "二十七、论喜忌干支有别",
            "二十八、论支中喜忌逢运透清",
        ],
    },
    "29-shishuo-eche.md": {
        "label": "论时说拘泥格局 / 论时说以讹传讹",
        "role": "辨伪 / 反对俗说 — 命理产品文案禁忌 + 反 D-tier 民间法的依据",
        "chapters": ["二十九、论时说拘泥格局", "三十、论时说以讹传讹"],
    },
    "48-zage-quyun.md": {
        "label": "附论杂格取运（注：徐乐吾本章序为四十八）",
        "role": "杂格大运取舍 — DayunEngine.ts 杂格分支",
        "chapters": ["四十八、附论杂格取运"],
    },
}


def parse_chapters() -> dict:
    """
    Returns {chapter_full_title: body_text} where body_text is everything between
    this chapter heading and the next chapter heading.
    """
    text = SRC.read_text(encoding="utf-8")
    lines = text.splitlines()

    # Find all chapter heading line numbers
    headings = []  # list of (lineno, title)
    chapter_re = re.compile(
        r"^[ \t]+([一二三四五六七八九十百零]+)[、．\.]\s*[附]?论[\u4e00-\u9fff].*$"
    )
    for i, line in enumerate(lines):
        if chapter_re.match(line):
            headings.append((i, line.strip()))

    # Build {title: body}
    result = {}
    for idx, (start, title) in enumerate(headings):
        end = headings[idx + 1][0] if idx + 1 < len(headings) else len(lines)
        body_lines = lines[start + 1 : end]
        result[title] = "\n".join(body_lines).strip()
    return result


def normalize_body(raw: str) -> str:
    """
    PDF was extracted with -layout. Clean up:
    - Strip page-number / header noise (lines that are just numbers or dashes)
    - Collapse hard-wrapped paragraphs (lines ending mid-sentence) into single paras
    - Preserve blank-line paragraph breaks
    """
    out_paras = []
    current = []
    for raw_line in raw.split("\n"):
        line = raw_line.rstrip()
        # skip pure noise
        if not line.strip():
            if current:
                out_paras.append("".join(current))
                current = []
            continue
        # Skip lines that are only digits or punctuation (likely page numbers)
        stripped = line.strip()
        if re.fullmatch(r"[0-9·\-—\s]+", stripped):
            continue
        # Append, joining wrapped Chinese lines without space
        current.append(stripped)
    if current:
        out_paras.append("".join(current))
    # Re-split obvious paragraph boundaries that PDF kept on same blank-separated chunk
    return "\n\n".join(out_paras)


def build_file(filename: str, meta: dict, chapters_dict: dict) -> str:
    parts = []
    parts.append("---")
    parts.append("book: 子平真诠评注")
    parts.append(f'chapter: {meta["label"]}')
    parts.append(
        'edition: "PDF: 783164565-子平真诠评注-徐乐吾.pdf （沈孝瞻原著 + 徐乐吾评注，民国二十五年初版本之电子化）— 待与上海星相书局/中州古籍出版社印刷版核校"'
    )
    parts.append("fillStatus: filled-from-pdf")
    parts.append(
        'filledBy: "extracted from pdf via scripts/extract-ziping.py (pdftotext -layout)"'
    )
    parts.append("filledAt: 2026-05-07")
    parts.append("priority: P0")
    parts.append(f'algorithmRole: "{meta["role"]}"')
    parts.append("---")
    parts.append("")
    parts.append(f'# 子平真诠评注 · {meta["label"]}')
    parts.append("")
    parts.append("> 来源：徐乐吾《子平真诠评注》PDF 电子版，pdftotext -layout 提取。")
    parts.append(
        "> 进入 fixture 校验前需与印刷版（推荐：上海星相书局民国版 / 中州古籍点校本）逐字核校。"
    )
    parts.append(
        "> 结构：每章包含沈孝瞻 原文 + 徐乐吾 评注，PDF 中两者通常按段交错；本文件保留 epub 段落顺序，下游解析时需按行人工标注。"
    )
    parts.append("")

    for chapter_title in meta["chapters"]:
        if chapter_title not in chapters_dict:
            parts.append(
                f"## {chapter_title}\n\n⚠ 提取失败：PDF 中未找到该章节标题，可能拼写/标点不一致。\n\n---\n"
            )
            continue
        parts.append(f"## {chapter_title}")
        parts.append("")
        body = normalize_body(chapters_dict[chapter_title])
        if body:
            parts.append(body)
        parts.append("")
        parts.append("---")
        parts.append("")

    parts.append("## 录入备注")
    parts.append("")
    parts.append("- PDF 自动提取，未做语义校对；段落顺序保持 PDF 原序。")
    parts.append(
        "- PDF 双栏 / 表格 / 命例八字 在 -layout 模式下可能错位，**所有命例的八字配对需与原书核校**。"
    )
    parts.append(
        "- 沈孝瞻 原文与徐乐吾 评注在 PDF 中没有显式区分（无字号/字体差），需要人工标注：通常每节开头 1-2 段为原文，后续小段为评注。下游解析时建议加 `> 原文：` `> 评注：` 标注。"
    )
    parts.append(
        '- 部分繁简混排（"剋/克"、"歷/历"、"財/财"）未 normalize；下游用 `lib/utils/text.ts` 做转换。'
    )
    parts.append("")
    return "\n".join(parts)


if __name__ == "__main__":
    chapters = parse_chapters()
    print(f"Parsed {len(chapters)} chapters from PDF text.")
    for fname, meta in CHAPTER_MAP.items():
        out_path = OUT_BASE / fname
        content = build_file(fname, meta, chapters)
        out_path.write_text(content, encoding="utf-8")
        # report which chapters resolved
        hit = sum(1 for c in meta["chapters"] if c in chapters)
        print(
            f'  wrote {fname}: {len(content)} chars, {hit}/{len(meta["chapters"])} chapters resolved'
        )
