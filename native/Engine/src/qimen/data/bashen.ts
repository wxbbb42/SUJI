import type { BashenInfo } from '../types';

export const BASHEN: Record<string, BashenInfo> = {
  值符: { name: '值符', jiXiong: '大吉', meaning: '八神之首、贵人',     application: '万事之主，求事看其落宫 → 大吉之兆' },
  腾蛇: { name: '腾蛇', jiXiong: '凶',   meaning: '怪异、虚惊',         application: '多疑、惊扰、虚假信息、噩梦' },
  太阴: { name: '太阴', jiXiong: '吉',   meaning: '阴贵之神',           application: '暗藏私事、女性、阴谋暗助' },
  六合: { name: '六合', jiXiong: '中吉', meaning: '和合、媒人',         application: '婚姻、合作、沟通、契约' },
  白虎: { name: '白虎', jiXiong: '凶',   meaning: '道路、刑伤',         application: '出行、争斗、官非、刑伤' },
  玄武: { name: '玄武', jiXiong: '凶',   meaning: '暗昧、盗贼',         application: '失物、暗算、欺骗、阴损' },
  九地: { name: '九地', jiXiong: '吉',   meaning: '安定、藏匿',         application: '求稳、暗助、积累、藏宝' },
  九天: { name: '九天', jiXiong: '吉',   meaning: '远方、高位',         application: '出行、扬名、上升、宣扬' },
};

/** 八神顺序（用于排神，阳遁顺布、阴遁逆布） */
export const BASHEN_ORDER: BashenInfo['name'][] = [
  '值符', '腾蛇', '太阴', '六合',
  '白虎', '玄武', '九地', '九天',
];
