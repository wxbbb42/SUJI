import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { TIAOHOU_REVIEWS, getTiaoHouReview } from '../tiaohou';
import { BaziEngine } from '../BaziEngine';

describe('source-linked conditional tiaohou candidates', () => {
  it('covers all 120 distinct stem/month cells and keeps unknown rules inactive', () => {
    expect(TIAOHOU_REVIEWS).toHaveLength(120);
    expect(new Set(TIAOHOU_REVIEWS.map(r=>r.ruleId)).size).toBe(120);
    expect(TIAOHOU_REVIEWS.filter(r=>r.reviewStatus==='transcription-checked')).toHaveLength(119);
    expect(TIAOHOU_REVIEWS.filter(r=>r.reviewStatus==='needs-source-review')).toHaveLength(1);
    for(const r of TIAOHOU_REVIEWS){
      expect(r.automatedSelection).toBe(false);
      expect(r.editionStatus).toBe('online-transcription-unverified-against-printed-edition');
      if(r.reviewStatus==='needs-source-review') expect(r.candidateStems).toEqual([]);
    }
  });
  it('binds every checked quotation to its exact source and hash, without blessing interpretation', () => {
    const root=path.resolve(__dirname,'../../../../../');
    for(const r of TIAOHOU_REVIEWS){
      const bytes=fs.readFileSync(path.join(root,r.sourceDocument));
      expect(crypto.createHash('sha256').update(bytes).digest('hex')).toBe(r.sourceSha256);
      if(r.reviewStatus==='transcription-checked'){
        expect(r.excerpt.length).toBeGreaterThan(0);
        expect(bytes.toString('utf8')).toContain(r.excerpt);
        expect(r.conditions.length).toBeGreaterThan(0);
      }
    }
  });
  it('corrects the source-conflicting Jia/Chen, Jia/Wei, Jia/Shen entries', () => {
    expect(getTiaoHouReview('甲','辰').candidateStems).toEqual(['庚','壬']);
    expect(getTiaoHouReview('甲','未').candidateStems).toEqual(['丁','庚']);
    expect(getTiaoHouReview('甲','申').candidateStems).toEqual(['丁','庚']);
    expect(getTiaoHouReview('甲','辰').conditions.join('')).toContain('不把壬列为固定忌神');
  });
  it('preserves season subperiods and conditional substitutions as unresolved conditions', () => {
    expect(getTiaoHouReview('乙','酉').conditions.join('')).toContain('秋分');
    expect(getTiaoHouReview('癸','辰').conditions.join('')).toContain('谷雨');
    expect(getTiaoHouReview('癸','巳').conditions.join('')).toContain('替代');
    expect(getTiaoHouReview('乙','丑').candidateStems).toEqual([]);
  });
  it('does not let any unreviewed tiaohou table determine production yong-shen', () => {
    const p=new BaziEngine().calculate(new Date('1995-01-01T12:00:00+08:00'),'女');
    expect(p.wuXingStrength).toMatchObject({suggestionBasis:'fuyi-heuristic',suggestionStatus:'not-empirically-validated',tiaohouApplied:false});
    expect(p.tiaoHou?.automatedSelection).toBe(false);
    expect(p.interpretationPolicy?.strengthYongShen).toContain('调候另列来源候选');
  });
  it('does not count the day-master element twice in the named strength heuristic', () => {
    // 乙亥 庚辰 壬辰 丙午: water 2.1 + metal 1 = support 3.1;
    // wood 1.7 + fire 1.7 + earth 1.5 = drain 4.9 under these declared weights.
    // The former duplicate water count turned 3.1 into 5.2 and inverted this result.
    const p = new BaziEngine().calculate(new Date('1995-05-01T12:00:00+08:00'), '女');
    expect(p.wuXingStrength).toMatchObject({
      riZhuStrong: false,
      yongShen: '金',
      xiShen: '水',
      jiShen: '土',
      suggestionBasis: 'fuyi-heuristic',
    });
  });
});
