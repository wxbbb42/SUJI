/**
 * MingPanCard — 四柱命盘（重设计版）
 * 天干大字 26px · 地支中字 18px · 藏干小字 11px
 * 铺在页面上，不包卡片容器；十神淡色文字，不用彩色背景标签
 */
import React, { useState } from 'react';
import { View, Text, StyleSheet, Pressable } from 'react-native';
import type { MingPan, WuXing, ZhuDetail } from '@/lib/bazi';

// ── 五行色（偏水墨，比原版更沉） ───────────────────────────────────────
const WX_COLOR: Record<WuXing, string> = {
  金: '#B8943A',
  木: '#4A7A3A',
  水: '#3A5C8B',
  火: '#B84A3A',
  土: '#7A5A14',
};

// ── 色彩系统 ───────────────────────────────────────────────────────────
const C = {
  deep:    '#2C1810',
  mid:     '#6B5040',
  mute:    '#8B7355',
  faint:   '#B8A898',
  surface: '#FFFBF5',
  brand:   '#8B4513',
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
    paddingVertical: 4,
  },

  // 四柱行
  pillarsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 32,
  },
  pillar: {
    flex: 1,
    alignItems: 'center',
    paddingHorizontal: 4,
    gap: 8,
  },
  pillarDay: {
    // 日柱仅靠间距和品牌色 label 区分，不加任何边框/背景
  },
  pillarLabel: {
    fontSize: 10,
    color: C.faint,
    letterSpacing: 1,
  },
  pillarLabelDay: {
    color: C.brand,
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
    fontSize: 10,
    color: C.mute,
    letterSpacing: 1,
    opacity: 0.75,
  },
  cangGan: {
    fontSize: 11,
    color: C.faint,
    letterSpacing: 2,
  },
  naYin: {
    fontSize: 9,
    color: C.faint,
    textAlign: 'center',
    lineHeight: 13,
  },

  // 日主 / 格局 / 神煞
  block: {
    marginBottom: 20,
  },
  blockLabel: {
    fontSize: 13,
    color: C.deep,
    fontWeight: '500',
    letterSpacing: 1,
    marginBottom: 6,
  },
  blockSuffix: {
    fontSize: 11,
    color: C.faint,
    fontWeight: '400',
  },
  blockBody: {
    fontSize: 13,
    color: C.mid,
    lineHeight: 22,
  },
  faintText: {
    fontSize: 12,
    color: C.faint,
  },
  shenShaToggle: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  shenShaList: {
    gap: 12,
  },
  shenShaRow: {
    gap: 3,
  },
  shenShaName: {
    fontSize: 13,
    color: C.deep,
    fontWeight: '500',
    letterSpacing: 1,
  },
  shenShaDesc: {
    fontSize: 12,
    color: C.mute,
    lineHeight: 18,
  },
  colorJi: {
    color: '#7A8B14',
  },
  colorXiong: {
    color: '#B84A3A',
  },
});
