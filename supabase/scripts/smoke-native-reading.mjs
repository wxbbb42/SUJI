// Explicit operator-only native integration. Never prints credentials or uses a real user's notebook.
import { execFileSync, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { mkdirSync, mkdtempSync, writeFileSync, unlinkSync, rmdirSync, createWriteStream, readFileSync, existsSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { tmpdir } from 'node:os';

const option = name => process.argv[process.argv.indexOf(name) + 1];
if (!process.argv.includes('--create-test-user') || !process.argv.includes('--xctestrun') || !process.argv.includes('--output')) {
  throw new Error('Usage: --create-test-user --xctestrun built-tests.xctestrun --output new-evidence-directory [--device simulator-id] [--matrix fixture.json] [--cases id,id]');
}
const project = 'kwhjutkuntfuhpkrlbly';
const base = `https://${project}.supabase.co`;
const output = resolve(option('--output'));
const matrixPath = resolve(process.argv.includes('--matrix') ? option('--matrix') : 'native/Tests/Fixtures/live-reading-matrix.json');
const matrix = JSON.parse(readFileSync(matrixPath, 'utf8'));
const selected = process.argv.includes('--cases') ? option('--cases').split(',') : matrix.cases.slice(0, 8).map(c => c.id);
if (!matrix.syntheticOnly || !selected.length || selected.length > 8 || new Set(selected).size !== selected.length || selected.some(id => !matrix.cases.some(c => c.id === id))) throw new Error('Select 1–8 unique valid synthetic cases per bounded account batch');
if (existsSync(output)) throw new Error('Use a new output directory to preserve previous evidence');
mkdirSync(output, { recursive: true });
const temp = mkdtempSync(join(tmpdir(), 'suji-native-live-'));
const configPath = join(temp, 'account.json');
const originalRun = resolve(option('--xctestrun'));
const runPath = join(dirname(originalRun), `SujiLive-${randomUUID()}.xctestrun`);
const cli = args => execFileSync('npx', ['--yes', 'supabase@2.117.0', ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 90000 });
let admin;
let userID;
async function adminRequest(path, body, method = 'POST') {
  const response = await fetch(base + path, { method, headers: { apikey: admin, Authorization: `Bearer ${admin}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new Error(`Disposable-account operation failed: HTTP ${response.status}`);
  return response.status === 204 ? null : response.json();
}
try {
  const records = JSON.parse(cli(['projects', 'api-keys', '--project-ref', project, '--reveal', '--output', 'json']));
  admin = records.find(item => item.name === 'service_role')?.api_key;
  if (!admin) throw new Error('Could not obtain project-admin authorization');
  const email = `suji-native-${randomUUID()}@example.com`, password = randomUUID() + randomUUID();
  const user = await adminRequest('/auth/v1/admin/users', { email, password, email_confirm: true, user_metadata: { purpose: 'suji-native-live-test' } });
  userID = user.id;
  if (!/^[a-f0-9-]{36}$/.test(userID)) throw new Error('Invalid disposable account identifier');
  writeFileSync(configPath, JSON.stringify({ email, password, reportPath: join(output, 'report.json'), matrixPath, caseIDs: selected }), { mode: 0o600 });
  execFileSync('python3', ['-c', `import plistlib,sys
source,dest,config=sys.argv[1:]
d=plistlib.load(open(source,'rb'))
def visit(v):
 if isinstance(v,dict):
  if v.get('ProductModuleName')=='SujiTests':
   v.setdefault('EnvironmentVariables',{})['SUJI_LIVE_READING_CONFIG']=config
  for item in v.values(): visit(item)
 elif isinstance(v,list):
  for item in v: visit(item)
visit(d)
with open(dest,'wb') as f: plistlib.dump(d,f)
`, originalRun, runPath, configPath], { stdio: ['ignore', 'pipe', 'pipe'] });
  console.log('Running actual native login, dossier, reading and deployed model journey with a disposable account');
  const log = createWriteStream(join(output, 'xcodebuild.log'));
  const code = await new Promise((resolveCode, reject) => {
    const child = spawn('xcodebuild', ['test-without-building', '-xctestrun', runPath, '-destination', `platform=iOS Simulator,id=${process.argv.includes('--device') ? option('--device') : '09FF0B1D-9E60-4F2A-9465-3B156C88BD28'}`, '-only-testing:SujiTests/LiveReadingSessionTests', '-parallel-testing-enabled', 'NO', '-resultBundlePath', join(output, 'tests.xcresult')], { stdio: ['ignore', 'pipe', 'pipe'] });
    child.stdout.pipe(log, { end: false }); child.stderr.pipe(log, { end: false });
    let teardownTimer, selectedTestsFinished = false, terminatedAfterTests = false;
    let tail = '';
    const observe = chunk => {
      tail = (tail + chunk.toString()).slice(-4096);
      if (!selectedTestsFinished && /Test Suite 'Selected tests' (passed|failed)/.test(tail)) {
        selectedTestsFinished = true;
        // XCTest has completed and private config cleanup ran. Preserve the
        // report if xcodebuild subsequently hangs while collecting diagnostics.
        teardownTimer = setTimeout(() => { terminatedAfterTests = true; child.kill('SIGTERM'); }, 60000);
      }
    };
    child.stdout.on('data', observe); child.stderr.on('data', observe);
    child.on('error', reject); child.on('close', (status, signal) => {
      clearTimeout(teardownTimer); log.end();
      writeFileSync(join(output, 'run-status.json'), JSON.stringify({ status, signal, selectedTestsFinished, terminatedAfterTests }));
      resolveCode(status);
    });
  });
  console.log(`Native live test exited ${code}; evidence: ${output}`);
  if (code !== 0) process.exitCode = 1;
} catch (error) {
  console.error(error.message?.startsWith('Disposable-') ? error.message : 'Native live setup/run failed; credentials were not printed');
  process.exitCode = 1;
} finally {
  if (userID) {
    try {
      // One bounded retry handles a transient auth-admin failure. Deleting this
      // exact disposable ID is idempotent; never broaden cleanup to other users.
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          await adminRequest(`/auth/v1/admin/users/${userID}`, { should_soft_delete: false }, 'DELETE');
          break;
        } catch (error) {
          if (error.message.endsWith('HTTP 404')) break;
          if (attempt === 1) throw error;
        }
      }
      cli(['db', 'query', '--linked', '--project-ref', project, `delete from public.ai_usage where account_id = '${userID}'::uuid`]);
      writeFileSync(join(output, 'cleanup.json'), JSON.stringify({ disposableAccountRemoved: true, quotaRowRemoved: true }));
      console.log('Removed the disposable test account and its quota row');
    } catch { writeFileSync(join(output, 'cleanup.json'), JSON.stringify({ disposableAccountRemoved: false, operatorAccountID: userID })); console.error(`Cleanup needs operator attention for disposable account ${userID}`); process.exitCode = 1; }
  }
  for (const file of [configPath, runPath]) { try { unlinkSync(file); } catch {} }
  try { rmdirSync(temp); } catch {}
}
