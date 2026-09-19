/**
 * 格局注册表 — 强制古籍出处 + 稳定 id 管理（Phase 0.5 骨架）
 *
 * 借鉴：bazi-life-curves `_phase_registry.py:94–104`
 *   仓库：https://github.com/XiaoChu-1208/bazi-life-curves
 *   License: MIT
 *
 * 设计目标：
 *  1. 每个 PhaseMeta 必须带非空 source（古籍出处），违规抛错；
 *  2. id 跨版本稳定，为未来 confirmed_facts 跨会话兼容奠基；
 *  3. 反向规则、相神关系等结构化属性集中管理，避免散落业务逻辑。
 *
 * 当前未注册任何具体格局；Phase 1.3 / Phase 2 才会按《子平真诠》
 * 14 个 core phase 逐个注册。
 */

import type { PhaseMeta } from './types';

export class PhaseRegistry {
  private readonly map = new Map<string, PhaseMeta>();

  /**
   * 注册一个相位
   * @throws 若 id 重复 / source 为空 / source 含"自创"或"原创"
   */
  register(meta: PhaseMeta): void {
    if (this.map.has(meta.id)) {
      throw new Error(`PhaseRegistry: id 冲突 "${meta.id}"`);
    }
    const src = (meta.source ?? '').trim();
    if (src.length === 0) {
      throw new Error(`PhaseRegistry: "${meta.id}" 缺古籍出处 (source)`);
    }
    if (src.includes('自创') || src.includes('原创')) {
      throw new Error(`PhaseRegistry: "${meta.id}" source 不可标记为自创/原创规则`);
    }
    this.map.set(meta.id, meta);
  }

  get(id: string): PhaseMeta | undefined {
    return this.map.get(id);
  }

  has(id: string): boolean {
    return this.map.has(id);
  }

  list(): PhaseMeta[] {
    return Array.from(this.map.values());
  }

  size(): number {
    return this.map.size;
  }
}

/** 默认空注册表；调用方按需注入 */
export const defaultPhaseRegistry = new PhaseRegistry();
