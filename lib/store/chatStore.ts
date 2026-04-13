/**
 * 对话历史持久化 Store
 *
 * 独立于 userStore，避免大量对话数据拖慢用户配置的读写
 */

import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';
import type { ChatMessage } from '../ai';

export interface ChatState {
  messages: ChatMessage[];
  addMessage: (msg: ChatMessage) => void;
  clearMessages: () => void;
}

export const useChatStore = create<ChatState>()(
  persist(
    (set) => ({
      messages: [],

      addMessage: (msg: ChatMessage) =>
        set((state) => ({
          messages: [...state.messages.slice(-99), msg], // 保留最近100条
        })),

      clearMessages: () => set({ messages: [] }),
    }),
    {
      name: 'suiji-chat-store',
      storage: createJSONStorage(() => AsyncStorage),
    },
  ),
);
