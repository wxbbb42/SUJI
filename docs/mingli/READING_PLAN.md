# 有时 · 命理专家化阅读与实现审查计划

> Goal: 把有时的命理能力从“能排盘/能解释”推进到“每条规则、文案、设计判断都能回到 source，并能发现实现偏差”。

## 工作原则

1. **先读原文，再写结论**
   - 不把书名当 citation。
   - 每次阅读必须留下 reading note：读了哪一卷/哪一节、关键摘录、我的理解、对应代码影响。

2. **source-grounded，不玄学脑补**
   - 算法规则：优先 A tier 原典 + fixture + 独立排盘/资料源交叉验证。
   - 解释/产品语言：A/B tier + `product.no-absolute-fortune-claims`。
   - C/D tier 只作工程对照或启发，不能单独作为理论依据。

3. **contested 优先显式标记**
   - 不同版本/门派有差异时，标记 `contested`。
   - 不 silently choose；需要记录我们采用哪一版、为什么。

4. **读书和审代码同步推进**
   - 每读到一条规则，检查 app 当前实现：是否实现、是否简化、是否错引、是否需要 fixture。
   - 每个发现落成 claim / issue / TODO，而不是停留在聊天里。

---

## Phase 0 — 基建已完成 / 进行中

- [x] 建立 `docs/mingli/sources.json`
- [x] 建立 `docs/mingli/claims.json`
- [x] 建立 `npm run kb:mingli` ingest/校验脚本
- [x] 建立 `docs/mingli/reading-notes/`
- [ ] 建立 `docs/mingli/audit/`，沉淀实现审查报告
- [ ] 给每个核心领域建立 fixture plan

---

## Candidate source map — 2026-04-30 first expansion

> 这一步是“补全 source registry”，不是宣称已读完。全部候选都需要后续版本校勘、阅读笔记、claim 拆解和代码审查。

### 八字 / 子平 / 禄命

P0/P1 core:
- 《渊海子平》
- 《三命通会》
- 《滴天髓》
- 《穷通宝鉴》
- 《子平真诠》
- 《神峰通考》
- 《命理约言》
- 《五行精纪》
- 《玉井奥诀》

P2/P3 context / boundary:
- 《星平会海》
- 《珞琭子三命消息赋》
- 《兰台妙选》
- 《子平粹言》（D-tier 近现代解释参考）

### 紫微斗数 / 星命

- 《紫微斗数全书》
- 《紫微斗数全集》
- 《十八飞星策天紫微斗数全集》
- 太微赋/太玄赋相关传本
- 《果老星宗》（星命边界 source，不作为紫微默认算法）
- 飞星派现代资料占位（D-tier，后续必须替换为具体书名）

### 易经 / 六爻 / 梅花

- 《周易》通行本
- 《周易正义》
- 《周易本义》
- 《周易集解》
- 《火珠林》
- 《增删卜易》
- 《卜筮正宗》
- 《易隐》
- 《黄金策》
- 《断易天机》
- 《梅花易数》（边界 source，避免混入六爻纳甲）

### 奇门遁甲

- 《奇门遁甲全书》
- 《烟波钓叟歌》
- 《御定奇门宝鉴》
- 《奇门遁甲统宗大全》
- 《奇门法窍》
- 《景祐遁甲符应经》
- 《奇门旨归》

### 黄历 / 择日 / 首页宜忌

- 《协纪辨方书》
- 《御纂象吉通书》

### 现代学术 / 产品表达

- 陆致极《中国命理学史论》
- 《八字与中国智慧》（书目信息待确认）
- 《命理哲学研究》（书目信息待确认）
- 《周易研究》（期刊容器，后续按论文主题收）
- Richard J. Smith 相关占卜/易经研究（具体书名待最终确认）

---

## Phase 1 — 八字 / 子平体系 P0

### 1.1 《三命通会》

Priority: P0  
Repo focus: `lib/bazi/BaziEngine.ts`, `lib/bazi/DayunEngine.ts`, `lib/bazi/SiLing.ts`

Reading scope:
- [x] 卷二：论地支
- [x] 卷二：论人元司事
- [x] 卷二：论五行旺相休囚死并寄生十二宫
- [x] 卷二：论支元六合 / 三合 / 六害 / 三刑
- [ ] 卷二：论十干合 / 十干化气
- [ ] 卷二：论大运 / 小运 / 太岁 / 岁运
- [ ] 神煞相关章节：天乙、文昌、桃花、驿马、华盖、羊刃、禄神等
- [ ] 纳音相关章节

Implementation audit questions:
- 当前地支藏干表是否与选定版本一致？
- `SiLing.ts` 人元司令表为什么与《三命通会》正文/玉井引表不同？采用依据是什么？
- 旺相休囚死是否被机械化为吉凶？
- 六合/三合/刑冲害破是否在解释层被恐吓式表达？
- 神煞是否有过度断语？

Expected outputs:
- `bazi.siling.table.contested`
- `bazi.hidden-stems.table.versioned`
- `bazi.branch-relations.*`
- `bazi.shensha.*`
- fixtures for hidden stems / branch relations / dayun

### 1.2 《渊海子平》

Priority: P0  
Repo focus: 十神、格局、大运、天干五合、地支六冲/相刑

Reading scope:
- [ ] 十神 / 六亲基础
- [ ] 格局论：正格、外格、建禄/月刃、专旺等
- [ ] 大运起法与岁运
- [ ] 天干五合、地支冲刑

