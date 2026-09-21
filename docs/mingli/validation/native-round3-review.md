# Native round 3 independent review

Reviewed on 2026-09-19. This report audits the recorded writer drafts, raw successful tool receipts, verifier responses, and final displayed answers independently of their `accepted` / `fact-fallback` labels. Production source was frozen during this review; this report does not change it.

## Evidence and scope

- Result: `native/Engine/validation/reasoning/native-round3-results.json`
- Result SHA-256: `e13e8290a9fce3876c39eb4c7d1959d517869ff92f8ad67f68bcd48bac34047a`
- Recorded timestamp: `2026-09-19T07:48:43Z`
- Prompt: `suji-grounded-reading-6`; 21 provider requests; five cases.
- Executable SHA-256: `3a4a2a4ff9945af0d13c2aff705726dc16d5ad794ac0102532d2511bd614429a`
- Engine revision: `4e1ef94cee4d5cd6fff63a2f36d05cd1c139ff075e81328a32cdb718ee727082`
- Normal bundle SHA-256: `451036e701144f190def6f733d70b0d7589b95d8586ef02d0d70365c8d3fe9b0`
- Fixed 六爻 evaluation bundle SHA-256: `b7e4ad86b7863038c18904ba1e500c934a45170774270dffaa27bef77c2d3e0a`; evaluation-only `Math.random` substitution, yielding `[6,7,8,8,9,6]`.

This is the actual Swift ChatClient/SSE, MingliBridge, ToolOrchestrator, ReadingVerifier, and backend-handler path. Loopback authentication and quota are mocked. It is **not** evidence of deployed Supabase authentication or SwiftUI end-to-end success. Planner prose is not the final writer answer; its mistakes are identified separately below.

## Overall result

The round shows meaningful recovery: a sourced health response is no longer falsely rejected, the fixed multiple-moving-line facts remain correct, and fallback no longer invents a saved chart when no calculation succeeded. It does **not** establish that accepted interpretations are reliable. The accepted 八字 explanation still elevates a candidate pattern into an established one and asserts both approaches are correct. The 奇门 draft has a real palace error, but neither verifier response identifies it; fallback is safe because the responses fail protocol validation, not because semantic checking successfully finds the actual error.

| Case | Recorded result | Independent finding |
| --- | --- | --- |
| health-with-facts | accepted; 1 receipt | Target health boundary passes. One minor terminology error remains. |
| liuyao-multichange | accepted; 1 receipt | Requested coin/line/trigram facts pass. One unsupported project interpretation remains. |
| explicit-qimen | fact-fallback; 1 receipt; invalid_verdict | Final chief-star/door facts pass; draft contains a real palace error, while reviews give unrelated or false objections. |
| interpretation-disagreement | accepted; 4 receipts | Four pillars and 五行 roles are correct; candidate status and framework-validity boundaries fail. |
| tool-failure | fact-fallback; 0 receipts; invalid_verdict | Final recovery is accurate for **no tool calls**. The configured injected failure was not exercised in this sample. |

These mixed outcomes should not be summarized as “3/5 semantic passes” merely because three cases were accepted.

## Health: successful narrow regression

The sole `get_ziwei_palace` receipt returns 疾厄宫酉位、干支乙酉、无主星、左辅/文曲/擎羊/红鸾/三台/天使、四化空。The displayed answer reports those facts and explicitly refuses to infer external injury, organ disease, constitution, or individual medical risk from them. Its general health advice is not bound to the chart. The verifier accepts without issues. This resolves the round-2 false rejection of a denial while actually using a successful receipt.

Minor wording remains: “宫干为乙酉” should be “宫干支为乙酉” or “宫干乙、宫支酉.” This does not create a personal health prediction. The planner also incorrectly offered 疾厄宫对宫 as 迁移宫; that sentence is absent from the writer/final answer, so it is not a displayed-answer failure in this run.

## 六爻: core facts correct; interpretation coverage incomplete

The fixed draw `[6,7,8,8,9,6]` gives 动爻1/5/6、坎为水→山泽损，变卦上艮下兑。The final answer correctly lists:

