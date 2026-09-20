import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { HexagramEngine } from '../HexagramEngine';
import type { CastOptions, QuestionType } from '../types';

// Controlled traditional calendar coordinates, NOT a historical Gregorian-date
// reconstruction. This isolates line rules from the separately audited calendar.
let mockDay = '甲子', mockMonth = '甲子';
jest.mock('@engine/calendar/precision', () => ({
  getCalendarPillars: () => ({ year: '甲子', month: mockMonth, day: mockDay, hour: '甲子' }),
}));

type Oracle = { binary: string; name: string; palace: string; ganzhi: string[]; liuqin: string[] };
const oracle: Oracle[] = JSON.parse(readFileSync(resolve(__dirname, '../../../validation/research-divination/independent-results.json'), 'utf8')).najia;
const engine = new HexagramEngine();
const date = new Date('2026-09-19T04:00:00Z');
const branches = [...'子丑寅卯辰巳午未申酉戌亥'];
const stems = [...'甲乙丙丁戊己庚辛壬癸'];
const values = (f: Oracle) => [...f.binary].map(x => x === '1' ? 7 : 8) as CastOptions['lineValues'];
const cast = (lineValues: CastOptions['lineValues'], questionType: QuestionType = 'general') =>
  engine.cast({ question: '独立规则审计：合成输入', castTime: date, lineValues, questionType });
const report: Record<string, unknown> = {
  scope: 'Controlled GanZhi inputs; not an astronomical/calendar or historical-date oracle.',
  najiaOracle: 'bopo/najia 9cf119169d7eb8e48febc05274aebf3f7106d647 archived independent-results.json',
};
afterAll(() => {
  if (process.env.SUJI_LIUYAO_AUDIT_OUTPUT) writeFileSync(process.env.SUJI_LIUYAO_AUDIT_OUTPUT, JSON.stringify(report, null, 2) + '\n');
});