Implementation audit questions:
- `BaziEngine.ts` 十神计算是否只按五行阴阳关系？
- 格局判定是否过度简化？是否需要标 `mvp_simplified`？
- 大运顺逆、起运年龄是否需要 fixture 对照？

### 1.3 《滴天髓》

Priority: P0/P1  
Repo focus: 日主强弱、用神、格局清浊、通变原则

Reading scope:
- [ ] 天干/地支总论
- [ ] 体用、清浊、顺逆、寒暖燥湿
- [ ] 格局与岁运通变

Implementation audit questions:
- 当前日主强弱评分是否过于数量化？
- 用神/喜忌是否被说得太确定？
- 是否需要把算法输出改成“倾向/结构”，而非“定论”？

### 1.4 《穷通宝鉴》

Priority: P0  
Repo focus: 调候用神、季节性分析

Reading scope:
- [ ] 十干十二月调候总表
- [ ] 甲木/乙木/丙火等逐干逐月章节

Implementation audit questions:
- `调候用神表` 是否和采用版本一致？
- `@lunisolar/plugin-thegods` 数据是否与古籍可对照？

---

## Phase 2 — 紫微斗数 P0

Primary sources:
- `ziwei-doushu-quanshu`
- `ziwei-doushu-quanji`
- `ziwei-iztro` as C-tier implementation cross-check

Repo focus:
- `lib/ziwei/ZiweiEngine.ts`
- `lib/ai/tools/ziwei.ts`
- `lib/ziwei/__tests__/iztro-smoke.test.ts`

Reading scope:
- [x] 《紫微斗数全书》卷一目录/太微赋/形性赋开头
- [x] 《紫微斗数全书》卷二安身命例、十二宫、安星、四化口诀
- [ ] 卷一：诸星问答论，逐星整理十四主星 + 辅星性质
- [ ] 卷一：十二宫得地/失陷、富贵贫贱局
- [ ] 卷二：完整安星法
- [ ] 卷三：大限、流年、太岁、行限

Implementation audit questions:
- `iztro` 命宫/身宫/十四主星/四化是否与《全书》卷二 fixture 一致？
- 闰月、夜子时、真太阳时是否处理清楚？
- 解释层是否只按单星输出？是否需要上下文：宫位、庙陷、三方四正、四化、限运？
- 现代产品语言如何避免“富贵贫贱/夭寿”等古籍断语直接伤害用户？

Expected outputs:
- `ziwei.ming-shen-placement.rule`
- `ziwei.four-transformations.by-year-stem`
- `ziwei.star.*` claims
- `ziwei.interpretation.requires-context`
- fixture set comparing iztro + classical rule + independent charting source

---

## Phase 3 — 六爻 / 易占 P1

Primary sources:
- `yijing-zhouyi-received`
- `liuyao-huojulin`

Repo focus:
- `lib/divination/**`
- `lib/ai/tools/liuyao.ts`

Reading scope:
- [ ] 《周易》六十四卦卦辞/爻辞 source mapping
- [ ] 《火珠林》纳甲、六亲、世应、动变、用神

Implementation audit questions:
- 六十四卦数据是否可追溯到通行本？
- 六亲表是否有 source citation？
- 动爻/变卦/世应/用神是否实现，若未实现是否清楚标 MVP？

---

## Phase 4 — 奇门遁甲 P1/P2

Primary sources:
- `qimen-quanshu`
- C-tier cross-check: `qimen-ziwei-pro`, `qimen-qimendunjia-net`, and other named sources only as verification

Repo focus:
- `lib/qimen/**`
- `lib/ai/tools/qimen.ts`

Reading scope:
- [ ] 起局：阴阳遁、节气、三元、局数
- [ ] 地盘/天盘/人盘/神盘
- [ ] 八门、九星、八神
- [ ] 格局/吉凶门类
- [ ] 中五寄宫与争议规则

Implementation audit questions:
- 现有奇门规则中哪些来自 C/D tier 网站？
- 哪些规则缺少 A-tier source？
- 三源验证是否满足？不满足则标 `needs_verification`。

---

## Phase 5 — 产品解释层 / 安全表达 P0 ongoing

Repo focus:
- `lib/ai/**`
- prompt/tool output copy
- app UI 文案

Audit questions:
- 是否有绝对预测、恐吓、医学/法律/财务确定性建议？
- 是否把古籍中的阶层/性别/寿夭断语直接输出给用户？
- 是否把“命理结构”翻译成现代自我观察语言？
- 是否明确区分：传统文本、工程推算、产品建议？

Expected outputs:
- Prompt/source policy
- Risky copy inventory
- Safer interpretation templates

---

## Execution rhythm

Daily/每轮：
1. 读一个小节原文。
2. 写 reading note。
3. 抽 claim。
4. 查对应代码。
5. 标记：implemented / mismatch / simplified / missing / contested。
6. 补 fixture 或 TODO。
7. 跑 `npm run kb:mingli`，必要时跑 tests/tsc。

Milestone definitions:
- **M1**: 八字核心表与紫微排盘核心规则完成 first-pass source audit。
- **M2**: 所有当前 app 已实现命理规则都有 claim id 或明确 `mvp_simplified` 标记。
- **M3**: 关键规则有 fixture 对照。
- **M4**: 解释层全部经过安全表达审查。

