/**
 * Auth Store — Supabase 认证状态管理
 */

import { create } from 'zustand';
import { supabase } from '../supabase/client';
import { pullProfile, startProfileAutoSync } from './profileSync';
import type { User, Session } from '@supabase/supabase-js';

export interface AuthState {
  user: User | null;
  session: Session | null;
  loading: boolean;
  error: string | null;

  initialize: () => Promise<void>;
  signUpWithEmail: (email: string, password: string) => Promise<void>;
  signInWithEmail: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  clearError: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  session: null,
  loading: true,
  error: null,

  initialize: async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      set({
        session,
        user: session?.user ?? null,
        loading: false,
      });

      if (session?.user) {
        try { await pullProfile(session.user.id); } catch {}
      }
      startProfileAutoSync();

      supabase.auth.onAuthStateChange((event, session) => {
        set({
          session,
          user: session?.user ?? null,
        });
        if (event === 'SIGNED_IN' && session?.user) {
          pullProfile(session.user.id).catch(() => {});
        }
      });
    } catch {
      set({ loading: false });
    }
  },

  signUpWithEmail: async (email: string, password: string) => {
    set({ loading: true, error: null });
    const { data, error } = await supabase.auth.signUp({ email, password });
    if (error) {
      set({ loading: false, error: error.message });
    } else {
      set({
        user: data.user,
        session: data.session,
        loading: false,
      });
    }
  },

  signInWithEmail: async (email: string, password: string) => {
    set({ loading: true, error: null });
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      set({ loading: false, error: error.message });
    } else {
      set({
        user: data.user,
        session: data.session,
        loading: false,
      });
    }
  },

  signOut: async () => {
    set({ loading: true });
    await supabase.auth.signOut();
    set({ user: null, session: null, loading: false });
  },

  clearError: () => set({ error: null }),
}));
