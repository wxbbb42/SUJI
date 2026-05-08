#!/usr/bin/env python3
"""
Extract 穷通宝鉴 epub xhtml -> per-干 markdown files.
Source: /tmp/穷通宝鉴-epub/OPS/c0_qiong_tong_bao_jian.xhtml
Output: docs/mingli/source-texts/bazi/qiongtong-baojian/{jiamu,yimu,...}.md
"""

import re
from pathlib import Path
from html import unescape

SRC = Path("/tmp/穷通宝鉴-epub/OPS/c0_qiong_tong_bao_jian.xhtml")
OUT_BASE = Path(
    "/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/qiongtong-baojian"
)

GAN_FILE_MAP = {
    "论甲木": ("jiamu.md", "甲木", "论木"),
    "论乙木": ("yimu.md", "乙木", "论木"),
    "论丙火": ("binghuo.md", "丙火", "论火"),
    "论丁火": ("dinghuo.md", "丁火", "论火"),
    "论戊土": ("wutu.md", "戊土", "论土"),
    "论己土": ("jitu.md", "己土", "论土"),
    "论庚金": ("gengjin.md", "庚金", "论金"),
    "论辛金": ("xinjin.md", "辛金", "论金"),
    "论壬水": ("renshui.md", "壬水", "论水"),
    "论癸水": ("guishui.md", "癸水", "论水"),
}

WUXING_INTRO_KEYS = {"论木", "论火", "论土", "论金", "论水"}


def strip_tags_keep_bold(s: str) -> str:
    s = re.sub(r"<b[^>]*>(.*?)</b>", r"**\1**", s, flags=re.DOTALL)
    s = re.sub(r"<[^>]+>", "", s)
    return unescape(s).strip()


def parse_xhtml() -> dict:
    """
    Returns:
      {
        'h2_intro_lun_mu': inner_html_of_论木,
        'h2_per_gan_论甲木': {
            'intro': inner_html_after_h2_before_first_h3,
            'sections': [('三春甲木', inner), ('三夏甲木', inner), ...]
        },
        ...
      }
    """
    text = SRC.read_text(encoding="utf-8")
    intro = {}  # 五行 intro: 论木/论火/...
    per_gan = {}  # 论甲木 -> {'intro': ..., 'sections': [(title, html)]}

    # Tokenize
    pieces = re.split(r"(<h[1-3][^>]*>.*?</h[1-3]>)", text, flags=re.DOTALL)
    state = None  # 'wuxing_intro' / 'gan_intro' / 'gan_section'
    current_wuxing = None
    current_gan = None
    current_h3 = None
    buf = []

    def flush():
        nonlocal buf, state, current_wuxing, current_gan, current_h3
        chunk = "".join(buf).strip()
        if state == "wuxing_intro" and current_wuxing:
            intro[current_wuxing] = chunk
        elif state == "gan_intro" and current_gan:
            per_gan.setdefault(current_gan, {"intro": "", "sections": []})
            per_gan[current_gan]["intro"] = chunk
        elif state == "gan_section" and current_gan and current_h3:
            per_gan.setdefault(current_gan, {"intro": "", "sections": []})
            per_gan[current_gan]["sections"].append((current_h3, chunk))
        buf = []

    for piece in pieces:
        h2m = re.match(r"<h2[^>]*>(.*?)</h2>", piece, re.DOTALL)
        h3m = re.match(r"<h3[^>]*>(.*?)</h3>", piece, re.DOTALL)
        h1m = re.match(r"<h1[^>]*>(.*?)</h1>", piece, re.DOTALL)
        if h1m:
            flush()
            state = None
            current_wuxing = current_gan = current_h3 = None
        elif h2m:
            flush()
            title = strip_tags_keep_bold(h2m.group(1))
            if title in WUXING_INTRO_KEYS:
                state = "wuxing_intro"
                current_wuxing = title
                current_gan = current_h3 = None
            elif title in GAN_FILE_MAP:
                state = "gan_intro"
                current_gan = title
                current_h3 = None
            else:
                state = None
        elif h3m:
            flush()
            if current_gan:
                state = "gan_section"
                current_h3 = strip_tags_keep_bold(h3m.group(1))
            else:
                state = None
        else:
            if state:
                buf.append(piece)
    flush()
    return intro, per_gan


