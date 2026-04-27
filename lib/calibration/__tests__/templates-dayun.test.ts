import { DAYUN_TEMPLATES } from '../templates/dayun';

describe('DAYUN_TEMPLATES', () => {
  it('has 6 templates with unique ids', () => {
    expect(DAYUN_TEMPLATES).toHaveLength(6);
    const ids = DAYUN_TEMPLATES.map(t => t.id);
    expect(new Set(ids).size).toBe(6);
  });

  it('each template has rawQuestion containing {year} and {age}', () => {
    for (const t of DAYUN_TEMPLATES) {
      expect(t.rawQuestion).toMatch(/\{year\}/);
      expect(t.rawQuestion).toMatch(/\{age\}/);
    }
  });

  it('each template has at least 2 trigger events with non-irrelevant variants', () => {
    for (const t of DAYUN_TEMPLATES) {
      const meaningful = Object.values(t.variants).filter(v => v !== 'irrelevant');
      expect(meaningful.length).toBeGreaterThanOrEqual(2);
    }
  });
});
