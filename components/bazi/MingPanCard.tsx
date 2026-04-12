/**
 * MingPanCard — 四柱命盘展示组件
 * 竖排显示年月日时四柱（天干/地支/藏干/十神/纳音），
 * 附日主描述卡片、格局和神煞简要展示。
 */
import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable, ScrollView } from 'react-native';
import type { MingPan, WuXing, ZhuDetail } from '@/lib/bazi';

// ── 五行颜色（用于天干地支着色） ────────────────────────────────────
const WUXING_COLOR: Record<WuXing, string> = {
  金: '#C4A35A',
  木: '#4CAF50',
  水: '#2196F3',
  火: '#E53935',
  土: '#8B6914',
};

// ── 十神颜色（吉/凶区分） ────────────────────────────────────────────
const SHISHEN_COLOR: Record<string, string> = {
  比肩: '#8B7355', 劫财: '#CD853F',
  食神: '#4CAF50', 伤官: '#8BC34A',
  偏财: '#FF9800', 正财: '#FFC107',
  七杀: '#E53935', 正官: '#F44336',
  偏印: '#9C27B0', 正印: '#673AB7',
};

const PILLAR_LABELS = ['年柱', '月柱', '日柱', '时柱'];

interface MingPanCardProps {
  mingPan: MingPan;
}

export default function MingPanCard({ mingPan }: MingPanCardProps) {
  const { siZhu, riZhu, geJu, shenSha } = mingPan;
  const [showShenSha, setShowShenSha] = useState(false);

  const pillars = [siZhu.year, siZhu.month, siZhu.day, siZhu.hour];

  return (
    <View style={styles.container}>
      {/* 标题 */}
      <Text style={styles.title}>四柱八字</Text>
      <Text style={styles.subtitle}>{mingPan.lunarDate}</Text>

      {/* 四柱横排 */}
      <View style={styles.pillarsRow}>
        {pillars.map((pillar, i) => (
          <PillarColumn
            key={i}
            label={PILLAR_LABELS[i]}
            pillar={pillar}
            isDay={i === 2}
          />
        ))}
      </View>

      {/* 日主描述 */}
      <View style={styles.riZhuCard}>
        <View style={styles.riZhuHeader}>
          <View style={[styles.riZhuDot, { backgroundColor: WUXING_COLOR[riZhu.wuXing] }]} />
          <Text style={styles.riZhuTitle}>
            日主 · {riZhu.gan}（{riZhu.wuXing}·{riZhu.yinYang}）
          </Text>
        </View>
        <Text style={styles.riZhuDesc}>{riZhu.description}</Text>
      </View>

      {/* 格局 */}
      <View style={styles.geJuCard}>
        <View style={styles.geJuHeader}>
          <Text style={styles.geJuName}>{geJu.name}</Text>
          <View style={styles.geJuBadge}>
            <Text style={styles.geJuBadgeText}>{geJu.category} · {geJu.strength}等</Text>
          </View>
        </View>
        <Text style={styles.geJuModern}>{geJu.modernMeaning}</Text>
      </View>

      {/* 神煞折叠 */}
      {shenSha.length > 0 && (
        <View style={styles.shenShaSection}>
          <Pressable style={styles.shenShaToggle} onPress={() => setShowShenSha(v => !v)}>
            <Text style={styles.shenShaToggleText}>
              神煞（{shenSha.length}项）
            </Text>
            <Text style={styles.shenShaArrow}>{showShenSha ? '▲' : '▼'}</Text>
          </Pressable>

          {showShenSha && (
            <View style={styles.shenShaList}>
              {shenSha.map((ss, i) => (
                <View key={i} style={styles.shenShaItem}>
                  <View style={[
                    styles.shenShaDot,
                    { backgroundColor: ss.type === '吉' ? '#4CAF50' : ss.type === '凶' ? '#E53935' : '#B8A898' }
                  ]} />
                  <View style={styles.shenShaText}>
                    <Text style={styles.shenShaName}>{ss.name}</Text>
                    <Text style={styles.shenShaDesc}>{ss.modernMeaning || ss.description}</Text>
                  </View>
                  <Text style={styles.shenShaPos}>{ss.position}</Text>
                </View>
              ))}
            </View>
          )}
        </View>
      )}
    </View>
  );
}

