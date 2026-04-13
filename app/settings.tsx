/**
 * 设置页面
 *
 * BYOM 模型配置 + 个人信息管理
 */

import { StyleSheet, View, Text, TextInput, Pressable, ScrollView, Alert } from 'react-native';
import { useState, useCallback } from 'react';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import { useAuthStore } from '@/lib/store/authStore';

const PROVIDERS = [
  { id: 'openai',    label: 'OpenAI',     defaultModel: 'gpt-4o' },
  { id: 'deepseek',  label: 'DeepSeek',   defaultModel: 'deepseek-chat' },
  { id: 'anthropic', label: 'Anthropic',  defaultModel: 'claude-sonnet-4-20250514' },
  { id: 'custom',    label: '自定义',     defaultModel: '' },
] as const;

export default function SettingsScreen() {
  const router = useRouter();
  const store = useUserStore();
  const { user, signOut } = useAuthStore();

  const [provider, setProvider] = useState(store.apiProvider ?? 'openai');
  const [apiKey, setApiKey] = useState(store.apiKey ?? '');
  const [model, setModel] = useState(store.apiModel ?? '');
  const [baseUrl, setBaseUrl] = useState(store.apiBaseUrl ?? '');

  const defaultModel = PROVIDERS.find(p => p.id === provider)?.defaultModel ?? '';

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
    Alert.alert('清除所有数据', '将清除生辰、命盘、AI 配置等所有数据', [
      { text: '取消', style: 'cancel' },
      {
        text: '确定',
        style: 'destructive',
        onPress: () => {
          store.reset();
          router.back();
        },
      },
    ]);
  }, [store, router]);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.scroll}>
      <Pressable onPress={() => router.back()} style={styles.backBtn}>
        <Text style={styles.backText}>← 返回</Text>
      </Pressable>

      <Text style={styles.heading}>设置</Text>

      {/* ── AI 模型配置 ── */}
      <Text style={styles.sectionTitle}>AI 模型</Text>
      <Text style={styles.sectionSub}>配置你的 AI 服务，用于问道对话</Text>

      {/* Provider 选择 */}
      <View style={styles.providerRow}>
        {PROVIDERS.map(p => (
          <Pressable
            key={p.id}
            style={styles.providerBtn}
            onPress={() => {
              setProvider(p.id);
              setModel('');
            }}
          >
            <Text style={[
              styles.providerText,
              provider === p.id && styles.providerTextOn,
            ]}>
              {p.label}
            </Text>
            {provider === p.id && <View style={styles.providerLine} />}
          </Pressable>
        ))}
      </View>

      {/* API Key */}
      <Text style={styles.inputLabel}>API Key</Text>
      <TextInput
        style={styles.input}
        value={apiKey}
        onChangeText={setApiKey}
        placeholder="sk-..."
        placeholderTextColor={Colors.inkHint}
        secureTextEntry
        autoCapitalize="none"
        autoCorrect={false}
      />

      {/* Model */}
      <Text style={styles.inputLabel}>模型</Text>
      <TextInput
        style={styles.input}
        value={model}
        onChangeText={setModel}
        placeholder={defaultModel || '模型名称'}
        placeholderTextColor={Colors.inkHint}
        autoCapitalize="none"
        autoCorrect={false}
      />

      {/* Custom Base URL */}
      {provider === 'custom' && (
        <>
          <Text style={styles.inputLabel}>Base URL</Text>
          <TextInput
            style={styles.input}
            value={baseUrl}
            onChangeText={setBaseUrl}
            placeholder="https://api.example.com/v1"
            placeholderTextColor={Colors.inkHint}
            autoCapitalize="none"
            autoCorrect={false}
          />
        </>
      )}

      <Pressable style={styles.saveBtn} onPress={handleSave}>
        <Text style={styles.saveBtnText}>保存配置</Text>
      </Pressable>

      {/* ── 账户 ── */}
      <Text style={[styles.sectionTitle, { marginTop: Space['2xl'] }]}>账户</Text>
      {user ? (
        <View style={styles.infoBlock}>
          <InfoRow label="邮箱" value={user.email ?? '未设置'} />
          <Pressable style={{ marginTop: Space.md }} onPress={() => signOut()}>
            <Text style={styles.dangerText}>退出登录</Text>
          </Pressable>
        </View>
      ) : (
        <Pressable
          style={styles.saveBtn}
          onPress={() => router.push('/auth')}
        >
          <Text style={styles.saveBtnText}>登录 / 注册</Text>
        </Pressable>
      )}

      {/* ── 个人信息 ── */}
      <Text style={[styles.sectionTitle, { marginTop: Space['2xl'] }]}>个人信息</Text>

      {store.birthDate ? (
        <View style={styles.infoBlock}>
          <InfoRow label="生辰" value={new Date(store.birthDate).toLocaleString('zh-CN')} />
          <InfoRow label="性别" value={store.gender ?? '未设置'} />
          <InfoRow label="出生地" value={store.birthCity ?? '未设置'} />
          <InfoRow
            label="经度"
            value={store.birthLongitude ? `${store.birthLongitude}°` : '未设置'}
          />
        </View>
      ) : (
        <Text style={styles.noInfo}>尚未输入生辰信息</Text>
      )}

      {/* ── 危险区 ── */}
      <View style={styles.dangerZone}>
        <Pressable onPress={handleReset}>
          <Text style={styles.dangerText}>清除所有数据</Text>
        </Pressable>
      </View>
    </ScrollView>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.infoRow}>
      <Text style={styles.infoLabel}>{label}</Text>
      <Text style={styles.infoValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  scroll: {
    paddingHorizontal: Space.lg,
    paddingBottom: Space['3xl'],
  },

  backBtn: {
    paddingTop: Space.xl,
    paddingBottom: Space.md,
  },
  backText: {
    ...Type.body,
    color: Colors.brand,
  },

  heading: {
    fontSize: 32,
    color: Colors.ink,
    fontWeight: '200',
    letterSpacing: 8,
    marginBottom: Space.xl,
  },

  sectionTitle: {
    ...Type.subtitle,
    color: Colors.ink,
    fontWeight: '400',
    marginBottom: Space.xs,
  },
  sectionSub: {
    ...Type.caption,
    color: Colors.inkHint,
    marginBottom: Space.lg,
  },

  // Provider
  providerRow: {
    flexDirection: 'row',
    gap: Space.lg,
    marginBottom: Space.xl,
  },
  providerBtn: {
    alignItems: 'center',
    paddingBottom: Space.xs,
  },
  providerText: {
    ...Type.body,
    color: Colors.inkHint,
  },
  providerTextOn: {
    color: Colors.ink,
    fontWeight: '500',
  },
  providerLine: {
    marginTop: Space.xs,
    height: 1,
    width: '100%',
    backgroundColor: Colors.brand,
  },

  // Input
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

  // Save
  saveBtn: {
    alignSelf: 'flex-start',
    paddingVertical: Space.md,
    paddingHorizontal: Space.xl,
    borderWidth: 1,
    borderColor: Colors.brand,
    borderRadius: 2,
  },
  saveBtnText: {
    ...Type.body,
    color: Colors.brand,
    fontWeight: '500',
  },

  // Info
  infoBlock: {
    gap: Space.md,
    marginTop: Space.sm,
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  infoLabel: {
    ...Type.caption,
    color: Colors.inkTertiary,
  },
  infoValue: {
    ...Type.body,
    color: Colors.inkSecondary,
  },
  noInfo: {
    ...Type.body,
    color: Colors.inkHint,
    marginTop: Space.sm,
  },

  // Danger
  dangerZone: {
    marginTop: Space['3xl'],
    paddingTop: Space.xl,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.inkHint + '30',
  },
  dangerText: {
    ...Type.body,
    color: Colors.warn,
  },
});
