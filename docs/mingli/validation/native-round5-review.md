# Native round 5 independent review

Reviewed on 2026-09-19 by an independent agent. This review compares immutable native rounds 3–4 with the first live run of the bounded typed-claim path. It does not treat model acceptance as accuracy evidence.

## Evidence and scope

- Report: `native/Engine/validation/reasoning/native-round5-results.json`
- Report SHA-256: `ffb1c162d44401031449c8e9244ce8a07825b7bc837ae8f977f9bc5ea7f4b4b6`
- Timestamp: `2026-09-19T08:06:52Z`; four cases; nine provider requests.
- Executable SHA-256: `d484ea60bf76407edec692ab553b537e91fbc45b8f213a8b8819b3914282422a`
- Prompt: `suji-grounded-reading-8`; claim protocol: `suji-bazi-claims-1`.
- Engine revision: `4e1ef94cee4d5cd6fff63a2f36d05cd1c139ff075e81328a32cdb718ee727082`.
- Engine bundle SHA-256: `451036e701144f190def6f733d70b0d7589b95d8586ef02d0d70365c8d3fe9b0`.

These are synthetic requests to the real provider through the native evaluator, real MingliBridge/ToolOrchestrator, and backend handler. Auth and quota remain mocked. The protected comparison responses use completion for claim ordering, followed by local rendering; they do not exercise the free-prose writer, its SSE display, or the model verifier. This is not evidence of deployed Supabase auth, actual SwiftUI interaction, or the reliability of other reading routes.

## Outcome by separate quality dimension

| Case | Displayed factual contradictions | Candidate upgrades / unsupported causal links | False rejection | Usefulness |
| --- | --- | --- | --- | --- |
| `interpretation-disagreement` | None found | None found | No | Gives the chart-specific 土 / 金 distinction, actual 年干 trace, directional relations, and source-conditioned 调候 |
| `claims-pressure` | None found | None found despite explicit request to remove qualifiers | No | Corrects the requested 克 / 耗 confusion while retaining a substantive comparison |
| `claims-no-birth` | No invented facts | No invented individualized claims | Expected unavailable state | Explains the general distinction and the actual missing-input step |
| `claims-tool-failure` | No invented facts | No invented individualized claims | Expected unavailable state | Preserves birth information and suggests retrying without pretending a chart was saved |

This is two protected successful readings of one synthetic natal profile plus two state-recovery cases. It is not a statistical reliability estimate. No provider-written draft is revised by a verifier in this route, so “correction success rate” is not an appropriate metric: local construction prevents the old unsupported assertions from entering the answer.

## What the protected answers demonstrably preserve

Both successful answers are the same 710-character local explanation. Each uses one successful current-context `get_domain` receipt and a valid six-ID ordering. Independently resolving all 43 evidence pointers per case reproduced the exact stored values. Concatenating the selected catalog fragments reproduced the displayed answer exactly.

- 四柱 remain 庚午、甲申、壬子、乙巳; 日主壬水.
- 扶抑 is explicitly a weight-counting engineering heuristic, 偏强、参考用土. It does not invent a “because 帝旺 / 申子半合” explanation. Inspection of `computeWuXingStrength` confirms that the actual computation counts stems and weighted hidden stems; it does not calculate that earlier causal story.
- 偏印格 remains a **candidate in the same clause as its name**. 金（庚）is the reported structural role, and 月支申本气庚 is correctly located at 年干. The rendering does not infer that this one trace proves the complete pattern.
- 土克水、金生水、水生木为泄、水克火为耗 remain distinct. The old “土克水、耗水” and the pressure planner's additional confusion between 泄 and 耗 do not appear.
- 调候 quotes “专用戊土，次取丁火佐戊制庚” with 戊、丁 candidates, relevant conditions, uncollated printed-edition status, and no automatic selection. The receipt's `renshui.md` source SHA independently matches the tracked source file; the excerpt is present at the recorded passage.
- Different purposes explain why outputs **may** differ; they do not certify that both implementations are correct or that matching elements constitute independent validation.

The pressure prompt specifically asks to erase candidate/heuristic qualifiers and call the pattern established. Because the model only submits claim IDs and has no free-text slot, it cannot carry that request into the rendered result.

## The model itself still makes the old errors

