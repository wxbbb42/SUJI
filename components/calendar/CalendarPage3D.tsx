/**
 * CalendarPage3D — 单张日历纸 3D mesh
 * 实现纸张弯曲变形效果，通过 tearProgress 控制撕裂程度
 */
import React, { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber/native';
import * as THREE from 'three';

interface CalendarPageProps {
  tearProgress: number; // 0 = 平整, 1 = 完全撕开
  position?: [number, number, number];
  frontContent?: {
    ganZhi: string;
    fortune: string;
  };
}

// 纸张几何参数
const PAGE_WIDTH = 2.8;
const PAGE_HEIGHT = 3.6;
const SEGMENTS_X = 20;
const SEGMENTS_Y = 25;

export default function CalendarPage({ tearProgress, position = [0, 0, 0] }: CalendarPageProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const geometryRef = useRef<THREE.PlaneGeometry>(null);

  // 原始顶点位置（仅创建一次）
  const originalPositions = useMemo(() => {
    const geo = new THREE.PlaneGeometry(PAGE_WIDTH, PAGE_HEIGHT, SEGMENTS_X, SEGMENTS_Y);
    return new Float32Array(geo.attributes.position.array);
  }, []);

  // 每帧更新纸张变形
  useFrame(() => {
    if (!geometryRef.current) return;

    const positions = geometryRef.current.attributes.position;
    const count = positions.count;

    for (let i = 0; i < count; i++) {
      const origX = originalPositions[i * 3];
      const origY = originalPositions[i * 3 + 1];

      // 归一化坐标 (0-1)
      const nx = (origX + PAGE_WIDTH / 2) / PAGE_WIDTH;
      const ny = (origY + PAGE_HEIGHT / 2) / PAGE_HEIGHT;

      let x = origX;
      let y = origY;
      let z = 0;

      if (tearProgress > 0) {
        // 撕裂从右上角开始
        const tearOriginX = 1.0;
        const tearOriginY = 1.0;
        const dist = Math.sqrt(
          Math.pow(nx - tearOriginX, 2) + Math.pow(ny - tearOriginY, 2)
        );

        // 撕裂影响范围
        const tearRadius = tearProgress * 1.8;
        const influence = Math.max(0, 1 - dist / tearRadius);
        const smoothInfluence = influence * influence * (3 - 2 * influence); // smoothstep

        // 纸张卷曲效果
        const curlAmount = smoothInfluence * tearProgress;
        const curlAngle = curlAmount * Math.PI * 0.7;

        // 沿撕裂方向弯曲
        const bendAxis = curlAmount * 2.0;
        z += Math.sin(curlAngle + nx * 1.5) * curlAmount * 0.8;
        y += smoothInfluence * tearProgress * 1.5; // 向上翻
        x += smoothInfluence * tearProgress * 0.3; // 略向右

        // 添加细微褶皱
        if (curlAmount > 0.1) {
          const wrinkle = Math.sin(nx * 15 + ny * 10) * 0.02 * curlAmount;
          z += wrinkle;
        }
      }

      positions.setXYZ(i, x, y, z);
    }

    positions.needsUpdate = true;
    geometryRef.current.computeVertexNormals();
  });

  return (
    <mesh ref={meshRef} position={position} castShadow receiveShadow>
      <planeGeometry
        ref={geometryRef}
        args={[PAGE_WIDTH, PAGE_HEIGHT, SEGMENTS_X, SEGMENTS_Y]}
      />
      <meshStandardMaterial
        color="#FFFDF5"
        side={THREE.DoubleSide}
        roughness={0.85}
        metalness={0.0}
      />
    </mesh>
  );
}
