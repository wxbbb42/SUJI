import { ALL_TOOLS } from '../index';
import { validateToolArguments } from '../validation';

function check(name: string, args: unknown) {
  const definition = ALL_TOOLS.find(tool => tool.function.name === name)!;
  validateToolArguments(definition, args);
}

describe('bounded local tool contract', () => {
  it.each([
    { scope: 'liunian', yearRange: [1900, 2100] },
    { scope: 'liunian', yearRange: [2026, 2020] },
    { scope: 'liunian', yearRange: [2026.1, 2027] },
    { scope: 'liunian', yearRange: [2026] },
    { scope: 'current_dayun', yearRange: [2026, 2027] },
    { scope: 'liuyue', year: 2200 },
    { scope: 'liuyue', year: 2026.5 },
    { scope: 'liunian', yearRange: [2026, Infinity] },
  ])('rejects unbounded or contradictory timing input %j', args => {
    expect(() => check('get_timing', args)).toThrow();
  });

  it('allows supported bounded queries and default ranges', () => {
    expect(() => check('get_timing', { scope: 'liunian', yearRange: [2026, 2030] })).not.toThrow();
    expect(() => check('get_timing', { scope: 'liuyue', year: 2026 })).not.toThrow();
    expect(() => check('get_timing', { scope: 'current_dayun' })).not.toThrow();
    expect(() => check('get_today_context', {})).not.toThrow();
  });

  it('does not let a model pick coin values or inject chart settings', () => {
    expect(() => check('cast_liuyao', { question: '工作', lineValues: [9, 9, 9, 9, 9, 9] })).toThrow();
    expect(() => check('setup_qimen', { question: '迁居', juNumber: 1 })).toThrow();
    expect(() => check('get_domain', { domain: '财富', system: 'override' })).toThrow();
  });

  it.each(['', '  ', '问'.repeat(1601)])('rejects empty or oversized questions', question => {
    expect(() => check('cast_liuyao', { question })).toThrow();
    expect(() => check('setup_qimen', { question })).toThrow();
  });

  it.each(['cast_liuyao','setup_qimen'])('bounds explicit context and rejects invented identities: %s',name=>{
    expect(()=>check(name,{question:'问母亲',subject:'parent',event:'母亲近况',timeHorizon:'near'})).not.toThrow();
    expect(()=>check(name,{question:'问'.repeat(1600),subject:'self',event:'事'.repeat(200),timeHorizon:'far'})).not.toThrow();
    for(const args of [{subject:'boss'},{event:' '},{event:'事'.repeat(201)},{timeHorizon:'next-week'}])expect(()=>check(name,{question:'问事',...args})).toThrow();
  });

  it('requires plain object arguments and valid enums', () => {
    expect(() => check('get_today_context', [])).toThrow();
    expect(() => check('get_ziwei_palace', { palace: '不存在宫' })).toThrow();
    expect(() => check('cast_liuyao', { question: '计划', questionType: 'invented' })).toThrow();
  });
});
