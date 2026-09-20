// Shared by Supabase's Deno runtime and dependency-free Node contract tests.
export const MODEL = "deepseek-flash";
export const MAX_BODY_BYTES = 262144;
const UPSTREAM = "https://api.deepseek.com/chat/completions";
const TOOLS = new Set([
  "get_domain", "get_bazi_star", "list_shensha", "get_timing",
  "get_today_context", "get_ziwei_palace", "get_ziwei_timing", "cast_liuyao", "setup_qimen",
]);
const HEADERS = { "Content-Type": "application/json", "Cache-Control": "no-store" };

class Failure extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
const fail = (status, code) => { throw new Failure(status, code); };
const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
const string = (value, max = 32000) => typeof value === "string" && value.length <= max;
const id = value => string(value, 200) && /^[\w-]+$/.test(value);

async function readJSON(request, signal) {
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) fail(415, "json_required");
  if (Number(request.headers.get("content-length")) > MAX_BODY_BYTES) fail(413, "request_too_large");
  if (!request.body) fail(400, "invalid_request");
  const reader = request.body.getReader();
  const cancel = () => { void reader.cancel().catch(() => {}); };
  signal.addEventListener("abort", cancel, { once: true });
  if (signal.aborted) cancel();
  const chunks = []; let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > MAX_BODY_BYTES) { await reader.cancel(); fail(413, "request_too_large"); }
      chunks.push(value);
    }
  } finally { signal.removeEventListener("abort", cancel); reader.releaseLock(); }
  signal.throwIfAborted();
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  try { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
  catch { fail(400, "invalid_json"); }
}

export function providerRequest(input) {
  if (!object(input) || typeof input.stream !== "boolean" || !Array.isArray(input.messages) ||
      input.messages.length < 1 || input.messages.length > 120) fail(400, "invalid_request");
  let characters = 0;
  const pending = new Set();
  const seenCalls = new Set();
  const messages = input.messages.map(message => {
    if (!object(message) || !["system", "user", "assistant", "tool"].includes(message.role)) fail(400, "invalid_message");
    const { role, content } = message;
    if (content !== null && !string(content)) fail(400, "invalid_content");
    characters += content?.length ?? 0;
    if (pending.size && role !== "tool") fail(400, "missing_tool_result");
    const result = { role, content };
    if (role === "tool") {
      if (!id(message.tool_call_id) || !pending.delete(message.tool_call_id) || !string(content)) fail(400, "invalid_tool_result");
      result.tool_call_id = message.tool_call_id;
    } else if (message.tool_call_id != null) fail(400, "invalid_tool_result");
    if (message.tool_calls != null) {
      if (role !== "assistant" || !Array.isArray(message.tool_calls) || !message.tool_calls.length || message.tool_calls.length > 8) fail(400, "invalid_tools");
      result.tool_calls = message.tool_calls.map(call => {
        if (!object(call) || !id(call.id) || seenCalls.has(call.id) || call.type !== "function" ||
            !object(call.function) || !TOOLS.has(call.function.name) || !string(call.function.arguments, 16000)) fail(400, "invalid_tool_call");
        try { if (!object(JSON.parse(call.function.arguments))) fail(400, "invalid_arguments"); }
        catch { fail(400, "invalid_arguments"); }
        characters += call.function.arguments.length;
        pending.add(call.id); seenCalls.add(call.id);
        return { id: call.id, type: "function", function: { name: call.function.name, arguments: call.function.arguments } };
      });
    } else if (!string(content)) fail(400, "invalid_content");
    return result;
  });
  if (pending.size || !messages.some(m => m.role === "user")) fail(400, "invalid_history");
  const result = {
    model: MODEL, messages, stream: input.stream,
    thinking: { type: "disabled" }, max_tokens: 2048,
  };
  if (input.tools != null) {
    if (!Array.isArray(input.tools) || input.tools.length > TOOLS.size || input.stream) fail(400, "invalid_tools");
    const names = new Set();
    result.tools = input.tools.map(tool => {
      if (!object(tool) || tool.type !== "function" || !object(tool.function)) fail(400, "invalid_tools");
      const { name, description, parameters } = tool.function;
      if (!TOOLS.has(name) || names.has(name) || !string(description, 4000) || !object(parameters) ||
          parameters.type !== "object" || JSON.stringify(parameters).length > 16000) fail(400, "invalid_tools");
      names.add(name); characters += description.length + JSON.stringify(parameters).length;
      return { type: "function", function: { name, description, parameters } };
    });
    if (result.tools.length) result.tool_choice = "auto";
    else delete result.tools;
  }
  if (characters > 120000) fail(413, "context_too_large");
  // No client-selected endpoint, key, model, token budget or reasoning mode is forwarded.
  return result;
}

