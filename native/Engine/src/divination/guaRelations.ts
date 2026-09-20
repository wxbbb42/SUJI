import type { GuaInfo, HexagramLine } from './types';
import { ganZhiForGua } from './data/liuqin';
import { LINE_CONTEXT_SOURCE } from './lineContext';

const BRANCHES = '子丑寅卯辰巳午未申酉戌亥';
const SOURCE_ID = LINE_CONTEXT_SOURCE.id;

function branchRelation(a: string, b: string) {
  const i = BRANCHES.indexOf(a), j = BRANCHES.indexOf(b);
  return {combination:(i + j) % 12 === 1, clash:(i - j + 12) % 12 === 6, sameBranch:a === b};
}

function projection(gua: GuaInfo, side: 'original' | 'resulting') {
  const ganZhi = ganZhiForGua(gua);
  const pairs = [0,1,2].map(i => {
    const branches = [ganZhi[i][1], ganZhi[i+3][1]], relation = branchRelation(branches[0], branches[1]);
    return {positions:[i+1,i+4], relation:relation.combination ? '六合' : relation.clash ? '六冲' : 'neither'};
  });
  return {guaPath:side === 'original' ? '/benGua' : '/bianGua', ganZhi, pairs,
    kind:pairs.every(p => p.relation === '六合') ? '六合' : pairs.every(p => p.relation === '六冲') ? '六冲' : 'ordinary'};
}

/** Full resulting chart projection does not create line-level changed objects. */
export function guaRelations(benGua: GuaInfo, bianGua: GuaInfo, changingYao: number[]) {
  const original = projection(benGua, 'original'), resulting = projection(bianGua, 'resulting');
  const hasChange = changingYao.length > 0;
  return {assessmentStatus:'structural-only', outcomeEstablished:false, sourceId:SOURCE_ID,
    original, resulting, transition:{hasChange, fromKind:original.kind, toKind:resulting.kind,
      kind:!hasChange ? 'static' : original.kind !== 'ordinary' && resulting.kind !== 'ordinary' ? original.kind + '变' + resulting.kind : 'other-change',
      factPaths:['/changingYao','/guaRelations/original/kind','/guaRelations/resulting/kind']}};
}

/** Branch clash and element control are independent, including 酉→卯. */
export function returningBranch(line: HexagramLine) {
  if (!line.isChanging || !line.changed) return undefined;
  const relation = branchRelation(line.changed.ganZhi[1], line.ganZhi[1]);
  // Inherits the existing returning rule's from/to and condition pointers;
  // branch source remains separate from its five-element source.
  return {branchRelation:relation.combination ? '六合' : relation.clash ? '六冲' : relation.sameBranch ? '同支' : 'neither', branchSourceId:SOURCE_ID};
}
