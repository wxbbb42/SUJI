/** Typed surface used by SUJI; upstream lunar-javascript 1.7.7 ships JavaScript only. */
declare module 'lunar-javascript' {
  export interface SolarDate {
    getYear(): number; getMonth(): number; getDay(): number;
    getHour(): number; getMinute(): number; getSecond(): number;
    getLunar(): LunarDate; toYmd(): string; toYmdHms(): string;
  }
  export interface JieQi { getName(): string; getSolar(): SolarDate; }
  export interface Yun {
    isForward(): boolean; getStartYear(): number; getStartMonth(): number;
    getStartDay(): number; getStartHour(): number; getStartSolar(): SolarDate;
  }
  export interface EightChar {
    setSect(sect: 1 | 2): void;
    getYear(): string; getMonth(): string; getDay(): string; getTime(): string;
    getTaiYuan(): string; getTaiYuanNaYin(): string;
    getMingGong(): string; getMingGongNaYin(): string;
    getYun(gender: 0 | 1, sect?: 1 | 2): Yun;
  }
  export interface LunarDate {
    getYear(): number; getMonth(): number; getDay(): number;
    getYearInChinese(): string; getMonthInChinese(): string; getDayInChinese(): string;
    getSolar(): SolarDate; getEightChar(): EightChar;
    getDayInGanZhi(): string; getDayInGanZhiExact(): string; getDayInGanZhiExact2(): string;
    getJieQi(): string; getJieQiTable(): Record<string, SolarDate>;
    getPrevJie(wholeDay?: boolean): JieQi; getNextJie(wholeDay?: boolean): JieQi;
  }
  export const Solar: {
    fromYmd(year: number, month: number, day: number): SolarDate;
    fromYmdHms(year: number, month: number, day: number, hour: number, minute: number, second: number): SolarDate;
  };
  export const Lunar: { fromYmd(year: number, month: number, day: number): LunarDate; };
  export const LunarUtil: { NAYIN: Record<string, string>; JIA_ZI: string[]; };
}
