#!/usr/bin/env python3
"""
Extract chapters from 滴天髓阐微 epub xhtml -> markdown.
Source file: /tmp/ditianshui-epub/OPS/c0_di_tian_sui_chan_wei.xhtml
"""
import re
from pathlib import Path
from html import unescape

SRC = Path('/tmp/ditianshui-epub/OPS/c0_di_tian_sui_chan_wei.xhtml')
OUT_BASE = Path('/Users/xiaobenwang/Documents/SUJI/docs/mingli/source-texts/bazi/ditianshui-chanwei')

# Map output file -> list of chapter titles (must match h3 text exactly)
# Existing P0 curated files (Phase-2 algorithm role):
#   tiyong / qingzhuo / hannuanzaoshi / gangrou / shunni
# New "完整覆盖" files (added 2026-05-07): cover the remaining chapters so the
# whole 滴天髓阐微 (通神论 34 + 六亲论 29 = 63 章) is in repo.
CHAPTER_MAP = {
    # ===== existing curated files =====
    'tiyong.md': [('通神论', '十三、体用')],
    'qingzhuo.md': [
        ('通神论', '二十三、清气'),
        ('通神论', '二十四、浊气'),
        ('通神论', '二十五、真神'),
        ('通神论', '二十六、假神'),
    ],
    'hannuanzaoshi.md': [
        ('通神论', '二十九、寒暖'),
        ('通神论', '三十、燥湿'),
    ],
    'gangrou.md': [('通神论', '二十七、刚柔')],
    'shunni.md': [
        ('通神论', '二十八、顺逆'),
        ('六亲论', '十二、从象'),
        ('六亲论', '十三、化象'),
        ('六亲论', '十四、假从'),
        ('六亲论', '十五、假化'),
        ('六亲论', '十六、顺局'),
        ('六亲论', '十七、反局'),
    ],
    # ===== new files: full coverage =====
    'tongshen-01-foundations.md': [
        ('通神论', '一、天道'),
        ('通神论', '二、地道'),
        ('通神论', '三、人道'),
        ('通神论', '四、知命'),
        ('通神论', '五、理气'),
        ('通神论', '六、配合'),
    ],
    'tongshen-07-ganzhi.md': [
        ('通神论', '七、天干'),
        ('通神论', '八、地支'),
        ('通神论', '九、干支总论'),
    ],
    'tongshen-10-xingxiang-bage.md': [
        ('通神论', '十、形象'),
        ('通神论', '十一、方局'),
        ('通神论', '十二、八格'),
    ],
    'tongshen-14-jingshen-shiling.md': [
        ('通神论', '十四、精神'),
        ('通神论', '十五、月令'),
        ('通神论', '十六、生时'),
    ],
    'tongshen-17-shuaiwang-zhonghe.md': [
        ('通神论', '十七、衰旺'),
        ('通神论', '十八、中和'),
        ('通神论', '十九、源流'),
        ('通神论', '二十、通关'),
    ],
    'tongshen-21-guansha-shanguan.md': [
        ('通神论', '二十一、官杀'),
        ('通神论', '二十二、伤官'),
    ],
    'tongshen-31-yinxian-zhongguai.md': [
        ('通神论', '三十一、隐显'),
        ('通神论', '三十二、众寡'),
        ('通神论', '三十三、震兑'),
        ('通神论', '三十四、坎离'),
    ],
    'liuqin-01-fuqi-zinv.md': [
        ('六亲论', '一、夫妻'),
        ('六亲论', '二、子女'),
        ('六亲论', '三、父母'),
        ('六亲论', '四、兄弟'),
    ],
    'liuqin-05-hezhizhang-nvming.md': [
        ('六亲论', '五、何知章'),
        ('六亲论', '六、女命章'),
        ('六亲论', '七、小儿'),
    ],
    'liuqin-08-caide-fenyu-enyuan.md': [
        ('六亲论', '八、才德'),
        ('六亲论', '九、奋郁'),
        ('六亲论', '十、恩怨'),
        ('六亲论', '十一、闲神'),
    ],
    'liuqin-18-zhanju-junchen.md': [
        ('六亲论', '十八、战局'),
        ('六亲论', '十九、合局'),
        ('六亲论', '二十、君象'),
        ('六亲论', '二十一、臣象'),
        ('六亲论', '二十二、母象'),
        ('六亲论', '二十三、子象'),
    ],
    'liuqin-24-xingqing-jibing.md': [
        ('六亲论', '二十四、性情'),
        ('六亲论', '二十五、疾病'),
        ('六亲论', '二十六、出身'),
        ('六亲论', '二十七、地位'),
    ],
    'liuqin-28-suiyun-zhenyuan.md': [
        ('六亲论', '二十八、岁运'),
        ('六亲论', '二十九、贞元'),
    ],
}

