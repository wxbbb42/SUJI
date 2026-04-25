/**
 * 工具汇总：聚合 get_domain（实现细节用其他 handlers），导出全集
 */
import type { ToolDefinition, ToolHandler } from './types';
import { baziTools, baziHandlers } from './bazi';
import { ziweiTools, ziweiHandlers } from './ziwei';
import { liuyaoTools, liuyaoHandlers } from './liuyao';
import { qimenTools, qimenHandlers } from './qimen';

const DOMAIN_TO_PALACE: Record<string, string> = {
  子女: '子女宫',
  婚姻: '夫妻宫',
  事业: '官禄宫',
  财富: '财帛宫',
  健康: '疾厄宫',
  父母: '父母宫',
  兄弟: '兄弟宫',
  迁移: '迁移宫',
  田宅: '田宅宫',
  福德: '福德宫',
};

const DOMAIN_TO_PERSON: Record<string, string | null> = {
  子女: '子女',
  婚姻: '配偶',
  父母: '父母',
  兄弟: '兄弟',
  事业: null,
  财富: null,
  健康: null,
  迁移: null,
  田宅: null,
  福德: null,
};

const DOMAIN_TO_SHENSHA_KIND: Record<string, string> = {
  婚姻: '桃花',
  事业: '权贵',
  健康: '凶',
};

const aggregatedTools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'get_domain',
      description: '一次获取某领域的命盘相关数据：八字星位 + 紫微对应宫位 + 相关神煞。最常用工具。',
      parameters: {
        type: 'object',
        properties: {
          domain: {
            type: 'string',
            enum: ['子女', '婚姻', '事业', '财富', '健康', '父母', '兄弟', '迁移', '田宅', '福德'],
          },
        },
        required: ['domain'],
      },
    },
  },
];

const aggregatedHandlers: Record<string, ToolHandler> = {
  get_domain: async ({ domain }, ctx) => {
    const palace = DOMAIN_TO_PALACE[domain as string];
    if (!palace) return { domain, error: 'unknown_domain' };

    const person = DOMAIN_TO_PERSON[domain as string];
    const shenshaKind = DOMAIN_TO_SHENSHA_KIND[domain as string] ?? 'all';

    const baziPart = person
      ? await baziHandlers.get_bazi_star({ person }, ctx)
      : { domain, note: '此领域不直接对应六亲星位' };
    const ziweiPart = await ziweiHandlers.get_ziwei_palace(
      { palace, withFlying: true }, ctx,
    );
    const shenshaPart = await baziHandlers.list_shensha(
      { kind: shenshaKind }, ctx,
    );

    return {
      domain,
      bazi: baziPart,
      ziwei: ziweiPart,
      shensha: shenshaPart,
    };
  },
};

export const ALL_TOOLS: ToolDefinition[] = [
  ...aggregatedTools,
  ...baziTools,
  ...ziweiTools,
  ...liuyaoTools,
  ...qimenTools,
];

export const ALL_HANDLERS: Record<string, ToolHandler> = {
  ...aggregatedHandlers,
  ...baziHandlers,
  ...ziweiHandlers,
  ...liuyaoHandlers,
  ...qimenHandlers,
};

/** 工具使用策略文本，注入 thinker prompt */
export const TOOL_STRATEGY = `工具使用策略：
1. 用户问题涉及具体领域（婚姻/子女/事业/财富/健康/父母/兄弟/迁移/田宅/福德）→ 优先用 get_domain
2. 用户问题涉及"何时" → 加 get_timing
3. 跨领域复杂问题 → 用 get_bazi_star / get_ziwei_palace 精查
4. "今日运势"类问题 → get_today_context
5. 一次推演中工具调用 ≤ 4 次（避免无意义遍历）
6. 单一事件决策类问题（"该不该 X" / "会不会 Y" / "X 这件事的结果" / "她回我吗" / "明天面试结果"）→ 用 cast_liuyao
7. 长期模式 / 时间节奏 / 性格画像 → 用命理工具（get_domain / get_timing 等）
8. 收到 user_force_mode=liuyao 时强制走 cast_liuyao；收到 user_force_mode=mingli 时禁用 cast_liuyao
9. 战略级重大决策（"要不要换城市/移民/换行业/创业"/"明年这件大事"/"这家公司能干长吗"/"我要不要和这个人结婚"）→ 用 setup_qimen
10. 普通决策（"她回我吗"/"明天面试结果"）→ 用 cast_liuyao
11. 区分启发：影响时间跨度 / 影响生活面广度 / 严肃度。模糊时优先 cast_liuyao（更通俗）`;
