/** Research-only sensitivity experiment. No production sources/bundles are rewritten. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const engine = path.resolve(here, '../..');
const require = createRequire(import.meta.url);
const { build } = require(path.join(engine, 'node_modules/esbuild'));
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'suji-structural-sensitivity-'));
const source = fs.readFileSync(path.join(engine, 'src/bazi/structural.ts'), 'utf8');
const digest = crypto.createHash('sha256').update(source).digest('hex');

function replaceVerified(text, before, after, expected = 1) {
  if (text.split(before).length - 1 !== expected) throw new Error(`Source changed: expected ${expected} occurrences of ${before}`);
  return text.split(before).join(after);
}
function rootThresholds(text, factor) {
  for (const old of ['0.30', '0.70', '1.50', '2.50']) text = replaceVerified(text, `if (total < ${old})`, `if (total < ${Number(old) * factor})`, 2);
  return text;
}
const variants = [
  { id: 'baseline', description: 'Current declared engineering parameters', mutate: s => s },
  { id: 'root-label-thresholds-minus20pct', description: 'Only root-label cutoffs ×0.8, both day and useful-element roots', mutate: s => rootThresholds(s, 0.8) },
  { id: 'root-label-thresholds-plus20pct', description: 'Only root-label cutoffs ×1.2, both day and useful-element roots', mutate: s => rootThresholds(s, 1.2) },
  { id: 'secondary-roots-minus0.1', description: 'Middle/remaining hidden-stem weights 0.5/0.2 → 0.4/0.1', mutate: s => replaceVerified(replaceVerified(s, 'zhong: 0.5,', 'zhong: 0.4,'), 'yu: 0.2,', 'yu: 0.1,') },
  { id: 'secondary-roots-plus0.1', description: 'Middle/remaining hidden-stem weights 0.5/0.2 → 0.6/0.3', mutate: s => replaceVerified(replaceVerified(s, 'zhong: 0.5,', 'zhong: 0.6,'), 'yu: 0.2,', 'yu: 0.3,') },
  { id: 'qing-share-minus0.05', description: 'Clean/mixed root-share cutoffs 0.6/0.3 → 0.55/0.25', mutate: s => replaceVerified(replaceVerified(s, 'dayPartyShare >= 0.6', 'dayPartyShare >= 0.55'), 'dayPartyShare < 0.3', 'dayPartyShare < 0.25') },
  { id: 'qing-share-plus0.05', description: 'Clean/mixed root-share cutoffs 0.6/0.3 → 0.65/0.35', mutate: s => replaceVerified(replaceVerified(s, 'dayPartyShare >= 0.6', 'dayPartyShare >= 0.65'), 'dayPartyShare < 0.3', 'dayPartyShare < 0.35') },
  { id: 'special-party-counts-minus1', description: 'Following/dominant configuration count gates each relaxed by one', mutate: s => replaceVerified(replaceVerified(replaceVerified(s, 'topCount < 4', 'topCount < 3'), 'topCount - secondCount < 2', 'topCount - secondCount < 1'), 'bijie < 4 || yin < 1 || keXie > 1', 'bijie < 3 || yin < 1 || keXie > 2') },
  { id: 'special-party-counts-plus1', description: 'Following/dominant configuration count gates each tightened by one', mutate: s => replaceVerified(replaceVerified(replaceVerified(s, 'topCount < 4', 'topCount < 5'), 'topCount - secondCount < 2', 'topCount - secondCount < 3'), 'bijie < 4 || yin < 1 || keXie > 1', 'bijie < 5 || yin < 1 || keXie > 0') },
];

await build({ entryPoints: [path.join(engine, 'src/calendar/precision.ts')], bundle: true, platform: 'node', format: 'cjs', outfile: path.join(scratch, 'calendar.cjs'), logLevel: 'silent' });
const calendar = require(path.join(scratch, 'calendar.cjs'));
const inputs = [];
for (let year = 1990; year <= 2025; year += 5) for (let month = 1; month <= 12; month++) for (const day of [1, 15, 28]) for (const hour of [0, 6, 12, 18]) {
  const instant = calendar.fromBeijingParts(year, month, day, hour);
  const p = calendar.getCalendarPillars(instant);
  const pillars = [p.year, p.month, p.day, p.hour];
  inputs.push({ date: instant.toISOString(), pillars, dayGan: p.day[0], stems: pillars.map(v => v[0]), branches: pillars.map(v => v[1]) });
}
function run(module, input) {
  const r = module.computeRiZhuStructure(input.dayGan, input.stems, input.branches);
  const g = module.computeGeJuV2(input.dayGan, input.stems, input.branches, r);
  return { rootLabel: r.rootStrength.label, strength: r.strength, qingZhuo: r.qingZhuo, configuration: g.name, category: g.category, chengBai: g.chengBai, rank: g.jibie, usefulElement: g.yongShen };
}
let baseline;
const results = [];
for (const variant of variants) {
  const outfile = path.join(scratch, `${variant.id}.cjs`);
  await build({ stdin: { contents: variant.mutate(source), loader: 'ts', resolveDir: path.join(engine, 'src/bazi') }, bundle: true, platform: 'node', format: 'cjs', outfile, logLevel: 'silent' });
  const module = require(outfile);
  const outputs = inputs.map(input => run(module, input));
  if (variant.id === 'baseline') baseline = outputs;
  const changedFields = Object.fromEntries(Object.keys(outputs[0]).map(k => [k, 0]));
  const examples = [];
  let anyChanged = 0;
  outputs.forEach((output, index) => {
    const fields = Object.keys(output).filter(k => output[k] !== baseline[index][k]);
    if (!fields.length) return;
    anyChanged++;
    fields.forEach(k => changedFields[k]++);
    if (examples.length < 12) examples.push({ date: inputs[index].date, pillars: inputs[index].pillars, changedFields: fields, baseline: baseline[index], variant: output });
  });
  results.push({ id: variant.id, description: variant.description, anyChanged, changedFields, examples });
}
const report = {
  purpose: 'Parameter sensitivity, NOT empirical accuracy or prediction validation',
  structuralSourceSha256: digest,
  sample: { count: inputs.length, years: '1990…2025 in 5-year steps', months: 'all 12', days: [1, 15, 28], hoursCST: [0, 6, 12, 18], solarTimeCorrection: false, fixedPillarsAcrossVariants: true },
  results,
};
fs.writeFileSync(path.join(here, 'structural-sensitivity.json'), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ sample: report.sample, results: results.map(({ id, anyChanged, changedFields }) => ({ id, anyChanged, changedFields })) }, null, 2));
fs.rmSync(scratch, { recursive: true, force: true });
