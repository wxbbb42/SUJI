/** 徐乐吾《子平真诠评注》十二月令人元司令分野表。
 * This is one source profile, not a universal or astronomically measured rule.
 * Elapsed days start at zero at 月节; segments use [start,end).
 */
import type { TianGan, DiZhi, WuXing } from './types';

export const SI_LING_SOURCE = {
  id: 'ziping-xu-renyuan-v1',
  document: 'docs/mingli/source-texts/bazi/ziping-zhenquan/01-foundations.md',
  sha256: '8ea626e3744bb7129351b57dd3c4d6b6be595484345d8ea8101df50611993596',
  locator: '三、论阴阳生死；十二月令人元司令分野表，第70–72行',
  quote: '申月 立秋后戊己土十日，壬水三日，庚金十七日',
  caution: '按此表人元司令日数，虽未可执着',
  editionStatus: 'electronic-transcription-not-print-collated',
} as const;

export interface SiLingSegment {
  /** null means the source names multiple stems, not missing information. */
  gan: TianGan | null;
  gans: TianGan[];
  element: WuXing;
  days: number;
  label: string;
}

const ELEMENT: Record<TianGan, WuXing> = {
  甲:'木',乙:'木',丙:'火',丁:'火',戊:'土',己:'土',庚:'金',辛:'金',壬:'水',癸:'水',
};
const TABLE: Record<DiZhi, [TianGan[], number][]> = {
  寅: [[['戊'],7],[['丙'],7],[['甲'],16]],
  卯: [[['甲'],10],[['乙'],20]],
  辰: [[['乙'],9],[['癸'],3],[['戊'],18]],
  巳: [[['戊'],5],[['庚'],9],[['丙'],16]],
  午: [[['丙'],10],[['己'],9],[['丁'],11]],
  未: [[['丁'],9],[['乙'],3],[['己'],18]],
  申: [[['戊','己'],10],[['壬'],3],[['庚'],17]],
  酉: [[['庚'],10],[['辛'],20]],
  戌: [[['辛'],9],[['丁'],3],[['戊'],18]],
  亥: [[['戊'],7],[['甲'],5],[['壬'],18]],
  子: [[['壬'],10],[['癸'],20]],
  丑: [[['癸'],9],[['辛'],3],[['己'],18]],
};

export function getSiLingSegments(monthZhi: DiZhi): SiLingSegment[] {
  if (!Object.prototype.hasOwnProperty.call(TABLE,monthZhi)) throw new RangeError('Unknown solar-month branch');
  let start = 0;
  return TABLE[monthZhi].map(([gans, days]) => {
    const label = `节后${start}至${start + days}日${gans.join('')}${ELEMENT[gans[0]]}司令`;
    start += days;
    return { gan:gans.length === 1 ? gans[0] : null, gans:[...gans], element:ELEMENT[gans[0]], days, label };
  });
}

export function getCurrentSiLing(monthZhi: DiZhi, daysAfterJie: number) {
  if (!Number.isFinite(daysAfterJie) || daysAfterJie < 0) throw new RangeError('Elapsed days after Jie must be finite and nonnegative');
  const segments = getSiLingSegments(monthZhi);
  let start = 0;
  for (const [index, segment] of segments.entries()) {
    const end = start + segment.days;
    if (daysAfterJie < end || index === segments.length - 1) {
      return {
        ...segment, tableId:SI_LING_SOURCE.id, source:{...SI_LING_SOURCE},
        interval:{startDay:start,endDay:end,convention:'left-closed-right-open' as const},
        beyondNominalMonth:daysAfterJie >= 30,
        tailPolicy:'last-segment-until-next-jie-caller-verifies-month' as const,
      };
    }
    start = end;
  }
  throw new Error('Month commander table is empty');
}

/** Longest segment in this profile; it is unambiguous in all twelve months. */
export function getDefaultSiLing(monthZhi: DiZhi): TianGan {
  const segments = getSiLingSegments(monthZhi);
  const longest = segments.reduce((max, segment) => segment.days > max.days ? segment : max);
  if (!longest.gan) throw new Error('Longest month commander is ambiguous');
  return longest.gan;
}