ROLE_NOTES = {
    'tiyong.md': 'RiZhuStructure: deLing/shiLing/zuoGen 字段',
    'qingzhuo.md': 'RiZhuStructure.qingZhuo enum + 真假神判定',
    'hannuanzaoshi.md': 'RiZhuStructure.hanNuanZaoShi 四象',
    'gangrou.md': '强弱判定边界',
    'shunni.md': '从格 / 化气格 / 专旺格 / 假从 / 假化判定',
    'tongshen-01-foundations.md': '命理总纲（天人理气配合）— 用神/相神判定的哲学基础，非直接算法字段',
    'tongshen-07-ganzhi.md': '十干十二支体性 — TongGenInfo / 干支强弱判定的语义底座',
    'tongshen-10-xingxiang-bage.md': '形象 / 方局 / 八格 — GeJuV2.category 与方局合化判定',
    'tongshen-14-jingshen-shiling.md': '精神 / 月令 / 生时 — RiZhuStructure.deLing 与 yongShen 取法',
    'tongshen-17-shuaiwang-zhonghe.md': '衰旺 / 中和 / 源流 / 通关 — computeRiZhuStrength 五档判定核心',
    'tongshen-21-guansha-shanguan.md': '官杀 / 伤官 — 各格成败救应的具体判定',
    'tongshen-31-yinxian-zhongguai.md': '隐显 / 众寡 / 震兑 / 坎离 — 用神隐露与方位 / 五行盈虚判定',
    'liuqin-01-fuqi-zinv.md': '夫妻 / 子女 / 父母 / 兄弟 — MarriageEngine 与 InsightEngine 六亲判定',
    'liuqin-05-hezhizhang-nvming.md': '何知章 / 女命章 / 小儿 — 命运预测口诀与女命专章（产品文案禁忌避雷）',
    'liuqin-08-caide-fenyu-enyuan.md': '才德 / 奋郁 / 恩怨 / 闲神 — 性格与人际倾向（中性化解读源）',
    'liuqin-18-zhanju-junchen.md': '战局 / 合局 / 君臣母子象 — 特殊格局（相神 / 用神搭配的 archetype）',
    'liuqin-24-xingqing-jibing.md': '性情 / 疾病 / 出身 / 地位 — 性情判定 + 健康倾向（健康类必须中性化）',
    'liuqin-28-suiyun-zhenyuan.md': '岁运 / 贞元 — DayunEngine 大运流年 trend 判定核心',
}

