/**
 * 登录/注册页面
 *
 * Apple Sign In + Google Sign In + 邮箱密码
 * 设计：极简，大面积留白，登录方式纯文字按钮
 */

import React, { useState, useCallback } from 'react';
import {
  StyleSheet, View, Text, TextInput, Pressable, ScrollView,
  ActivityIndicator, KeyboardAvoidingView, Platform, Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as AuthSession from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useAuthStore } from '@/lib/store/authStore';
import { supabase } from '@/lib/supabase/client';

// Google OAuth — 需要在 Google Cloud Console 配置
// TODO: 替换为正式的 Client ID
const GOOGLE_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID || '';

WebBrowser.maybeCompleteAuthSession();

export default function AuthScreen() {
  const router = useRouter();
  const { signInWithEmail, signUpWithEmail, loading, error, clearError } = useAuthStore();

  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [showEmailForm, setShowEmailForm] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // ── Apple Sign In ──────────────────────────────────
  const handleAppleSignIn = useCallback(async () => {
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });

      if (credential.identityToken) {
        const { error } = await supabase.auth.signInWithIdToken({
          provider: 'apple',
          token: credential.identityToken,
        });
        if (error) throw error;
        router.replace('/(tabs)');
      }
    } catch (e: any) {
      if (e.code !== 'ERR_REQUEST_CANCELED') {
        Alert.alert('Apple 登录失败', e.message || '请重试');
      }
    }
  }, [router]);

  // ── Google Sign In ─────────────────────────────────
  const [googleRequest, googleResponse, googlePromptAsync] = AuthSession.useAuthRequest(
    {
      clientId: GOOGLE_CLIENT_ID,
      redirectUri: AuthSession.makeRedirectUri({ scheme: 'suiji' }),
      scopes: ['openid', 'profile', 'email'],
      responseType: 'id_token',
    },
    { authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth' },
  );

  const handleGoogleSignIn = useCallback(async () => {
    try {
      const result = await googlePromptAsync();
      if (result.type === 'success' && result.params?.id_token) {
        const { error } = await supabase.auth.signInWithIdToken({
          provider: 'google',
          token: result.params.id_token,
        });
        if (error) throw error;
        router.replace('/(tabs)');
      }
    } catch (e: any) {
      Alert.alert('Google 登录失败', e.message || '请重试');
    }
  }, [googlePromptAsync, router]);

  // ── 邮箱登录/注册 ─────────────────────────────────
  const handleEmailSubmit = useCallback(async () => {
    clearError();
    if (!email.trim() || !password.trim()) return;

    if (mode === 'login') {
      await signInWithEmail(email.trim(), password);
    } else {
      await signUpWithEmail(email.trim(), password);
    }

    // 检查登录是否成功（store 更新后 user 不为 null）
    const { user } = useAuthStore.getState();
    if (user) {
      router.replace('/(tabs)');
    }
  }, [mode, email, password, signInWithEmail, signUpWithEmail, clearError, router]);

  // ── 跳过 ──────────────────────────────────────────
  const handleSkip = useCallback(() => {
    router.replace('/(tabs)');
  }, [router]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        contentContainerStyle={styles.scroll}
        keyboardShouldPersistTaps="handled"
      >
        {/* 品牌 */}
        <View style={styles.brand}>
          <Text style={styles.brandChar}>岁</Text>
          <Text style={styles.brandName}>岁吉</Text>
          <Text style={styles.brandSub}>顺时而行，从容而生</Text>
        </View>

        {/* 社交登录 */}
        <View style={styles.socialSection}>
          {/* Apple */}
          {Platform.OS === 'ios' && (
            <Pressable style={styles.socialBtn} onPress={handleAppleSignIn}>
              <Text style={styles.socialIcon}>🍎</Text>
              <Text style={styles.socialText}>通过 Apple 继续</Text>
            </Pressable>
          )}

          {/* Google */}
          <Pressable
            style={styles.socialBtn}
            onPress={handleGoogleSignIn}
            disabled={!googleRequest}
          >
            <Text style={styles.socialIcon}>G</Text>
            <Text style={styles.socialText}>通过 Google 继续</Text>
          </Pressable>

          {/* 邮箱 */}
          {!showEmailForm ? (
            <Pressable
              style={styles.socialBtn}
              onPress={() => setShowEmailForm(true)}
            >
              <Text style={styles.socialIcon}>✉</Text>
              <Text style={styles.socialText}>邮箱登录</Text>
            </Pressable>
          ) : (
            /* 邮箱表单 */
            <View style={styles.emailForm}>
              <View style={styles.emailModeRow}>
                <Pressable onPress={() => { setMode('login'); clearError(); }}>
                  <Text style={[styles.modeText, mode === 'login' && styles.modeTextOn]}>
                    登录
                  </Text>
                </Pressable>
                <Text style={styles.modeSep}>·</Text>
                <Pressable onPress={() => { setMode('signup'); clearError(); }}>
                  <Text style={[styles.modeText, mode === 'signup' && styles.modeTextOn]}>
                    注册
                  </Text>
                </Pressable>
              </View>

              <TextInput
                style={styles.input}
                value={email}
                onChangeText={setEmail}
                placeholder="邮箱"
                placeholderTextColor={Colors.inkHint}
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
              />
              <TextInput
                style={styles.input}
                value={password}
                onChangeText={setPassword}
                placeholder="密码（至少6位）"
                placeholderTextColor={Colors.inkHint}
                secureTextEntry
              />

              {error ? <Text style={styles.error}>{error}</Text> : null}

              <Pressable
                style={[styles.emailSubmit, loading && { opacity: 0.5 }]}
                onPress={handleEmailSubmit}
                disabled={loading}
              >
                {loading ? (
                  <ActivityIndicator size="small" color={Colors.bg} />
                ) : (
                  <Text style={styles.emailSubmitText}>
                    {mode === 'login' ? '登录' : '注册'}
                  </Text>
                )}
              </Pressable>
            </View>
          )}
        </View>

        {/* 分隔线 */}
        <View style={styles.divider} />

        {/* 跳过 */}
        <Pressable style={styles.skipBtn} onPress={handleSkip}>
          <Text style={styles.skipText}>稍后再说，先看看</Text>
        </Pressable>

        <Text style={styles.disclaimer}>
          登录即表示同意《用户协议》和《隐私政策》
        </Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingHorizontal: Space.xl,
    paddingTop: Platform.OS === 'ios' ? 100 : 80,
    paddingBottom: Space['3xl'],
  },

  // 品牌
  brand: {
    alignItems: 'center',
    marginBottom: Space['3xl'],
  },
  brandChar: {
    fontSize: 72,
    color: Colors.ink,
    fontWeight: '100',
    marginBottom: Space.sm,
  },
  brandName: {
    fontSize: 24,
    color: Colors.ink,
    fontWeight: '300',
    letterSpacing: 12,
  },
  brandSub: {
    ...Type.caption,
    color: Colors.inkHint,
    marginTop: Space.sm,
    letterSpacing: 4,
  },

  // 社交登录
  socialSection: {
    gap: Space.md,
  },
  socialBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: Space.md + 2,
    borderWidth: 1,
    borderColor: Colors.inkHint + '40',
    borderRadius: 2,
    gap: Space.md,
  },
  socialIcon: {
    fontSize: 18,
    width: 24,
    textAlign: 'center',
  },
  socialText: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 2,
  },

  // 邮箱表单
  emailForm: {
    paddingTop: Space.md,
    gap: Space.md,
  },
  emailModeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Space.md,
    marginBottom: Space.sm,
  },
  modeText: {
    ...Type.body,
    color: Colors.inkHint,
  },
  modeTextOn: {
    color: Colors.ink,
    fontWeight: '500',
  },
  modeSep: {
    ...Type.body,
    color: Colors.inkHint,
  },
  input: {
    ...Type.body,
    color: Colors.ink,
    backgroundColor: Colors.surface,
    borderRadius: 2,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
  },
  error: {
    ...Type.caption,
    color: Colors.warn,
  },
  emailSubmit: {
    backgroundColor: Colors.ink,
    borderRadius: 2,
    paddingVertical: Space.md,
    alignItems: 'center',
  },
  emailSubmitText: {
    ...Type.body,
    color: Colors.bg,
    fontWeight: '400',
    letterSpacing: 6,
  },

  // 分隔线
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.inkHint + '30',
    marginVertical: Space['2xl'],
  },

  // 跳过
  skipBtn: {
    alignItems: 'center',
    paddingVertical: Space.md,
  },
  skipText: {
    ...Type.body,
    color: Colors.inkTertiary,
    letterSpacing: 2,
  },

  // 免责
  disclaimer: {
    ...Type.label,
    color: Colors.inkHint,
    textAlign: 'center',
    marginTop: Space.xl,
    letterSpacing: 1,
  },
});
