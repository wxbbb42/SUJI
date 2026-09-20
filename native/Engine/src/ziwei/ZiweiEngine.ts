/**
 * 紫微斗数排盘引擎
 *
 * 包装 iztro 库，提供精简、稳定的接口供 AI 工具层使用
 */
import { astro } from 'iztro';
import { Lunar, Solar } from 'lunar-javascript';
import { decadalSchedule } from './timing';
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
    for (const [name,value,min,max] of [
      ['year',input.year,1901,2100],['month',input.month,1,12],['day',input.day,1,31],
      ['hour',input.hour,0,23],['minute',input.minute ?? 0,0,59],
    ] as const) {
      if (!Number.isInteger(value) || value<min || value>max) throw new Error(`invalid ziwei ${name}`);
    }
    if (!['男','女'].includes(input.gender)) throw new Error('invalid ziwei gender');
    if (input.isLeapMonth && !input.isLunar) throw new Error('leap month requires lunar input');
    const dateCheck = new Date(Date.UTC(input.year,input.month-1,input.day));
    if (!input.isLunar && (dateCheck.getUTCMonth()!==input.month-1 || dateCheck.getUTCDate()!==input.day)) throw new Error('invalid ziwei calendar date');
    // lunar-lite silently ignores an impossible leap-month flag; validate before calling it.
    const solar = input.isLunar
      ? Lunar.fromYmd(input.year,input.isLeapMonth ? -input.month : input.month,input.day).getSolar()
      : Solar.fromYmd(input.year,input.month,input.day);
    const solarDate = solar.toYmd();
    if (!input.isLunar && solarDate !== `${input.year}-${String(input.month).padStart(2,'0')}-${String(input.day).padStart(2,'0')}`) throw new Error('invalid ziwei calendar date');
    if (solarDate<'1901-01-01' || solarDate>'2100-12-31') throw new Error('ziwei date outside 1901 through 2100');
    // Pin the selected school's policies; upstream process-global settings must not leak in.
    const globalRules = astro.getConfig();
    for (const key of Object.keys(globalRules.mutagens)) delete globalRules.mutagens[key as keyof typeof globalRules.mutagens];
    for (const key of Object.keys(globalRules.brightness)) delete globalRules.brightness[key as keyof typeof globalRules.brightness];
    astro.config({yearDivide:'normal',horoscopeDivide:'normal',ageDivide:'normal',dayDivide:'forward',algorithm:'default'});
    // iztro's late-zi index advances the star day but leaves month/year behind
    // (and skips the leap-month split). Our selected full zi-hour rollover must
    // advance the calendar exactly once, including the raw date used by decades.
    // The input range applies to civil birth; its derived chart date may be 2101-01-01.
    const chartSolar = input.hour === 23 ? solar.next(1) : solar;
    const hourIndex = this.hourToIndex(input.hour);
    const astrolabe: IFunctionalAstrolabe = astro.bySolar(chartSolar.toYmd(), hourIndex, input.gender, true, 'zh-CN');

    const palaces: Palace[] = astrolabe.palaces.map((p: any) => ({
      name: this.normalizePalaceName(p.name),
      position: p.earthlyBranch,
      ganZhi: `${p.heavenlyStem}${p.earthlyBranch}`,
      mainStars: p.majorStars.map((s: any) => this.normalizeStar(s, 'major', 'major')),
      minorStars: [
        ...p.minorStars.map((s: any) => this.normalizeStar(s, this.mapMinorStarType(s), 'minor')),
        ...p.adjectiveStars.map((s: any) => this.normalizeStar(s, 'helper', 'adjective')),
      ],
      isShenGong: p.isBodyPalace ?? false,
    }));

    const pan: ZiweiPan = {
      birthDateTime: new Date(`${solarDate}T${String(input.hour).padStart(2,'0')}:${String(input.minute ?? 0).padStart(2,'0')}:00+08:00`),
      gender: input.gender,
      palaces,
      mingGongPosition: astrolabe.earthlyBranchOfSoulPalace ?? this.findMingGongPosition(palaces),
      shenGongPosition: astrolabe.earthlyBranchOfBodyPalace ?? (palaces.find(p => p.isShenGong)?.position ?? ''),
      fiveElementsClass: astrolabe.fiveElementsClass ?? '',
      natalYear: {
        lunarYear:astrolabe.rawDates.lunarDate.lunarYear,
        ganZhi:astrolabe.rawDates.chineseDate.yearly.join(''),
        stem:astrolabe.rawDates.chineseDate.yearly[0], branch:astrolabe.rawDates.chineseDate.yearly[1],
      },
      method: {algorithm:'iztro-2.5.8-default',dayBoundary:'zi-hour',yearBoundary:'lunar-new-year',leapMonth:'split-at-day-15',calculationDate:chartSolar.toYmd(),civilTimeZone:'UTC+08:00',caveats:[
        '采用子初23点换日、农历正月换年、闰月前15日当月后15日次月；不同流派可能另取规则',
        '四化使用默认十干表；亮度、四化和闰月规则存在传本差异',
        '排盘一致性不等于对现实事件的预测效度',
      ]},
    };
    pan.decadalSchedule = decadalSchedule(pan);
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

  /** 23点已经完整推进计算日期，传子时0避免库再次加日。 */
  private hourToIndex(hour: number): number {
    if (hour === 23 || hour === 0) return 0;
    return Math.floor((hour + 1) / 2);
  }

  private normalizeStar(s: any, defaultType: Star['type'], source: Star['source']): Star {
    const mutagen = s.mutagen ? String(s.mutagen).replace(/^化/,'') : '';
    const sihua = ['禄','权','科','忌'].includes(mutagen) ? [`化${mutagen}` as SiHua] : undefined;
    return {
      name: s.name,
      brightness: s.brightness as Star['brightness'],
      type: defaultType,
      source,
      sihua,
    };
  }

  private mapMinorStarType(s: any): Star['type'] {
    const type = String(s.type ?? '').toLowerCase();
    if (['soft', 'tough', 'lucky', 'unlucky', 'flower', 'helper'].includes(type)) {
      return type as Star['type'];
    }
    return 'other';
  }

  private findMingGongPosition(palaces: Palace[]): string {
    return palaces.find(p => p.name === '命宫')?.position ?? '';
  }
}
