/**
 * 有时设计系统 Tokens
 *
 * Neo-Tactile Warmth — 新触感温暖
 *
 * 参考：Airbnb（大圆角+呼吸感）· 小宇宙（温暖触感）·
 *       Notion（排版优雅）· Teenager Engineer（碰撞色+拟物）
 *
 * iOS HIG 对齐：8pt grid · SF Pro · 标准导航模式
 */

import { Platform } from 'react-native';

// ═══════════════════════════════════════════════════
// § 颜色 — 暖中性色系 + 碰撞色点缀
// ═══════════════════════════════════════════════════

export const Colors = {
  // 表面色（暖纸张底色，不是冷灰白）
  bg:          '#FAF7F2',       // 宣纸色
  bgSecondary: '#F3EDE4',       // 稍深的暖底
  surface:     '#FFFFFF',       // 纯白卡片（和暖底形成对比）
  surfaceHover:'#F8F4EE',       // 卡片 hover/pressed

  // 墨色系（暖灰，不是纯黑灰）
  ink:           '#2C1810',     // 主文字（深棕墨）
  inkSecondary:  '#5C4A3E',     // 次要文字
  inkTertiary:   '#8C7B6E',     // 三级文字
  inkHint:       '#B8A99A',     // 提示/占位符

  // 碰撞色（点缀用，不铺满）
  vermilion:   '#D94F3A',       // 朱砂红 — 主强调
  celadon:     '#5BA68A',       // 青瓷绿 — 辅助强调
  amber:       '#E8A838',       // 琥珀黄 — 警示/高亮
  indigo:      '#4A6FA5',       // 靛蓝 — 信息/链接
  plum:        '#8B5E8B',       // 梅紫 — 特殊状态

  // 功能色
  brand:       '#D94F3A',       // 主品牌色 = 朱砂红
  brandMuted:  '#E8A89E',       // 品牌淡色
  brandBg:     '#FDF5F3',       // 品牌色背景
  success:     '#5BA68A',       // 成功 = 青瓷绿
  warn:        '#E8A838',       // 警告 = 琥珀黄
  error:       '#C83C2C',       // 错误

  // 分割线
  border:      '#E8E0D6',       // 普通分割线
  borderLight: '#F0EBE3',       // 轻分割线

  // overlay
  overlay:     'rgba(44, 24, 16, 0.4)',   // 遮罩
  overlayLight:'rgba(44, 24, 16, 0.15)',  // 轻遮罩

  // 五行色（用于命盘展示）
  wuxing: {
    木: '#5BA68A',   // 青瓷绿
    火: '#D94F3A',   // 朱砂红
    土: '#E8A838',   // 琥珀黄
    金: '#B8A99A',   // 暖银
    水: '#4A6FA5',   // 靛蓝
  },

  // 吉凶色
  good: '#5BA68A',
  bad: '#D94F3A',
} as const;

// ═══════════════════════════════════════════════════
// § 间距 — 8pt grid（带 4pt 微调）
// ═══════════════════════════════════════════════════

export const Space = {
  /** 2px — 极微间距 */  '2xs': 2,
  /** 4px — 微间距 */    xs:    4,
  /** 8px — 紧凑 */      sm:    8,
  /** 12px — 过渡 */     md:    12,
  /** 16px — 标准 */     base:  16,
  /** 20px — 舒适 */     lg:    20,
  /** 24px — 宽松 */     xl:    24,
  /** 32px — 段落间 */   '2xl': 32,
  /** 40px — 区块间 */   '3xl': 40,
  /** 48px — 大区块 */   '4xl': 48,
  /** 64px — 页面间 */   '5xl': 64,
  /** 80px — 特殊 */     '6xl': 80,
} as const;

// ═══════════════════════════════════════════════════
// § 圆角 — iOS 风格大圆角
// ═══════════════════════════════════════════════════

export const Radius = {
  /** 4px — 微圆角（标签、小按钮） */  xs:   4,
  /** 8px — 紧凑圆角（输入框） */      sm:   8,
  /** 12px — 标准圆角（卡片） */       md:   12,
  /** 16px — iOS 标准（大卡片） */     lg:   16,
  /** 20px — 突出圆角（弹窗） */       xl:   20,
  /** 24px — 大圆角（底部 sheet） */   '2xl': 24,
  /** 9999 — 全圆（按钮胶囊） */       full: 9999,
} as const;

