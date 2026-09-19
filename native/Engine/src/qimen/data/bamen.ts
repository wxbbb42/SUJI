import type { BamenInfo } from '../types';

export const BAMEN: Record<string, BamenInfo> = {
  休门: { name: '休门', wuXing: '水', jiXiong: '吉',   description: '安息、求财、亲和' },
  生门: { name: '生门', wuXing: '土', jiXiong: '大吉', description: '求财、求事、生发' },
  伤门: { name: '伤门', wuXing: '木', jiXiong: '凶',   description: '受伤、损失' },
  杜门: { name: '杜门', wuXing: '木', jiXiong: '凶',   description: '闭塞、隐避' },
  景门: { name: '景门', wuXing: '火', jiXiong: '平',   description: '情报、文书' },
  死门: { name: '死门', wuXing: '土', jiXiong: '大凶', description: '死亡、终止' },
  惊门: { name: '惊门', wuXing: '金', jiXiong: '凶',   description: '惊讶、官非' },
  开门: { name: '开门', wuXing: '金', jiXiong: '大吉', description: '求事、开拓' },
};

/** 八门顺序（用于排门） */
export const BAMEN_ORDER: BamenInfo['name'][] = [
  '开门', '休门', '生门', '伤门',
  '杜门', '景门', '死门', '惊门',
];