def section_to_markdown(html: str) -> str:
    """Convert a chapter section's inner html into clean markdown paragraphs."""
    paragraphs = re.findall(r"<p[^>]*>(.*?)</p>", html, re.DOTALL)
    out = []
    for p in paragraphs:
        text = strip_tags_keep_bold(p)
        if text:
            out.append(text)
    return "\n\n".join(out)


def build_file(
    filename: str,
    gan_label: str,
    wuxing_intro_key: str,
    wuxing_intro_html: str,
    gan_data: dict,
) -> str:
    parts = []
    parts.append("---")
    parts.append("book: 穷通宝鉴")
    parts.append(f"chapter: {gan_label} 12 月（按四季分组）")
    parts.append(
        'edition: "Wikisource zh epub (https://zh.wikisource.org/wiki/穷通宝鉴) — 余春台辑本。本电子版未注明底本，待与中州古籍出版社/同等 A-tier 印刷本（含徐乐吾评注版）核校"'
    )
    parts.append("fillStatus: filled-from-epub")
    parts.append('filledBy: "extracted from epub via scripts/extract-qiongtong.py"')
    parts.append("filledAt: 2026-05-07")
    parts.append("priority: P0")
    parts.append(
        f'algorithmRole: "TIAO_HOU_YONG_SHEN 表 — {gan_label}各月调候用神/喜神/忌神核校来源"'
    )
    parts.append("---")
    parts.append("")
    parts.append(f"# 穷通宝鉴 · {gan_label}")
    parts.append("")
    parts.append(
        "> 来源：epub `穷通宝鉴.epub`，原文取自 zh.wikisource.org，未提供印刷底本。"
    )
    parts.append("> 进入 fixture 校验前需与印刷版（含徐乐吾评注本）逐字核校。")
    parts.append(
        "> 结构：五行总论（同五行） + 干总论 + 三春/三夏/三秋/三冬 × 内含正月/二月/三月（以 **加粗** 标记起始）。"
    )
    parts.append("")

    if wuxing_intro_html:
        parts.append(f"## 《十干分论》{wuxing_intro_key}")
        parts.append("")
        parts.append(section_to_markdown(wuxing_intro_html))
        parts.append("")

    if gan_data.get("intro"):
        intro_md = section_to_markdown(gan_data["intro"])
        if intro_md:
            parts.append(f"## 《十干分论》论{gan_label}")
            parts.append("")
            parts.append(intro_md)
            parts.append("")

    for title, body in gan_data.get("sections", []):
        parts.append(f"## {title}")
        parts.append("")
        body_md = section_to_markdown(body)
        if body_md:
            parts.append(body_md)
        else:
            parts.append("⚠ 提取失败：epub 中此节为空。")
        parts.append("")

    parts.append("---")
    parts.append("")
    parts.append("## 录入备注")
    parts.append("")
    parts.append("- epub 自动提取，未做语义校对；段落顺序保持 epub 原序。")
    parts.append(
        '- 月份切分：epub 按"三春/三夏/三秋/三冬"分组，每段内部用 `**正月X**` `**二月X**` `**三月X**` 加粗标识月头；下游索引时以加粗 token 作为月份锚点。'
    )
    parts.append(
        "- `BaziEngine.ts:382` `TIAO_HOU_YONG_SHEN` 表的 desc/yongShen/jiShen 字段需与本文件逐月核校；不一致须以本文件（升级到 A-tier 后）为准。"
    )
    parts.append("")
    return "\n".join(parts)


if __name__ == "__main__":
    intro, per_gan = parse_xhtml()
    print(f"Parsed {len(per_gan)} 干 sections, {len(intro)} 五行 intro sections.")
    for h2_label, (filename, gan_label, wuxing_key) in GAN_FILE_MAP.items():
        out_path = OUT_BASE / filename
        wuxing_html = intro.get(wuxing_key, "")
        gan_data = per_gan.get(h2_label, {"intro": "", "sections": []})
        content = build_file(filename, gan_label, wuxing_key, wuxing_html, gan_data)
        out_path.write_text(content, encoding="utf-8")
        n_sections = len(gan_data.get("sections", []))
        print(f"  wrote {filename}: {len(content)} chars, {n_sections} 季 sections")
