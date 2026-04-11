/**
 * TearCalendar — 完整的手撕黄历场景
 * 包含 3D Canvas + 手势控制 + 前景文字
 */
import React, { useState, useCallback, useRef } from 'react';
import { View, Text, StyleSheet, Dimensions, PanResponder, Animated } from 'react-native';
import { Canvas } from '@react-three/fiber/native';
import CalendarPage from './CalendarPage3D';
import CalendarScene from './CalendarScene';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// 撕裂需要拖动的距离（像素）
const TEAR_THRESHOLD = SCREEN_HEIGHT * 0.35;

interface TearCalendarProps {
  lunarDate: string;
  solarDate: string;
  ganZhi: string;
  fortune: string;
  fortuneSub: string;
  wisdom: string;
  onTearComplete?: () => void;
}

export default function TearCalendar({
  lunarDate,
  solarDate,
  ganZhi,
  fortune,
  fortuneSub,
  wisdom,
  onTearComplete,
}: TearCalendarProps) {
  const [tearProgress, setTearProgress] = useState(0);
  const [isTorn, setIsTorn] = useState(false);
  const dragStartY = useRef(0);
  const currentProgress = useRef(0);

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => !isTorn,
      onMoveShouldSetPanResponder: (_, gestureState) => {
        // 只响应向上拖动
        return !isTorn && gestureState.dy < -10;
      },
      onPanResponderGrant: (_, gestureState) => {
        dragStartY.current = gestureState.y0;
      },
      onPanResponderMove: (_, gestureState) => {
        if (isTorn) return;

        // 向上拖动 = 负 dy
        const dragDistance = Math.max(0, -gestureState.dy);
        const progress = Math.min(1, dragDistance / TEAR_THRESHOLD);

        currentProgress.current = progress;
        setTearProgress(progress);
      },
      onPanResponderRelease: () => {
        if (isTorn) return;

        if (currentProgress.current > 0.6) {
          // 超过阈值，完成撕裂
          setTearProgress(1);
          setIsTorn(true);
          onTearComplete?.();
        } else {
          // 没达到阈值，弹回
          setTearProgress(0);
          currentProgress.current = 0;
        }
      },
    })
  ).current;

  // 文字透明度随撕裂进度变化
  const textOpacity = isTorn ? 0 : 1 - tearProgress * 0.8;

  return (
    <View style={styles.container} {...panResponder.panHandlers}>
      {/* 3D 场景 */}
      <View style={styles.canvasContainer}>
        <Canvas
          camera={{ position: [0, 0, 5], fov: 50 }}
          style={styles.canvas}
        >
          <CalendarScene tearProgress={tearProgress} />
        </Canvas>
      </View>

      {/* 前景文字覆盖层 */}
      <View style={[styles.overlay, { opacity: textOpacity }]} pointerEvents="none">
        <Text style={styles.lunarDate}>{lunarDate}</Text>
        <Text style={styles.solarDate}>{solarDate}</Text>

        <View style={styles.mainContent}>
          <Text style={styles.ganZhi}>{ganZhi}</Text>
          <Text style={styles.fortune}>{fortune}</Text>
          <Text style={styles.fortuneSub}>{fortuneSub}</Text>
        </View>

        <Text style={styles.wisdom}>"{wisdom}"</Text>
      </View>

      {/* 撕裂提示 */}
      {!isTorn && tearProgress === 0 && (
        <View style={styles.hintContainer}>
          <Text style={styles.hint}>↑ 向上拖动撕开日历</Text>
        </View>
      )}

      {/* 撕裂后揭晓内容 */}
      {isTorn && (
        <View style={styles.revealContainer}>
          <Text style={styles.revealEmoji}>✨</Text>
          <Text style={styles.revealTitle}>今日已揭晓</Text>
          <Text style={styles.revealText}>
            {fortune}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F0E8',
  },
  canvasContainer: {
    ...StyleSheet.absoluteFillObject,
  },
  canvas: {
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 30,
  },
  lunarDate: {
    position: 'absolute',
    top: 60,
    fontSize: 16,
    color: '#8B7355',
    fontWeight: '300',
    letterSpacing: 4,
  },
  solarDate: {
    position: 'absolute',
    top: 84,
    fontSize: 13,
    color: '#B8A898',
    letterSpacing: 2,
  },
  mainContent: {
    alignItems: 'center',
  },
  ganZhi: {
    fontSize: 42,
    color: '#2C1810',
    fontWeight: '700',
    letterSpacing: 10,
    marginBottom: 24,
  },
  fortune: {
    fontSize: 18,
    color: '#6B8E23',
    fontWeight: '400',
    letterSpacing: 4,
    marginBottom: 8,
  },
  fortuneSub: {
    fontSize: 18,
    color: '#CD853F',
    fontWeight: '400',
    letterSpacing: 4,
  },
  wisdom: {
    position: 'absolute',
    bottom: 120,
    fontSize: 15,
    color: '#8B7355',
    fontWeight: '300',
    fontStyle: 'italic',
    textAlign: 'center',
    lineHeight: 24,
    letterSpacing: 1,
    paddingHorizontal: 40,
  },
  hintContainer: {
    position: 'absolute',
    bottom: 50,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  hint: {
    fontSize: 12,
    color: '#C8B8A8',
    letterSpacing: 2,
  },
  revealContainer: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(245, 240, 232, 0.95)',
  },
  revealEmoji: {
    fontSize: 48,
    marginBottom: 16,
  },
  revealTitle: {
    fontSize: 22,
    color: '#2C1810',
    fontWeight: '600',
    letterSpacing: 4,
    marginBottom: 12,
  },
  revealText: {
    fontSize: 16,
    color: '#8B7355',
    letterSpacing: 2,
  },
});
