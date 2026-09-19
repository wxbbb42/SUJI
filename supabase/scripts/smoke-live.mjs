// Explicit operator-only smoke test. Credentials stay in memory and are never printed.
// Creates one disposable confirmed account without sending email; deletes it in finally.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";

if (!process.argv.includes("--create-test-user")) {
  throw new Error("Requires --create-test-user and an authenticated Supabase CLI.");
}
const project = "kwhjutkuntfuhpkrlbly";
const base = `https://${project}.supabase.co`;
const endpoint = `${base}/functions/v1/suji-chat/chat/completions`;
const cli = process.env.SUJI_SUPABASE_CLI ?? "npx";
const prefix = cli === "npx" ? ["--yes", "supabase@2.117.0"] : [];
const command = args => execFileSync(cli, [...prefix, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 90000 });
let records;
try { records = JSON.parse(command(["projects", "api-keys", "--project-ref", project, "--reveal", "--output", "json"])); }
catch { throw new Error("Could not retrieve project API keys through the authenticated CLI."); }
if (!Array.isArray(records)) throw new Error("Unexpected CLI response shape; no credentials printed.");
const anon = records.find(value => value.name === "anon")?.api_key;
const admin = records.find(value => value.name === "service_role")?.api_key;
if (!anon || !admin) throw new Error("Expected this project's legacy public and service API keys.");
const adminHeaders = { apikey: admin, Authorization: `Bearer ${admin}`, "Content-Type": "application/json" };
const jsonRequest = async (url, body, headers, method = "POST") => {
  const response = await fetch(url, { method, headers, body: JSON.stringify(body), signal: AbortSignal.timeout(100000), redirect: "error" });
  if (!response.ok) throw new Error(`Smoke request failed with HTTP ${response.status} at ${new URL(url).pathname}`);
  return response.status === 204 ? null : response.json();
};
const basic = { stream: false, messages: [{ role: "user", content: "请用一句中文提醒我今天慢慢来。" }] };
let testUser;
try {
  for (const headers of [{ "Content-Type": "application/json" }, { "Content-Type": "application/json", apikey: anon, Authorization: `Bearer ${anon}` }]) {
    const response = await fetch(endpoint, { method: "POST", headers, body: JSON.stringify(basic), signal: AbortSignal.timeout(30000) });
    assert.equal(response.status, 401); await response.body?.cancel();
  }
  console.log("PASS deployed endpoint rejects missing sessions and anon-key-only requests");
  const email = `suji-smoke-${randomUUID()}@example.com`;
  const password = randomUUID() + randomUUID();
  const created = await jsonRequest(`${base}/auth/v1/admin/users`, { email, password, email_confirm: true, user_metadata: { purpose: "suji-deepseek-smoke-test" } }, adminHeaders);
  testUser = created.id;
  if (!testUser) throw new Error("No disposable user ID returned");
  const session = await jsonRequest(`${base}/auth/v1/token?grant_type=password`, { email, password }, { apikey: anon, "Content-Type": "application/json" });
  const headers = { apikey: anon, Authorization: `Bearer ${session.access_token}`, "Content-Type": "application/json" };

  const streamed = await fetch(endpoint, { method: "POST", headers, body: JSON.stringify({ ...basic, stream: true }), signal: AbortSignal.timeout(100000) });
  assert.equal(streamed.status, 200);
  let text = ""; let pending = ""; let done = false; const decoder = new TextDecoder();
  for await (const chunk of streamed.body) {
    pending += decoder.decode(chunk, { stream: true });
    const lines = pending.split("\n"); pending = lines.pop();
    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const value = line.slice(6).trim();
      if (value === "[DONE]") { done = true; continue; }
      const event = JSON.parse(value);
      for (const choice of event.choices ?? []) text += choice.delta?.content ?? "";
    }
  }
  assert.ok(text.trim()); assert.equal(done, true);
  console.log("PASS authenticated live Flash stream, nonempty text and DONE marker");

  const messages = [{ role: "user", content: "今天几号？请先调用 get_today_context 工具获取实时日期，再用一句中文给我一个日常建议。" }];
  const tool = { type: "function", function: { name: "get_today_context", description: "获取今天的实时日期。", parameters: { type: "object", properties: {} } } };
  const result = await jsonRequest(endpoint, { stream: false, messages, tools: [tool] }, headers);
  const message = result.choices[0].message;
  assert.ok(message.tool_calls?.length, "Expected a real tool call");
  assert.equal(message.tool_calls[0].function.name, "get_today_context");
  messages.push({ role: "assistant", content: message.content, tool_calls: message.tool_calls });
  for (const call of message.tool_calls) messages.push({ role: "tool", tool_call_id: call.id, content: '{"date":"2026-09-19","source":"synthetic smoke fixture"}' });
  const continuation = await jsonRequest(endpoint, { stream: false, messages }, headers);
  assert.ok(continuation.choices[0].message.content?.trim());
  console.log("PASS authenticated live tool request and tool-result continuation");

  // Hit the minute limit using inexpensive counter RPCs, never extra model calls.
  for (let i = 0; i < 12; i++) {
    const value = await jsonRequest(`${base}/rest/v1/rpc/consume_ai_quota`, {}, headers);
    if (!value.allowed) break;
  }
  const limited = await fetch(endpoint, { method: "POST", headers, body: JSON.stringify(basic), signal: AbortSignal.timeout(30000) });
  assert.equal(limited.status, 429); await limited.body?.cancel();
  console.log("PASS deployed per-account quota rejects excess requests");
} catch (error) {
  // Do not print objects from auth/provider APIs, fetch exceptions or CLI stderr.
  console.error(`FAIL live smoke: ${error instanceof assert.AssertionError ? error.message.slice(0, 200) : error.message}`);
  process.exitCode = 1;
} finally {
  if (testUser) {
    try {
      await jsonRequest(`${base}/auth/v1/admin/users/${testUser}`, { should_soft_delete: false }, adminHeaders, "DELETE");
      assert.match(testUser, /^[a-f0-9-]{36}$/);
      command(["db", "query", "--linked", "--project-ref", project, `delete from public.ai_usage where account_id = '${testUser}'::uuid`]);
      console.log("PASS disposable test account and its private quota row removed");
    } catch {
      console.error(`Test cleanup needs operator attention for disposable account ${testUser}`);
      process.exitCode = 1;
    }
  }
}
