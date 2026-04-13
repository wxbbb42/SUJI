/**
 * 用户 Store
 * zustand + AsyncStorage persist
 */

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface UserState {
  // 生辰信息
  birthDate: string | null;        // ISO string
  gender: '男' | '女' | null;
  birthCity: string | null;
  birthLongitude: number | null;

  // API 配置
  apiProvider: 'openai' | 'deepseek' | 'anthropic' | 'custom' | null;
  apiKey: string | null;
  apiModel: string | null;
  apiBaseUrl: string | null;

  // 命盘缓存
  mingPanCache: string | null;     // JSON.stringify(MingPan)

  // Actions
  setBirthDate: (date: Date) => void;
  setGender: (gender: '男' | '女') => void;
  setBirthCity: (city: string, longitude: number) => void;
  setApiProvider: (provider: UserState['apiProvider']) => void;
  setApiKey: (key: string) => void;
  setApiModel: (model: string) => void;
  setApiBaseUrl: (url: string) => void;
  setMingPanCache: (json: string) => void;
  reset: () => void;
}

const initialState = {
  birthDate: null,
  gender: null,
  birthCity: null,
  birthLongitude: null,
  apiProvider: null,
  apiKey: null,
  apiModel: null,
  apiBaseUrl: null,
  mingPanCache: null,
} as const;

export const useUserStore = create<UserState>()(
  persist(
    (set) => ({
      ...initialState,

      setBirthDate: (date: Date) =>
        set({ birthDate: date.toISOString() }),

      setGender: (gender: '男' | '女') =>
        set({ gender }),

      setBirthCity: (city: string, longitude: number) =>
        set({ birthCity: city, birthLongitude: longitude }),

      setApiProvider: (provider) =>
        set({ apiProvider: provider }),

      setApiKey: (key: string) =>
        set({ apiKey: key }),

      setApiModel: (model: string) =>
        set({ apiModel: model }),

      setApiBaseUrl: (url: string) =>
        set({ apiBaseUrl: url }),

      setMingPanCache: (json: string) =>
        set({ mingPanCache: json }),

      reset: () =>
        set({ ...initialState }),
    }),
    {
      name: 'suiji-user-store',
      storage: createJSONStorage(() => AsyncStorage),
    },
  ),
);
