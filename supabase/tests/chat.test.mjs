import { test } from "node:test";
import assert from "node:assert/strict";
import { createHandler, providerRequest, MODEL, MAX_BODY_BYTES } from "../functions/suji-chat/handler.mjs";

const input = { stream: false, messages: [{ role: "user", content: "给我一句简单的鼓励。" }] };
const request = (body = input, authorization = "Bearer user-session") => new Request(
  "https://project.supabase.co/functions/v1/suji-chat/chat/completions",
  { method: "POST", headers: { "Content-Type": "application/json", Authorization: authorization }, body: JSON.stringify(body) },
);
function fixture(options = {}) {
  const calls = [];
  const fetcher = async (url, init) => {
    calls.push({ url, ...init });
    if (url.endsWith("/auth/v1/user")) return options.auth?.() ?? Response.json({ id: "account-1", role: "authenticated", is_anonymous: false });
    if (url.endsWith("/rpc/consume_ai_quota")) return options.quota?.() ?? Response.json({ allowed: true });
    return options.upstream?.(init) ?? Response.json({ choices: [{ message: { role: "assistant", content: "慢慢来。" } }] });
  };
  const handler = createHandler({ supabaseURL: "https://project.supabase.co", anonKey: "public-key", deepseekKey: "server-secret", fetcher, ...options.config });
  return { handler, calls };
}