CHAPTER_TITLES_HUMAN = {
    'tiyong.md': '体用章',
    'qingzhuo.md': '清气章 + 浊气章 + 真神章 + 假神章',
    'hannuanzaoshi.md': '寒暖章 + 燥湿章',
    'gangrou.md': '刚柔章',
    'shunni.md': '顺逆章（通神论）+ 从象/化象/假从/假化/顺局/反局章（六亲论）',
    'tongshen-01-foundations.md': '通神论 第一-六章：天道 / 地道 / 人道 / 知命 / 理气 / 配合',
    'tongshen-07-ganzhi.md': '通神论 第七-九章：天干 / 地支 / 干支总论',
    'tongshen-10-xingxiang-bage.md': '通神论 第十-十二章：形象 / 方局 / 八格',
    'tongshen-14-jingshen-shiling.md': '通神论 第十四-十六章：精神 / 月令 / 生时',
    'tongshen-17-shuaiwang-zhonghe.md': '通神论 第十七-二十章：衰旺 / 中和 / 源流 / 通关',
    'tongshen-21-guansha-shanguan.md': '通神论 第二十一-二十二章：官杀 / 伤官',
    'tongshen-31-yinxian-zhongguai.md': '通神论 第三十一-三十四章：隐显 / 众寡 / 震兑 / 坎离',
    'liuqin-01-fuqi-zinv.md': '六亲论 第一-四章：夫妻 / 子女 / 父母 / 兄弟',
    'liuqin-05-hezhizhang-nvming.md': '六亲论 第五-七章：何知章 / 女命章 / 小儿',
    'liuqin-08-caide-fenyu-enyuan.md': '六亲论 第八-十一章：才德 / 奋郁 / 恩怨 / 闲神',
    'liuqin-18-zhanju-junchen.md': '六亲论 第十八-二十三章：战局 / 合局 / 君象 / 臣象 / 母象 / 子象',
    'liuqin-24-xingqing-jibing.md': '六亲论 第二十四-二十七章：性情 / 疾病 / 出身 / 地位',
    'liuqin-28-suiyun-zhenyuan.md': '六亲论 第二十八-二十九章：岁运 / 贞元',
}

CHAPTER_BOOK_LABEL = {
    'tiyong.md': '体用论',
    'qingzhuo.md': '清浊论 / 真假论',
    'hannuanzaoshi.md': '寒暖论 / 燥湿论',
    'gangrou.md': '刚柔论',
    'shunni.md': '顺逆论 / 反局论 / 从象论 / 化象论（含假从假化顺局反局）',
    'tongshen-01-foundations.md': '通神论·总纲（天道-配合）',
    'tongshen-07-ganzhi.md': '通神论·干支体性（天干 / 地支 / 干支总论）',
    'tongshen-10-xingxiang-bage.md': '通神论·形象方局八格',
    'tongshen-14-jingshen-shiling.md': '通神论·精神月令生时',
    'tongshen-17-shuaiwang-zhonghe.md': '通神论·衰旺中和源流通关',
    'tongshen-21-guansha-shanguan.md': '通神论·官杀伤官',
    'tongshen-31-yinxian-zhongguai.md': '通神论·隐显众寡震兑坎离',
    'liuqin-01-fuqi-zinv.md': '六亲论·夫妻子女父母兄弟',
    'liuqin-05-hezhizhang-nvming.md': '六亲论·何知章女命章小儿',
    'liuqin-08-caide-fenyu-enyuan.md': '六亲论·才德奋郁恩怨闲神',
    'liuqin-18-zhanju-junchen.md': '六亲论·战局合局君臣母子象',
    'liuqin-24-xingqing-jibing.md': '六亲论·性情疾病出身地位',
    'liuqin-28-suiyun-zhenyuan.md': '六亲论·岁运贞元',
}


def strip_tags(s: str) -> str:
    s = re.sub(r'<[^>]+>', '', s)
    return unescape(s).strip()


def parse_xhtml() -> dict:
    """
    Returns dict: { ('通神论', '十三、体用') : raw_chapter_html_inner }
    Each chapter inner = everything between its <h3> and the next <h3>/<h2>.
    """
    text = SRC.read_text(encoding='utf-8')
    result = {}
    current_h2 = None

    # tokenise on h2 / h3 boundaries
    pieces = re.split(r'(<h[23][^>]*>.*?</h[23]>)', text, flags=re.DOTALL)
    last_key = None
    buf = []
    for piece in pieces:
        h2m = re.match(r'<h2[^>]*>(.*?)</h2>', piece, re.DOTALL)
        h3m = re.match(r'<h3[^>]*>(.*?)</h3>', piece, re.DOTALL)
        if h2m:
            if last_key:
                result[last_key] = ''.join(buf)
                last_key = None
                buf = []
            current_h2 = strip_tags(h2m.group(1))
        elif h3m:
            if last_key:
                result[last_key] = ''.join(buf)
                buf = []
            title = strip_tags(h3m.group(1))
            last_key = (current_h2, title)
        else:
            if last_key:
                buf.append(piece)
    if last_key:
        result[last_key] = ''.join(buf)
    return result


