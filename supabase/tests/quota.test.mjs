import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const { PGlite } = await import(process.env.SUJI_PGLITE_MODULE ?? "@electric-sql/pglite");

test("PostgreSQL quota: RLS, session identity, atomic limits and rollover", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon; create role authenticated;
      create schema auth;
      create function auth.jwt() returns jsonb language sql stable as
        $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
      create function auth.uid() returns uuid language sql stable as
        $$ select (auth.jwt()->>'sub')::uuid $$;
      grant usage on schema auth, public to anon, authenticated;
      grant execute on all functions in schema auth to anon, authenticated;
    `);
    await db.exec(await readFile(new URL("../migrations/0002_managed_ai_quota.sql", import.meta.url), "utf8"));
    const setUser = async (sub, is_anonymous = false) => {
      await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ sub, is_anonymous })]);
      await db.exec("set role authenticated");
    };
    const consume = async (connection = db) => (await connection.query("select public.consume_ai_quota() as result")).rows[0].result;
    const account = "11111111-1111-4111-8111-111111111111";
    const second = "22222222-2222-4222-8222-222222222222";
    await db.exec("set role anon");
    await assert.rejects(consume(), /permission denied/);
    await db.exec("reset role");
    await setUser(account, true);
    await assert.rejects(consume(), /sign_in_required/);
    await db.exec("reset role");
    await setUser(null);
    await assert.rejects(consume(), /sign_in_required/);
    await db.exec("reset role");
    await setUser(account);
    await assert.rejects(db.query("select * from public.ai_usage"), /permission denied/);
    await assert.rejects(db.query("delete from public.ai_usage"), /permission denied/);
    // PostgreSQL now() is fixed within a transaction. Keep this burst in one
    // quota minute even when CI crosses a wall-clock minute boundary; window
    // rollover is exercised separately below. PGlite serializes these calls.
    const attempts = await db.transaction(async transaction =>
      Promise.all(Array.from({ length: 20 }, () => consume(transaction))));
    assert.equal(attempts.filter(value => value.allowed).length, 12);
    assert.equal(attempts.filter(value => value.code === "rate_limit").length, 8);
    await db.exec("reset role");
    await setUser(second);
    assert.deepEqual(await consume(), { allowed: true });
    await db.exec("reset role");
    await db.query("update public.ai_usage set usage_minute = now() - interval '2 minutes' where account_id = $1", [account]);
    await setUser(account);
    assert.equal((await consume()).allowed, true);
    await db.exec("reset role");
    await db.query("update public.ai_usage set day_requests = 120 where account_id = $1", [account]);
    await setUser(account);
    assert.deepEqual(await consume(), { allowed: false, code: "daily_limit" });
    await db.exec("reset role");
    await db.query("update public.ai_usage set usage_day = current_date - 1 where account_id = $1", [account]);
    await setUser(account);
    assert.equal((await consume()).allowed, true);
    await db.exec("reset role");
    await db.exec("update public.ai_usage set day_requests = 5000 where account_id = '00000000-0000-0000-0000-000000000000'");
    await setUser(second);
    assert.deepEqual(await consume(), { allowed: false, code: "daily_limit" });
    await db.exec("reset role");
    const rows = (await db.query("select * from public.ai_usage")).rows;
    assert.equal(rows.length, 3); // Two identities and a global counter; no per-message data.
    assert.equal(rows.find(row => row.account_id === second).day_requests, 1);
  } finally { await db.close(); }
});
