import { BaziEngine } from '@/lib/bazi/BaziEngine';
import { ZiweiEngine } from '@/lib/ziwei/ZiweiEngine';
import type { Candidate, CandidateId } from './types';

export const SHICHEN_ANCHORS: Record<string, number> = {
  '子': 0,  '丑': 2,  '寅': 4,  '卯': 6,
  '辰': 8,  '巳': 10, '午': 12, '未': 14,
  '申': 16, '酉': 18, '戌': 20, '亥': 22,
};

const ORDER = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'] as const;

function shichenOfHour(hour: number): typeof ORDER[number] {
  // 子时跨日: 23-1 都归子。hour===23 必须前置拦截，否则会落到 ORDER[12] 越界。
  if (hour === 23 || hour === 0) return '子';
  return ORDER[Math.floor((hour + 1) / 2)];
}

const engine = new BaziEngine();
const ziweiEngine = new ZiweiEngine();

export function buildCandidates(
  birthDate: Date,
  gender: '男' | '女',
  longitude: number,
): [Candidate, Candidate, Candidate] {
  // 23:00-23:59 出生（夜子时）的命盘日柱属次日，本期不在校准支持范围。
  // 调用前已 throw NIGHT_ZISHI_UNSUPPORTED；hour === 0 的早子时仍走正常路径。
  if (birthDate.getHours() === 23) {
    throw new Error('NIGHT_ZISHI_UNSUPPORTED');
  }

  const originShi = shichenOfHour(birthDate.getHours());

  // 以 originDate 的 anchor 时刻为基准，再 ±2h 用 ms math 让 Date 自动处理跨日。
  const originAnchorDate = (() => {
    const d = new Date(birthDate);
    d.setHours(SHICHEN_ANCHORS[originShi], 0, 0, 0);
    return d;
  })();

  const beforeDate = new Date(originAnchorDate.getTime() - 2 * 3600 * 1000);
  const afterDate = new Date(originAnchorDate.getTime() + 2 * 3600 * 1000);

  const make = (id: CandidateId, date: Date): Candidate => {
    const { pan, astrolabe } = ziweiEngine.computeWithAstrolabe({
      year: date.getFullYear(),
      month: date.getMonth() + 1,
      day: date.getDate(),
      hour: date.getHours(),
      minute: date.getMinutes(),
      gender,
    });
    return {
      id,
      birthDate: date,
      mingPan: engine.calculate(date, gender, longitude),
      ziweiPan: pan,
      astrolabe,
    };
  };

  return [
    make('before', beforeDate),
    make('origin', originAnchorDate),
    make('after', afterDate),
  ];
}
