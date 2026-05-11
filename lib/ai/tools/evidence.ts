import type { ToolCall } from './types';

const MAX_EVIDENCE_LINES = 6;

function compact(value: unknown, max = 18): string {
  if (value === null || value === undefined || value === '') return '';
  const text = String(value);
  return text.length > max ? `${text.slice(0, max)}…` : text;
}

function getRecord(value: unknown): Record<string, any> | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as Record<string, any>;
}

function compactGanZhi(value: unknown): string {
  const r = getRecord(value);
  if (!r) return compact(value);
  const gan = r.gan ?? '';
  const zhi = r.zhi ?? '';
  return compact(`${gan}${zhi}`);
}

function firstArrayItem(value: unknown): any | null {
  return Array.isArray(value) && value.length > 0 ? value[0] : null;
}

function uniqPush(lines: string[], line: string) {
  const normalized = line.trim();
  if (!normalized || lines.includes(normalized)) return;
  lines.push(normalized);
}

function evidenceFromTool(call: ToolCall, result: unknown): string[] {
  const r = getRecord(result);
  if (!r || r.error) return [];

  switch (call.name) {
    case 'cast_liuyao': {
      const lines: string[] = [];
      const mainName = r.benGua?.name ?? r.mainHexagram?.name ?? r.hexagram?.name ?? r.name;
      const changedName = r.bianGua?.name ?? r.changedHexagram?.name ?? r.changeHexagram?.name;
      const moving = Array.isArray(r.changingYao)
        ? r.changingYao.join('/')
        : Array.isArray(r.movingLines)
          ? r.movingLines.join('/')
          : r.movingLine;
      if (mainName) uniqPush(lines, `主卦 · ${compact(mainName)}`);
      if (changedName) uniqPush(lines, `变卦 · ${compact(changedName)}`);
      if (moving) uniqPush(lines, `动爻 · ${compact(moving)}`);
      return lines;
    }

    case 'setup_qimen': {
      const lines: string[] = [];
      if (r.jieqi) uniqPush(lines, `节气 · ${compact(r.jieqi)}`);
      if (r.yinYangDun && r.juNumber) uniqPush(lines, `${r.yinYangDun}遁 · ${r.juNumber}局`);
      if (r.yongShen?.summary) uniqPush(lines, `用神 · ${compact(r.yongShen.summary, 20)}`);
      if (Array.isArray(r.geJu)) {
        for (const g of r.geJu.slice(0, 2)) {
          if (g?.name) uniqPush(lines, `格局 · ${compact(g.name)}`);
        }
      }
      if (r.yingQi?.description) uniqPush(lines, `应期 · ${compact(r.yingQi.description)}`);
      if (r.method?.level) uniqPush(lines, `方法 · ${compact(r.method.level)}`);
      return lines;
    }

    case 'get_domain': {
      const lines: string[] = [];
      const domain = call.arguments.domain ?? r.domain;
      const palace = r.palace ?? r.ziwei?.palace ?? r.palaceName;
      const baziSummary = r.summary ?? r.bazi?.summary ?? r.modernMeaning;
      const stars = Array.isArray(r.ziwei?.mainStars) ? r.ziwei.mainStars.slice(0, 3).join('/') : '';
      const sihua = Array.isArray(r.ziwei?.sihua) ? r.ziwei.sihua.slice(0, 2).join('/') : '';
      const shenshaList = Array.isArray(r.shensha?.list) ? r.shensha.list : [];
      const shenshaNames = shenshaList.map((s: any) => s?.name ?? s).filter(Boolean).slice(0, 3).join('/');
      if (domain) uniqPush(lines, `领域 · ${compact(domain)}`);
      if (palace) uniqPush(lines, `宫位 · ${compact(palace)}`);
      if (stars) uniqPush(lines, `主星 · ${compact(stars, 20)}`);
      if (sihua) uniqPush(lines, `四化 · ${compact(sihua, 20)}`);
      if (shenshaNames) uniqPush(lines, `神煞 · ${compact(shenshaNames, 20)}`);
      if (baziSummary) uniqPush(lines, `依据 · ${compact(baziSummary, 20)}`);
      return lines;
    }

    case 'get_timing': {
      const lines: string[] = [];
      const scope = call.arguments.scope ?? r.scope;
      const data = r.data;
      const current = r.current ?? r.currentDayun ?? r.dayun ?? r.liunian
        ?? (Array.isArray(data) ? firstArrayItem(data) : data);
      if (scope) uniqPush(lines, `时间 · ${compact(scope)}`);
      if (current?.year) uniqPush(lines, `年份 · ${compact(current.year)}`);
      if (current?.month) uniqPush(lines, `月份 · ${compact(current.month)}`);
      if (current?.ganZhi) uniqPush(lines, `干支 · ${compactGanZhi(current.ganZhi)}`);
      if (current?.shiShen) uniqPush(lines, `十神 · ${compact(current.shiShen)}`);
      if (current?.ageRange ?? current?.period) uniqPush(lines, `阶段 · ${compact(current.ageRange ?? current.period)}`);
      if (r.summary) uniqPush(lines, `依据 · ${compact(r.summary, 20)}`);
      return lines;
    }

    case 'get_bazi_star': {
      const lines: string[] = [];
      const person = call.arguments.person ?? r.person;
      const star = r.star ?? r.shiShen ?? r.name
        ?? (Array.isArray(r.relevantShiShen) ? r.relevantShiShen.join('/') : '');
      const position = r.position ?? r.pillar ?? firstArrayItem(r.positionsInChart);
      if (person) uniqPush(lines, `${compact(person)} · ${compact(star || '星位')}`);
      if (position) uniqPush(lines, `位置 · ${compact(position)}`);
      if (r.summary) uniqPush(lines, `依据 · ${compact(r.summary, 20)}`);
      return lines;
    }

    case 'get_ziwei_palace': {
      const lines: string[] = [];
      const palace = call.arguments.palace ?? r.name ?? r.palace;
      const stars = r.mainStars ?? r.stars;
      if (palace) uniqPush(lines, `紫微 · ${compact(palace)}`);
      if (Array.isArray(stars) && stars.length > 0) {
        const names = stars.map((s: any) => s?.name ?? s).filter(Boolean).slice(0, 3).join('/');
        if (names) uniqPush(lines, `主星 · ${compact(names, 20)}`);
      }
      return lines;
    }

    case 'list_shensha': {
      const lines: string[] = [];
      const kind = call.arguments.kind ?? r.kind;
      const items = Array.isArray(r.list) ? r.list
        : Array.isArray(r.items) ? r.items
          : Array.isArray(r.shenSha) ? r.shenSha : [];
      if (kind) uniqPush(lines, `神煞 · ${compact(kind)}`);
      if (items.length > 0) {
        const names = items.map((s: any) => s?.name ?? s).filter(Boolean).slice(0, 3).join('/');
        if (names) uniqPush(lines, `星曜 · ${compact(names, 20)}`);
      }
      return lines;
    }

    case 'get_today_context': {
      const lines: string[] = [];
      if (r.todayGanZhi ?? r.ganZhi) uniqPush(lines, `今日 · ${compact(r.todayGanZhi ?? r.ganZhi)}`);
      if (r.solarTerm) uniqPush(lines, `节气 · ${compact(r.solarTerm)}`);
      if (r.dayInteraction) uniqPush(lines, `互动 · ${compact(r.dayInteraction, 20)}`);
      return lines;
    }

    default:
      return [];
  }
}

/**
 * 从已执行工具的结构化结果生成 evidence。
 * 优先使用真实工具数据，避免只从 interpreter 文本里硬拆依据。
 */
export function buildEvidenceFromToolCalls(
  toolCalls: Array<{ call: ToolCall; result: unknown }>,
  limit = MAX_EVIDENCE_LINES,
): string[] {
  const lines: string[] = [];
  for (const entry of toolCalls) {
    for (const line of evidenceFromTool(entry.call, entry.result)) {
      uniqPush(lines, line);
      if (lines.length >= limit) return lines;
    }
  }
  return lines;
}
