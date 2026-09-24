// Preserve real outcomes. This is a transport/stage summary, not an automatic
// claim that a nonempty or verifier-accepted answer is semantically adequate.
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve, join, relative } from 'node:path';
import { createHash } from 'node:crypto';
const root = resolve(process.argv[2] ?? 'native/artifacts/reading-matrix-2026-09-22');
const fixture = JSON.parse(readFileSync('native/Tests/Fixtures/live-reading-matrix.json', 'utf8'));
function reports(path) {
  return readdirSync(path, { withFileTypes: true }).flatMap(e => e.isDirectory() && !e.name.endsWith('.xcresult') ? reports(join(path, e.name)) : e.name === 'report.json' ? [join(path, e.name)] : []);
}
const parse = s => { try { return JSON.parse(s); } catch { return null; } };
function response(x) {
  if (!x.request?.stream) return parse(x.response)?.choices?.[0]?.message;
  return { content: (x.response ?? '').split('\n').filter(l => l.startsWith('data: {')).map(l => parse(l.slice(6))?.choices?.[0]?.delta?.content ?? '').join('') };
}
const runs = [];
for (const file of reports(root).sort()) {
  const data = readFileSync(file), report = JSON.parse(data), fileSHA256 = createHash('sha256').update(data).digest('hex');
  for (const [index, row] of report.results.entries()) {
    const exchanges = row.exchanges ?? [], writer = exchanges.find(x => x.request?.stream);
    const reviews = exchanges.map((x, i) => ({ x, i })).filter(({ x }) => x.request?.messages?.[0]?.content?.startsWith('你是命理解读的事实核对员'));
    const plans = exchanges.filter(x => x.request?.tools?.length).flatMap(x => response(x)?.tool_calls ?? []);
    const delivered = writer?.request.messages.filter(m => m.role === 'tool').map(m => ({ id: m.tool_call_id, error: parse(m.content)?.error ?? null, bytes: Buffer.byteLength(m.content ?? '') })) ?? [];
    const network = exchanges.some(x => x.error || (x.status && x.status !== 200));
    const stage = row.executionOK ? (reviews.length ? 'native-verifier-accepted' : row.receipts.length ? 'native-closed-render' : 'unverified-check-required')
      : network ? 'network-or-http-failure' : row.confirmationFailure ? 'confirmation-failure' : row.receipts.length ? 'verification-or-delivery-rejection-with-receipts' : plans.length ? 'tool-failure-or-unusable' : 'no-computation-and-rejected';
    runs.push({ id: row.id, turn: row.turn, kind: row.kind, question: row.question, profile: row.profile, birth: row.birth, mode: row.mode,
      context: row.context, confirmations: row.confirmations, timedOut: row.timedOut, confirmationFailure: row.confirmationFailure,
      expected: row.expected, expectation: row.expectation, stage, executionOK: row.executionOK, answer: row.answer, failure: row.failure,
      modelRequests: exchanges.length, planned: plans.map(c => ({ name: c.function.name, arguments: parse(c.function.arguments) })),
      receipts: row.receipts.map(r => ({ name: r.name, arguments: r.arguments, evidence: r.evidence, callID: r.callID })), delivered,
      reviews: reviews.map(({ x, i }) => ({ exchange: i, verdict: parse(response(x)?.content), raw: response(x)?.content })),
      dossierReused: row.dossierReused, archiveReplayOK: row.archiveReplayOK, retryPreservedReceipts: row.retryPreservedReceipts, retryDidNotAppend: row.retryDidNotAppend,
      evidence: `${relative(process.cwd(), file)}#/results/${index}`, fileSHA256, promptVersion: report.promptVersion });
  }
}
const unique = [...new Set(runs.filter(r => r.turn === 0).map(r => r.id))];
const summary = { notice: 'executionOK and verifier acceptance do not replace manual semantic evaluation. No result is silently discarded; before/after runs remain separate.', independentExecuted: unique.length, turnsExecuted: runs.length, modelRequests: runs.reduce((n, r) => n + r.modelRequests, 0), missing: fixture.cases.filter(c => !unique.includes(c.id)).map(c => c.id), runs };
writeFileSync(join(root, 'summary.json'), JSON.stringify(summary, null, 2));
console.log(JSON.stringify({ independentExecuted: summary.independentExecuted, turnsExecuted: summary.turnsExecuted, modelRequests: summary.modelRequests, missing: summary.missing, stageCounts: Object.fromEntries([...new Set(runs.map(r => r.stage))].map(s => [s, runs.filter(r => r.stage === s).length])) }, null, 2));
