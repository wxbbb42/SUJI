# Typed reading presentation — independent product and Impeccable critique

Scope: native Chat, the qualified Bazi framework comparison, its short follow-up, calculation-evidence navigation, and a failed-calculation recovery state. Reviewed against `.agents/skills/impeccable/SKILL.md` and the existing `.impeccable.md` audience/brand context. The paper/olive palette, Noto Serif SC headings, and system body font remain the existing product direction.

## Findings and changes

| Finding from the initial implementation | User impact | Change |
| --- | --- | --- |
| P1: Chat initialized in 倾诉 even when the retained question was 命理. The baseline screenshot shows the wrong selected segment directly below a Bazi reply. | A natural follow-up could enter the wrong response path after reopening Chat. | Restore the latest user turn's valid `analysisMode` on initial presentation and account-scope changes. A user's later manual mode choice is retained while the view remains alive. |
| P2: About 700 Chinese characters appeared as six paragraphs in one body text element. “启发式”, “候选”, and source conditions were embedded at the same visual level as the results. | Scanning could promote a tentative result into a fact; method comparisons required rereading. | Render persisted local sections as a continuous reading page: serif headings, explicit qualification labels, and the complete body. No cards around each section, no collapsed qualification, and no model-written presentation summary. |
| P2: Calculation evidence appeared only after the full reply in a small text link. | Checking a result required scrolling several screens before finding the supporting record. | An evidence link at both ends of a structured reply; minimum 44-point row, full-width hit region, descriptive accessible name/hint, and native navigation. |
| P2: Every appended reply scrolled to its end, including a complete local document arriving at once. | The first visible content could be the last caveat rather than the start of the explanation. | A new structured reply scrolls to its beginning while following the reply. If the reader has manually scrolled away, arrival does not steal their reading position. A final synthetic arrival test reproduces draft assignment → reply persistence → draft clearing → working=false and verifies the opening heading stays visible. Manual-scroll preservation and real streaming remain outside that test. |
| P2: A retained tool result always used “不会重新起卦” wording. | Bazi, failed calculations, and imported history could imply a saved reusable cast that did not exist. | Failed/error-only results do not get a retained-calculation panel; cast wording requires a successful current-context cast receipt. Non-cast results and historical records have distinct labels. |
| P2: Login/retry actions had small text-only targets; the long login sentence consumed much of the viewport at AX XXXL. | Harder action targeting and less room to read enlarged text. | Minimum 44-point login/retry targets, a concise equivalent login label at accessibility sizes, and an explicit accessible composer container. |

The section contract is `ReadingDocument.Section`: closed local title, immutable full body, qualification, and field evidence. Presentation does not extract values from generated prose or shorten a claim. The body still carries its qualifications when copied or archived. A “复制完整回信” action preserves the whole document after splitting it into independently navigable text sections.

## Evidence and limits

All images in `native/Documentation/typed-reading-presentation/` are real iPhone 17 Pro iOS 26.5 simulator captures. The fixture is guarded by DEBUG plus both `--ui-testing` and `--reading-presentation-fixtures`; storage is in memory and account restoration is disabled. It uses synthetic birth input, the actual local engine and local Bazi renderer. The short follow-up is a locally rendered focused document. The failure is an explicitly injected presentation state; a separate delayed-arrival fixture reproduces the completion observation order. **None is a real AI response or a signed-in network test.** The visible banner says so.

The three `00`–`02` before captures were taken before presentation changes. Their fixture banner was initially outside the navigation stack, which displaced the title in those images. That fixture-only placement was corrected before the after captures; it is not evidence of a production navigation defect. The original body, selected mode, and absent top evidence link are visible and comparable.

The default light and dark checks cover the original question, typed sections, complete qualified bodies in the accessibility tree, navigation to calculation evidence and back, the full-copy action, and the still-reachable composer. AX XXXL additionally verifies headings and qualification labels remain within horizontal bounds and reachable by scrolling. Recovery checks cover a zero-result state, absence of a misleading calculation-evidence link, reachable retry, and navigation to account settings. These tests do not exercise an actual retry transport or produce a new model answer.

The qualification label uses the existing secondary text on paper: token-derived contrast is 4.525:1 in light mode and 8.092:1 in dark mode. Body text is 11.545:1 and 14.518:1 respectively. These ratios are computed from the exact theme RGB values, not a claim about every antialiased screenshot pixel. Meaning is also present in words, not color alone.

Manual VoiceOver speech/rotor/gesture operation, physical-device readability, iOS 18 runtime behavior, and authenticated streaming/error recovery remain outside these captures. Header traits, readable text labels, and action names are present in the inspected accessibility trees; that is narrower evidence than a manual VoiceOver pass. Source/attachment hashes and the exact test bundles are recorded in the capture manifest. The artifacts contain 27 screenshots and 27 corresponding accessibility trees.

## Remaining product work

The local full comparison is intentionally detailed and still requires several screens. The separate short follow-up is the useful way to reduce information load while retaining the candidate/heuristic distinctions; typography alone cannot fix overly broad answers. No claim is made here that all interpretation methods are accurate, that a candidate is established, or that display labels validate the underlying calculation. Continuity and false-accept evaluation remain Core/live-evaluation responsibilities, documented separately.

## Completed verification

- `/tmp/suji-reading-presentation-baseline.xcresult`: one pre-change capture test passed.
- `/tmp/suji-reading-presentation-final.xcresult`: five presentation UI tests and 13 hosted tests passed. This is the light/dark/AX XXXL, focused follow-up, recovery, evidence-navigation and copy build.
- `/tmp/suji-reading-presentation-arrival.xcresult`: the final arrival UI test and all 13 hosted tests passed after the draft-clear scroll fix and final Core polite-follow-up routing change. The older five-test layout capture is retained with its own binary/source hashes; it is not relabelled as the newer binary.
- Current compiled-input aggregate: `1058aaf2f8373203e6c1591098fe95e489fe447009fc337e2a9c350d3ae0215c`; every listed input matched the working tree when this review closed. Final app debug dylib: `371982ad26e7f3723a6ed58dbf03a7a6dca52159b3c7271432b6a86078a3b9f3`.

A diagnostic attempt failed because the test gesture overshot its target at AX XXXL; the capture helper now uses a slow drag with an end hold. The final recovery and qualified-reading checks passed with that corrected helper. The initial actor-isolation compile issue in the injectable session initializer was also resolved before these successful builds.

Reproduce the final suite with the repository's normal signed simulator setup:

```sh
python3 native/scripts/generate-project.py
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath native/DerivedDataSigned -parallel-testing-enabled NO \
  -only-testing:SujiUITests/ReadingPresentationUITests -only-testing:SujiTests test
```

The six UI tests are one new family in this change. The full unrelated app UI suite was not repeated. Existing default appearance tokens and font resources were preserved.
