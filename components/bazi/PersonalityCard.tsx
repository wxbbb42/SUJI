/**
 * 人格洞察卡片组件
 * 
 * 展示 InsightEngine 生成的 PersonalityInsight 数据，
 * 包括核心特质、优势、挑战、沟通风格、职业倾向等。
 */

import React from 'react';
import { StyleSheet, View, Text, ScrollView } from 'react-native';
import FontAwesome from '@expo/vector-icons/FontAwesome';
import type { PersonalityInsight } from '@/lib/bazi/types';

interface PersonalityCardProps {
  insight: PersonalityInsight;
}

/** 特质标签颜色池 */
const TAG_COLORS = [
  '#8B4513', '#4CAF50', '#2196F3', '#E53935', '#C4A35A',
  '#9C27B0', '#FF9800', '#00BCD4', '#795548', '#607D8B',
];

export function PersonalityCard({ insight }: PersonalityCardProps) {
  return (
    <View style={styles.container}>
      {/* 核心特质 */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <FontAwesome name="star" size={14} color="#8B4513" />
          <Text style={styles.sectionTitle}>核心特质</Text>
        </View>
        <View style={styles.tagsRow}>
          {insight.coreTraits.map((trait, i) => (
            <View
              key={trait}
              style={[styles.tag, { backgroundColor: TAG_COLORS[i % TAG_COLORS.length] + '18' }]}
            >
              <Text style={[styles.tagText, { color: TAG_COLORS[i % TAG_COLORS.length] }]}>
                {trait}
              </Text>
            </View>
          ))}
        </View>
      </View>

      {/* 优势 */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <FontAwesome name="arrow-up" size={14} color="#4CAF50" />
          <Text style={styles.sectionTitle}>天赋优势</Text>
        </View>
        {insight.strengths.map((s) => (
          <View key={s} style={styles.listItem}>
            <Text style={styles.bullet}>●</Text>
            <Text style={styles.listText}>{s}</Text>
          </View>
        ))}
      </View>

      {/* 挑战 */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <FontAwesome name="exclamation-circle" size={14} color="#E53935" />
          <Text style={styles.sectionTitle}>成长课题</Text>
        </View>
        {insight.challenges.map((c) => (
          <View key={c} style={styles.listItem}>
            <Text style={[styles.bullet, { color: '#E53935' }]}>●</Text>
            <Text style={styles.listText}>{c}</Text>
          </View>
        ))}
      </View>

      {/* 沟通与情绪 */}
      <View style={styles.section}>
        <View style={styles.row}>
          <View style={styles.halfCard}>
            <FontAwesome name="comments" size={16} color="#2196F3" />
            <Text style={styles.halfTitle}>沟通风格</Text>
            <Text style={styles.halfText}>{insight.communicationStyle}</Text>
          </View>
          <View style={styles.halfCard}>
            <FontAwesome name="heart" size={16} color="#E53935" />
            <Text style={styles.halfTitle}>情绪模式</Text>
            <Text style={styles.halfText}>{insight.emotionalPattern}</Text>
          </View>
        </View>
      </View>

      {/* 职业倾向 */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <FontAwesome name="briefcase" size={14} color="#C4A35A" />
          <Text style={styles.sectionTitle}>职业倾向</Text>
        </View>
        <View style={styles.tagsRow}>
          {insight.careerAptitude.map((career) => (
            <View key={career} style={[styles.tag, styles.careerTag]}>
              <Text style={styles.careerTagText}>{career}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* 关系模式 */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <FontAwesome name="users" size={14} color="#9C27B0" />
          <Text style={styles.sectionTitle}>关系模式</Text>
        </View>
        <Text style={styles.description}>{insight.relationshipStyle}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFDF8',
    borderRadius: 16,
    padding: 20,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  section: {
    marginBottom: 20,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 2,
  },
  tagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  tagText: {
    fontSize: 13,
    fontWeight: '500',
  },
  careerTag: {
    backgroundColor: '#C4A35A18',
  },
  careerTagText: {
    fontSize: 13,
    color: '#8B6914',
    fontWeight: '500',
  },
  listItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    marginBottom: 6,
    paddingLeft: 4,
  },
  bullet: {
    fontSize: 8,
    color: '#4CAF50',
    marginRight: 8,
    marginTop: 5,
  },
  listText: {
    flex: 1,
    fontSize: 14,
    color: '#2C1810',
    lineHeight: 22,
  },
  row: {
    flexDirection: 'row',
    gap: 12,
  },
  halfCard: {
    flex: 1,
    backgroundColor: '#F5F0E8',
    borderRadius: 12,
    padding: 14,
    alignItems: 'center',
    gap: 6,
  },
  halfTitle: {
    fontSize: 12,
    color: '#8B7355',
    fontWeight: '600',
    letterSpacing: 1,
  },
  halfText: {
    fontSize: 13,
    color: '#2C1810',
    lineHeight: 20,
    textAlign: 'center',
  },
  description: {
    fontSize: 14,
    color: '#2C1810',
    lineHeight: 24,
    paddingLeft: 4,
  },
});
