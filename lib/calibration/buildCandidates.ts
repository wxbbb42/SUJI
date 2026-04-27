import { BaziEngine } from '@/lib/bazi/BaziEngine';
import type { Candidate, CandidateId } from './types';

export const SHICHEN_ANCHORS: Record<string, number> = {
  '子': 0,  '丑': 2,  '寅': 4,  '卯': 6,
  '辰': 8,  '巳': 10, '午': 12, '未': 14,
  '申': 16, '酉': 18, '戌': 20, '亥': 22,
};

const ORDER = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'] as const;

function shichenOfHour(hour: number): typeof ORDER[number] {
  if (hour === 23 || hour === 0) return '子';
  return ORDER[Math.floor((hour + 1) / 2)];
}

function adjacent(shi: typeof ORDER[number], offset: number): typeof ORDER[number] {
  const idx = ORDER.indexOf(shi);
  const next = (idx + offset + 12) % 12;
  return ORDER[next];
}

function buildAt(originDate: Date, anchorHour: number): Date {
  const d = new Date(originDate);
  d.setHours(anchorHour, 0, 0, 0);
  return d;
}

const engine = new BaziEngine();

export function buildCandidates(
  birthDate: Date,
  gender: '男' | '女',
  longitude: number,
): [Candidate, Candidate, Candidate] {
  const originShi = shichenOfHour(birthDate.getHours());
  const beforeShi = adjacent(originShi, -1);
  const afterShi = adjacent(originShi, +1);

  const make = (id: CandidateId, shi: typeof ORDER[number]): Candidate => {
    const date = buildAt(birthDate, SHICHEN_ANCHORS[shi]);
    return { id, birthDate: date, mingPan: engine.calculate(date, gender, longitude) };
  };

  return [
    make('before', beforeShi),
    make('origin', originShi),
    make('after', afterShi),
  ];
}