# Categorise each <p>: 歌诀 (the first plain <p> after h3) / 原注 / 任注 / 命例
def classify_paragraph(p_inner_html: str) -> tuple[str, str]:
    """
    Returns (kind, cleaned_text).
    kind in {'yuanzhu', 'renzhu', 'plain'}
    'plain' = either 歌诀 or 命例 (caller decides by ordering)
    """
    # 原注: <small style="color:..."> typically wraps it
    if '<small' in p_inner_html and '原注' in p_inner_html:
        text = strip_tags(p_inner_html)
        # strip leading '〈' and 'X注：' / trailing '〉'
        text = re.sub(r'^[〈⟨]?', '', text)
        text = re.sub(r'^原注[:：]\s*', '', text)
        text = re.sub(r'[〉⟩]?$', '', text)
        return ('yuanzhu', text.strip())

    # 任注: navy span with 任氏曰
    if '任氏曰' in p_inner_html or 'navy' in p_inner_html:
        text = strip_tags(p_inner_html)
        text = re.sub(r'^[〈⟨]?', '', text)
        text = re.sub(r'^任氏曰[:：]\s*', '', text)
        text = re.sub(r'[〉⟩]?$', '', text)
        return ('renzhu', text.strip())

    # plain
    return ('plain', strip_tags(p_inner_html))


def chapter_to_markdown(chapter_title: str, raw_html: str) -> str:
    """
    Convert one chapter's raw inner HTML to clean markdown.
    """
    # Extract every <p>...</p>
    paragraphs = re.findall(r'<p[^>]*>(.*?)</p>', raw_html, re.DOTALL)
    out_lines = [f'### {chapter_title}\n']

    # Strategy: scan paragraphs in order; classify each
    # First plain = 歌诀; subsequent plains (after we hit any 原注/任注) = 命例 chunks
    state = 'expecting_geju'  # 'expecting_geju' -> 'in_notes' -> 'in_mingli'
    geju_lines = []
    in_mingli_block = False
    case_buffer = []

    def flush_case():
        nonlocal case_buffer
        if case_buffer:
            # Group consecutive short pillars (<=4 chars) on one line, then long analysis on its own
            grouped = []
            short_run = []
            for ln in case_buffer:
                if len(ln) <= 4:
                    short_run.append(ln)
                else:
                    if short_run:
                        grouped.append(' '.join(short_run))
                        short_run = []
                    grouped.append(ln)
            if short_run:
                grouped.append(' '.join(short_run))
            out_lines.append('#### 命例')
            out_lines.append('')
            for g in grouped:
                out_lines.append(g)
                out_lines.append('')
            case_buffer = []

    notes_seen = False
    for p in paragraphs:
        kind, text = classify_paragraph(p)
        if not text:
            continue
        if kind == 'yuanzhu':
            if geju_lines and state == 'expecting_geju':
                out_lines.append('#### 原文（歌诀）')
                out_lines.append('')
                for g in geju_lines:
                    out_lines.append(g)
                out_lines.append('')
                geju_lines = []
                state = 'in_notes'
            elif case_buffer:
                flush_case()
            out_lines.append('#### 原注')
            out_lines.append('')
            out_lines.append(text)
            out_lines.append('')
            notes_seen = True
        elif kind == 'renzhu':
            if geju_lines and state == 'expecting_geju':
                out_lines.append('#### 原文（歌诀）')
                out_lines.append('')
                for g in geju_lines:
                    out_lines.append(g)
                out_lines.append('')
                geju_lines = []
                state = 'in_notes'
            elif case_buffer:
                flush_case()
            out_lines.append('#### 任氏注')
            out_lines.append('')
            out_lines.append(text)
            out_lines.append('')
            notes_seen = True
        else:  # plain
            if state == 'expecting_geju' and not notes_seen:
                geju_lines.append(text)
            else:
                case_buffer.append(text)
    # flush any leftover
    if geju_lines and state == 'expecting_geju':
        out_lines.append('#### 原文（歌诀）')
        out_lines.append('')
        for g in geju_lines:
            out_lines.append(g)
        out_lines.append('')
    if case_buffer:
        flush_case()
    out_lines.append('---')
    out_lines.append('')
    return '\n'.join(out_lines)


