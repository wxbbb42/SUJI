// Sequential batches against the existing backend; no deployment or quota changes.
import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { resolve, join } from 'node:path';
const args = process.argv.slice(2);
const option = key => args[args.indexOf(key) + 1];
if (!args.includes('--create-test-user') || !args.includes('--xctestrun') || !args.includes('--output')) throw new Error('Required: --create-test-user --xctestrun path --output new-directory [--cases id,id]');
const matrix = resolve('native/Tests/Fixtures/live-reading-matrix.json');
const fixture = JSON.parse(readFileSync(matrix, 'utf8'));
const ids = args.includes('--cases') ? option('--cases').split(',') : fixture.cases.map(c => c.id);
if (!ids.length || ids.length > 40 || new Set(ids).size !== ids.length || ids.some(id => !fixture.cases.some(c => c.id === id))) throw new Error('Invalid bounded selection');
const output = resolve(option('--output'));
if (existsSync(output)) throw new Error('Use a new output directory to preserve previous evidence');
mkdirSync(output, { recursive: true });
const runs = [];
for (let start = 0; start < ids.length; start += 6) {
  const subset = ids.slice(start, start + 6), dir = join(output, `batch-${1 + start / 6}`);
  console.log(`Starting independent cases ${subset.join(', ')}`);
  const code = await new Promise((done, reject) => {
    const child = spawn(process.execPath, ['supabase/scripts/smoke-native-reading.mjs', '--create-test-user', '--xctestrun', resolve(option('--xctestrun')), '--output', dir, '--matrix', matrix, '--cases', subset.join(','), ...(args.includes('--device') ? ['--device', option('--device')] : [])], { stdio: 'inherit' });
    child.on('error', reject); child.on('close', done);
  });
  runs.push({ cases: subset, code, evidence: dir });
  writeFileSync(join(output, 'batches.json'), JSON.stringify(runs, null, 2));
  // A test assertion may fail after recording real cases. A missing report is
  // infrastructure failure: stop instead of burning through more accounts/calls.
  if (!existsSync(join(dir, 'report.json'))) { process.exitCode = 1; break; }
  if (code) process.exitCode = 1;
}
