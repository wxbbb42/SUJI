/**
 * 登录/注册页面
 *
 * Google + 邮箱
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useCallback } from 'react';
import {
  StyleSheet, View, Text, TextInput, Pressable, ScrollView,
  ActivityIndicator, KeyboardAvoidingView, Platform, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring, withTiming,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import { GoogleSignin, statusCodes } from '@react-native-google-signin/google-signin';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useAuthStore } from '@/lib/store/authStore';
import { supabase } from '@/lib/supabase/client';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

GoogleSignin.configure({
  webClientId: process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID,
  iosClientId: process.env.EXPO_PUBLIC_GOOGLE_IOS_CLIENT_ID,
});

export default function AuthScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { signInWithEmail, signUpWithEmail, loading, error, clearError } = useAuthStore();

  const [showEmail, setShowEmail] = useState(false);
  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  // ── Google（原生 SDK：iOS Credential Manager → id_token → Supabase signInWithIdToken） ──
  const handleGoogle = useCallback(async () => {
    try {
      await GoogleSignin.hasPlayServices();
      const response = await GoogleSignin.signIn();
      const idToken = response.data?.idToken;
      if (!idToken) throw new Error('未获取到 Google id_token');
      const { error } = await supabase.auth.signInWithIdToken({
        provider: 'google',
        token: idToken,
      });
      if (error) throw error;
      router.replace('/(tabs)');
    } catch (e: any) {
      if (e.code === statusCodes.SIGN_IN_CANCELLED) return;
      Alert.alert('登录失败', e.message || '请重试');
    }
  }, [router]);

  // ── 邮箱 ──
  const handleEmail = useCallback(async () => {
    clearError();
    if (!email.trim() || !password.trim()) return;
    if (mode === 'login') {
      await signInWithEmail(email.trim(), password);
    } else {
      await signUpWithEmail(email.trim(), password);
    }
    const { user } = useAuthStore.getState();
    if (user) router.replace('/(tabs)');
  }, [mode, email, password, signInWithEmail, signUpWithEmail, clearError, router]);

  // ── 跳过 ──
  const handleSkip = useCallback(() => {
    router.replace('/(tabs)');
  }, [router]);

  return (
    <KeyboardAvoidingView
      style={[styles.container, { paddingTop: insets.top }]}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + Space['3xl'] }]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        {/* 品牌区 */}
        <View style={styles.brandArea}>
          <Text style={styles.brandChar}>岁</Text>
          <Text style={styles.brandName}>有时</Text>
        </View>

        {/* 社交登录按钮 */}
        <View style={styles.socialArea}>
          <SocialButton
            icon="G"
            label="通过 Google 继续"
            onPress={handleGoogle}
          />

          {!showEmail ? (
            <SocialButton
              icon="✉"
              label="邮箱登录"
              onPress={() => setShowEmail(true)}
            />
          ) : (
            <View style={styles.emailCard}>
              {/* 登录/注册切换 */}
              <View style={styles.modeRow}>
                {(['login', 'signup'] as const).map(m => (
                  <Pressable
                    key={m}
                    onPress={() => { setMode(m); clearError(); }}
                    style={styles.modeBtn}
                  >
                    <Text style={[styles.modeText, mode === m && styles.modeTextActive]}>
                      {m === 'login' ? '登录' : '注册'}
                    </Text>
                    {mode === m && <View style={styles.modeIndicator} />}
                  </Pressable>
                ))}
              </View>

              <TextInput
                style={styles.input}
                value={email}
                onChangeText={setEmail}
                placeholder="邮箱地址"
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

              <TactileButton
                label={mode === 'login' ? '登录' : '注册'}
                onPress={handleEmail}
                loading={loading}
                color={Colors.vermilion}
              />
            </View>
          )}
        </View>

        {/* 分隔 */}
        <View style={styles.dividerRow}>
          <View style={styles.dividerLine} />
          <Text style={styles.dividerText}>或</Text>
          <View style={styles.dividerLine} />
        </View>

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

// ── 社交登录按钮 ──────────────────────────────────

