import { getCurrentSiLing, getDefaultSiLing, getSiLingSegments } from '../SiLing';
import type { DiZhi } from '../types';

describe('Xu commentary month commander, elapsed-day boundaries', () => {
  it.each([
    [0, null, ['戊', '己']], [9, null, ['戊', '己']], [9.99999, null, ['戊', '己']],
    [10, '壬', ['壬']], [12, '壬', ['壬']], [12.99999, '壬', ['壬']], [13, '庚', ['庚']],
  ])('preserves the source 申 10/3/17 at elapsed %s', (days, gan, gans) => {
    expect(getCurrentSiLing('申', days as number)).toMatchObject({gan, gans});
  });
  it('assigns an exact seven-day boundary to the second 寅 segment', () => {
    expect(getCurrentSiLing('寅', 6.99999).gan).toBe('戊');
    expect(getCurrentSiLing('寅', 7).gan).toBe('丙');
    expect(getCurrentSiLing('寅', 14).gan).toBe('甲');
  });
  it('marks continuation of the nominal 30-day tail explicitly', () => {
    expect(getCurrentSiLing('申', 30.8)).toMatchObject({gan:'庚', beyondNominalMonth:true});
    expect(getCurrentSiLing('申', 29.99)).toMatchObject({beyondNominalMonth:false});
  });
  it.each([-1, NaN, Infinity, -Infinity])('rejects invalid elapsed %s', days => {
    expect(() => getCurrentSiLing('申', days)).toThrow(RangeError);
  });
  it('rejects an unknown month instead of misreporting a commander', () => {
    expect(() => getCurrentSiLing('甲' as DiZhi, 1)).toThrow(RangeError);
  });
  it('does not let caller mutation rewrite later readings', () => {
    const segments = getSiLingSegments('申');
    segments[0].days = 1;
    expect(getCurrentSiLing('申', 9)).toMatchObject({gan:null, gans:['戊','己']});
  });
  it.each([
    ['寅', '甲'],['卯','乙'],['辰','戊'],['巳','丙'],['午','丁'],['未','己'],
    ['申','庚'],['酉','辛'],['戌','戊'],['亥','壬'],['子','癸'],['丑','己'],
  ])('retains the unambiguous majority commander for %s', (month, gan) => {
    expect(getDefaultSiLing(month as DiZhi)).toBe(gan);
  });
});

describe('all months retain literal source segments and metadata', () => {
  it.each([
    ['寅', [[['戊'],7],[['丙'],7],[['甲'],16]]], ['卯', [[['甲'],10],[['乙'],20]]],
    ['辰', [[['乙'],9],[['癸'],3],[['戊'],18]]], ['巳', [[['戊'],5],[['庚'],9],[['丙'],16]]],
    ['午', [[['丙'],10],[['己'],9],[['丁'],11]]], ['未', [[['丁'],9],[['乙'],3],[['己'],18]]],
    ['申', [[['戊','己'],10],[['壬'],3],[['庚'],17]]], ['酉', [[['庚'],10],[['辛'],20]]],
    ['戌', [[['辛'],9],[['丁'],3],[['戊'],18]]], ['亥', [[['戊'],7],[['甲'],5],[['壬'],18]]],
    ['子', [[['壬'],10],[['癸'],20]]], ['丑', [[['癸'],9],[['辛'],3],[['己'],18]]],
  ] as [DiZhi,[string[],number][]][])('reads each %s transition from its source interval', (month, segments) => {
    let start = 0;
    for (const [gans,days] of segments) {
      expect(getCurrentSiLing(month,start).gans).toEqual(gans);
      expect(getCurrentSiLing(month,start+days-0.00001).gans).toEqual(gans);
      start += days;
    }
    expect(start).toBe(30);
  });
  it('binds the selected table to the actually archived source', () => {
    const r = getCurrentSiLing('申',9);
    expect(r.tableId).toBe('ziping-xu-renyuan-v1');
    const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
    const bytes = fs.readFileSync(path.resolve(__dirname,'../../../../..',r.source.document));
    expect(crypto.createHash('sha256').update(bytes).digest('hex')).toBe(r.source.sha256);
    expect(bytes.toString()).toContain(r.source.quote);
    expect(bytes.toString()).toContain(r.source.caution);
  });
});
