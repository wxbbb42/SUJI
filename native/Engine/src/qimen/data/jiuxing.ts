import type { JiuxingInfo } from '../types';

export const JIUXING: Record<string, JiuxingInfo> = {
  天蓬: { name: '天蓬', wuXing: '水', jiXiong: '凶',   description: '盗、险' },
  天芮: { name: '天芮', wuXing: '土', jiXiong: '大凶', description: '病、损' },
  天冲: { name: '天冲', wuXing: '木', jiXiong: '中',   description: '战斗' },
  天辅: { name: '天辅', wuXing: '木', jiXiong: '大吉', description: '辅佐' },
  天禽: { name: '天禽', wuXing: '土', jiXiong: '大吉', description: '吉祥' },
  天心: { name: '天心', wuXing: '金', jiXiong: '大吉', description: '智慧、医药' },
  天柱: { name: '天柱', wuXing: '金', jiXiong: '凶',   description: '破坏' },
  天任: { name: '天任', wuXing: '土', jiXiong: '吉',   description: '稳重' },
  天英: { name: '天英', wuXing: '火', jiXiong: '中',   description: '学问' },
};

/** 九星地盘固定位置（用于起九星）：宫 ID → 该宫的固定地盘九星 */
export const JIUXING_DI_PAN_FIXED: Record<number, JiuxingInfo['name']> = {
  1: '天蓬',
  2: '天芮',
  3: '天冲',
  4: '天辅',
  5: '天禽',
  6: '天心',
  7: '天柱',
  8: '天任',
  9: '天英',
};
