/**
 * Supabase 客户端配置
 *
 * 用户需要在 .env 或设置中配置 Supabase URL 和 Anon Key
 * 暂时用 AsyncStorage 中的配置，后续迁移到 .env
 */

import { createClient } from '@supabase/supabase-js';
import AsyncStorage from '@react-native-async-storage/async-storage';

// 默认值：用户可以在设置中覆盖
// TODO: 发布时替换为正式的 Supabase 项目
const SUPABASE_URL = process.env.EXPO_PUBLIC_SUPABASE_URL || '';
const SUPABASE_ANON_KEY = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || '';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: false, // React Native 不需要
  },
});
