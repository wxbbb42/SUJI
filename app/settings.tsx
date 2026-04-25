/**
 * 设置页面
 *
 * 分组卡片式布局（iOS Settings 风格）
 * Neo-Tactile Warmth 设计
 */

import React, { useState, useCallback } from 'react';
import {
  StyleSheet, View, Text, TextInput, Pressable, ScrollView, Alert,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, {
  useSharedValue, useAnimatedStyle, withSpring,
} from 'react-native-reanimated';
import { useRouter } from 'expo-router';
import Constants from 'expo-constants';
import { Colors, Space, Radius, Type, Shadow, Motion, Size } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { useAuthStore } from '@/lib/store/authStore';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

const PROVIDERS = [
  { id: 'openai',    label: 'OpenAI',    model: 'gpt-4o' },
  { id: 'deepseek',  label: 'DeepSeek',  model: 'deepseek-chat' },
  { id: 'anthropic', label: 'Anthropic', model: 'claude-sonnet-4-20250514' },
  { id: 'custom',    label: '自定义',     model: '' },
] as const;

export default function SettingsScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const store = useUserStore();
  const { user, signOut } = useAuthStore();

  const [provider, setProvider] = useState(store.apiProvider ?? 'openai');
  const [apiKey, setApiKey] = useState(store.apiKey ?? '');
  const [model, setModel] = useState(store.apiModel ?? '');
  const [baseUrl, setBaseUrl] = useState(store.apiBaseUrl ?? '');

  const defaultModel = PROVIDERS.find(p => p.id === provider)?.model ?? '';

  const handleSave = useCallback(() => {
    store.setApiProvider(provider as any);
    store.setApiKey(apiKey.trim());
    store.setApiModel(model.trim() || defaultModel);
    if (provider === 'custom' && baseUrl.trim()) {
      store.setApiBaseUrl(baseUrl.trim());
    }
    Alert.alert('已保存', 'AI 配置已更新');
  }, [provider, apiKey, model, baseUrl, defaultModel, store]);

  const handleReset = useCallback(() => {
    Alert.alert('清除所有数据', '将清除生辰、命盘、AI 配置等全部数据', [
      { text: '取消', style: 'cancel' },
      { text: '确定清除', style: 'destructive', onPress: () => { store.reset(); router.back(); } },
    ]);
  }, [store, router]);

  return (
    <ScrollView
      style={[styles.container, { paddingTop: insets.top }]}
      contentContainerStyle={[styles.scroll, { paddingBottom: insets.bottom + Space['3xl'] }]}
      showsVerticalScrollIndicator={false}
    >
      {/* 导航 */}
      <Pressable onPress={() => router.back()} style={styles.navBtn} hitSlop={12}>
        <Text style={styles.navText}>← 返回</Text>
      </Pressable>

      <Text style={styles.heading}>设置</Text>

      {/* ── 账户 ── */}
      <Text style={styles.groupTitle}>账户</Text>
      <View style={[styles.group, Shadow.sm]}>
        {user ? (
          <>
            <Row label="邮箱" value={user.email ?? '未设置'} />
            <View style={styles.rowDivider} />
            <Pressable style={styles.row} onPress={() => signOut()}>
              <Text style={[styles.rowLabel, { color: Colors.error }]}>退出登录</Text>
            </Pressable>
          </>
        ) : (
          <Pressable style={styles.row} onPress={() => router.push('/auth')}>
            <Text style={[styles.rowLabel, { color: Colors.vermilion }]}>登录 / 注册</Text>
            <Text style={styles.rowChevron}>›</Text>
          </Pressable>
        )}
      </View>

      {/* ── AI 模型 ── */}
      <Text style={styles.groupTitle}>AI 模型</Text>
      <View style={[styles.group, Shadow.sm]}>
        {/* Provider 选择 */}
        <View style={styles.providerRow}>
          {PROVIDERS.map(p => (
            <Pressable
              key={p.id}
              style={[styles.providerChip, provider === p.id && styles.providerChipActive]}
              onPress={() => { setProvider(p.id); setModel(''); }}
            >
              <Text style={[styles.providerText, provider === p.id && styles.providerTextActive]}>
                {p.label}
              </Text>
            </Pressable>
          ))}
        </View>

        <View style={styles.rowDivider} />

        {/* API Key */}
        <View style={styles.inputRow}>
          <Text style={styles.inputLabel}>API Key</Text>
          <TextInput
            style={styles.inputField}
            value={apiKey}
            onChangeText={setApiKey}
            placeholder="sk-..."
            placeholderTextColor={Colors.inkHint}
            secureTextEntry
            autoCapitalize="none"
          />
        </View>

        <View style={styles.rowDivider} />

        {/* Model */}
        <View style={styles.inputRow}>
          <Text style={styles.inputLabel}>模型</Text>
          <TextInput
            style={styles.inputField}
            value={model}
            onChangeText={setModel}
            placeholder={defaultModel}
            placeholderTextColor={Colors.inkHint}
            autoCapitalize="none"
          />
        </View>

        {provider === 'custom' && (
          <>
            <View style={styles.rowDivider} />
            <View style={styles.inputRow}>
              <Text style={styles.inputLabel}>Base URL</Text>
              <TextInput
                style={styles.inputField}
                value={baseUrl}
                onChangeText={setBaseUrl}
                placeholder="https://api.example.com/v1"
                placeholderTextColor={Colors.inkHint}
                autoCapitalize="none"
              />
            </View>
          </>
        )}

        <View style={styles.rowDivider} />

        <Pressable style={styles.row} onPress={handleSave}>
          <Text style={[styles.rowLabel, { color: Colors.vermilion, fontWeight: '500' }]}>
            保存配置
          </Text>
        </Pressable>
      </View>

      {/* ── 个人信息 ── */}
      <Text style={styles.groupTitle}>个人信息</Text>
      <View style={[styles.group, Shadow.sm]}>
        {store.birthDate ? (
          <>
            <Row label="生辰" value={new Date(store.birthDate).toLocaleString('zh-CN')} />
            <View style={styles.rowDivider} />
            <Row label="性别" value={store.gender ?? '未设置'} />
            <View style={styles.rowDivider} />
            <Row label="出生地" value={store.birthCity ?? '未设置'} />
          </>
        ) : (
          <View style={styles.row}>
            <Text style={styles.rowValue}>尚未输入生辰</Text>
          </View>
        )}
      </View>

      {/* ── 危险操作 ── */}
      <Text style={styles.groupTitle}> </Text>
      <View style={[styles.group, Shadow.sm]}>
        <Pressable style={styles.row} onPress={handleReset}>
          <Text style={[styles.rowLabel, { color: Colors.error }]}>清除所有数据</Text>
        </Pressable>
      </View>

      <Text style={styles.version}>
        岁吉 v{Constants.expoConfig?.version ?? '?'}
        {process.env.EXPO_PUBLIC_BUILD_SHA ? ` · ${process.env.EXPO_PUBLIC_BUILD_SHA}` : ' · dev'}
      </Text>
    </ScrollView>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.bg },
  scroll: { paddingHorizontal: Space.lg },

  navBtn: { paddingVertical: Space.md },
  navText: { ...Type.body, color: Colors.vermilion },

  heading: {
    fontFamily: 'Georgia',
    fontSize: 32,
    color: Colors.ink,
    fontWeight: '400',
    marginBottom: Space.xl,
  },

  // 分组
  groupTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    marginTop: Space.xl,
    marginBottom: Space.sm,
    paddingLeft: Space.sm,
  },
  group: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    overflow: 'hidden',
  },

  // 行
  row: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Space.md + 2,
    paddingHorizontal: Space.base,
    minHeight: Size.buttonMd,
  },
  rowLabel: {
    ...Type.body,
    color: Colors.ink,
  },
  rowValue: {
    ...Type.body,
    color: Colors.inkTertiary,
    textAlign: 'right',
    flex: 1,
    marginLeft: Space.lg,
  },
  rowChevron: {
    fontSize: 20,
    color: Colors.inkHint,
    marginLeft: Space.sm,
  },
  rowDivider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: Colors.borderLight,
    marginLeft: Space.base,
  },

  // Provider chips
  providerRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Space.sm,
    padding: Space.base,
  },
  providerChip: {
    paddingVertical: Space.sm,
    paddingHorizontal: Space.md,
    borderRadius: Radius.full,
    backgroundColor: Colors.bgSecondary,
  },
  providerChipActive: {
    backgroundColor: Colors.vermilion,
  },
  providerText: {
    ...Type.bodySmall,
    color: Colors.inkSecondary,
    fontWeight: '500',
  },
  providerTextActive: {
    color: '#FFFFFF',
  },

  // 输入行
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: Space.sm,
    paddingHorizontal: Space.base,
    minHeight: Size.buttonMd,
  },
  inputLabel: {
    ...Type.body,
    color: Colors.ink,
    width: 80,
  },
  inputField: {
    flex: 1,
    ...Type.body,
    color: Colors.ink,
    textAlign: 'right',
  },

  // 版本
  version: {
    ...Type.caption,
    color: Colors.inkHint,
    textAlign: 'center',
    marginTop: Space['2xl'],
  },
});
