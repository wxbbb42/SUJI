import { ALL_TEMPLATES, findTemplate, fillTemplate, deltaFromAnswer } from '../templates';
import type { BifurcatedYear } from '../types';

describe('templates index', () => {
  it('aggregates 12 templates with unique ids', () => {
    expect(ALL_TEMPLATES).toHaveLength(12);
    const ids = ALL_TEMPLATES.map(t => t.id);
    expect(new Set(ids).size).toBe(12);
  });

  it('findTemplate matches a 大运转七杀 vs 正官 vs 比肩 year', () => {
    const bif: BifurcatedYear = {
      year: 2014,
      ageAt: { before: 18, origin: 19, after: 20 },
      events: { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' },
      diversity: 3,
    };
    const tpl = findTemplate(bif);
    expect(tpl).not.toBeNull();
    expect(tpl!.id).toBe('qisha_role_shift');
  });

  it('returns null when fewer than 2 candidate events match the best template', () => {
    const bif: BifurcatedYear = {
      year: 2010,
      ageAt: { before: 15, origin: 15, after: 15 },
      events: { before: 'none', origin: '大运转七杀', after: 'none' },
      diversity: 2,
    };
    const tpl = findTemplate(bif);
    expect(tpl).toBeNull();
  });

  it('fillTemplate substitutes year and age', () => {
    const out = fillTemplate(ALL_TEMPLATES[0], 2014, 19);
    expect(out).toContain('2014');
    expect(out).toContain('19');
    expect(out).not.toContain('{');
  });

  it('deltaFromAnswer scores +1 for matching expected, -1 for opposite', () => {
    const tpl = ALL_TEMPLATES.find(t => t.id === 'qisha_role_shift')!;
    const events = { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' } as const;
    const d = deltaFromAnswer(tpl, events, 'yes');
    expect(d.before).toBe(1);
    expect(d.origin).toBe(-1);
    expect(d.after).toBe(-1);
  });

  it('deltaFromAnswer returns zeros for uncertain', () => {
    const tpl = ALL_TEMPLATES[0];
    const events = { before: '大运转七杀', origin: '大运转正官', after: '大运转比肩' } as const;
    const d = deltaFromAnswer(tpl, events, 'uncertain');
    expect(d).toEqual({ before: 0, origin: 0, after: 0 });
  });
});