// ── 单柱组件 ─────────────────────────────────────────────────────────
function PillarColumn({
  label,
  pillar,
  isDay,
}: {
  label: string;
  pillar: ZhuDetail;
  isDay: boolean;
}) {
  const { ganZhi, shiShen, cangGan } = pillar;
  const ganColor = WUXING_COLOR[ganZhi.ganWuXing];
  const zhiColor = WUXING_COLOR[ganZhi.zhiWuXing];
  const ssColor  = SHISHEN_COLOR[shiShen] ?? '#8B7355';

  // 藏干取前 2 个
  const topCangGan = cangGan.slice(0, 2);

  return (
    <View style={[styles.pillar, isDay && styles.pillarDay]}>
      {/* 柱位标签 */}
      <Text style={[styles.pillarLabel, isDay && styles.pillarLabelDay]}>{label}</Text>

      {/* 天干 */}
      <View style={[styles.ganBox, { borderColor: ganColor }]}>
        <Text style={[styles.ganText, { color: ganColor }]}>{ganZhi.gan}</Text>
      </View>

      {/* 地支 */}
      <View style={[styles.zhiBox, { borderColor: zhiColor }]}>
        <Text style={[styles.zhiText, { color: zhiColor }]}>{ganZhi.zhi}</Text>
      </View>

      {/* 十神 */}
      <View style={[styles.ssBox, { backgroundColor: ssColor + '22' }]}>
        <Text style={[styles.ssText, { color: ssColor }]}>{shiShen}</Text>
      </View>

      {/* 藏干 */}
      <View style={styles.cangGanBox}>
        {topCangGan.map((cg, i) => (
          <Text key={i} style={[styles.cangGanText, { color: WUXING_COLOR[cg.wuXing] }]}>
            {cg.gan}
          </Text>
        ))}
      </View>

      {/* 纳音 */}
      <Text style={styles.naYin} numberOfLines={2}>{ganZhi.naYin}</Text>
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
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 12,
    color: '#B8A898',
    letterSpacing: 2,
    marginBottom: 16,
  },

  // ── 四柱 ────────────────────────────────────────────────────────
  pillarsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 20,
  },
  pillar: {
    flex: 1,
    alignItems: 'center',
    marginHorizontal: 3,
    backgroundColor: '#F5F0E8',
    borderRadius: 12,
    paddingVertical: 12,
    paddingHorizontal: 4,
  },
  pillarDay: {
    backgroundColor: '#FFF8F0',
    borderWidth: 1,
    borderColor: '#E5C89A',
  },
  pillarLabel: {
    fontSize: 10,
    color: '#B8A898',
    letterSpacing: 1,
    marginBottom: 8,
  },
  pillarLabelDay: {
    color: '#8B4513',
    fontWeight: '600',
  },
  ganBox: {
    width: 34,
    height: 34,
    borderRadius: 17,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  ganText: {
    fontSize: 18,
    fontWeight: '700',
  },
  zhiBox: {
    width: 30,
    height: 30,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  zhiText: {
    fontSize: 16,
    fontWeight: '600',
  },
  ssBox: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    marginBottom: 6,
  },
  ssText: {
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 0.5,
  },
  cangGanBox: {
    flexDirection: 'row',
    gap: 2,
    marginBottom: 6,
  },
  cangGanText: {
    fontSize: 11,
    fontWeight: '500',
  },
  naYin: {
    fontSize: 9,
    color: '#B8A898',
    textAlign: 'center',
    lineHeight: 13,
  },

  // ── 日主卡片 ────────────────────────────────────────────────────
  riZhuCard: {
    backgroundColor: '#F5F0E8',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
  },
  riZhuHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 6,
    gap: 8,
  },
  riZhuDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  riZhuTitle: {
    fontSize: 13,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 1,
  },
  riZhuDesc: {
    fontSize: 13,
    color: '#6B5040',
    lineHeight: 20,
  },

  // ── 格局卡片 ────────────────────────────────────────────────────
  geJuCard: {
    backgroundColor: '#F5F0E8',
    borderRadius: 12,
    padding: 14,
    marginBottom: 12,
  },
  geJuHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 6,
  },
  geJuName: {
    fontSize: 15,
    color: '#8B4513',
    fontWeight: '700',
    letterSpacing: 2,
  },
  geJuBadge: {
    backgroundColor: '#E5DDD0',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  geJuBadgeText: {
    fontSize: 10,
    color: '#8B7355',
    letterSpacing: 1,
  },
  geJuModern: {
    fontSize: 13,
    color: '#6B5040',
    lineHeight: 20,
  },

  // ── 神煞 ────────────────────────────────────────────────────────
  shenShaSection: {
    borderRadius: 12,
    overflow: 'hidden',
    borderWidth: 0.5,
    borderColor: '#E5DDD0',
  },
  shenShaToggle: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 14,
    backgroundColor: '#F5F0E8',
  },
  shenShaToggleText: {
    fontSize: 13,
    color: '#8B7355',
    fontWeight: '500',
    letterSpacing: 1,
  },
  shenShaArrow: {
    fontSize: 11,
    color: '#B8A898',
  },
  shenShaList: {
    backgroundColor: '#FFFDF8',
    padding: 12,
    gap: 10,
  },
  shenShaItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
  },
  shenShaDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginTop: 4,
  },
  shenShaText: {
    flex: 1,
  },
  shenShaName: {
    fontSize: 13,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 1,
    marginBottom: 2,
  },
  shenShaDesc: {
    fontSize: 12,
    color: '#8B7355',
    lineHeight: 18,
  },
  shenShaPos: {
    fontSize: 11,
    color: '#B8A898',
    minWidth: 36,
    textAlign: 'right',
  },
});
