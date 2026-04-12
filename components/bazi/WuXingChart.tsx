/**
 * WuXingChart — 五行花瓣图（重设计版）
 * 五角星形点阵布局（纯 View，无 SVG）
 * 圆点大小代表力量，用神/喜神标注在点外侧
 */
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import type { WuXingBalance, WuXing } from '@/lib/bazi';

// ── 五行色（偏水墨） ──────────────────────────────────────────────────
const WX_COLOR: Record<WuXing, string> = {
  金: '#B8943A',
  木: '#4A7A3A',
  水: '#3A5C8B',
  火: '#B84A3A',
  土: '#7A5A14',
};

// ── 排列顺序 & 角度（顶点起，顺时针，五角星形）
//   木(270°) → 火(342°) → 土(54°) → 金(126°) → 水(198°)
const ITEMS: { key: WuXing; field: keyof WuXingBalance; deg: number }[] = [
  { key: '木', field: 'mu',   deg: 270 },
  { key: '火', field: 'huo',  deg: 342 },
  { key: '土', field: 'tu',   deg: 54  },
  { key: '金', field: 'jin',  deg: 126 },
  { key: '水', field: 'shui', deg: 198 },
];

// ── 画布参数 ──────────────────────────────────────────────────────────
const CANVAS  = 240;   // 容器边长（px）
const C_XY    = CANVAS / 2;    // 中心点
const ORBIT   = 82;            // 轨道半径
const DOT_MAX = 60;
const DOT_MIN = 18;

function petalXY(deg: number) {
  const rad = (deg * Math.PI) / 180;
  return { x: C_XY + ORBIT * Math.cos(rad), y: C_XY + ORBIT * Math.sin(rad) };
}

// ── 标注相对于圆心的偏移方向（避免遮挡） ─────────────────────────────
// deg → 标注 anchor (相对于圆点中心的偏移，单位 px)
function tagOffset(deg: number, dotR: number): { dx: number; dy: number } {
  const rad = (deg * Math.PI) / 180;
  const dist = dotR + 6;
  return { dx: Math.round(dist * Math.cos(rad)), dy: Math.round(dist * Math.sin(rad)) };
}

// ── 色彩 ──────────────────────────────────────────────────────────────
const C = {
  faint: '#B8A898',
  mute:  '#8B7355',
};

interface WuXingChartProps {
  balance:  WuXingBalance;
  yongShen: WuXing;
  xiShen:   WuXing;
  jiShen?:  WuXing;
}

export default function WuXingChart({ balance, yongShen, xiShen, jiShen }: WuXingChartProps) {
  const vals   = ITEMS.map(e => balance[e.field]);
  const maxVal = Math.max(...vals, 1);

  const tagFor = (wx: WuXing): string | null => {
    if (wx === yongShen) return '用';
    if (wx === xiShen)   return '喜';
    if (wx === jiShen)   return '忌';
    return null;
  };

  return (
    <View style={styles.outer}>
      <Text style={styles.title}>五行</Text>

      {/* 花瓣点阵 — 绝对定位在固定画布内 */}
      <View style={styles.canvas}>
        {ITEMS.map(({ key, field, deg }) => {
          const val      = balance[field];
          const dotSize  = Math.round(DOT_MIN + (val / maxVal) * (DOT_MAX - DOT_MIN));
          const dotR     = dotSize / 2;
          const { x, y } = petalXY(deg);
          const color    = WX_COLOR[key];
          const tag      = tagFor(key);
          const { dx, dy } = tagOffset(deg, dotR);

          return (
            <React.Fragment key={key}>
              {/* 圆点 */}
              <View
                style={[
                  styles.dot,
                  {
                    width:           dotSize,
                    height:          dotSize,
                    borderRadius:    dotR,
                    backgroundColor: color + '1E',  // 12% alpha
                    borderColor:     color,
                    left:            x - dotR,
                    top:             y - dotR,
                  },
                ]}
              >
                <Text style={[styles.dotChi, { color, fontSize: Math.max(11, Math.round(dotSize * 0.38)) }]}>
                  {key}
                </Text>
              </View>

              {/* 用/喜/忌 标注（在圆外侧） */}
              {tag && (
                <View
                  style={[
                    styles.tagBox,
                    {
                      left: x + dx - 10,
                      top:  y + dy - 8,
                    },
                  ]}
                >
                  <Text style={[styles.tagText, { color }]}>{tag}</Text>
                </View>
              )}
            </React.Fragment>
          );
        })}
      </View>

      {/* 文字图例 */}
      <View style={styles.legend}>
        <LegendItem color={WX_COLOR[yongShen]} label={`用·${yongShen}`} />
        <LegendItem color={WX_COLOR[xiShen]}   label={`喜·${xiShen}`}   />
        {jiShen && <LegendItem color={C.faint} label={`忌·${jiShen}`} />}
      </View>
    </View>
  );
}

function LegendItem({ color, label }: { color: string; label: string }) {
  return (
    <View style={styles.legendItem}>
      <View style={[styles.legendDot, { backgroundColor: color }]} />
      <Text style={styles.legendLabel}>{label}</Text>
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  outer: {
    alignItems: 'center',
    paddingVertical: 8,
  },
  title: {
    fontSize: 11,
    color: C.faint,
    letterSpacing: 4,
    marginBottom: 16,
  },
  canvas: {
    width:    CANVAS,
    height:   CANVAS + 20,   // 额外20px 防止底部标注被裁掉
    position: 'relative',
  },
  dot: {
    position:        'absolute',
    borderWidth:     1,
    alignItems:      'center',
    justifyContent:  'center',
  },
  dotChi: {
    fontWeight: '400',
  },
  tagBox: {
    position:   'absolute',
    width:      20,
    height:     16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tagText: {
    fontSize:    9,
    fontWeight:  '500',
    letterSpacing: 0.5,
  },
  legend: {
    flexDirection: 'row',
    gap:           24,
    marginTop:     8,
  },
  legendItem: {
    flexDirection:  'row',
    alignItems:     'center',
    gap:            6,
  },
  legendDot: {
    width:        8,
    height:       8,
    borderRadius: 4,
  },
  legendLabel: {
    fontSize:     12,
    color:        C.mute,
    letterSpacing: 1,
  },
});
