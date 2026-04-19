/**
 * Profile 云端同步 — CRUD over Supabase `profiles` 表
 * api_key 永不上云，仅存本地 AsyncStorage
 */

import { supabase } from './client';

export interface CloudProfile {
  id: string;
  birth_date: string | null;
  gender: '男' | '女' | null;
  birth_city: string | null;
  birth_longitude: number | null;
  api_provider: 'openai' | 'deepseek' | 'anthropic' | 'custom' | null;
  api_model: string | null;
  api_base_url: string | null;
  has_onboarded: boolean;
  created_at: string;
  updated_at: string;
}

export type ProfileUpdate = Partial<
  Omit<CloudProfile, 'id' | 'created_at' | 'updated_at'>
>;

export async function fetchProfile(userId: string): Promise<CloudProfile | null> {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function upsertProfile(
  userId: string,
  patch: ProfileUpdate,
): Promise<CloudProfile> {
  const { data, error } = await supabase
    .from('profiles')
    .upsert({ id: userId, ...patch }, { onConflict: 'id' })
    .select()
    .single();
  if (error) throw error;
  return data;
}
