import { preprocessYiji } from '../preprocessYiji';

describe('preprocessYiji', () => {
  it('identifies a yi/ji pair on adjacent lines', () => {
    const input = '宜：静心、写字\n忌：争执、远行';
    const expected = '```yiji\nyi: 静心、写字\nji: 争执、远行\n```';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('identifies a yi/ji pair separated by blank line', () => {
    const input = '宜：静心\n\n忌：争执';
    const expected = '```yiji\nyi: 静心\nji: 争执\n```';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('accepts bolded markers', () => {
    const input = '**宜**：静心\n**忌**：争执';
    const expected = '```yiji\nyi: 静心\nji: 争执\n```';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('accepts ASCII colon', () => {
    const input = '宜: 静心\n忌: 争执';
    const expected = '```yiji\nyi: 静心\nji: 争执\n```';
    expect(preprocessYiji(input)).toBe(expected);
  });

  it('leaves a solo 宜 untouched', () => {
    const input = '今天宜：静心，没啥别的';
    expect(preprocessYiji(input)).toBe(input);
  });

  it('leaves unpaired 宜 without 忌 untouched', () => {
    const input = '宜：静心\n\n然后呢';
    expect(preprocessYiji(input)).toBe(input);
  });

  it('preserves surrounding text', () => {
    const input = '今天的建议：\n\n宜：静心\n忌：争执\n\n好好过一天。';
    const expected = '今天的建议：\n\n```yiji\nyi: 静心\nji: 争执\n```\n\n好好过一天。';
    expect(preprocessYiji(input)).toBe(expected);
  });
});
