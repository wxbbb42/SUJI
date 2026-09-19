/** Compare production calendar conversion against independently parsed HKO PDFs.
 * Run hko-daily-audit.py first. This writes research results only.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const engine = path.resolve(here, '../..');
const cache = path.join(here, 'hko-cache');
const require = createRequire(import.meta.url);
const { build } = require(path.join(engine, 'node_modules/esbuild'));
const manifest = JSON.parse(fs.readFileSync(path.join(here, 'hko-daily-manifest.json')));
if (manifest.sequenceErrors.length) throw new Error('HKO source sequence checks failed; do not compare an ambiguous oracle');
const official = JSON.parse(fs.readFileSync(path.join(cache, 'official-days.json')));
const sourcePath = path.join(engine, 'src/calendar/precision.ts');
await build({ entryPoints: [sourcePath], bundle: true, platform: 'node', format: 'cjs', outfile: path.join(cache, 'production-calendar.cjs'), logLevel: 'silent' });
const { toSolar, fromBeijingParts } = require(path.join(cache, 'production-calendar.cjs'));
const mismatches = [], errors = [], years = new Map();
let fullDatesCompared = 0;
for (const expected of official) {
  const [year, month, day] = expected.date.split('-').map(Number);
  const coverage = years.get(year) ?? { year, comparedDays: 0, fullDatesCompared: 0, mismatches: 0, errors: 0 };
  years.set(year, coverage);
  try {
    // Exact same civil facade used by production; independent oracle is the PDF.
    const lunar = toSolar(fromBeijingParts(year, month, day, 12)).getLunar();
    const actual = { lunarYear: lunar.getYear(), lunarMonth: Math.abs(lunar.getMonth()), leap: lunar.getMonth() < 0, lunarDay: lunar.getDay() };
    const fields = ['lunarYear', 'lunarMonth', 'leap', 'lunarDay'].filter(key => expected[key] !== null && expected[key] !== actual[key]);
    coverage.comparedDays++;
    if (expected.fullDateEstablished) { fullDatesCompared++; coverage.fullDatesCompared++; }
    if (fields.length) {
      coverage.mismatches++;
      mismatches.push({ date: expected.date, fields, expected: Object.fromEntries(['lunarYear', 'lunarMonth', 'leap', 'lunarDay'].map(key => [key, expected[key]])), actual,
        officialPDF: `https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/${year}e.pdf`,
        actualOracleSource: manifest.files.find(file => file.year === year).officialTextURL ?? `https://www.hko.gov.hk/en/gts/time/calendar/pdf/files/${year}e.pdf` });
    }
  } catch (error) {
    coverage.errors++;
    errors.push({ date: expected.date, error: error.message });
  }
}
const intervals = [];
for (const difference of mismatches) {
  const previous = intervals.at(-1);
  const follows = previous && new Date(difference.date).getTime() - new Date(previous.end).getTime() === 86400000;
  if (follows) { previous.end = difference.date; previous.days++; }
  else intervals.push({ start: difference.date, end: difference.date, days: 1 });
}
const result = {
  comparison: 'Production lunar-javascript through fixed-UTC+08 facade versus independent official Hong Kong Observatory PDF cells and explicit official TXT fallback',
  precisionSourceSha256: crypto.createHash('sha256').update(fs.readFileSync(sourcePath)).digest('hex'),
  sourceManifestSha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(here, 'hko-daily-manifest.json'))).digest('hex'),
  provider: JSON.parse(fs.readFileSync(path.join(engine, 'package.json'))).dependencies['lunar-javascript'],
  summary: { requestedYears: manifest.range, filesRequested: manifest.filesRequested, filesParsed: manifest.filesParsed,
    downloadOrParseFailures: manifest.files.filter(file => file.status !== 'parsed').length,
    pdfFilesParsed: manifest.pdfFilesParsed, officialTextFallbackFiles: manifest.officialTextFallbackFiles,
    daysCompared: official.length - errors.length, fullLunarDatesCompared: fullDatesCompared,
    partialLunarDatesCompared: official.length - errors.length - fullDatesCompared,
    mismatchDays: mismatches.length, conversionErrors: errors.length, mismatchIntervals: intervals },
  limitations: ['HKO PDF date tables are an independent published reference, not a proof that either future astronomical model is universally correct.',
    'The first partial lunar month has no printed month/leap label. Unknown fields stay null until the official sequence establishes them; production data never fills the oracle.',
    'No birth-time, pillars, solar-term seconds, fortune-telling rules, or historical local time/DST are validated by this civil lunar-date comparison.'],
  perYear: [...years.values()], mismatches, errors,
};
fs.writeFileSync(path.join(here, 'hko-daily-results.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result.summary, null, 2));
