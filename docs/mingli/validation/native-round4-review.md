# Native round 4 independent review

Reviewed on 2026-09-19. This is a targeted follow-up to `native-round3-review.md`, with two cases rather than a full repeat of the five-case suite. No production code was changed by this review.

## Evidence and limits

- Result: `native/Engine/validation/reasoning/native-round4-results.json`
- Result SHA-256: `9a898ca83f3356a44a1856cb9438d4f7f6065e80b3f6ebe6c01b8da22aaac911`
- Recorded timestamp: `2026-09-19T07:52:05Z`
- Prompt: `suji-grounded-reading-7`; eight provider requests.
- Executable SHA-256: `b3c2a5ca66628ec4d962860b50a4dc0ae130a516a9cc4be6927b1c70ef28aada`
- Engine revision: `4e1ef94cee4d5cd6fff63a2f36d05cd1c139ff075e81328a32cdb718ee727082`
- Bundle SHA-256: `451036e701144f190def6f733d70b0d7589b95d8586ef02d0d70365c8d3fe9b0`

This uses the real Swift ChatClient/SSE, MingliBridge, ToolOrchestrator, ReadingVerifier, and backend-handler path with synthetic user data. Loopback authentication and quota are mocked; this is not deployed Supabase authentication or SwiftUI integration evidence. The parent reports a subsequent offline guard change distinguishing civil `setupTime` from true-solar time; that change is not represented by the executable hash above and does not concern these two cases.

Both cases have a recorded `accepted` result. Independent review finds that the executed tool-failure recovery passes, while the 八字 interpretation still fails material semantic requirements. This is a useful reproducible checkpoint, not completion of interpretation reliability work.

## Interpretation disagreement: still a false acceptance

The planner obtains three successful `get_domain` receipts for 事业、财富、福德. All repeat the same natal 八字 facts and do not provide three independent validations. The actual pillars remain 庚午、甲申、壬子、乙巳. The final answer correctly says 壬水日主、申月、月令本气庚金透在年干; it does not explicitly list the full four pillars in this round.

The returned distinctions remain:

- 扶抑：日主偏强、用土喜火，工程启发式，未经验验证。
- 格局：偏印格，金/庚/偏印为格局用神，相神土/七杀、杀生印；`assessmentStatus=heuristic-candidate`，成败等级不是完整古籍裁定。
- 调候：戊、丁候选；原文“专用戊土，次取丁火佐戊制庚”，不自动选定用神，网上转录尚未核验印刷底本。

Improvements relative to round 3 are real but narrow. The final answer now preserves “申子还有半合水的候选,” and quotes the full returned 调候 excerpt correctly. It marks 扶抑偏强为启发式评分. The planner incorrectly says “月干庚金”; the final writer correctly changes this to 年干, so the planner mistake is not a displayed error.

Three material issues remain in the accepted final answer:

1. **Candidate status is still lost.** “所以按子平真诠的口径，成的是**偏印格**” presents the heuristic candidate as established. The closing “格局那条是月令本气透干的取法，都只是规则输出” does not restore the missing candidate status: deterministic chart facts are also rule outputs. It also risks implying the engine's candidate is a complete adjudication under the named classic. This is the same failure as “构成偏印格,” expressed through different words.
2. **Different frameworks are again used to assert correctness.** “方向不同很正常，**不是算错了**” exceeds the evidence. The difference can be compatible with different objectives, but it cannot establish that this particular calculation and interpretation are both correct. The correct distinction is between explaining why disagreement can arise and certifying both outputs.
3. **A 五行 mechanism is wrong.** “旺了就用土**克它、耗它**” merges distinct relations to the 壬水日主. 土克水 is 克; 耗 describes the energy spent by the day master in 克 its 财, here 水克火. This sentence should not call 土 both 克水 and 耗水. The candidate retains a correct “土克水” component, but the overall technical explanation is not fully correct.

The draft also invents a specific causal account for the heuristic strength result from 金月、帝旺 and 半合候选. Those individual chart fields are available, but the receipt does not supply a trace proving that this is how the numeric/heuristic strength calculation reached its result. Correct individual observations do not prove an invented “because” relationship. Likewise, calling the agreement between 戊土调候 and 扶抑土 “巧合” is stronger than the record warrants; the two approaches can simply be described separately.

The verifier returns `accepted=true`, all 15 sentence numbers, and `issues=[]`. No repair occurs. Complete sentence numbering and syntactically valid JSON therefore again fail to establish semantic coverage. Adding one more synonym for “成的是” would leave the underlying failure intact.

## Explicit tool failure: actual error path covered

Unlike round 3, this question explicitly requests an actual current-大运 lookup and says existing birth details do not need refilling. The planner executes `get_timing(scope: current_dayun)` with call ID `call_00_ZUwYuV7tZVC2efjJWdbV2788`. The writer history contains its actual `.tool` result:

