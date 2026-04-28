/**
 * 紫微斗数排盘引擎
 *
 * 包装 iztro 库，提供精简、稳定的接口供 AI 工具层使用
 */
import { astro } from 'iztro';
import type { IFunctionalAstrolabe } from 'iztro/lib/astro/FunctionalAstrolabe';
import type {
  ZiweiPan, ZiweiBirthInput, Palace, Star, PalaceName, SiHua,
} from './types';

export class ZiweiEngine {
  /**
   * 排出一张紫微命盘
   */
  compute(input: ZiweiBirthInput): ZiweiPan {
    return this.computeWithAstrolabe(input).pan;
  }

  /**
   * 同时返回我们封装过的 ZiweiPan 与 iztro 原生 astrolabe。
   * 校准引擎需要原生 astrolabe 上的 palace.decadal 来读紫微大限干支序列；
   * 普通调用方仍可继续用 compute() 拿 ZiweiPan，互不影响。
   */
  computeWithAstrolabe(input: ZiweiBirthInput): { pan: ZiweiPan; astrolabe: IFunctionalAstrolabe } {
    const dateStr = `${input.year}-${input.month}-${input.day}`;
    const hourIndex = this.hourToIndex(input.hour);

    const astrolabe: IFunctionalAstrolabe = input.isLunar
      ? astro.byLunar(dateStr, hourIndex, input.gender, false, true, 'zh-CN')
      : astro.bySolar(dateStr, hourIndex, input.gender, true, 'zh-CN');

    const palaces: Palace[] = astrolabe.palaces.map((p: any) => ({
      name: this.normalizePalaceName(p.name),
      position: p.earthlyBranch,
      ganZhi: `${p.heavenlyStem}${p.earthlyBranch}`,
      mainStars: p.majorStars.map((s: any) => this.normalizeStar(s, 'major')),
      minorStars: [
        ...p.minorStars.map((s: any) => this.normalizeStar(s, 'other')),
        ...p.adjectiveStars.map((s: any) => this.normalizeStar(s, 'helper')),
      ],
      isShenGong: p.isBodyPalace ?? false,
    }));

    const pan: ZiweiPan = {
      birthDateTime: new Date(input.year, input.month - 1, input.day, input.hour, input.minute ?? 0),
      gender: input.gender,
      palaces,
      mingGongPosition: astrolabe.earthlyBranchOfSoulPalace ?? this.findMingGongPosition(palaces),
      shenGongPosition: astrolabe.earthlyBranchOfBodyPalace ?? (palaces.find(p => p.isShenGong)?.position ?? ''),
      fiveElementsClass: astrolabe.fiveElementsClass ?? '',
    };
    return { pan, astrolabe };
  }

  /**
   * iztro 的中文宫名不一致：'命宫'/'身宫' 带"宫"字，其余 12 主宫不带。
   * 统一补全"宫"字，让消费方按 PalaceName 一致查询。
   */
  private normalizePalaceName(name: string): PalaceName {
    if (!name) return name as PalaceName;
    return (name.endsWith('宫') ? name : name + '宫') as PalaceName;
  }

  /** 24 小时制转 iztro 的 0-11 时辰索引 */
  private hourToIndex(hour: number): number {
    if (hour === 23 || hour === 0) return 0;
    return Math.floor((hour + 1) / 2);
  }

  private normalizeStar(s: any, defaultType: Star['type']): Star {
    return {
      name: s.name,
      brightness: s.brightness as Star['brightness'],
      type: defaultType,
      sihua: s.mutagen ? [s.mutagen as SiHua] : undefined,
    };
  }

  private findMingGongPosition(palaces: Palace[]): string {
    return palaces.find(p => p.name === '命宫')?.position ?? '';
  }
}
