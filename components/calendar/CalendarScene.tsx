/**
 * CalendarScene — 3D 场景（灯光 + 日历纸）
 */
import React from 'react';
import CalendarPage from './CalendarPage3D';

interface CalendarSceneProps {
  tearProgress: number;
}

export default function CalendarScene({ tearProgress }: CalendarSceneProps) {
  return (
    <>
      {/* 环境光 — 柔和基础照明 */}
      <ambientLight intensity={0.6} />

      {/* 主光源 — 从上方偏左打下来，模拟自然光 */}
      <directionalLight
        position={[2, 4, 3]}
        intensity={0.8}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
      />

      {/* 补光 — 从下方微弱补光，减少阴影过重 */}
      <directionalLight
        position={[-1, -2, 2]}
        intensity={0.2}
      />

      {/* 当前页（会被撕开） */}
      <CalendarPage
        tearProgress={tearProgress}
        position={[0, 0, 0.01]}
      />

      {/* 底下一页（撕开后露出） */}
      <CalendarPage
        tearProgress={0}
        position={[0, 0, 0]}
      />
    </>
  );
}
