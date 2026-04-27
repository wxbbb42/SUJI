import { BaziEngine } from '@/lib/bazi/BaziEngine';
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

export function buildCandidates(
  birthDate: Date,
  gender: '男' | '女',
  longitude: number,
): [Candidate, Candidate, Candidate] {
  const originShi = shichenOfHour(birthDate.getHours());

  // 以 originDate 的 anchor 时刻为基准，再 ±2h 用 ms math 让 Date 自动处理跨日。
  // 注意：23:30 的子时 origin 会被 setHours(0) 倒回当日 0:00；
  // known limitation: 23:30 子时 anchor 倒回当日 0:00（待真机命盘对齐后再处理）。
  const originAnchorDate = (() => {
    const d = new Date(birthDate);
    d.setHours(SHICHEN_ANCHORS[originShi], 0, 0, 0);
    return d;
  })();

  const beforeDate = new Date(originAnchorDate.getTime() - 2 * 3600 * 1000);
  const afterDate = new Date(originAnchorDate.getTime() + 2 * 3600 * 1000);

  const make = (id: CandidateId, date: Date): Candidate => ({
    id,
    birthDate: date,
    mingPan: engine.calculate(date, gender, longitude),
  });

  return [
    make('before', beforeDate),
    make('origin', originAnchorDate),
    make('after', afterDate),
  ];
}
