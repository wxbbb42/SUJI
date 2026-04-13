/**
 * 设置页面
 *
 * - BYOM 配置：Provider / API Key / 模型名 / 自定义 Base URL
 * - 个人信息：查看当前生辰/出生地，可重新输入
 * - 清除全部数据
 */

import React, { useState } from 'react';
import {
  View, Text, StyleSheet, Pressable, TextInput, ScrollView,
  Alert, Switch,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';

type Provider = 'openai' | 'deepseek' | 'anthropic' | 'custom';

const PROVIDERS: { id: Provider; label: string }[] = [
  { id: 'openai',    label: 'OpenAI' },
  { id: 'deepseek',  label: 'DeepSeek' },
  { id: 'anthropic', label: 'Anthropic' },
  { id: 'custom',    label: '自定义' },
];

const DEFAULT_MODELS: Record<Provider, string> = {
  openai:    'gpt-4o',
  deepseek:  'deepseek-chat',
  anthropic: 'claude-sonnet-4-20250514',
  custom:    '',
};

export default function SettingsScreen() {
  const router = useRouter();

  const {
    birthDate, gender, birthCity, birthLongitude,
    apiProvider, apiKey, apiModel, apiBaseUrl,
    setApiProvider, setApiKey, setApiModel, setApiBaseUrl,
    reset,
  } = useUserStore();

  // 本地编辑态（保存时写入 store）
  const [provider, setProvider] = useState<Provider>(apiProvider ?? 'openai');
  const [key,      setKey]      = useState(apiKey ?? '');
  const [model,    setModel]    = useState(
    apiModel ?? DEFAULT_MODELS[apiProvider ?? 'openai']
  );
  const [baseUrl,  setBaseUrl]  = useState(apiBaseUrl ?? '');
  const [showKey,  setShowKey]  = useState(false);

  const handleProviderChange = (p: Provider) => {
    setProvider(p);
    // 自动填充默认模型名
    if (!model || model === DEFAULT_MODELS[provider]) {
      setModel(DEFAULT_MODELS[p]);
    }
  };

  const handleSaveApi = () => {
    setApiProvider(provider);
    setApiKey(key.trim());
    setApiModel(model.trim() || DEFAULT_MODELS[provider]);
    if (provider === 'custom') setApiBaseUrl(baseUrl.trim());
    Alert.alert('已保存', 'API 配置已更新');
  };

  const handleClearAll = () => {
    Alert.alert(
      '清除所有数据',
      '将清除命盘、生辰信息和 API 配置。此操作不可撤销。',
      [
        { text: '取消', style: 'cancel' },
        {
          text: '确定清除',
          style: 'destructive',
          onPress: () => {
            reset();
            router.back();
          },
        },
      ],
    );
  };

  // 格式化生辰
  const birthInfo = (() => {
    if (!birthDate) return null;
    const d = new Date(birthDate);
    return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日  ${gender ?? ''}`;
  })();

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      keyboardShouldPersistTaps="handled"
    >
      {/* ── 标题行 ── */}
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12}>
          <Text style={styles.backText}>‹ 返回</Text>
        </Pressable>
        <Text style={styles.pageTitle}>设置</Text>
        <View style={{ width: 48 }} />
      </View>

      {/* ══ 个人信息 ══ */}
      <SectionHead title="个人信息" />

      {birthInfo ? (
        <View style={styles.infoBlock}>
          <Row label="生辰" value={birthInfo} />
          {birthCity ? (
            <Row
              label="出生地"
              value={`${birthCity}  东经 ${birthLongitude}°`}
            />
          ) : null}
        </View>
      ) : (
        <Text style={styles.emptyHint}>尚未输入生辰，请前往「我」页面输入。</Text>
      )}

      {/* ══ AI 配置 ══ */}
      <SectionHead title="AI 配置（BYOM）" />
      <Text style={styles.sectionDesc}>
        带上自己的模型密钥，岁吉将基于你的命盘与你深度对话。
      </Text>

      {/* Provider 选择 */}
      <Text style={styles.fieldLabel}>服务商</Text>
      <View style={styles.providerRow}>
        {PROVIDERS.map(p => (
          <Pressable
            key={p.id}
            style={[styles.providerBtn, provider === p.id && styles.providerBtnOn]}
            onPress={() => handleProviderChange(p.id)}
          >
            <Text style={[styles.providerText, provider === p.id && styles.providerTextOn]}>
              {p.label}
            </Text>
          </Pressable>
        ))}
      </View>

      {/* API Key */}
      <Text style={[styles.fieldLabel, { marginTop: Space.base }]}>API Key</Text>
      <View style={styles.keyRow}>
        <TextInput
          style={[styles.input, { flex: 1 }]}
          value={key}
          onChangeText={setKey}
          placeholder="sk-..."
          placeholderTextColor={Colors.inkHint}
          secureTextEntry={!showKey}
          autoCapitalize="none"
          autoCorrect={false}
        />
        <Pressable style={styles.eyeBtn} onPress={() => setShowKey(v => !v)}>
          <Text style={styles.eyeText}>{showKey ? '隐藏' : '显示'}</Text>
        </Pressable>
      </View>

      {/* 模型名 */}
      <Text style={[styles.fieldLabel, { marginTop: Space.base }]}>模型名称</Text>
      <TextInput
        style={styles.input}
        value={model}
        onChangeText={setModel}
        placeholder={DEFAULT_MODELS[provider]}
        placeholderTextColor={Colors.inkHint}
        autoCapitalize="none"
        autoCorrect={false}
      />

      {/* 自定义 Base URL（仅 custom） */}
      {provider === 'custom' && (
        <>
          <Text style={[styles.fieldLabel, { marginTop: Space.base }]}>Base URL</Text>
          <TextInput
            style={styles.input}
            value={baseUrl}
            onChangeText={setBaseUrl}
            placeholder="https://your-api-endpoint.com/v1"
            placeholderTextColor={Colors.inkHint}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
          />
        </>
      )}

      {/* 保存按钮 */}
      <Pressable style={styles.saveBtn} onPress={handleSaveApi}>
        <Text style={styles.saveBtnText}>保存配置</Text>
      </Pressable>

      {/* ══ 危险区域 ══ */}
      <SectionHead title="数据" />
      <Pressable style={styles.dangerBtn} onPress={handleClearAll}>
        <Text style={styles.dangerText}>清除所有数据</Text>
      </Pressable>

      <View style={{ height: Space['4xl'] }} />
    </ScrollView>
  );
}

// ── 小组件 ──

function SectionHead({ title }: { title: string }) {
  return (
    <View style={styles.sectionHead}>
      <Text style={styles.sectionTitle}>{title}</Text>
    </View>
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

// ── Styles ──

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.bg,
  },
  content: {
    paddingHorizontal: Space.lg,
    paddingBottom: Space['3xl'],
  },

  // 标题行
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: Space.xl,
    paddingBottom: Space.lg,
  },
  backText: {
    ...Type.body,
    color: Colors.brand,
    width: 48,
  },
  pageTitle: {
    ...Type.subtitle,
    color: Colors.ink,
    fontWeight: '300',
    letterSpacing: 4,
  },

  // 分区
  sectionHead: {
    paddingTop: Space['2xl'],
    paddingBottom: Space.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.inkHint + '40',
    marginBottom: Space.base,
  },
  sectionTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 3,
    textTransform: 'uppercase',
  },
  sectionDesc: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginBottom: Space.base,
  },

  // 个人信息
  infoBlock: {
    gap: Space.sm,
    marginBottom: Space.sm,
  },
  row: {
    flexDirection: 'row',
    paddingVertical: Space.sm,
  },
  rowLabel: {
    ...Type.body,
    color: Colors.inkTertiary,
    width: 56,
  },
  rowValue: {
    ...Type.body,
    color: Colors.ink,
    flex: 1,
  },
  emptyHint: {
    ...Type.caption,
    color: Colors.inkTertiary,
    marginBottom: Space.base,
  },

  // 表单
  fieldLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    marginBottom: Space.sm,
  },
  input: {
    backgroundColor: Colors.surface,
    borderRadius: 4,
    paddingHorizontal: Space.base,
    paddingVertical: Space.md,
    ...Type.body,
    color: Colors.ink,
  },
  keyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Space.sm,
  },
  eyeBtn: {
    paddingHorizontal: Space.md,
    paddingVertical: Space.md,
  },
  eyeText: {
    ...Type.caption,
    color: Colors.brand,
  },

  // Provider 选择
  providerRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Space.sm,
  },
  providerBtn: {
    paddingVertical: Space.sm,
    paddingHorizontal: Space.base,
    borderRadius: 4,
    backgroundColor: Colors.surface,
  },
  providerBtnOn: {
    backgroundColor: Colors.brand,
  },
  providerText: {
    ...Type.caption,
    color: Colors.inkSecondary,
  },
  providerTextOn: {
    color: Colors.float,
    fontWeight: '600',
  },

  // 保存
  saveBtn: {
    marginTop: Space.xl,
    alignSelf: 'flex-start',
    paddingVertical: Space.sm,
  },
  saveBtnText: {
    ...Type.body,
    color: Colors.brand,
    letterSpacing: 4,
    fontWeight: '500',
  },

  // 危险
  dangerBtn: {
    paddingVertical: Space.base,
  },
  dangerText: {
    ...Type.body,
    color: Colors.warn,
  },
});
