import type { Trigram } from '../types';

export const TRIGRAMS: Record<string, Trigram> = {
  乾: { name: '乾', symbol: '☰', yao: ['阳','阳','阳'], wuXing: '金', nature: '天' },
  兑: { name: '兑', symbol: '☱', yao: ['阳','阳','阴'], wuXing: '金', nature: '泽' },
  离: { name: '离', symbol: '☲', yao: ['阳','阴','阳'], wuXing: '火', nature: '火' },
  震: { name: '震', symbol: '☳', yao: ['阳','阴','阴'], wuXing: '木', nature: '雷' },
  巽: { name: '巽', symbol: '☴', yao: ['阴','阳','阳'], wuXing: '木', nature: '风' },
  坎: { name: '坎', symbol: '☵', yao: ['阴','阳','阴'], wuXing: '水', nature: '水' },
  艮: { name: '艮', symbol: '☶', yao: ['阴','阴','阳'], wuXing: '土', nature: '山' },
  坤: { name: '坤', symbol: '☷', yao: ['阴','阴','阴'], wuXing: '土', nature: '地' },
};

/** 给定 3 爻数组（下→上），查找对应的 trigram name */
export function trigramFromYao(yao: ['阴'|'阳','阴'|'阳','阴'|'阳']): Trigram {
  for (const t of Object.values(TRIGRAMS)) {
    if (t.yao[0] === yao[0] && t.yao[1] === yao[1] && t.yao[2] === yao[2]) {
      return t;
    }
  }
  throw new Error(`unknown trigram: ${yao.join(',')}`);
}
