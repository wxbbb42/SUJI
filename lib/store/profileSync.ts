/**
 * 桥接 userStore 与 Supabase profiles 表
 * - pullProfile: 云端 → 本地（登录/恢复 session 时）
 * - startProfileAutoSync: 订阅 userStore 变更，已登录时自动推送
 *
 * api_key 永不上云；mingPanCache 不上云（派生数据）
 */

import { fetchProfile, upsertProfile, type ProfileUpdate } from '../supabase/profile';
import { useUserStore, type UserState } from './userStore';
import { useAuthStore } from './authStore';

let suppressPush = false;
let autoSyncStarted = false;

export async function pullProfile(userId: string): Promise<void> {
  const profile = await fetchProfile(userId);
  if (!profile) return;

  suppressPush = true;
  try {
    useUserStore.setState({
      birthDate: profile.birth_date,
      gender: profile.gender,
      birthCity: profile.birth_city,
      birthLongitude: profile.birth_longitude,
      apiProvider: profile.api_provider,
      apiModel: profile.api_model,
      apiBaseUrl: profile.api_base_url,
      hasOnboarded: profile.has_onboarded,
    });
  } finally {
    suppressPush = false;
  }
}

export async function pushProfile(userId: string): Promise<void> {
  const s = useUserStore.getState();
  const patch: ProfileUpdate = {
    birth_date: s.birthDate,
    gender: s.gender,
    birth_city: s.birthCity,
    birth_longitude: s.birthLongitude,
    api_provider: s.apiProvider,
    api_model: s.apiModel,
    api_base_url: s.apiBaseUrl,
    has_onboarded: s.hasOnboarded,
  };
  await upsertProfile(userId, patch);
}

const SYNCED_KEYS = [
  'birthDate', 'gender', 'birthCity', 'birthLongitude',
  'apiProvider', 'apiModel', 'apiBaseUrl', 'hasOnboarded',
] as const satisfies readonly (keyof UserState)[];

function hasSyncedChange(a: UserState, b: UserState): boolean {
  return SYNCED_KEYS.some((k) => a[k] !== b[k]);
}

export function startProfileAutoSync(): () => void {
  if (autoSyncStarted) return () => {};
  autoSyncStarted = true;

  return useUserStore.subscribe((state, prev) => {
    if (suppressPush) return;
    if (!hasSyncedChange(state, prev)) return;
    const userId = useAuthStore.getState().user?.id;
    if (!userId) return;
    pushProfile(userId).catch((err) => {
      console.warn('[profileSync] push failed', err);
    });
  });
}
