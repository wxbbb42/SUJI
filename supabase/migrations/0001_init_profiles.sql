-- 岁吉 SUJI — profiles 表初始化
-- 在 Supabase Dashboard → SQL Editor 粘贴运行

-- 1. profiles 表：每个用户一行，主键直接引用 auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  -- 生辰信息
  birth_date timestamptz,
  gender text check (gender in ('男', '女')),
  birth_city text,
  birth_longitude numeric,

  -- AI 配置（不含 api_key，api_key 只存设备本地）
  api_provider text check (api_provider in ('openai', 'deepseek', 'anthropic', 'custom')),
  api_model text,
  api_base_url text,

  -- 状态
  has_onboarded boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Row Level Security：用户只能读写自己那行
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);

-- 3. 注册时自动插入一行 profile
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. updated_at 自动维护
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