// ═══════════════════════════════════════════════════
// § 字体 — SF Pro + Noto Serif CJK 混排
// ═══════════════════════════════════════════════════

const fontFamily = Platform.select({
  ios: 'System',                         // SF Pro
  android: 'Roboto',
  default: 'System',
});

const serifFamily = Platform.select({
  ios: 'Georgia',                        // iOS 内置衬线，替代 Noto Serif
  android: 'serif',
  default: 'Georgia',
});

export const Type = {
  // 大标题 — 衬线体，文化感
  heroDisplay: {
    fontFamily: serifFamily,
    fontSize: 56,
    lineHeight: 64,
    fontWeight: '300' as const,
    letterSpacing: -0.5,
  },
  // 页面标题
  title: {
    fontFamily: serifFamily,
    fontSize: 28,
    lineHeight: 36,
    fontWeight: '400' as const,
    letterSpacing: 0.2,
  },
  // 区块标题
  subtitle: {
    fontFamily: fontFamily,
    fontSize: 20,
    lineHeight: 28,
    fontWeight: '600' as const,
    letterSpacing: 0.15,
  },
  // 正文
  body: {
    fontFamily: fontFamily,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: '400' as const,
    letterSpacing: 0.1,
  },
  // 正文小号
  bodySmall: {
    fontFamily: fontFamily,
    fontSize: 14,
    lineHeight: 20,
    fontWeight: '400' as const,
    letterSpacing: 0.1,
  },
  // 标签 — 大写间距
  label: {
    fontFamily: fontFamily,
    fontSize: 12,
    lineHeight: 16,
    fontWeight: '500' as const,
    letterSpacing: 0.8,
  },
  // 说明文字
  caption: {
    fontFamily: fontFamily,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '400' as const,
    letterSpacing: 0.2,
  },
  // 数字 — tabular figures
  number: {
    fontFamily: fontFamily,
    fontSize: 16,
    lineHeight: 24,
    fontWeight: '500' as const,
    letterSpacing: 0,
    fontVariant: ['tabular-nums' as const],
  },
} as const;

// ═══════════════════════════════════════════════════
// § 阴影 — 微妙的 elevation，不是生硬 drop shadow
// ═══════════════════════════════════════════════════

export const Shadow = {
  // 轻微抬起（卡片默认）
  sm: Platform.select({
    ios: {
      shadowColor: '#2C1810',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.06,
      shadowRadius: 3,
    },
    android: { elevation: 1 },
    default: {},
  }),
  // 中等抬起（悬浮卡片、按压态）
  md: Platform.select({
    ios: {
      shadowColor: '#2C1810',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.08,
      shadowRadius: 12,
    },
    android: { elevation: 3 },
    default: {},
  }),
  // 高抬起（弹窗、底部 sheet）
  lg: Platform.select({
    ios: {
      shadowColor: '#2C1810',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.12,
      shadowRadius: 24,
    },
    android: { elevation: 8 },
    default: {},
  }),
} as const;

// ═══════════════════════════════════════════════════
// § 动画 — Spring-based，不是 linear
// ═══════════════════════════════════════════════════

export const Motion = {
  // 快速反馈（按钮 press）
  quick: { damping: 20, stiffness: 300, mass: 0.8 },
  // 标准过渡（页面切换）
  standard: { damping: 20, stiffness: 200, mass: 1 },
  // 柔和展开（展开/收起）
  gentle: { damping: 25, stiffness: 120, mass: 1 },
  // 弹性（有趣的弹跳）
  bouncy: { damping: 12, stiffness: 180, mass: 0.8 },

  // 时长参考（非 spring 场景）
  durationFast: 150,
  durationNormal: 250,
  durationSlow: 400,
} as const;

// ═══════════════════════════════════════════════════
// § 尺寸常量
// ═══════════════════════════════════════════════════

export const Size = {
  // 按钮高度
  buttonSm: 36,
  buttonMd: 44,       // iOS 最小触控区域
  buttonLg: 52,

  // 图标
  iconSm: 16,
  iconMd: 20,
  iconLg: 24,

  // Tab bar
  tabBarHeight: 83,   // iOS 标准（含 safe area）

  // Header
  headerHeight: 44,

  // 最大内容宽度
  maxContentWidth: 500,
} as const;
