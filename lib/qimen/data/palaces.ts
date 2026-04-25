import type { Palace, TianGan } from '../types';

/** 9 宫基础信息（地盘干为默认起始位，setup 时会按局数重排） */
export const PALACES_BASE: Array<Pick<Palace, 'id' | 'name' | 'position' | 'wuXing' | 'diPanGan'>> = [
  { id: 1, name: '坎宫', position: '北',   wuXing: '水', diPanGan: '癸' },
  { id: 2, name: '坤宫', position: '西南', wuXing: '土', diPanGan: '己' },
  { id: 3, name: '震宫', position: '东',   wuXing: '木', diPanGan: '乙' },
  { id: 4, name: '巽宫', position: '东南', wuXing: '木', diPanGan: '辛' },
  { id: 5, name: '中宫', position: '中',   wuXing: '土', diPanGan: '戊' },
  { id: 6, name: '乾宫', position: '西北', wuXing: '金', diPanGan: '庚' },
  { id: 7, name: '兑宫', position: '西',   wuXing: '金', diPanGan: '丁' },
  { id: 8, name: '艮宫', position: '东北', wuXing: '土', diPanGan: '丙' },
  { id: 9, name: '离宫', position: '南',   wuXing: '火', diPanGan: '壬' },
];
