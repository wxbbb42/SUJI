import fs from 'node:fs';
import path from 'node:path';
import { BaziEngine } from '../../bazi/BaziEngine';

// Frozen expectations come from astronomy-engine + independent JDN/five-rat/
// five-tiger formulas, never from the production `actual` fields in the report.
// Regeneration and birth-record limitations: validation/professional/README.md.
const directory = path.resolve(__dirname, '../../../validation/professional');
const records = JSON.parse(fs.readFileSync(path.join(directory, 'public-birth-cases.json'), 'utf8'));
const reference = JSON.parse(fs.readFileSync(path.join(directory, 'calendar-audit-results.json'), 'utf8'));
const engine = new BaziEngine();
type Comparison = { id: string; instant: string; gender: '男' | '女'; longitude?: number; expected: string[] };
const comparisons: Comparison[] = [];
for (const person of records.cases) {
  const evidence = reference.publicCases.find((item: { id: string }) => item.id === person.id);
  for (const row of evidence.clockRows) comparisons.push({
    id: `${person.id}/${row.policy}`, instant: person.instant, gender: person.gender,
    longitude: row.policy === 'apparent-solar' ? person.longitude : undefined, expected: row.expected,
  });
  for (const row of evidence.apparentSolarSensitivity) comparisons.push({
    id: `${person.id}/solar/${row.offsetMinutes}min`,
    instant: new Date(Date.parse(person.instant) + row.offsetMinutes * 60_000).toISOString(),
    gender: person.gender, longitude: person.longitude, expected: row.expected,
  });
  for (const row of evidence.reportedAlternatives) comparisons.push({
    id: `${person.id}/alternative/${row.wall}`, instant: row.instant,
    gender: person.gender, longitude: person.longitude, expected: row.expected,
  });
}

describe('public historical birth records: independent clock and pillar references', () => {
  it('keeps all four sources, both clock policies, 52 sensitivity samples and two alternatives', () => {
    expect(records.cases).toHaveLength(4);
    expect(comparisons).toHaveLength(62);
    expect(new Set(comparisons.map(row => row.id)).size).toBe(62);
  });

  it.each(comparisons)('$id', row => {
    const actual = engine.calculate(new Date(row.instant), row.gender, row.longitude);
    expect([actual.siZhu.year, actual.siZhu.month, actual.siZhu.day, actual.siZhu.hour]
      .map(pillar => pillar.ganZhi.gan + pillar.ganZhi.zhi)).toEqual(row.expected);
  });
});
