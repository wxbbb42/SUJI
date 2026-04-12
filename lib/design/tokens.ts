/**
 * 岁吉 · 设计系统
 * 
 * 审美方向：侘寂 × 宋代美学 × 现代极简
 * 核心：文字即界面、留白呼吸、克制装饰
 */

// ═══════════════════════════════════
// 色彩系统
// ═══════════════════════════════════
// 所有灰色微偏暖（向品牌色 #8B4513 倾斜）

export const Colors = {
  // 三层底面系统
  bg: '#F5EDE0',        // 底层 — 宣纸
  surface: '#FFFBF5',   // 面层 — 卡纸
  float: '#FFFFFF',      // 浮层 — 白

  // 品牌色
  brand: '#8B4513',      // 檀木棕
  brandLight: '#A0623A', // 品牌浅
  brandMuted: '#C4A078', // 品牌哑光

  // 文字层次
  ink: '#2C1810',        // 墨 — 正文
  inkSecondary: '#6B5C52', // 次墨 — 辅助文字
  inkTertiary: '#9E9089',  // 淡墨 — 三级文字
  inkHint: '#C4B8AE',      // 痕 — placeholder / hint

  // 五行色
  wuxing: {
    jin: '#B8964A',   // 金 — 暗金
    mu: '#5B8C5A',    // 木 — 苍绿
    shui: '#4A7B8C',  // 水 — 深青
    huo: '#C25B3A',   // 火 — 赭红
    tu: '#8B7355',    // 土 — 赭黄
  },

  // 语义色
  good: '#5B8C5A',
  caution: '#B8964A',
  warn: '#C25B3A',
} as const;

// ═══════════════════════════════════
// 间距系统 (4pt base)
// ═══════════════════════════════════

export const Space = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 24,
  xl: 32,
  '2xl': 48,
  '3xl': 64,
  '4xl': 96,
} as const;

// ═══════════════════════════════════
// 字号系统 (modular scale ~1.33)
// ═══════════════════════════════════

export const Type = {
  // 展示
  display: { fontSize: 36, lineHeight: 44, letterSpacing: 2 },
  // 标题
  title: { fontSize: 24, lineHeight: 32, letterSpacing: 1.5 },
  // 子标题
  subtitle: { fontSize: 18, lineHeight: 26, letterSpacing: 1 },
  // 正文
  body: { fontSize: 15, lineHeight: 24, letterSpacing: 0.3 },
  // 辅助
  caption: { fontSize: 13, lineHeight: 20, letterSpacing: 0.2 },
  // 标注
  label: { fontSize: 11, lineHeight: 16, letterSpacing: 0.5 },
} as const;
