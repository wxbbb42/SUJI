/**
 * PersonalityCard — 人格洞察（重设计版）
 * 散文式排版 · 核心特质大字 · 无彩色标签 · 无图标 · 无 bullet list
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { PersonalityInsight } from '@/lib/bazi/types';

// ── 色彩系统 ───────────────────────────────────────────────────────────
const C = {
  deep:  '#2C1810',
  mid:   '#6B5040',
  mute:  '#8B7355',
  faint: '#B8A898',
  brand: '#8B4513',
};

interface PersonalityCardProps {
  insight: PersonalityInsight;
}

export function PersonalityCard({ insight }: PersonalityCardProps) {
  return (
    <View style={styles.container}>
      {/* 核心特质 — 大字，奇偶行交替品牌色 */}
      <View style={styles.traitsRow}>
        {insight.coreTraits.map((trait, i) => (
          <Text key={trait} style={[styles.trait, i % 2 === 1 && styles.traitAccent]}>
            {trait}
          </Text>
        ))}
      </View>

      {/* 天赋优势 */}
      <Section label="天赋优势">
        <Text style={styles.prose}>{insight.strengths.join('。')}</Text>
      </Section>

      {/* 成长课题 */}
      <Section label="成长课题">
        <Text style={styles.prose}>{insight.challenges.join('。')}</Text>
      </Section>

      {/* 沟通与情绪 */}
      <Section label="沟通与情绪">
        <Text style={styles.prose}>
          {insight.communicationStyle}。{insight.emotionalPattern}
        </Text>
      </Section>

      {/* 职业倾向 */}
      <Section label="职业倾向">
        <Text style={styles.prose}>{insight.careerAptitude.join('、')}</Text>
      </Section>

      {/* 关系模式 */}
      <Section label="关系模式">
        <Text style={styles.prose}>{insight.relationshipStyle}</Text>
      </Section>
    </View>
  );
}

function Section({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.label}>{label}</Text>
      {children}
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    paddingVertical: 4,
  },
  // 核心特质大字
  traitsRow: {
    flexDirection:  'row',
    flexWrap:       'wrap',
    gap:            12,
    marginBottom:   32,
  },
  trait: {
    fontSize:    22,
    color:       C.deep,
    fontWeight:  '200',
    letterSpacing: 4,
  },
  traitAccent: {
    color: C.brand,
  },
  // 段落
  section: {
    marginBottom: 24,
  },
  label: {
    fontSize:    11,
    color:       C.faint,
    letterSpacing: 3,
    marginBottom:  8,
  },
  prose: {
    fontSize:    14,
    color:       C.mid,
    lineHeight:  26,
    letterSpacing: 0.5,
  },
});