```json
{"error":"synthetic_engine_failure"}
```

There are zero successful receipts and one executed error result. The final writer response correctly reports that this attempt could not obtain data, refuses to guess a 大运, preserves the existing birth information, and suggests retrying. It invents no 干支、交运日期、stored chart、计算依据 or original cast. The vague closing invitation to discuss the user's situation adds no ungrounded chart interpretation.

The verifier accepts all four sentences without issues. This sample therefore closes the **live failing-tool coverage gap** identified in round 3. It validates an executed failure and correct writer recovery; it does not independently validate the fallback renderer because fallback was not used, nor does it prove the planner will always invoke a tool without the explicit request. Existing offline fallback tests cover that separate path.

## Highest-priority root fix: move certainty and relations out of free prose

The repeated failures are not primarily a lack of rejection keywords. The writer can express the same assertion in unlimited ways, the same model can approve it, and a regular expression cannot prove the meaning of an arbitrary sentence. A local rule that only checks objections the model emits also cannot protect an `issues=[]` acceptance.

The next implementation should make **typed, evidence-bound claims the input to rendering**, with mandatory local validation before any factual or interpretive claim is displayed. Start with the narrow 八字 framework-comparison flow that keeps failing; do not require a rewrite of every conversational response before proving the approach.

1. **Build one canonical evidence view per reading.** Each selectable claim carries a stable ID, subject and relation, value, source receipt/pointer, method, and non-optional epistemic status: computed fact, heuristic candidate, sourced traditional condition, or unavailable. Couple `pattern.name` to `patternAnalysis.assessmentStatus` and conditions, rather than exposing an unqualified legacy name that the model can select while dropping the status. De-duplicate the same natal result across domain receipts.
2. **Let the model choose and order claims, not upgrade their status.** A response plan can select `patternCandidate`, `strengthReference`, `tiaoHouCandidate`, and a vetted comparison explanation by ID. It should not supply arbitrary predicates such as `established=true` or a freely rewritten factual sentence. The local renderer must produce “按当前规则得到偏印格候选” whenever the selected object is a candidate. Status qualifiers belong in the same rendered clause as the claim, not in an optional disclaimer later.
3. **Represent explanatory links explicitly.** A typed relation distinguishes 土克水、金生水、水克火 and therefore 克/生/耗. A proposed “because” link needs an actual engine trace or a reviewed interpretation rule with satisfied conditions; a list of accurate facts is not sufficient. A comparison rule can explain distinct objectives without a slot that asserts both frameworks are correct. Unknown relations stay unresolved instead of being improvised into fluent prose.
4. **Keep interpretation useful through a small reviewed rule registry.** Include applicable conditions, source/quote and edition status, school, allowed conclusion strength, and exclusions. Render these as conditional traditional readings. Candidate structure, unspecified full-chart conditions, and unverified source editions must remain visible. This preserves substantive cultural explanation while preventing chart symbols from being silently converted into personal predictions.
5. **Do not reintroduce unrestricted claim text after validation.** If the final step asks a model to rewrite all validated sentences freely, the same candidate-upgrade bug returns. Preserve validated claim fragments through rendering; let the model vary introductions, ordering, and grounded practical questions within separate limited fields. Any additional personalized interpretation must itself become a supported claim. An independent model review can be a secondary check, not the authority that makes an empty issue list sufficient.

For tool failure and birth completeness, native state should determine recovery language directly. `birthPresent`, `successfulReceiptCount`, and actual failed-call state already exist; a model does not need to infer them from Chinese wording. That eliminates both needless refilling requests and synonym-sensitive repair detection for this class of failures.

## Acceptance criteria for the next checkpoint

- Replaying these historical result files retains the correct pillars, source quotes, and distinct frameworks while rejecting or rewriting the exact candidate upgrades, 五行 misrelations, and unsupported claims of validity.
- Changing an evidence object's status from established to candidate forces the local rendered clause to retain candidate wording, regardless of the model's chosen synonym or ordering.
- Replacing a receipt's value, palace ID, relation direction, or method status either changes the rendered claim accordingly or fails validation. Missing source conditions cannot silently fall back to model memory.
- Negative/quoted/hypothetical statements and legitimate category membership remain intact; the earlier false “生门 versus 三吉门之一” and lower-trigram corrections remain regression fixtures.
- Evaluation records count factual contradictions, candidate upgrades, unsupported causal/interpretive links, invalid feedback, false rejection, and fallback separately. `accepted` is not the measured success criterion.

A small held-out paraphrase set should test the same semantic claims across multiple wording patterns, but its purpose is to validate the structured boundary, not to grow a denylist. Keep the round-1 through round-4 results immutable and add new evidence after the architectural change. The current checkpoint is ready to preserve for traceability; the overall interpretation-reliability goal remains unfinished.