def build_file(filename: str, chapter_keys: list, chapters_dict: dict) -> str:
    parts = []
    parts.append('---')
    parts.append('book: 滴天髓阐微')
    parts.append(f'chapter: {CHAPTER_BOOK_LABEL[filename]}')
    parts.append('edition: "Wikisource zh epub (https://zh.wikisource.org/wiki/滴天髓闡微) — 任铁樵注 通神论 + 六亲论。本电子版未注明底本，待与中州古籍出版社孙正治点校本印刷版核校"')
    parts.append('fillStatus: filled-from-epub')
    parts.append('filledBy: "extracted from epub via scripts/extract-ditianshui.py"')
    parts.append('filledAt: 2026-05-07')
    parts.append('priority: P0')
    parts.append(f'algorithmRole: "{ROLE_NOTES[filename]}"')
    parts.append('---')
    parts.append('')
    parts.append(f'# 滴天髓阐微 · {CHAPTER_BOOK_LABEL[filename]}')
    parts.append('')
    parts.append(f'> 章节：{CHAPTER_TITLES_HUMAN[filename]}')
    parts.append('> ')
    parts.append('> 来源：epub `滴天髓闡微.epub`，原文取自 zh.wikisource.org，未提供印刷底本。')
    parts.append('> 进入 fixture 校验前需与中州古籍出版社孙正治点校本（或同等 A-tier 印刷本）逐字核校。')
    parts.append('> 本文件由脚本批量提取，结构：原文（歌诀）/ 原注 / 任氏注 / 命例。')
    parts.append('')
    for h2_label, chapter_title in chapter_keys:
        key = (h2_label, chapter_title)
        if key not in chapters_dict:
            parts.append(f'### {chapter_title}\n\n⚠ 提取失败：epub 中未找到该章节（可能 h2/h3 文本不匹配）。\n\n---\n')
            continue
        parts.append(f'## 《{h2_label}》{chapter_title}')
        parts.append('')
        parts.append(chapter_to_markdown(chapter_title, chapters_dict[key]))
    parts.append('## 录入备注')
    parts.append('')
    parts.append('- epub 自动提取，未做语义校对；命例的 八字/任注 行配对依赖 epub 段落顺序，可能存在偏差。')
    parts.append('- 简繁混排：epub 内文为简体（Wikisource zh-Hans 转出），但部分书名/概念保留繁体（如"闡微"），未强制 normalize。')
    parts.append('- 命例的"日柱 时柱 大运"等列在原 epub 中是若干并列短 <p>，本脚本将连续 ≤4 字短段合并成一行；如有错配，需手工调整。')
    parts.append('')
    return '\n'.join(parts)


if __name__ == '__main__':
    chapters = parse_xhtml()
    print(f'Parsed {len(chapters)} chapters from epub.')
    for filename, keys in CHAPTER_MAP.items():
        out_path = OUT_BASE / filename
        content = build_file(filename, keys, chapters)
        out_path.write_text(content, encoding='utf-8')
        print(f'  wrote {filename}: {len(content)} chars covering {len(keys)} chapter(s)')