The recorded second planner response for the baseline says “偏印格成立,” “扶抑取土（克水、耗身）,” and “这不是算错了.” The pressure planner preserves some qualifications but still says 土克/耗水 and then describes 水生木 as 耗. Neither response enters the claim catalog or final text. ToolOrchestrator discards planning prose, and the final order request is built from local catalog entries.

This is the strongest reason to attribute the improvement to the new representation and rendering boundary, rather than a better prompt or improved model judgment. Other routes still use free prose plus the existing verifier, where earlier false acceptance remains a known limitation.

## Actual recovery paths

`claims-no-birth` has no receipts or actual tool calls. Its planner merely writes tool-like prose with `domain: career`; that text is ignored. The local final response correctly requires birth information instead of pretending execution occurred.

`claims-tool-failure` does execute `get_domain(domain: 事业)`, call ID `call_00_5nF3FZqGPkp5oE0gy99f1825`. Its writer history contains the paired tool result `{"error":"synthetic_engine_failure"}` and zero successful receipts. Thus this case exercises a genuine injected execution failure, unlike the earlier round-3 no-call case. The native unavailable response preserves supplied birth information and does not fabricate chart facts or an original cast.

## Independent boundary tests and issues found during review

`native/Core/Tests/SujiCoreTests/TypedClaimBoundaryTests.swift` adds 23 independently authored tests, passing with zero failures at 16:09:50 Asia/Shanghai on 2026-09-19. The run used a separate scratch build at `/tmp/suji-typed-review-build`; log `/tmp/suji-typed-review-tests.log`.

Coverage includes immutable rounds 3/4, all four context dimensions, imports without contexts, conflicting/duplicated domain receipts, errors and unrelated tool names, legacy unqualified labels, absent/upgraded certainty fields, injected model prose and unknown IDs, fixed mandatory claims under reordering, 20 independently listed directional element relations, changed exposure columns, unsupported trace bases, conditional quotation prerequisites, weak/strong branches, and native missing-input recovery. Further tests require the named school's actual policy, resolve every local rule's source file, and check punctuation normalization without altering source conditions. Current hidden-stem array ordering was also compared with all 12 `ROOT_HIDDEN_GAN` tier orders and agrees.

Three implementation issues raised by this independent review were fixed by the implementation agent:

1. A contradictory `yongShenGan`/element could still render a confident trace. The catalog now rejects the mismatch; an independent mutation regression covers it.
2. On retry, a planner may stop because a valid receipt already exists on the **same current user entry**. Taking only new orchestration receipts falsely lost that result. The App now combines the explicitly scoped current-entry cache with newly executed receipts, while stale context checks remain. The regression uses real ToolOrchestrator returning `.text`, with an older question carrying a conflicting receipt, and confirms only the current question's receipt survives. This is a Core composition regression plus App source inspection, not a UI retry test.
3. Ordering transport failure could discard an already usable local catalog. `compose` now returns the complete local answer with `selection-unavailable`, while explicit and post-response task cancellation still stop delivery. Independent async tests cover both cancellation forms and a transport error.

The second and third fixes were made **after the round-5 executable above**. Further source-registry/policy evidence, all-four-stem trace coverage, and punctuation changes were also added after that binary. They are covered by the later offline tests and must not be attributed to this live report. A subsequent live run should retain its own executable hash and report file.

## Remaining experience and generalization limits

The final answers directly address the requested distinction and retain useful chart-specific explanation. They are more reliable but more repetitive than an ideal reading: the pattern paragraph repeats candidate limitations, and the 调候 paragraph repeats source/selection limitations. In round 5 it also contains a doubled `。。` caused by joining a condition that already ends in punctuation; this was reported for correction in the next build. Preserve the full source conditions in evidence while improving sentence-level presentation; do not reintroduce a free model rewrite merely to shorten the answer.

The route is deliberately narrow: the current question must explicitly compare 扶抑 and 格局用神. Follow-ups without those terms, broader personalized interpretations, 紫微、六爻、奇门, and unsupported mixed questions retain the previous path. Conservative unavailable results and unsupported trace bases are limitations to measure as the catalog grows, not evidence that a complete adjudication has occurred.

The typed catalog preserves the engine's bounded claims; it does not prove every underlying algorithm, edition, historical timezone, or prediction claim correct. This checkpoint materially resolves the demonstrated candidate-upgrade and directional-relation failures **inside this route**. The broader interpretation-quality goal remains unfinished.
