import { splitIntoKeywordSegments } from '../keywords';

describe('splitIntoKeywordSegments', () => {
  it('finds 日主 in middle of a sentence', () => {
    const segs = splitIntoKeywordSegments('你的日主是庚金');
    expect(segs).toEqual([
      { text: '你的', isKeyword: false },
      { text: '日主', isKeyword: true },
      { text: '是庚金', isKeyword: false },
    ]);
  });

  it('finds multiple keywords in one string', () => {
    const segs = splitIntoKeywordSegments('用神为水，喜神为金');
    expect(segs.filter(s => s.isKeyword).map(s => s.text)).toEqual(['用神', '喜神']);
  });

  it('does NOT match 金 as five-element inside 金色', () => {
    const segs = splitIntoKeywordSegments('夕阳金色');
    expect(segs.some(s => s.isKeyword)).toBe(false);
  });

  it('does match 金 as five-element when surrounded by punctuation', () => {
    const segs = splitIntoKeywordSegments('你属金，适合收敛');
    expect(segs.filter(s => s.isKeyword).map(s => s.text)).toContain('金');
  });

  it('returns whole string as non-keyword when no match', () => {
    const segs = splitIntoKeywordSegments('今天天气真好');
    expect(segs).toEqual([{ text: '今天天气真好', isKeyword: false }]);
  });
});
