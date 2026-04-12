/**
 * 人格洞察
 * 
 * 设计：像读散文，不是看数据面板
 * 核心特质用大字排列，描述用段落
 * 无彩色标签、无bullet list
 */

import React from 'react';
import { StyleSheet, View, Text } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import type { PersonalityInsight } from '@/lib/bazi/types';

interface PersonalityCardProps {
  insight: PersonalityInsight;
}

export function PersonalityCard({ insight }: PersonalityCardProps) {
  return (
    <View style={styles.container}>
      {/* 核心特质 — 大字 */}
      <View style={styles.traitsRow}>
        {insight.coreTraits.map((trait) => (
          <Text key={trait} style={styles.trait}>{trait}</Text>
        ))}
      </View>

      {/* 优势 */}
      <Section title="天赋">
        <Text style={styles.paragraph}>
          {insight.strengths.join('。')}。
        </Text>
      </Section>

      {/* 挑战 */}
      <Section title="课题">
        <Text style={styles.paragraph}>
          {insight.challenges.join('。')}。
        </Text>
      </Section>

      {/* 沟通与情绪 */}
      <View style={styles.dualRow}>
        <View style={styles.dualItem}>
          <Text style={styles.dualLabel}>沟通</Text>
          <Text style={styles.dualText}>{insight.communicationStyle}</Text>
        </View>
        <View style={styles.dualItem}>
          <Text style={styles.dualLabel}>情绪</Text>
          <Text style={styles.dualText}>{insight.emotionalPattern}</Text>
        </View>
      </View>

      {/* 职业 */}
      <Section title="职业倾向">
        <Text style={styles.paragraph}>
          {insight.careerAptitude.join(' · ')}
        </Text>
      </Section>

      {/* 关系 */}
      <Section title="关系模式">
        <Text style={styles.paragraph}>{insight.relationshipStyle}</Text>
      </Section>
    </View>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: Space.base,
  },

  // 核心特质 — 横排大字
  traitsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Space.base,
    marginBottom: Space.xl,
  },
  trait: {
    ...Type.subtitle,
    color: Colors.ink,
    fontWeight: '300',
  },

  // 分区
  section: {
    marginBottom: Space.lg,
  },
  sectionTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    textTransform: 'uppercase',
    marginBottom: Space.sm,
  },
  paragraph: {
    ...Type.body,
    color: Colors.inkSecondary,
  },

  // 双栏
  dualRow: {
    flexDirection: 'row',
    gap: Space.lg,
    marginBottom: Space.lg,
  },
  dualItem: {
    flex: 1,
  },
  dualLabel: {
    ...Type.label,
    color: Colors.inkTertiary,
    marginBottom: Space.xs,
  },
  dualText: {
    ...Type.caption,
    color: Colors.inkSecondary,
  },
});
