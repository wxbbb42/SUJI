/**
 * 登录/注册页面
 *
 * 邮箱密码认证（Supabase Auth）
 * 可选：未配置 Supabase 时跳过
 */

import {
  StyleSheet, View, Text, TextInput, Pressable, ScrollView,
  ActivityIndicator, KeyboardAvoidingView, Platform,
} from 'react-native';
import { useState, useCallback } from 'react';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useAuthStore } from '@/lib/store/authStore';

export default function AuthScreen() {
  const router = useRouter();
  const { signInWithEmail, signUpWithEmail, loading, error, clearError } = useAuthStore();

  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = useCallback(async () => {
    clearError();
    if (!email.trim() || !password.trim()) return;

    if (mode === 'login') {
      await signInWithEmail(email.trim(), password);
    } else {
      await signUpWithEmail(email.trim(), password);
    }
  }, [mode, email, password, signInWithEmail, signUpWithEmail, clearError]);

  const handleSkip = useCallback(() => {
    router.replace('/(tabs)');
  }, [router]);

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.header}>
          <Text style={styles.title}>岁吉</Text>
          <Text style={styles.subtitle}>
            {mode === 'login' ? '欢迎回来' : '创建账户'}
          </Text>
        </View>

        {/* 邮箱 */}
        <Text style={styles.inputLabel}>邮箱</Text>
        <TextInput
          style={styles.input}
          value={email}
          onChangeText={setEmail}
          placeholder="your@email.com"
          placeholderTextColor={Colors.inkHint}
          keyboardType="email-address"
          autoCapitalize="none"
          autoCorrect={false}
        />

        {/* 密码 */}
        <Text style={styles.inputLabel}>密码</Text>
        <TextInput
          style={styles.input}
          value={password}
          onChangeText={setPassword}
          placeholder="至少6位"
          placeholderTextColor={Colors.inkHint}
          secureTextEntry
        />

        {/* 错误提示 */}
        {error ? <Text style={styles.error}>{error}</Text> : null}

        {/* 提交 */}
        <Pressable
          style={[styles.submitBtn, loading && styles.submitBtnDisabled]}
          onPress={handleSubmit}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator size="small" color={Colors.bg} />
          ) : (
            <Text style={styles.submitBtnText}>
              {mode === 'login' ? '登录' : '注册'}
            </Text>
          )}
        </Pressable>

        {/* 切换模式 */}
        <Pressable
          style={styles.switchBtn}
          onPress={() => {
            clearError();
            setMode(mode === 'login' ? 'signup' : 'login');
          }}
        >
          <Text style={styles.switchText}>
            {mode === 'login' ? '没有账户？注册' : '已有账户？登录'}
          </Text>
        </Pressable>

        {/* 跳过 */}
        <Pressable style={styles.skipBtn} onPress={handleSkip}>
          <Text style={styles.skipText}>跳过，稍后注册</Text>
        </Pressable>
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
    paddingTop: 120,
    paddingBottom: Space['3xl'],
  },

  header: {
    marginBottom: Space['2xl'],
  },
  title: {
    fontSize: 48,
    color: Colors.ink,
    fontWeight: '200',
    letterSpacing: 12,
  },
  subtitle: {
    ...Type.body,
    color: Colors.inkTertiary,
    marginTop: Space.sm,
  },

  inputLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    marginBottom: Space.sm,
  },
  input: {
    ...Type.body,
    color: Colors.ink,
    backgroundColor: Colors.surface,
    borderRadius: 2,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
    marginBottom: Space.lg,
  },

  error: {
    ...Type.caption,
    color: Colors.warn,
    marginBottom: Space.lg,
  },

  submitBtn: {
    backgroundColor: Colors.ink,
    borderRadius: 2,
    paddingVertical: Space.md + 2,
    alignItems: 'center',
    marginBottom: Space.lg,
  },
  submitBtnDisabled: {
    opacity: 0.5,
  },
  submitBtnText: {
    ...Type.body,
    color: Colors.bg,
    fontWeight: '500',
    letterSpacing: 4,
  },

  switchBtn: {
    alignItems: 'center',
    paddingVertical: Space.md,
  },
  switchText: {
    ...Type.body,
    color: Colors.brand,
  },

  skipBtn: {
    alignItems: 'center',
    paddingVertical: Space.lg,
    marginTop: Space.xl,
  },
  skipText: {
    ...Type.caption,
    color: Colors.inkHint,
  },
});
