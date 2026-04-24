/**
 * 首页时辰能量轴：横向滑动 + 自动居中当前时辰 + 点击展开详情
 * 仅在用户已配生辰（mingPanCache 存在）时渲染；否则返回 null
 */
import React, { useMemo, useState, useRef, useEffect } from 'react';
import { View, Text, FlatList, Dimensions, StyleSheet } from 'react-native';
import { Colors, Space, Type } from '@/lib/design/tokens';
import { useUserStore } from '@/lib/store/userStore';
import {
  SHICHEN_MAP, computeShichenVibe, currentShichenIndex,
  type ShichenEntry, type ShichenVibe, type MingPanSummary,
} from '@/lib/calendar/shichen';
import { ShichenCard } from './ShichenCard';
import { ShichenDetailSheet } from './ShichenDetailSheet';

const SCREEN_W = Dimensions.get('window').width;
const CARD_W_NORMAL = 110 + 8;   // 110 card + 8 marginRight
const CARD_W_ACTIVE = 130 + 8;

export function ShichenTimeline() {
  const { mingPanCache } = useUserStore();
  const mp = useMemo(() => parseMingPan(mingPanCache), [mingPanCache]);

  const [detailIdx, setDetailIdx] = useState<number | null>(null);
  const listRef = useRef<FlatList<ShichenEntry>>(null);
  const now = useMemo(() => new Date(), []);
  const currentIdx = currentShichenIndex(now);

  const vibes = useMemo<ShichenVibe[] | null>(
    () => mp ? SHICHEN_MAP.map(e => computeShichenVibe(e, mp, now)) : null,
    [mp, now],
  );

  useEffect(() => {
    if (!mp) return;
    const t = setTimeout(() => {
      const beforeWidth = currentIdx * CARD_W_NORMAL;
      const offset = beforeWidth - (SCREEN_W - CARD_W_ACTIVE) / 2;
      listRef.current?.scrollToOffset({ offset: Math.max(0, offset), animated: true });
    }, 300);
    return () => clearTimeout(t);
  }, [currentIdx, mp]);

  if (!mp || !vibes) return null;

  const detailEntry = detailIdx != null ? SHICHEN_MAP[detailIdx] : null;
  const detailVibe  = detailIdx != null ? vibes[detailIdx] : null;

  return (
    <View style={styles.container}>
      <Text style={styles.sectionTitle}>时辰能量</Text>

      <FlatList
        ref={listRef}
        data={SHICHEN_MAP}
        keyExtractor={e => e.zhi}
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        renderItem={({ item, index }) => (
          <ShichenCard
            entry={item}
            vibe={vibes[index]}
            active={index === currentIdx}
            onPress={() => setDetailIdx(index)}
          />
        )}
      />

      <ShichenDetailSheet
        visible={detailIdx != null}
        entry={detailEntry}
        vibe={detailVibe}
        mingPan={mp}
        onClose={() => setDetailIdx(null)}
      />
    </View>
  );
}

function parseMingPan(json: string | null): MingPanSummary | null {
  if (!json) return null;
  try {
    const p = JSON.parse(json);
    const ys = p.wuXingStrength?.yongShen;
    const xs = p.wuXingStrength?.xiShen;
    const js = p.wuXingStrength?.jiShen;
    if (!ys || !xs || !js) return null;
    return { yongShen: ys, xiShen: xs, jiShen: js };
  } catch {
    return null;
  }
}

const styles = StyleSheet.create({
  container: {
    marginTop: Space['2xl'],
  },
  sectionTitle: {
    ...Type.label,
    color: Colors.inkTertiary,
    letterSpacing: 2,
    marginBottom: Space.base,
    marginHorizontal: Space.lg,
  },
  listContent: {
    paddingHorizontal: Space.lg,
    paddingVertical: Space.xs,
  },
});
