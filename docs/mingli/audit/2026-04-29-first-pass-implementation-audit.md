# 2026-04-29 First-pass Implementation Audit

> Scope: quick cross-check between first reading notes and current app implementation. This is a living audit, not a final verdict.

## Summary

Current app already has substantial bazi/qimen/ziwei/divination code, but citations are uneven. Some code comments cite classic books broadly, while individual tables/rules often need exact chapter/version/fixture backing.

## Findings

### A-001 — 人元司令表版本不一致

- Severity: high for bazi accuracy
- Domain: bazi
- Claim: `bazi.siling.table.contested`
- Source: `bazi-sanming-tonghui`, 卷二 `论人元司事`
- Repo: `lib/bazi/SiLing.ts`

Current implementation:
- 寅: 戊7 → 丙7 → 甲16
- 卯: 甲10 → 乙20
- 辰: 乙9 → 癸3 → 戊18
- etc.

Text checked:
- 《三命通会》正文段：寅“艮土五日、丙火五日、甲木二十日”；卯“甲七日、乙二十三日”等。
- 同节又引玉井表：寅“己土七日、丙火五日、甲木十八日”等。

Assessment:
- Current table is not directly identical to either checked table.
- This may come from another tradition/modern table, but the code currently says simply “《三命通会》”, which is too confident.

Recommendation:
1. Change comment to indicate version discrepancy.
2. Add a versioned table model or document selected source.
3. Before using this in high-stakes interpretation, show lower confidence / avoid precise claims.

### A-002 — 旺相休囚死 should not be treated as mechanical good/bad

- Severity: medium-high for product interpretation
- Domain: bazi
- Claim: `bazi.wuxing.seasonal-prosperity.requires-tongbian`
- Source: `bazi-sanming-tonghui`, 卷二 `论五行旺相休囚死并寄生十二宫`
- Repo: `lib/bazi/BaziEngine.ts`

Text checked:
- Source explains seasonal prosperity/decline, but explicitly says 生旺未必吉、休囚死绝未必凶，妙在通变。

Assessment:
- Existing scoring in `BaziEngine.ts` may be acceptable as engineering heuristic, but explanation layer must not present numeric strength as deterministic fortune.

Recommendation:
- Add comments/claims to output layer: strength is a structural tendency, not a verdict.
- Audit UI/AI copy for “强/弱 = 好/坏” shortcuts.

### A-003 — Branch relations need contextual language

- Severity: medium for user trust/safety
- Domain: bazi
- Claim: `bazi.branch-relations.not-absolute-omens`
- Source: `bazi-sanming-tonghui`, 卷二 `六合/三合/六害/三刑`
- Repo: `lib/bazi/BaziEngine.ts`, `lib/bazi/DayunEngine.ts`

Assessment:
- Code implements many relations; source tradition discusses context, not simple “bad omen”.

Recommendation:
- Explanation should use language like “张力/牵动/结构冲突/资源合流” rather than direct disaster claims.
- For 六害/三刑 especially, avoid scare language.

### Z-001 — Ziwei charting uses iztro; fixture against classical placement needed

- Severity: high for ziwei correctness
- Domain: ziwei
- Claim: `ziwei.ming-shen-placement.rule`, `ziwei.four-transformations.by-year-stem`
- Source: `ziwei-doushu-quanshu`, 卷二
- Repo: `lib/ziwei/ZiweiEngine.ts`, `lib/ziwei/__tests__/iztro-smoke.test.ts`

Text checked:
- 命宫/身宫安法 in 卷二 `安身命例`.
- 十二宫顺序 and four transformations by year stem.

Assessment:
- Current use of `iztro` is reasonable for engineering, but we need fixtures for:
  - 命宫/身宫
  - 十二宫 order
  - fourteen main stars
  - 四化 by year stem
  - leap month handling

Recommendation:
- Build 2-3 known birth fixtures and compare iztro output against classical rule + one independent C-tier charting source.

### Z-002 — Ziwei interpretation must be contextual, not single-star fortune telling

- Severity: high for product quality
- Domain: ziwei
- Claim: `ziwei.interpretation.requires-context`
- Source: `ziwei-doushu-quanshu`, 卷一 `太微赋`
- Repo: `lib/ai/tools/ziwei.ts`

Assessment:
- 《太微赋》 emphasizes star domains, twelve palaces, 入庙/失度, 身命 and context.
- Product should avoid isolated “你有某星所以你一定...” statements.

Recommendation:
- Update prompt/tool output contract to include context fields and caveats.

## Next audit targets

1. `lib/bazi/BaziEngine.ts`: hidden stems, ten gods, wuxing strength, pattern detection.
2. `lib/ziwei/ZiweiEngine.ts`: inspect actual iztro mapping and tests.
3. `lib/qimen/**`: separate A-tier backed rules from C/D-tier website rules.
4. `lib/ai/**`: search for deterministic/risky prediction language.

### P-001 — App currently exposes raw 吉/凶 framing in UI/tool schemas

- Severity: medium-high for product tone/compliance
- Domain: product-framing
- Claim: `product.no-absolute-fortune-claims`, `bazi.branch-relations.not-absolute-omens`
- Repo examples:
  - `app/(tabs)/insight.tsx`: label “凶: 看看命里有哪些煞”
  - `lib/ai/tools/index.ts`: topic mapping `健康: '凶'`
  - `lib/ai/tools/bazi.ts`: shensha filter enum includes raw `吉/凶`
  - `components/bazi/MingPanCard.tsx`: renders shensha `吉/凶` color

Assessment:
- Internal taxonomy may need `吉/凶`, but user-facing labels should be softened.

Recommendation:
- Keep internal enum if needed, but map UI labels to “助力/提醒/中性” or similar.
- Health should not route primarily through “凶”; use “care/risk-signal” framing.

### Q-001 — Qimen static descriptions contain high-risk literal language

- Severity: high for product expression, medium for algorithm
- Domain: qimen/product-framing
- Claims: `qimen.require-three-source-verification`, `product.no-absolute-fortune-claims`
- Repo examples:
  - `lib/qimen/data/bamen.ts`: 死门 = “死亡、终止”
  - `lib/qimen/data/bashen.ts`: 玄武 = “盗贼/暗算/阴损”, 白虎 = “刑伤”
  - `lib/qimen/data/geju.ts`: “百事凶”, “破财疾病”, “远行多灾”, “用事大凶”

Assessment:
- These may be traditional shorthand, but if returned raw to AI/UI they can lead to fear-inducing output.
- `QimenEngine` has MVP caveats, but data strings themselves are too direct.

Recommendation:
- Separate `traditionalLabel` from `safeDescription`.
- Tool output should default to safeDescription; keep traditional terms only as optional evidence.

### Q-002 — Qimen sources are mostly C/D-tier websites; A-tier source still thin

- Severity: high for source-grounding
- Domain: qimen
- Claim: `qimen.require-three-source-verification`
- Repo examples:
  - `lib/qimen/data/geju.ts` cites Zhihu, guoyi360, 易德轩, training material, 易先生, httpcn excerpt.
  - `lib/qimen/helpers/diPan.ts`, `tianPan.ts` cite web sources with multi-source cross-check.

Assessment:
- Engineering cross-check is useful, but some rules may still lack direct `qimen-quanshu` A-tier citation.

Recommendation:
- For each static table/geju, add source tier metadata and mark `needs_A_tier_text` where only web sources exist.
- Do not promote those rules into confident theory explanations until A-tier verified.