- 初爻阴动：子孙木→妻财火；五爻阳动：官鬼土→兄弟水；上爻阴动：兄弟水→子孙木。
- 世在上爻兄弟子水，应在三爻妻财午火；二爻官鬼辰土旬空并受日冲。
- 起卦北京时间 `2024-02-04 12:00`，月乙丑、日戊戌、时戊午。

The earlier false lower-trigram correction does not recur. This round uses `questionType=event`; round 2 used `career`. Differences in initial 用神 selection are therefore not evidence of inconsistent coin calculation.

The final sentence “本次盘面动爻较多，表示阶段变化较明显” goes beyond the receipt. The tool supplies changing lines and method caveats, but no sourced rule establishing this project's actual phase changes. “不承诺结果” does not supply that missing basis. Generic explanations of 官鬼/父母 can be offered as traditional terminology, but this personal project inference should remain an explicitly conditional interpretive possibility, with its source and conditions, rather than a stated observation. The verifier's empty `issues` does not catch this distinction.

## 奇门: real draft error, invalid reasons for rejection

The final factual fallback is correct: 阳遁三局、上元、大寒、值符天任落3宫、值使生门落3宫。The successful receipt exists and therefore the fallback's saved-record / reuse-original-chart claims are justified.

The writer's chief facts are initially correct: 震三宫 contains 天任、生门、八神值符、地盘戊、天盘癸；值符源宫艮八。It then wrongly says:

> 时干戊也落在震宫，和值符值使同宫……同宫见伤门、天冲、腾蛇。

The receipt has `/yongShen/palaceId = 4`, with 时干戊 in **巽四宫**, whose 天盘干戊、伤门、天冲、腾蛇 match that palace. The writer has confused 震宫的地盘戊 with the 时干取用的天盘戊. The chief star and door remain in 震三, so the claimed same-palace relationship is false. This is a real factual error requiring correction, independent of how the model phrases project advice.

The first review instead rejects the ordinary advice to identify a project bottleneck and get outside feedback under `interpretation.personalized-rule-required`. That quoted advice does not itself infer a personal trait from a chart, so the local rejection of this feedback is appropriate.

The second review manufactures two field mismatches:

1. It treats “生门……属三吉门之一” as if the writer said the door's **name** was “三吉门之一.” A category membership is not a conflicting door name. The receipt's own 格局 entry explicitly says the actual 值使 is one of 开/休/生.
2. It binds “艮宫有丙奇逢吉门” to `/palaces/6/diPanGan` (兑七地盘壬). These refer to different palaces and subjects. The receipt explicitly has 丙奇遇吉门 in palace 8, with 天盘丙 and 休门; the draft's local 配合 statement is supported.

Both reviews are invalid, so neither is supplied as authoritative correction text to the writer. There is no revised writer draft. This is successful containment of bad feedback and a useful final fallback, **not** a successful semantic diagnosis of the actual palace error. The writer's “当前能量集中” is also unsourced personal interpretation. The round-2 UTC-as-Beijing mislabel does not recur: this writer only says 午时, compatible with true-solar `03:31:45Z = 11:31:45+08`.

## 八字: accepted interpretation still fails candidate boundaries

The four successful receipts are `get_domain(事业)`, `get_domain(婚姻)`, `get_timing(current_dayun)`, and `get_today_context`. Two domain receipts contain the same natal 八字 facts. The final answer correctly reports 庚午、甲申、壬子、乙巳；日主壬水、申月。庚是月支申本气，同时透于**年干**，巳藏戊七杀。The answer no longer repeats the old false reviewer claim that 庚没有透干.

The distinct returned approaches are also correctly enumerated:

- 扶抑参考：用土、喜火，`fuyi-heuristic`，非经验验证结论。
- 格局：金/庚/偏印，相神土/七杀、杀生印；`assessmentStatus=heuristic-candidate`。
- 调候：壬水申月的戊、丁候选，出处转录的原文是“专用戊土，次取丁火佐戊制庚”；不自动选定用神。