function SocialButton({
  icon, label, onPress, dark, disabled,
}: {
  icon: string; label: string; onPress: () => void;
  dark?: boolean; disabled?: boolean;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      style={[
        styles.socialBtn,
        dark && styles.socialBtnDark,
        Shadow.sm,
        animStyle,
        disabled && { opacity: 0.5 },
      ]}
      onPress={onPress}
      onPressIn={() => { scale.value = withSpring(0.97, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
      disabled={disabled}
    >
      <Text style={[styles.socialIcon, dark && styles.socialIconDark]}>{icon}</Text>
      <Text style={[styles.socialLabel, dark && styles.socialLabelDark]}>{label}</Text>
    </AnimatedPressable>
  );
}

// ── 触感按钮 ──────────────────────────────────────

function TactileButton({
  label, onPress, loading, color,
}: {
  label: string; onPress: () => void; loading?: boolean; color: string;
}) {
  const scale = useSharedValue(1);
  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <AnimatedPressable
      style={[
        styles.tactileBtn,
        { backgroundColor: color },
        Shadow.md,
        animStyle,
      ]}
      onPress={onPress}
      onPressIn={() => { scale.value = withSpring(0.95, Motion.quick); }}
      onPressOut={() => { scale.value = withSpring(1, Motion.quick); }}
      disabled={loading}
    >
      {loading ? (
        <ActivityIndicator size="small" color="#FFF" />
      ) : (
        <Text style={styles.tactileBtnText}>{label}</Text>
      )}
    </AnimatedPressable>
  );
}

// ── Styles ────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingHorizontal: Space.xl,
  },

  // 品牌
  brandArea: {
    alignItems: 'center',
    paddingTop: Space['5xl'],
    paddingBottom: Space['3xl'],
  },
  brandChar: {
    fontFamily: 'Georgia',
    fontSize: 72,
    color: Colors.ink,
    fontWeight: '300',
  },
  brandName: {
    fontFamily: 'Georgia',
    fontSize: 20,
    color: Colors.ink,
    fontWeight: '400',
    letterSpacing: 10,
    marginTop: Space.sm,
  },

  // 社交登录
  socialArea: {
    gap: Space.md,
  },
  socialBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Space.md,
    height: Size.buttonLg,
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
  },
  socialBtnDark: {
    backgroundColor: Colors.ink,
  },
  socialIcon: {
    fontSize: 18,
    width: 24,
    textAlign: 'center',
  },
  socialIconDark: {
    color: '#FFFFFF',
  },
  socialLabel: {
    ...Type.body,
    color: Colors.ink,
    fontWeight: '500',
  },
  socialLabelDark: {
    color: '#FFFFFF',
  },

  // 邮箱表单
  emailCard: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    padding: Space.lg,
    gap: Space.md,
    ...Shadow.sm,
  },
  modeRow: {
    flexDirection: 'row',
    gap: Space.xl,
    justifyContent: 'center',
    marginBottom: Space.sm,
  },
  modeBtn: {
    alignItems: 'center',
    paddingBottom: Space.xs,
  },
  modeText: {
    ...Type.body,
    color: Colors.inkHint,
  },
  modeTextActive: {
    color: Colors.ink,
    fontWeight: '600',
  },
  modeIndicator: {
    width: 20,
    height: 2,
    backgroundColor: Colors.vermilion,
    borderRadius: 1,
    marginTop: Space.xs,
  },
  input: {
    ...Type.body,
    color: Colors.ink,
    backgroundColor: Colors.bgSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Space.base,
    height: Size.buttonMd,
  },
  error: {
    ...Type.caption,
    color: Colors.error,
  },

  // 触感按钮
  tactileBtn: {
    height: Size.buttonMd,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: Space.xs,
  },
  tactileBtnText: {
    ...Type.body,
    color: '#FFFFFF',
    fontWeight: '600',
    letterSpacing: 2,
  },

  // 分隔
  dividerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.md,
    marginVertical: Space['2xl'],
  },
  dividerLine: {
    flex: 1,
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.border,
  },
  dividerText: {
    ...Type.caption,
    color: Colors.inkHint,
  },

  // 跳过
  skipBtn: {
    alignItems: 'center',
    paddingVertical: Space.md,
  },
  skipText: {
    ...Type.body,
    color: Colors.inkTertiary,
  },

  // 免责
  disclaimer: {
    ...Type.label,
    color: Colors.inkHint,
    textAlign: 'center',
    marginTop: Space.xl,
  },
});
