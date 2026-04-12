/**
 * PersonalityCard — 人格洞察组件
 * 展示 PersonalityInsight：核心特质标签、优势/挑战列表、职业倾向
 */
import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import type { PersonalityInsight } from '@/lib/bazi';

interface PersonalityCardProps {
  insight: PersonalityInsight;
}

export default function PersonalityCard({ insight }: PersonalityCardProps) {
  const [expanded, setExpanded] = useState(false);

  const {
    coreTraits,
    strengths,
    challenges,
    communicationStyle,
    emotionalPattern,
    careerAptitude,
    relationshipStyle,
  } = insight;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>人格洞察</Text>

      {/* 核心特质标签 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>核心特质</Text>
        <View style={styles.tagsRow}>
          {coreTraits.map((t, i) => (
            <View key={i} style={styles.traitTag}>
              <Text style={styles.traitTagText}>{t}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* 优势 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>优势</Text>
        {strengths.map((s, i) => (
          <View key={i} style={styles.listItem}>
            <View style={styles.bulletPlus} />
            <Text style={styles.listText}>{s}</Text>
          </View>
        ))}
      </View>

      {/* 挑战 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>挑战</Text>
        {challenges.map((c, i) => (
          <View key={i} style={styles.listItem}>
            <View style={styles.bulletMinus} />
            <Text style={styles.listText}>{c}</Text>
          </View>
        ))}
      </View>

      {/* 职业倾向 */}
      <View style={styles.section}>
        <Text style={styles.sectionLabel}>职业倾向</Text>
        <View style={styles.tagsRow}>
          {careerAptitude.map((c, i) => (
            <View key={i} style={styles.careerTag}>
              <Text style={styles.careerTagText}>{c}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* 展开更多 */}
      <Pressable style={styles.expandBtn} onPress={() => setExpanded(v => !v)}>
        <Text style={styles.expandText}>{expanded ? '收起' : '查看更多'}</Text>
        <Text style={styles.expandArrow}>{expanded ? '▲' : '▼'}</Text>
      </Pressable>

      {expanded && (
        <View style={styles.expandedSection}>
          <DetailRow label="沟通风格" value={communicationStyle} />
          <DetailRow label="情绪模式" value={emotionalPattern} />
          <DetailRow label="关系模式" value={relationshipStyle} />
        </View>
      )}
    </View>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detailRow}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text style={styles.detailValue}>{value}</Text>
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
  title: {
    fontSize: 15,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 3,
    marginBottom: 16,
  },
  section: {
    marginBottom: 16,
  },
  sectionLabel: {
    fontSize: 12,
    color: '#B8A898',
    letterSpacing: 2,
    marginBottom: 8,
    fontWeight: '500',
  },

  // 特质标签
  tagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  traitTag: {
    backgroundColor: '#F5F0E8',
    borderRadius: 20,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  traitTagText: {
    fontSize: 12,
    color: '#6B5040',
    letterSpacing: 1,
  },

  // 列表项
  listItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 10,
    marginBottom: 8,
  },
  bulletPlus: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#4CAF50',
    marginTop: 5,
  },
  bulletMinus: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#E53935',
    marginTop: 5,
  },
  listText: {
    flex: 1,
    fontSize: 13,
    color: '#2C1810',
    lineHeight: 20,
  },

  // 职业标签
  careerTag: {
    backgroundColor: '#8B4513',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  careerTagText: {
    fontSize: 12,
    color: '#FFFDF8',
    letterSpacing: 1,
    fontWeight: '500',
  },

  // 展开按钮
  expandBtn: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 10,
    borderTopWidth: 0.5,
    borderTopColor: '#E5DDD0',
    marginTop: 4,
  },
  expandText: {
    fontSize: 13,
    color: '#8B7355',
    letterSpacing: 1,
  },
  expandArrow: {
    fontSize: 10,
    color: '#B8A898',
  },

  // 展开内容
  expandedSection: {
    marginTop: 12,
    gap: 12,
  },
  detailRow: {
    backgroundColor: '#F5F0E8',
    borderRadius: 10,
    padding: 12,
  },
  detailLabel: {
    fontSize: 11,
    color: '#B8A898',
    letterSpacing: 2,
    marginBottom: 4,
  },
  detailValue: {
    fontSize: 13,
    color: '#2C1810',
    lineHeight: 20,
  },
});