test("missing sessions and public keys never reach Auth or DeepSeek", async () => {
  for (const token of ["", "Bearer public-key", "Bearer a b"]) {
    const { handler, calls } = fixture();
    assert.equal((await handler(request(input, token))).status, 401);
    assert.equal(calls.length, 0);
  }
});
test("expired, anonymous and unauthenticated identities cannot consume quota", async () => {
  for (const auth of [() => new Response("private auth detail", { status: 401 }), () => Response.json({ id: "visitor", role: "authenticated", is_anonymous: true }), () => Response.json({ id: "bad", role: "anon" })]) {
    const { handler, calls } = fixture({ auth });
    assert.equal((await handler(request())).status, 401);
    assert.equal(calls.length, 1);
  }
});
test("fixes upstream, model, reasoning and budget; forwards only the user's JWT to Supabase", async () => {
  const { handler, calls } = fixture();
  const response = await handler(request({ ...input, model: "expensive-model", thinking: { type: "enabled" }, max_tokens: 999999, base_url: "https://attacker.invalid", api_key: "client-key", n: 8 }));
  assert.equal(response.status, 200);
  assert.equal(calls.length, 3);
  assert.equal(calls[0].headers.Authorization, "Bearer user-session");
  assert.equal(calls[1].headers.Authorization, "Bearer user-session");
  assert.equal(calls[2].url, "https://api.deepseek.com/chat/completions");
  assert.equal(calls[2].headers.Authorization, "Bearer server-secret");
  assert.equal(calls[2].redirect, "error");
  assert.deepEqual(JSON.parse(calls[2].body), { ...input, model: MODEL, thinking: { type: "disabled" }, max_tokens: 2048 });
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal((await response.text()).includes("server-secret"), false);
});
test("forwards valid local tool history and definitions", () => {
  const call = { id: "call_1", type: "function", function: { name: "get_today_context", arguments: "{}" } };
  const body = providerRequest({ stream: false, messages: [
    ...input.messages, { role: "assistant", content: null, tool_calls: [call] },
    { role: "tool", content: '{"day":"2026-09-19"}', tool_call_id: call.id },
  ], tools: [{ type: "function", function: { name: "get_today_context", description: "今日历法", parameters: { type: "object", properties: {} } } }] });
  assert.equal(body.messages[2].tool_call_id, "call_1");
  assert.equal(body.tool_choice, "auto");
});
test("accepts all nine tools and the separate Ziwei timing round trip", () => {
  const names = ["get_domain","get_bazi_star","list_shensha","get_timing","get_today_context","get_ziwei_palace","get_ziwei_timing","cast_liuyao","setup_qimen"];
  const tools = names.map(name=>({type:"function",function:{name,description:name,parameters:{type:"object",properties:{}}}}));
  const call = {id:"ziwei-timing",type:"function",function:{name:"get_ziwei_timing",arguments:'{"date":"2025-01-29"}'}};
  const body = providerRequest({...input,tools,messages:[...input.messages,{role:"assistant",content:null,tool_calls:[call]},{role:"tool",content:'{"annual":{"ganZhi":"乙巳"}}',tool_call_id:call.id}]});
  assert.equal(body.tools.length,9);
  assert.equal(body.messages[1].tool_calls[0].function.name,"get_ziwei_timing");
  assert.throws(()=>providerRequest({...input,tools:[...tools,tools[0]]}));
});
test("rejects arbitrary tools, broken tool history and oversized context before billing", async () => {
  const badBodies = [
    { ...input, messages: [] }, { ...input, stream: "true" },
    { ...input, messages: [{ role: "user", content: "a".repeat(32001) }] },
    { ...input, messages: Array.from({ length: 5 }, () => ({ role: "user", content: "a".repeat(30000) })) },
    { ...input, tools: [{ type: "function", function: { name: "exec", description: "run", parameters: { type: "object" } } }] },
    { ...input, messages: [...input.messages, { role: "tool", content: "oops", tool_call_id: "missing" }] },
  ];
  for (const body of badBodies) {
    const { handler, calls } = fixture();
    assert.ok([400, 413].includes((await handler(request(body))).status));
    assert.equal(calls.length, 1);
  }
});
test("caps actual bytes even without Content-Length", async () => {
  const { handler, calls } = fixture();
  assert.equal((await handler(request({ ...input, padding: "x".repeat(MAX_BODY_BYTES) }))).status, 413);
  assert.equal(calls.length, 1);
});
test("quota rejection and quota outages fail closed", async () => {
  for (const [quota, status] of [
    [() => Response.json({ allowed: false, code: "daily_limit" }), 429],
    [() => Response.json({ allowed: false, code: "rate_limit" }), 429],
    [() => new Response("private SQL error", { status: 500 }), 503],
    [() => Response.json({}), 503],
  ]) {
    const { handler, calls } = fixture({ quota });
    const response = await handler(request());
    assert.equal(response.status, status);
    assert.equal(calls.length, 2);
    assert.equal((await response.text()).includes("private"), false);
  }
});
test("upstream authentication, billing and server errors are sanitized", async () => {
  for (const status of [401, 402, 429, 500]) {
    const { handler } = fixture({ upstream: () => new Response("server-secret private provider detail", { status }) });
    const response = await handler(request());
    assert.equal(response.status, status === 429 ? 429 : 503);
    assert.equal((await response.text()).includes("secret"), false);
  }
});
test("streams UTF-8 SSE immediately and preserves completion marker", async () => {
  let controller;
  const body = new ReadableStream({ start(value) { controller = value; } });
  const { handler } = fixture({ upstream: () => new Response(body, { headers: { "Content-Type": "text/event-stream" } }) });
  const response = await handler(request({ ...input, stream: true }));
  assert.equal(response.status, 200);
  const reader = response.body.getReader();
  const first = 'data: {"choices":[{"delta":{"content":"慢"}}]}\n\n';
  controller.enqueue(new TextEncoder().encode(first));
  assert.equal(new TextDecoder().decode((await reader.read()).value), first);
  controller.enqueue(new TextEncoder().encode("data: [DONE]\n\n")); controller.close();
  assert.equal(new TextDecoder().decode((await reader.read()).value), "data: [DONE]\n\n");
  assert.equal((await reader.read()).done, true);
});
test("consumer cancellation aborts the billed upstream request", async () => {
  let signal; let cancelled = false;
  const { handler } = fixture({ upstream: init => {
    signal = init.signal;
    return new Response(new ReadableStream({ cancel() { cancelled = true; } }), { headers: { "Content-Type": "text/event-stream" } });
  } });
  const response = await handler(request({ ...input, stream: true }));
  await response.body.cancel();
  assert.equal(signal.aborted, true); assert.equal(cancelled, true);
});
test("timeouts abort upstream without exposing exception details", async () => {
  const { handler } = fixture({ config: { timeoutMs: 15 }, upstream: init => new Promise((_, reject) => {
    init.signal.addEventListener("abort", () => reject(new Error("secret detail")), { once: true });
  }) });
  const response = await handler(request());
  assert.equal(response.status, 504);
  assert.deepEqual(await response.json(), { error: { code: "request_timeout" } });
});
test("stalled request bodies are timed out", async () => {
  const { handler } = fixture({ config: { timeoutMs: 15 } });
  const response = await handler(new Request("https://project.supabase.co/functions/v1/suji-chat", {
    method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer user-session" },
    body: new ReadableStream({}), duplex: "half",
  }));
  assert.equal(response.status, 504);
});
test("missing provider configuration never calls the provider", async () => {
  const { handler, calls } = fixture({ config: { deepseekKey: undefined } });
  assert.equal((await handler(request())).status, 503); assert.equal(calls.length, 0);
});
