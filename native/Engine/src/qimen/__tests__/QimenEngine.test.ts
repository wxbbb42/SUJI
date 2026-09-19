import { QimenEngine } from '../QimenEngine';

describe('QimenEngine setup', () => {
  const engine = new QimenEngine();

  it('returns a valid QimenChart with required fields', () => {
    const r = engine.setup({
      question: '我要不要换城市',
      questionType: 'event',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.palaces).toHaveLength(9);
    expect(r.yinYangDun).toMatch(/^[阳阴]$/);
    expect(r.juNumber).toBeGreaterThanOrEqual(1);
    expect(r.juNumber).toBeLessThanOrEqual(9);
    expect(['上','中','下']).toContain(r.yuan);
    expect(r.jieqi).toBeTruthy();
  });

  it('每个外宫（非中宫）都有 8 门 / 9 星 / 8 神', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    for (const p of r.palaces) {
      if (p.id === 5) continue; // 中宫无门
      expect(p.bamen).not.toBeNull();
      expect(p.jiuxing).not.toBeNull();
      expect(p.bashen).not.toBeNull();
    }
  });

  it('八门 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const mens = r.palaces.filter(p => p.id !== 5).map(p => p.bamen);
    expect(new Set(mens).size).toBe(8);
  });

  it('八神 8 个不重复（中宫除外）', () => {
    const r = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const shens = r.palaces.filter(p => p.id !== 5).map(p => p.bashen);
    expect(new Set(shens).size).toBe(8);
  });

  it('returns deterministic chart for same input', () => {
    const a = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    const b = engine.setup({
      question: 'test', questionType: 'general',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(a.juNumber).toBe(b.juNumber);
    expect(a.yinYangDun).toBe(b.yinYangDun);
  });
});

describe('QimenEngine yongShen selection', () => {
  const engine = new QimenEngine();

  it('career references the asker and career door, not an invented fixed 庚 officer', () => {
    const r = engine.setup({
      question: '我会得到这个 offer 吗',
      questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yongShen.type).toBe('己');
    expect(r.yongShen.references?.some(v=>v.label==='开门')).toBe(true);
    expect(r.yongShen.selectionStatus).toBe('initial-reference');
  });

  it('yongShen has palaceId, state, summary', () => {
    const r = engine.setup({
      question: 'test', questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yongShen.palaceId).toBeGreaterThanOrEqual(1);
    expect(r.yongShen.palaceId).toBeLessThanOrEqual(9);
    expect(['旺', '相', '休', '囚', '死', '不上卦']).toContain(r.yongShen.state);
    expect(r.yongShen.interactions[0]).toMatch(/^宫位五行判/);
    expect(r.yongShen.summary).toBeTruthy();
  });

  it('甲日求问者按甲子遁戊定位，仍保留原日干甲', () => {
    // lunar-javascript independent oracle: 2026-04-20 is 甲子日。
    const r = engine.setup({question:'事业',questionType:'career',setupTime:new Date('2026-04-20T15:32:00+08:00')});
    expect(r.dayGanZhi).toBe('甲子');
    expect(r.yongShen.type).toBe('甲');
    const carrier = r.palaces.find(p=>p.id!==5&&(p.tianPanGan==='戊'||p.hostedTianPanGan==='戊'))!;
    expect(r.yongShen.palaceId).toBe(carrier.id);
    expect(r.yongShen.references).toContainEqual({label:'求问者（日干甲）',palaceId:carrier.id});
  });

  it('事件与关系保留不同参考角色，不根据性别预设固定庚乙伴侣', () => {
    const setupTime=new Date('2026-04-25T15:32:00+08:00');
    const event=engine.setup({question:'出行',questionType:'event',setupTime});
    expect(event.yongShen.type).toBe('壬');
    const male=engine.setup({question:'关系',questionType:'marriage',gender:'男',setupTime});
    const female=engine.setup({question:'关系',questionType:'marriage',gender:'女',setupTime});
    expect(male.yongShen.type).toBe('己');
    expect(female.yongShen).toEqual(male.yongShen);
    const harmony=male.palaces.find(p=>p.bashen==='六合')!;
    expect(male.yongShen.references).toContainEqual({label:'六合',palaceId:harmony.id});
  });

  it('returns 应期 description', () => {
    const r = engine.setup({
      question: 'test', questionType: 'career',
      setupTime: new Date('2026-04-25T15:32:00'),
    });
    expect(r.yingQi.description).toBeTruthy();
  });
});
