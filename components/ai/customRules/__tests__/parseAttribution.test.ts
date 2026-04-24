import { parseAttribution } from '../ClassicalQuote';

describe('parseAttribution', () => {
  it('extracts —— 庄子 style attribution', () => {
    expect(parseAttribution('天行健\n——庄子')).toEqual({
      body: '天行健',
      attribution: '庄子',
    });
  });

  it('extracts —— 庄子《大宗师》', () => {
    expect(parseAttribution('夫大块载我以形\n—— 庄子《大宗师》')).toEqual({
      body: '夫大块载我以形',
      attribution: '庄子《大宗师》',
    });
  });

  it('leaves body without attribution alone', () => {
    expect(parseAttribution('海纳百川')).toEqual({
      body: '海纳百川',
      attribution: null,
    });
  });

  it('does not split on 《》 alone without ——', () => {
    expect(parseAttribution('我读了《道德经》')).toEqual({
      body: '我读了《道德经》',
      attribution: null,
    });
  });
});