export function createHandler({ supabaseURL, anonKey, deepseekKey, fetcher = fetch, timeoutMs = 90000 }) {
  return async request => {
    const path = new URL(request.url).pathname.replace(/\/$/, "");
    if (!path.endsWith("/suji-chat/chat/completions") && !path.endsWith("/suji-chat")) {
      return Response.json({ error: { code: "not_found" } }, { status: 404, headers: HEADERS });
    }
    if (request.method !== "POST") return Response.json({ error: { code: "method_not_allowed" } }, { status: 405, headers: { ...HEADERS, Allow: "POST" } });
    const controller = new AbortController();
    const abort = () => controller.abort();
    request.signal.addEventListener("abort", abort, { once: true });
    if (request.signal.aborted) abort();
    const timeout = setTimeout(abort, timeoutMs);
    const cleanup = () => { clearTimeout(timeout); request.signal.removeEventListener("abort", abort); };
    let streaming = false;
    try {
      const authorization = request.headers.get("authorization") ?? "";
      if (!/^Bearer [^\s]+$/i.test(authorization) || authorization.slice(7) === anonKey) fail(401, "sign_in_required");
      if (!supabaseURL || !anonKey || !deepseekKey) fail(503, "service_unavailable");
      const headers = { apikey: anonKey, Authorization: authorization };
      const auth = await fetcher(`${supabaseURL}/auth/v1/user`, { headers, signal: controller.signal, redirect: "error" });
      if (auth.status === 401 || auth.status === 403) { await auth.body?.cancel(); fail(401, "sign_in_required"); }
      if (!auth.ok) { await auth.body?.cancel(); fail(503, "auth_unavailable"); }
      const user = await auth.json();
      if (!user.id || user.role !== "authenticated" || user.is_anonymous === true) fail(401, "sign_in_required");
      const body = providerRequest(await readJSON(request, controller.signal));
      const quota = await fetcher(`${supabaseURL}/rest/v1/rpc/consume_ai_quota`, {
        method: "POST", headers: { ...headers, "Content-Type": "application/json" },
        body: "{}", signal: controller.signal, redirect: "error",
      });
      if (!quota.ok) { await quota.body?.cancel(); fail(503, "quota_unavailable"); }
      const allowance = await quota.json();
      if (!object(allowance) || typeof allowance.allowed !== "boolean") fail(503, "quota_unavailable");
      if (!allowance.allowed) fail(429, allowance.code === "daily_limit" ? "daily_limit" : "rate_limit");
      const upstream = await fetcher(UPSTREAM, {
        method: "POST", headers: { "Content-Type": "application/json", Authorization: `Bearer ${deepseekKey}` },
        body: JSON.stringify(body), signal: controller.signal, redirect: "error",
      });
      if (!upstream.ok) {
        await upstream.body?.cancel();
        fail(upstream.status === 429 ? 429 : 503, upstream.status === 429 ? "provider_busy" : "service_unavailable");
      }
      const type = upstream.headers.get("content-type") ?? "";
      if (!body.stream) {
        if (!type.includes("application/json")) { await upstream.body?.cancel(); fail(502, "invalid_response"); }
        const value = await upstream.json();
        if (!Array.isArray(value.choices) || !value.choices.length || value.error) fail(502, "invalid_response");
        return Response.json(value, { headers: HEADERS });
      }
      if (!upstream.body || !type.includes("text/event-stream")) { await upstream.body?.cancel(); fail(502, "invalid_response"); }
      const reader = upstream.body.getReader();
      const stream = new ReadableStream({
        async pull(target) {
          try {
            const { done, value } = await reader.read();
            if (done) { cleanup(); target.close(); }
            else target.enqueue(value);
          } catch { cleanup(); target.error(new Error("stream_interrupted")); }
        },
        async cancel() { abort(); cleanup(); await reader.cancel().catch(() => {}); },
      });
      streaming = true;
      return new Response(stream, { headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-store", "X-Accel-Buffering": "no" } });
    } catch (error) {
      const status = error instanceof Failure ? error.status : controller.signal.aborted ? 504 : 503;
      const code = error instanceof Failure ? error.message : controller.signal.aborted ? "request_timeout" : "service_unavailable";
      return Response.json({ error: { code } }, { status, headers: { ...HEADERS, ...(status === 429 ? { "Retry-After": code === "daily_limit" ? "3600" : "60" } : {}) } });
    } finally { if (!streaming) cleanup(); }
  };
}
