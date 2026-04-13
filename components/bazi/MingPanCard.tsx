/**
 * MingPanCard — 四柱命盘（重设计版）
 * 天干大字 26px · 地支中字 18px · 藏干小字 11px
 * 铺在页面上，不包卡片容器；十神淡色文字，不用彩色背景标签
 */
import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import type { MingPan, WuXing, ZhuDetail } from '@/lib/bazi';

import { Colors, Space, Type } from '@/lib/design/tokens';

// ── 五行色 ───────────────────────────────────────────────────────────
const WX_COLOR: Record<WuXing, string> = {
  金: Colors.wuxing.金,
  木: Colors.wuxing.木,
  水: Colors.wuxing.水,
  火: Colors.wuxing.火,
  土: Colors.wuxing.土,
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
      {/* 四柱 */}
      <View style={styles.pillarsRow}>
        {pillars.map((p, i) => (
          <PillarCol key={i} label={PILLAR_LABELS[i]} pillar={p} isDay={i === 2} />
        ))}
      </View>

      {/* 日主 */}
      <View style={styles.block}>
        <Text style={styles.blockLabel}>
          日主 · {riZhu.gan}
          <Text style={styles.blockSuffix}>（{riZhu.wuXing} {riZhu.yinYang}）</Text>
        </Text>
        <Text style={styles.blockBody}>{riZhu.description}</Text>
      </View>

      {/* 格局 */}
      <View style={styles.block}>
        <Text style={styles.blockLabel}>
          {geJu.name}
          <Text style={styles.blockSuffix}>  {geJu.category} · {geJu.strength}等</Text>
        </Text>
        <Text style={styles.blockBody}>{geJu.modernMeaning}</Text>
      </View>

      {/* 神煞折叠 */}
      {shenSha.length > 0 && (
        <View style={styles.block}>
          <Pressable style={styles.shenShaToggle} onPress={() => setShowShenSha(v => !v)}>
            <Text style={styles.blockLabel}>
              神煞
              <Text style={styles.faintText}>  {shenSha.length} 项</Text>
            </Text>
            <Text style={styles.faintText}>{showShenSha ? '收起' : '展开'}</Text>
          </Pressable>

          {showShenSha && (
            <View style={styles.shenShaList}>
              {shenSha.map((ss, i) => (
                <View key={i} style={styles.shenShaRow}>
                  <Text style={[
                    styles.shenShaName,
                    ss.type === '吉' ? styles.colorJi : ss.type === '凶' ? styles.colorXiong : null,
                  ]}>
                    {ss.name}
                  </Text>
                  <Text style={styles.shenShaDesc}>{ss.modernMeaning || ss.description}</Text>
                </View>
              ))}
            </View>
          )}
        </View>
      )}
    </View>
  );
}

// ── 单柱 ─────────────────────────────────────────────────────────────
function PillarCol({
  label, pillar, isDay,
}: { label: string; pillar: ZhuDetail; isDay: boolean }) {
  const { ganZhi, shiShen, cangGan } = pillar;
  const ganColor = WX_COLOR[ganZhi.ganWuXing];
  const zhiColor = WX_COLOR[ganZhi.zhiWuXing];

  return (
    <View style={[styles.pillar, isDay && styles.pillarDay]}>
      <Text style={[styles.pillarLabel, isDay && styles.pillarLabelDay]}>{label}</Text>
      {/* 天干 — 最大 */}
      <Text style={[styles.gan, { color: ganColor }]}>{ganZhi.gan}</Text>
      {/* 地支 — 中 */}
      <Text style={[styles.zhi, { color: zhiColor }]}>{ganZhi.zhi}</Text>
      {/* 十神 — 淡文字，不加彩色背景 */}
      <Text style={styles.shiShen}>{shiShen}</Text>
      {/* 藏干 — 小 */}
      <Text style={styles.cangGan}>
        {cangGan.slice(0, 2).map(cg => cg.gan).join(' ')}
      </Text>
      {/* 纳音 — 最小 */}
      <Text style={styles.naYin} numberOfLines={2}>{ganZhi.naYin}</Text>
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  container: {
    paddingVertical: Space.xs,
  },

  // 四柱行
  pillarsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: Space.xl,
  },
  pillar: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: Space.xs,
    gap: Space.sm,
  },
  pillarDay: {
    // 日柱仅靠间距和品牌色 label 区分，不加任何边框/背景
  },
  pillarLabel: {
    ...Type.label,
    color: Colors.inkHint,
  },
  pillarLabelDay: {
    color: Colors.brand,
  },
  // 字号比例：天干26 / 地支18 / 十神10 ≈ 2.6 : 1.8 : 1
  gan: {
    fontSize: 26,
    fontWeight: '600',
    lineHeight: 30,
  },
  zhi: {
    fontSize: 18,
    fontWeight: '400',
    lineHeight: 22,
  },
  shiShen: {
    ...Type.label,
    color: Colors.inkTertiary,
    opacity: 0.75,
  },
  cangGan: {
    ...Type.label,
    color: Colors.inkHint,
    letterSpacing: 2,
  },
  naYin: {
    fontSize: 9,
    color: Colors.inkHint,
    textAlign: 'center',
    lineHeight: 13,
  },

  // 日主 / 格局 / 神煞
  block: {
    marginBottom: Space.lg,
  },
  blockLabel: {
    ...Type.caption,
    color: Colors.ink,
    fontWeight: '500',
    letterSpacing: 1,
    marginBottom: Space.xs,
  },
  blockSuffix: {
    ...Type.label,
    color: Colors.inkHint,
    fontWeight: '400',
  },
  blockBody: {
    ...Type.caption,
    color: Colors.inkSecondary,
    lineHeight: 22,
  },
  faintText: {
    ...Type.caption,
    color: Colors.inkHint,
  },
  shenShaToggle: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Space.sm,
  },
  shenShaList: {
    gap: Space.md,
  },
  shenShaRow: {
    gap: Space.xs,
  },
  shenShaName: {
    ...Type.caption,
    color: Colors.ink,
    fontWeight: '500',
    letterSpacing: 1,
  },
  shenShaDesc: {
    ...Type.label,
    color: Colors.inkTertiary,
    lineHeight: 18,
  },
  colorJi: {
    color: Colors.good,
  },
  colorXiong: {
    color: Colors.warn,
  },
});