describe('professional liuyao audit: independently tabulated local facts', () => {
  it('checks all 60 days × 64 gua against the six-xun table and the six-spirit table', () => {
    // 《增删卜易》旬空章26、六神章18; rows are bottom to top.
    const voidTable = ['戌亥', '申酉', '午未', '辰巳', '寅卯', '子丑'];
    const spirits: Record<string, string[]> = {
      甲: ['青龙','朱雀','勾陈','腾蛇','白虎','玄武'], 乙: ['青龙','朱雀','勾陈','腾蛇','白虎','玄武'],
      丙: ['朱雀','勾陈','腾蛇','白虎','玄武','青龙'], 丁: ['朱雀','勾陈','腾蛇','白虎','玄武','青龙'],
      戊: ['勾陈','腾蛇','白虎','玄武','青龙','朱雀'], 己: ['腾蛇','白虎','玄武','青龙','朱雀','勾陈'],
      庚: ['白虎','玄武','青龙','朱雀','勾陈','腾蛇'], 辛: ['白虎','玄武','青龙','朱雀','勾陈','腾蛇'],
      壬: ['玄武','青龙','朱雀','勾陈','腾蛇','白虎'], 癸: ['玄武','青龙','朱雀','勾陈','腾蛇','白虎'],
    };
    const failures: unknown[] = [];
    for (let day = 0; day < 60; day++) {
      mockDay = stems[day % 10] + branches[day % 12];
      const expectedVoid = [...voidTable[Math.floor(day / 10)]];
      for (const f of oracle) {
        const r = cast(values(f));
        if (JSON.stringify(r.xunKong) !== JSON.stringify(expectedVoid)
          || r.lines.some((l, i) => l.liuShen !== spirits[mockDay[0]][i] || l.isVoid !== expectedVoid.includes(f.ganzhi[i][1])))
          failures.push({ day: mockDay, gua: f.name });
      }
    }
    report.xunAndSpirit = { charts: 3840, linePositions: 23040, mismatches: failures };
    expect(failures).toEqual([]);
  });

  it('checks 12 month branches × 12 day branches × 64 gua using explicit clash/combination pairs', () => {
    // Chapter 19/20 pair tables, not the engine's modulo formula.
    const clashes = ['子午','丑未','寅申','卯酉','辰戌','巳亥'];
    const combinations = ['子丑','寅亥','卯戌','辰酉','巳申','午未'];
    const inPairs = (a: string, b: string, pairs: string[]) => pairs.some(p => a !== b && p.includes(a) && p.includes(b));
    const failures: unknown[] = [];
    for (let month = 0; month < 12; month++) for (let day = 0; day < 12; day++) {
      mockMonth = stems[month % 10] + branches[month]; mockDay = stems[day % 10] + branches[day];
      for (const f of oracle) {
        const r = cast(values(f));
        for (const [i, l] of r.lines.entries()) {
          const branch = f.ganzhi[i][1];
          if (l.monthClash !== inPairs(branch, branches[month], clashes)
            || l.dayClash !== inPairs(branch, branches[day], clashes)
            || l.dayCombination !== inPairs(branch, branches[day], combinations)) failures.push({ month, day, gua: f.name, line: i + 1 });
        }
      }
    }
    report.monthDayPairs = { charts: 9216, linePositions: 55296, mismatches: failures };
    expect(failures).toEqual([]);
  });

  it('checks all hidden positions against independent pure-palace kinship/najia fixtures', () => {
    const pureBinary: Record<string, string> = { 乾:'111111', 兑:'110110', 离:'101101', 震:'100100', 巽:'011011', 坎:'010010', 艮:'001001', 坤:'000000' };
    const failures: unknown[] = []; let hidden = 0;
    for (const f of oracle) {
      const pure = oracle.find(x => x.binary === pureBinary[f.palace])!;
      const r = cast(values(f));
      for (let i = 0; i < 6; i++) {
        const expected = !f.liuqin.includes(pure.liuqin[i]);
        if (expected) hidden++;
        if (Boolean(r.lines[i].hidden) !== expected || (expected && (r.lines[i].hidden!.ganZhi !== pure.ganzhi[i] || r.lines[i].hidden!.liuQin !== pure.liuqin[i])))
          failures.push({ gua: f.name, line: i + 1 });
      }
    }
    report.hiddenPositions = { charts: 64, positions: 384, hidden, mismatches: failures };
    expect(failures).toEqual([]);
  });

  it('enumerates the eight fair three-coin outcomes, rather than a noisy random frequency sample', () => {
    const counts: Record<string, number> = { 6:0, 7:0, 8:0, 9:0 };
    for (let bits = 0; bits < 8; bits++) {
      let calls = 0;
      const random = jest.spyOn(Math, 'random').mockImplementation(() => ((bits >> (calls++ % 3)) & 1) ? 0.75 : 0.25);
      try {
        const r = cast(undefined); counts[String(r.lineValues[0])]++;
        expect(random).toHaveBeenCalledTimes(18);
        expect(r.lineValues.every(v => v === r.lineValues[0])).toBe(true);
      } finally { random.mockRestore(); }
    }
    report.coinOutcomeCounts = { equallyLikelyCoinTriples: 8, counts, movingProbability: '1/4 per line, assuming independent fair RNG comparisons' };
    expect(counts).toEqual({ 6:1, 7:3, 8:3, 9:1 });
  });

  it('records classical structures and synthetic counterexamples without inventing ancient Gregorian dates', () => {
    mockMonth = '庚申'; mockDay = '戊午';
    const classical = cast([8,6,7,7,7,7], 'health');
    expect(classical.benGua.name).toBe('天山遯'); expect(classical.bianGua.name).toBe('天风姤');
    expect(classical.shiYao).toBe(2); expect(classical.lines[1].ganZhi).toBe('丙午');
    expect(classical.lines[1].changed).toMatchObject({ ganZhi:'辛亥', wuXing:'水', liuQin:'子孙' });
    mockDay = '甲子';
    const changingVoid = cast([8,6,7,7,7,7]);
    expect(changingVoid.xunKong).toEqual(['戌','亥']);
    expect(changingVoid.lines[1].isVoid).toBe(false);
    expect(changingVoid.lines[1].changed!.ganZhi[1]).toBe('亥');
    mockMonth = '己未';
    const changingBroken = cast([9,7,7,7,7,7]);
    expect(changingBroken.lines[0].monthClash).toBe(false);
    expect(changingBroken.lines[0].changed!.ganZhi).toBe('辛丑');
    mockMonth = '庚申'; mockDay = '甲申';
    const hiddenClash = cast([8,7,7,7,7,7], 'wealth');
    expect(hiddenClash.lines[1].hidden!.ganZhi).toBe('甲寅');
    mockMonth = '乙丑'; mockDay = '甲子';
    const monthCombined = cast([8,7,8,8,7,8]);
    expect(monthCombined.lines[5].ganZhi).toBe('戊子');
    report.examples = {
      classicalDunToGou: { provenance:'增删卜易/17 申月戊午日, traditional coordinates only. Returned castTime is a synthetic test anchor.', reading:classical },
      syntheticChangingVoid: changingVoid, syntheticChangingMonthBreak: changingBroken,
      syntheticHiddenClash: hiddenClash, syntheticMonthCombination: monthCombined,
    };
    report.knownUnimplemented = ['flying-hidden relationships','return generation/control','advance/retreat','dark movement versus day break','comprehensive strength and use-god resolution','conditional event timing'];
  });
});
