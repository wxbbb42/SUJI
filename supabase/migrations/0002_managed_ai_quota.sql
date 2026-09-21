-- Only counters are stored. No prompts, responses or provider credentials.
create table if not exists public.ai_usage (
  account_id uuid primary key,
  usage_day date not null,
  day_requests integer not null default 0,
  usage_minute timestamptz not null,
  minute_requests integer not null default 0
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from public, anon, authenticated;

create or replace function public.consume_ai_quota()
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  account uuid := auth.uid();
  global_account constant uuid := '00000000-0000-0000-0000-000000000000';
  today date := (now() at time zone 'UTC')::date;
  this_minute timestamptz := date_trunc('minute', now());
  personal public.ai_usage;
  overall public.ai_usage;
begin
  if account is null or account = global_account or
     coalesce((auth.jwt()->>'is_anonymous')::boolean, false) then
    raise insufficient_privilege using message = 'sign_in_required';
  end if;
  -- Short transaction lock makes both per-account and global counters atomic
  -- across all Edge Function workers. No network I/O while holding this lock.
  perform pg_advisory_xact_lock(724803120);
  insert into public.ai_usage(account_id, usage_day, usage_minute)
  values (account, today, this_minute), (global_account, today, this_minute)
  on conflict do nothing;
  update public.ai_usage
  set day_requests = case when usage_day = today then day_requests else 0 end,
      minute_requests = case when usage_minute = this_minute then minute_requests else 0 end,
      usage_day = today, usage_minute = this_minute
  where account_id in (account, global_account);
  select * into personal from public.ai_usage where account_id = account;
  select * into overall from public.ai_usage where account_id = global_account;
  if personal.day_requests >= 120 or overall.day_requests >= 5000 then
    return jsonb_build_object('allowed', false, 'code', 'daily_limit');
  end if;
  if personal.minute_requests >= 12 then
    return jsonb_build_object('allowed', false, 'code', 'rate_limit');
  end if;
  update public.ai_usage set day_requests = day_requests + 1, minute_requests = minute_requests + 1
  where account_id in (account, global_account);
  return jsonb_build_object('allowed', true);
end;
$$;
revoke all on function public.consume_ai_quota() from public, anon;
grant execute on function public.consume_ai_quota() to authenticated;
