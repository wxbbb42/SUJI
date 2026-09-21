# 有时 AI 后端

SwiftUI App → Supabase Auth + `suji-chat` Edge Function → DeepSeek Flash.
The app sends a signed-in user's session token, never a provider key. The function verifies the user with Supabase Auth, refuses anonymous sessions, consumes a database quota and forwards either JSON tool calls or SSE text. No prompts or replies are stored or logged by this function.

## Provider

- Official endpoint: `https://api.deepseek.com/chat/completions`
- Model: `deepseek-flash` (DeepSeek V4.1 Flash, verified 2026-09-19).
- `thinking: {"type":"disabled"}` for fast replies and compatibility with existing local tool history.
- Fixed maximum 2,048 output tokens per inference request; 256 KiB HTTP body; 120,000 text characters; 90-second upstream deadline. Client-supplied model, credentials, URL and inference settings are ignored.
- References: [models](https://api-docs.deepseek.com/quick_start/pricing), [thinking mode](https://api-docs.deepseek.com/guides/thinking_mode).

## Deployment

Deployed and verified on **2026-09-19**: quota migration applied, provider secret stored, `suji-chat` live. An authenticated disposable account completed a real streamed reply and a tool round trip; missing sessions and public-key-only requests returned 401, and an exhausted minute quota returned 429. The disposable account and its quota row were removed afterward.

The existing project is `kwhjutkuntfuhpkrlbly`. Use the official Supabase CLI or the dashboard. The public app configuration continues to come from `native/scripts/configure-public.py`.

1. Apply **only** `migrations/0002_managed_ai_quota.sql` to the existing database (0001 already describes the existing profiles setup). This adds a private usage table and a quota function; it does not alter profiles or user records.
2. Store `DEEPSEEK_API_KEY` as an Edge Function secret. The locally prepared `supabase/.env.local` is ignored by Git and readable only by its owner. Never bundle it in the iPhone app.
3. Deploy the function:

```sh
npx supabase secrets set --project-ref kwhjutkuntfuhpkrlbly --env-file supabase/.env.local
npx supabase functions deploy suji-chat --project-ref kwhjutkuntfuhpkrlbly --no-verify-jwt
```

`verify_jwt = false` disables only the gateway's legacy JWT check; the function always calls `GET /auth/v1/user` and validates a non-anonymous authenticated user before forwarding. This supports current Supabase JWT signing keys. Requests without a valid user session are rejected. Do not replace this with an anon-key-only check.

Endpoint: `https://kwhjutkuntfuhpkrlbly.supabase.co/functions/v1/suji-chat/chat/completions`.

## Quotas

Initial limits are 12 model requests per account per minute, 120 per account per UTC day, and 5,000 per project per UTC day. Tool orchestration may use several model requests for one question. Failed provider requests also count, to bound retries. The SQL function atomically updates both counters across workers; clients cannot reset or read the table. A signed-in client can consume its own quota without running inference, but cannot increase its allowance. The quota is a request ceiling, not an exact monetary budget.

To adjust these limits, deploy a reviewed replacement of `consume_ai_quota`. For an emergency stop, remove `DEEPSEEK_API_KEY` from function secrets or revoke it in DeepSeek. Auth, SQL or provider outages fail closed; error messages do not include upstream error bodies or credentials.

## Checks

```sh
npm ci --prefix supabase
npm test --prefix supabase
```

The PostgreSQL test runs the real migration in PGlite with Supabase-compatible Auth stubs. It checks permissions, anonymous rejection, account isolation, minute/day rollover and global quotas. Node tests exercise request validation, credential separation, SSE, cancellation, timeouts and errors without live credentials.

Live smoke checks must use a signed-in non-anonymous test account and synthetic questions. Confirm that unauthenticated and anon-key-only requests get 401, then verify a streamed response and a complete local tool round trip. Do not print tokens or user content in logs.

An operator with project-admin CLI access can explicitly run `node supabase/scripts/smoke-live.mjs --create-test-user`. This creates a temporary confirmed account without sending email, performs three short inference requests, checks the rate limit with counter-only calls and removes its test account and quota row. It keeps credentials in memory. The global request counter intentionally retains these test calls. Review the script before running it against a different project.