The 五行 explanations in the **final writer answer** are correct: 土克水，土生金；it no longer describes 土 as 泄水. It distinguishes 扶抑强弱、格局结构、调候寒暖燥湿. The planner had mixed “冷热” into 扶抑 and added unsourced 大运行动 advice, but these do not survive into the final answer.

Material remaining problems are displayed unchanged and accepted with `issues=[]`:

1. “月令申的本气庚金透在年干，**构成偏印格**” does not preserve the pattern's candidate status. “这个结论标注为工程启发式” in the preceding 扶抑 paragraph qualifies the strength conclusion, not this separate 格局 statement. The source explicitly says its 成败/等级 are current-rule candidates, not complete classical adjudication.
2. “**这不是谁算错了**” and “**各自成立，各自有边界**” claim correctness merely from differences in the frameworks. Different objectives can explain different outputs; they do not prove either specific calculation or interpretation correct. The user's request not to confuse schools with arithmetic errors does not warrant assuming both are valid.
3. “偏强（申子半合水、日支子为帝旺）” invents a specific causal derivation of the heuristic strength output. 帝旺 is a returned fact; the branch relation is explicitly `半合候选`, partial, missing 辰, `outcomeEstablished=false`. The text should not silently convert that candidate into an established 水 transformation or imply that these two observations prove the score.
4. “象神是土” should use the returned term **相神**. The 调候 paraphrase preserves candidate language but omits “佐戊制庚” and the unverified printed-edition limitation; it should not be presented as the full quotation.

The current local protocol validates objections **when the verifier emits them**. A model response declaring acceptance with no issues bypasses the newly supported `构成X格` objection. This record demonstrates that valid schema and complete sentence coverage do not establish actual claim coverage. A next improvement should check candidate assertions independently or require checkable disposition of identified claims. This should preserve meaningful sourced explanations rather than reduce all traditional interpretation to empty refusals.

## No-tool recovery: accurate final answer, missing failure coverage

The case is labeled `tool-failure` and has `injectedFailure=synthetic_engine_failure`, but its planner calls **no tools**. The recorded writer history contains only `system` and `user`; there are zero tool errors as well as zero successful receipts. The configured injection therefore did not execute in this run. The planner mistakenly says birth information is missing even though the trusted system header says it exists.

The writer then asks the user to refill existing information:

> 你可以先把出生资料补全给我：出生年月日、具体时辰（越准越好）、出生地，以及性别。

Both verifier responses correctly flag that full sentence with `context.birth-already-provided`. Local validation rejects them because the current matcher recognizes 提供/填写/补充 before 出生资料, but not “把出生资料补全给我.” This is a valid semantic objection lost through limited local recall, not fabricated reviewer feedback. No writer revision occurs.

The final fallback is nevertheless accurate:

> 这次生成的解读暂未采用。这次尚未取得可用的计算结果。你的出生资料已保留，无需重新填写；可以重试取数。

It does not claim actual execution failed, invent computed chart data, expose nonexistent 计算依据, or promise reuse of an original cast. For this recorded state, “尚未取得” is more accurate than “取数失败.” The 15 fallback/replay unit tests separately passed, including real `.tool` error records, but this live sample must not be counted as an executed failing-engine integration test. A further failure-path evaluation needs to require at least one executed tool call and assert an actual error record before declaring the injected-failure scenario covered.

## Remaining verification priorities

1. Close false acceptance of candidate-pattern assertions and unsupported claims that both frameworks are established; retain correct four-pillar facts and useful differentiated explanations.
2. Make 奇门 时干/地盘干/天盘干 and palace relationships checkable without inventing category-name mismatches. Keep invalid feedback quarantined.
3. Preserve valid birth-recovery objections across common wording such as “把出生资料补全.” Force actual tool execution in failure-path evaluation fixtures.
4. Distinguish generic traditional terminology from unsourced claims about the user's actual project changes. Keep historical round-1/2/3 failures as evidence; later improvements should add results rather than overwrite them.
