import { astro } from 'iztro';

describe('iztro smoke', () => {
  it('排出一张紫微星盘（已知生辰）', () => {
    // 1990-08-16 14:30 男 北京（以阳历）
    const astrolabe = astro.bySolar('1990-8-16', 2, '男', true, 'zh-CN');

    expect(astrolabe).toBeDefined();
    expect(astrolabe.palaces).toHaveLength(12);
    // 命宫存在
    const mingGong = astrolabe.palaces.find(p => p.name === '命宫');
    expect(mingGong).toBeDefined();
  });
});
