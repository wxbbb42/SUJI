# Native rebuild verification

## Account-first setup and persistent natal dossiers — 2026-09-20

- Validated implementation: `a39838df3f0c75458d30a7e21e102f7db634d264`; [GitHub Actions 35489808350](https://github.com/wxbbb42/SUJI/actions/runs/35489808350) succeeded for engine, Swift Core and native app jobs.
- Engine typecheck, **37 suites / 592 tests**, reproducible bundle and **13 Node/JavaScriptCore parity fixtures** passed. Backend regression suite: **14 tests**.
- macOS Swift Core: **219 tests**, with `TZ=America/Los_Angeles`; iOS simulator: **18 hosted integration tests + 2 UI tests**, zero failures. The app and widget compiled on the remote runner. Local SwiftPM remains blocked by the existing Xcode license gate.
- New checks cover persisted-chart round trips without natal engine calls, dynamic Lichun reference dates, owner/birth/version mismatch, damaged records, concurrent first-build coalescing, restart reuse, archive/deletion boundaries, automatic cloud recovery, offline sync retry, login gating and birth confirmation through a real native form.
- Account HTTP tests use URLProtocol fixtures; they do not register or modify a real user account. UI birth data is synthetic. Existing guest records stay separate and require explicit import.
- Screenshots in [Documentation/natal-dossier](Documentation/natal-dossier) show the login gate and enabled birth-confirmation form. `03-dossier-during-dismissal.png` captures the built dossier while the birth sheet is animating away; it is evidence of the transition, not a polished stationary screen capture.
- Architecture, sync and recalculation boundaries: [natal-dossier.md](../docs/mingli/natal-dossier.md). Seven Luminaries/Four Residuals and independent mansions remain deferred; no zodiac module was added.


Date: 2026-09-19. Branch: `codex/swiftui-rebuild`; original Expo baseline: `08574c4`.

This is a native implementation and simulator verification record, not an App Store release certificate. Screens run in SwiftUI, deterministic TypeScript code runs locally in JavaScriptCore, and native services own persistence, audio, credentials and networking.

## Professional calculation audit before further UI work — 2026-09-20

Baseline `805683f`. Fixed two Bazi occurrence-identity defects (same-named peer stems were discarded, and one adjacent rescue covered a remote repeated stem). Qimen now uses explicit Beijing standard time when no divination longitude is supplied; explicit apparent-solar inputs remain supported. Clock policy and projection provenance are returned. No UI, Swift Core source, backend or model-prompt changes.

- Typecheck and **36 suites / 588 Engine tests passed** (`/tmp/suji-professional-engine-all.log`), including 89 newly added tests. Each production fix has observed failing-before/passing-after regressions and positive/negative controls.
- Independent Astronomy Engine 2.1.19 / Gregorian JDN references: **2,400 Jie instants / 4,800 four-pillar comparisons** at ±120 seconds, zero differences. Maximum term-time disagreement is **62.355 seconds**; this is not second-level boundary certification or resolution of the 2057 lunar discrepancy.
- **62 public historical birth comparisons** match independent expectations and now run in CI. Four IANA historical time-zone conversions match the recorded UTC offsets. Family-memory/conflicting times and ±30-minute sensitivity are retained; no biographies were fit and no public data was sent to a model.
- **432 Bazi table comparisons**, Liuyao **3,840** day-cycle and **9,216** month/day charts, 64-hexagram hidden-line checks, fair three-coin enumeration and four independent Qimen hand charts are documented with source limits. This verifies selected calculation rules, not interpretation completeness or predictive accuracy.
- Engine revision `3919ab954fc0715af1e3371d19cea6c2cab5b494d78d6e0497109282304d4852`; bundle SHA256 `bd0338c88ac5a3ec35f0959bbe5b76319c41eefa2cb5a767b2c627a2db8e201a`. The production bundle passes both new Qimen midnight cases; bundle, 11 parity fixtures and notices regenerate byte-for-byte.
- Knowledge registration validates **49 sources / 54 claims**, adding eight conditional grounding entries and correcting overbroad engineering-rule descriptions. These repository entries do not imply new runtime retrieval or implementation of missing rules.
- SwiftUI-only guard passed. Local Swift/Xcode is blocked by the Xcode license gate; no license was accepted and no new local Swift/UI pass is claimed. Current-commit macOS GitHub Actions runs Swift Core plus JavaScriptCore parity after push; verify its commit identity separately from earlier successful builds.
- Full scoring, exact cases, reproduction and remaining professional gaps: [professional audit](../docs/mingli/validation/professional-audit-2026-09-20.md). Bazi 60/100, Liuyao and Qimen 50/100 use equally weighted calculation-auditability and interpretation-completeness judgments, not statistical accuracy.

## Auditable strength evidence and multiple reading topics — 2026-09-20

Prompt `suji-grounded-reading-10`; existing closed-claim/document protocol versions retained. The engine now emits per-pillar arithmetic and separate month/root-matrix evidence. Integer tenths fix an actual 1990-03-15 12:00 tie that floating-point accumulation incorrectly classified as weak. Original weights and the `>=` threshold remain unchanged; this is not a complete traditional strength model.

- Engine typecheck and **31 suites / 499 tests passed** (`/tmp/suji-strength-engine-final.log`). Actual date regression, neighboring hours, day-master inclusion, five-element directions, root-label boundaries and tool projection are covered.
- **216 Swift Core tests passed** under `America/Los_Angeles` (`/tmp/suji-strength-core-final-v10-r2.log`). This includes trace tampering, source identity, mixed-topic persistence, brief text and refusal/continuity boundaries. A 144-case real month/hour grid checks standard/brief document round trips; the largest evidence value is 3,539 bytes against the 6,000-byte field limit.
- Actual Swift **round 10** retains 3 synthetic conversations / 14 turns and 14 provider ordering requests. All documents bind their field values to one current receipt. Three topics, exclusion of pattern, shorter wording and later expansion behave as recorded. **The direct root question still repeats a generic count summary**; trace facts are expandable, but direct semantic coverage is incomplete. The immutable report and separate review explicitly retain this failure.
- Independent code review found refusal-scope regressions: polite wording and coordinated exclusions retained unwanted topics; a first fix also confused factual negation with topic refusal. Permanent tests observed 9 initial and 4 follow-up failed assertions before the fixes. The reviewer independently compiled 14 final probe questions and closed the P2 finding. **Round 11** retains 18 intermediate turns; final-binary **round 12** verifies nine turns for polite/list/postposed refusals, factual negation and subsequent brief answers. Reports preserve both build identities and outstanding content gaps.
- Current engine revision `6ac5ff6a948b2b2d20459b81d5fbfb0cba8f1807986032be3bf86ccac2ca6b09`; bundle SHA256 `e0db8fcb48abc2ab67aafbf7ec268cd6a3577529928ccea55f49f4bd5e1a7792`. The final round-12 executable SHA256 is `bebda49cebe216e29c57350a4bd818dd2899b755395102099e8d21acb04e8143` and matched the local binary at the post-run check. Earlier hashes remain in each immutable report.
- Auth/quota were mocked through the actual backend handler. The typed route uses model ID ordering plus local rendering, not SSE drafting or a model verifier. This does not establish deployed authentication, SwiftUI network E2E, or predictive accuracy.
- Signed simulator App/Widget and **13 hosted tests passed** on the final production code. The verified and accessibility runs together pass **six distinct UI tests**: light chat/evidence, normal and AX XXXL Profile, brief qualifications, the existing AX XXXL reading journey, and large-type structure heading/metadata. The latter run passes all three selected tests; the earlier run's metadata lookup failure is retained and resolved by locating the actual merged accessibility element. Dark and the original chat XXXL trace tests passed on the preceding build. **25 screenshots and 25 accessibility trees** preserve these different source identities in [the capture manifest](Documentation/strength-trace-presentation/capture-manifest.json); they are synthetic fixtures, not live model replies. Final production library SHA256: `fee1ed51148e96912501bc264a6be97d59e0b89afbcd7c31237886e6dcaa3a1a`.
- Read-only regeneration from the final engine source reproduces the bundle byte-for-byte. The SwiftUI-only guard and whitespace checks passed; no configured private backend credential matched tracked or new nonignored files.
- Scope, actual body lengths, sources and outstanding content issues: [integration evidence](../docs/mingli/validation/strength-evidence-integration.md), [independent coverage review](../docs/mingli/validation/reading-coverage-critique.md), and [native presentation review](../docs/mingli/validation/strength-trace-ui-review.md). Broader interpretation validation remains incomplete.

## Focused reading continuity and native presentation — 2026-09-19

Prompt `suji-grounded-reading-9`, local document `suji-reading-document-1`. Known Bazi framework questions and supported adjacent follow-ups use a local one-call plan, current-context receipts and qualified closed claims. Local documents persist with the answer; external imports drop their authority. The native reading view exposes section qualifications and calculation evidence while preserving complete text.

- **198 Core tests passed** under `America/Los_Angeles` (`/tmp/suji-continuity-core-final.log`): includes 11 document/scope/import tests, eight independently authored continuity/local-plan tests, and a six-turn actual-engine integration. Earlier independent failures drove narrower intent matching and per-attempt retry IDs.
- Actual Swift **round 7** retains a failed five-turn run: model planning skipped current facts and a later free-prose verifier again accepted a wrong 克/耗 explanation. **Round 8** uses the shared local plan: five consecutive focused replies each acquire one current receipt; missing birth and an injected tool failure yield the appropriate local recovery. Five provider requests, all for closed-ID ordering. Auth/quota are mocked; this is not deployed authentication or SwiftUI network E2E.
- Final **round 9** exercises six turns including polite simplification and a climate-only simplification; all retain current receipts and their topic, using six provider ordering requests. Round-8/9 report/executable hashes and full scope: [reading continuity validation](../docs/mingli/validation/reading-continuity-validation.md). The current runner matched the evaluated binary at final check. Candidate, heuristic and source-transcription limits remain attached; this does not complete the broader interpretation-quality goal.
- Final signed App/Widget and **13 hosted tests passed** (`/tmp/suji-reading-presentation-arrival.xcresult`), together with one delayed-delivery UI test covering complete reply arrival and top positioning. The preceding layout build passed **five UI tests** (light, dark, AX XXXL, focused follow-up and failed-result recovery) in `/tmp/suji-reading-presentation-final.xcresult`. The 27 screenshots and 27 accessibility trees distinguish both builds; the final source manifest matched current inputs.
- The independent [native presentation review](../docs/mingli/validation/typed-reading-product-review.md) records actual synthetic-fixture screenshots, light/dark/AX XXXL readability, evidence navigation, short follow-up and empty-result recovery. Its capture manifest distinguishes baseline and final source/binary identities. Manual VoiceOver, authenticated streaming arrival and physical devices remain unverified here.
- The [2057 investigation](../docs/mingli/validation/hko-2057-resolution.md) independently confirms the HKO PDF/TXT date table and the official near-midnight warning. Production and DE440 TT new-moon times differ by 0.862 seconds, but future ΔT leaves the 30-day calendar disagreement unresolved. No date patch or engine/backend change was introduced.
- SwiftUI-only guard, script syntax and whitespace checks passed. No private backend key matched tracked or nonignored candidate files. The engine bundle remains unchanged.

## Locally rendered Bazi framework claims — 2026-09-19

Prompt `suji-grounded-reading-8`, claim protocol `suji-bazi-claims-1`. Explicit 扶抑 / 格局用神 comparisons now compile current-context receipts into complete qualified claims. The model may order closed IDs; local rendering preserves candidate/heuristic status and typed five-element directions. Other questions retain the existing writer/verifier path.

- **178 Core tests passed**, including 23 independently authored claim-boundary/retry/cancellation tests and one actual-engine test across 12 birth months (`/tmp/suji-claims-core-final.log`, `America/Los_Angeles`).
- Final signed App/Widget build and **13 hosted tests passed** (`/tmp/suji-claims-hosted-final.xcresult`). No new SwiftUI network E2E or screenshot/VoiceOver claim is made.
- Actual native rounds **5/6 retain 6 synthetic cases and 15 provider requests**. Two successful comparisons in each round keep qualified source claims; round 5 additionally covers missing birth and a real injected tool failure. Final round-6 binary: `391ca87003fd602b782a5d5eac68a362a90a28d7469d06e6011c920f209d393e`. Auth/quota are mocked; the claim route uses completion for ordering and local rendering, not SSE writing/model verification.
- The model's discarded planner prose still contains old errors. This is a representation boundary improvement for one path, not a general model-accuracy score or completion of the interpretation-quality goal. Current-entry retry caches and ordering transport failure are handled locally; cancellation and account/birth scope checks remain.
- Engine/backend sources and engine bundle are unchanged. Details and independent reviews: [typed claims validation](../docs/mingli/validation/typed-claims-validation.md).

## Structured verification and actual native evaluation — 2026-09-19

This checkpoint uses prompt `suji-grounded-reading-7` and verification protocol `suji-verification-2`. Field corrections require current source values, exact candidate text and locally supported binding; invalid reviewer opinions get one bounded recheck and are not forwarded as facts. Missing results, existing birth data and reusable charts have distinct recovery messages. The App and evaluator share tool-selection rules.

- Final Core: **154 tests passed** under `America/Los_Angeles` (`/tmp/suji-mingli-core-v7-final.log`), including 32 independently authored adversarial protocol cases, six immutable real-output regressions and ten recovery-state tests.
- Four **actual Swift** synthetic live rounds retain full batches, SSE counts, writer/verifier messages and receipts; 72 total provider requests. Auth/quota are locally mocked through the real backend handler, not deployed Supabase authentication. Fixed multi-moving coin input is evaluation-only, with a separate effective bundle hash.
- These runs exposed and helped repair negative-health false rejection, UTC label errors and invented recovery state. They also show continuing false acceptance of established-pattern wording and five-element explanations. **The full interpretation-quality goal is not complete.** See [current protocol evidence](../docs/mingli/validation/native-verifier-validation.md) and the four independent reviews; accepted counts are not accuracy scores.
- Engine source/bundle and backend are unchanged in this checkpoint. The existing 475 engine tests and 14 backend tests below remain earlier evidence. Native-only guard passed; no private backend credential matched the tracked/new nonignored files.
- Signed App/Widget and **13 hosted tests passed** on the final v7 Core (`/tmp/suji-mingli-v7-final-hosted.xcresult`). **Five UI tests passed** on the preceding v6 build; UI sources are unchanged, and 20 screenshots/AX trees preserve their distinct build identity. Final UI/hosted evidence is recorded separately in [the detailed UI review](../docs/mingli/validation/detail-ui-accessibility-review.md), including each build hash. UI screenshots use visibly labelled synthetic records, not actual model replies.

## Mingli validation and SwiftUI-only follow-up — 2026-09-19

Branch: `codex/mingli-validation`. Checkpoint `c89d93c` and its follow-up contain the native calendar, readings, UI and research changes. SwiftUI remains the only maintained client; CI rejects retired client paths and Expo / React Native dependencies. See [the validation plan](../docs/mingli/validation/PLAN.md) and [harness evidence and limits](../docs/mingli/validation/harness-final-validation.md).

- Engine typecheck passed; **30 suites / 475 tests passed**, including 60 Qimen pattern tests (`/tmp/suji-geju-final-tests.log`).
- Final bundled engine: SHA-256 `451036e701144f190def6f733d70b0d7589b95d8586ef02d0d70365c8d3fe9b0`; engine revision `4e1ef94cee4d5cd6fff63a2f36d05cd1c139ff075e81328a32cdb718ee727082`. A second generation of bundle, 11 fixtures and license notices was byte-for-byte identical. Xcode project regeneration also produced no changes.
- Final Swift core under `America/Los_Angeles`: **106 tests passed**, including Node/JavaScriptCore parity, actual Swift replay of historical provider decisions, invalid batch atomicity, stable cast retries and read-only reflection history (`/tmp/suji-mingli-core-verified.log`).
- Final signed iPhone 17 Pro simulator App/Widget build and **13 app-hosted tests passed** (`/tmp/suji-mingli-hosted-verified.xcresult`). Older race stubs were updated to return a real engine contract, preserving their delay and scope assertions.
- Backend **14 tests passed** earlier in this validation stage (`/tmp/suji-mingli-backend-final.log`); backend code has not changed since. Public configuration **4 Python tests passed** in final verification. The native-only repository check and `git diff --check` passed.
- Production-bundle Qimen regression at `2024-02-04T04:00Z` no longer emits the false ground-stem 戊击刑. Value-star/value-door palaces remain 3; the duty-door label includes only palace 3. Reproducible selected output is in `Engine/validation/research-divination/qimen-geju-regression.json`.
- UI: 21 post-fix screenshots and their distinct build hashes are preserved in `Documentation/mingli-improvements/capture-manifest.json`. The final main journey passed alone; dark/four-tab and XXXL tests passed on an earlier build. The final hosted run compiled the newer receipt details and reflection archive UI; it did not recapture these screens or repeat the whole UI suite.
- Four synthetic direct-provider model rounds are retained. Round 4 reported 8 accepted/3 rejected; independent review found false acceptance and false rejection. Actual Swift replay instead aborts one case before tool execution and renders fact-only recovery for two rejected cases. These counts are execution outcomes, not accuracy scores or a new authenticated end-to-end run.

Official HKO daily comparison covers 1901–2100 (73,049 day rows; 73,000 complete lunar dates). The 2057 30-day discrepancy, uncollated printed editions, heuristic interpretation thresholds, model-verifier fallibility, global historical timezone support, manual VoiceOver and physical-device/distribution checks remain explicit limits. No claim of empirically validated prediction is made.

## SwiftUI-only repository — 2026-09-19

The Expo / React Native client, root app package, Metro configuration, old UI assets, Zustand stores and client-side AI networking were retired after checkpoint `328bcff`. SwiftUI is the only maintained client. Its local deterministic sources and tests now live in the independent `native/Engine` package; historical Expo product documents are marked and archived under `docs/archive/expo`.

- Fresh `npm ci --prefix native/Engine` succeeded with no root `node_modules` or old `native/tooling` dependencies present. The lockfile contains no Expo, React, React Native, Metro, Zustand or Three packages.
- Engine typecheck passed; **22 suites / 187 tests passed** using the Node Jest environment.
- Regenerated `mingli.js` and all **11 parity fixtures are byte-for-byte identical** to the pre-cleanup resources. Existing runtime dependency versions and class-field compilation semantics are preserved.
- Swift core: **64 tests passed**, including JavaScriptCore parity under `America/Los_Angeles` (`/tmp/suji-swiftui-only-core.log`).
- Signed iPhone 17 Pro simulator: **13 app-hosted tests passed** (`/tmp/suji-swiftui-only-final.xcresult`); the managed-AI login/settings UI test **passed** in `/tmp/suji-swiftui-only-ui-recheck.xcresult`. One intermediate UI run lost the onboarding button between its existence check and tap; an isolated rerun passed without code changes. The intermittent startup interaction remains noted, rather than counted as a clean first-pass UI run.
- Backend: **14 tests passed** after a fresh install in `supabase`, including the actual PostgreSQL quota migration.
- Public configuration: **4 Python tests passed** for legacy env migration, canonical configuration precedence and exclusion of private/service credentials. New setups use `SUPABASE_URL` / `SUPABASE_ANON_KEY`; existing local Expo public env names remain migration-compatible.
- Knowledge-base regeneration succeeded (**49 sources / 46 claims**); current source references resolve to the new native locations.

This cleanup changes repository structure and build ownership, not deployed backend behavior or calculation rules. Physical-device and distribution checks below remain outstanding.

## Managed DeepSeek follow-up — 2026-09-19

The app now uses authenticated Supabase → `deepseek-flash` with thinking disabled. User-editable provider/model/key fields are removed. The deployed backend and quota migration are documented in `../supabase/README.md`; this supersedes the original rebuild's user-supplied provider configuration below.

- Swift core: **64 tests passed**, including fixed backend URL, user-session/public-key headers and managed errors (`/tmp/suji-deepseek-core.log`).
- App-hosted regression: **13 tests passed** (`/tmp/suji-deepseek-native.log`).
- iPhone 17 Pro: login-required chat, account navigation, fixed DeepSeek status and absence of model/key input fields **passed** (`/tmp/suji-deepseek-ui-verified.xcresult`).
- Backend: **14 Node/PostgreSQL tests passed**. Auth rejection, fixed model and inference budget, valid tools/history, input limits, SSE, cancellation, timeouts, error sanitization, database permissions and atomic quotas.
- Existing Expo TypeScript check passed; its compiler excludes the separately deployed Deno function.
- Live deployed endpoint: missing user tokens and anon-key-only requests returned **401**; a real signed-in disposable account received a **200** SSE response and completed a real DeepSeek tool-call/result round trip; minute quota returned **429**. Synthetic data only, no emails sent. Test account and personal quota row removed afterward.
- DeepSeek credential is in Supabase secrets and an ignored owner-readable backend env file. It is absent from native source/resources and the app bundle. Legacy notebook provider fields remain decodable but never select the model or endpoint.

Google OAuth/email delivery, real-device networking and release signing remain separate release checks. This follow-up did not repeat the unrelated audio/widget/ritual suite below.

## Original rebuild checks

| Layer | Result | Evidence and scope |
| --- | --- | --- |
| Original Expo/algorithm baseline | 34 Jest suites, 244 tests passed; TypeScript passed | `/tmp/suji-jest-final.log`, `/tmp/suji-tsc-final2.log`. Original tracked sources remain unchanged. |
| Swift core | 62 tests, 0 failures | Independent final review; `TZ=America/Los_Angeles`, scratch build `/tmp/suji-tool-build`. Models, local date rules, breathing clock, archives, Supabase request/PKCE contracts, SSE parsing, cancellation and tool orchestration. |
| Engine migration parity | 11 Node ↔ JavaScriptCore fixtures passed within core suite | Midnight/night-zi, leap day, longitude and LiChun boundaries, asynchronous domain tools, annual forecast. This proves migration consistency, not traditional predictive accuracy. |
| App-hosted tests | 13 tests, 0 failures | `/tmp/suji-figma-small-final.log`; includes safe backup-failure retry, exact artifact selection, SwiftData, Keychain, audio, routing and font checks. |
| iPhone 17 Pro UI | Six tests, 0 failures | `/tmp/suji-figma-ui-final.xcresult`; after Figma refinement. Profile hierarchy then passed focused tests on both devices in `/tmp/suji-figma-profile-final.xcresult`. |
| iPhone 17e UI | Six tests, 0 failures | `/tmp/suji-figma-small-final.xcresult`; normal dark botanical, accessibility chat/profile and full product flows. |
| Final accessibility fixes | One extended journey on each device, both passed | `/tmp/suji-figma-accessibility-final.xcresult`; full title, bounded send icon, reachable input and birth/profile reading at AX XXXL. |

## Behavioral evidence

- First launch requires neither an account nor birth data. Ritual reveal is keyed to local calendar date. UI tests exercise the real drag: a small movement returns the page, a larger movement completes the continuous cylindrical curl. A button supplies the same operation with Reduce Motion or VoiceOver.
- Journal composition, history, archive validation, share preparation and actual image rendering are implemented. The share preview uses the image supplied to the system share sheet.
- A real AVAudioEngine starts in hosted and UI tests. Hosted tests inject interruption begin/end and old-device-unavailable events, checking pause/resume/cleanup. UI tests check the playing state across a home/foreground transition. They do not measure speaker sound quality or emulate a real incoming call.
- Birth changes and account switches discard stale calculations. Disk-backed SwiftData survives rebuilding ModelContainer. Account scope and signed simulator Keychain isolation are tested.
- The production notebook explicitly disables App Group and CloudKit selection. A prerelease shared store is imported only for absent keys; existing private values win. Byte-for-byte record verification and a private JSON/store backup precede shared-store cleanup. Cleanup names are allowlisted; unrelated same-prefix files remain untouched. The failure/retry regression checks that a blocked backup destination retains the legacy store and that retry does not duplicate keys.
- Chat tests exercise provider request/stream contracts, call IDs, history, tool bounds, cancellation, error messages and preserved casts on retries. The UI exercises the missing-configuration recovery path. No synthetic successful assistant response is shown to the user.
- Widget tests verify that only daily-card fields enter the shared snapshot. Notification tests verify scheduling models and durable pending-route consumption. These are lower-level integration checks, not proof of OS delivery.

## Visual evidence

The user's Figma node `1:17` is a five-image moodboard. The app adapts its cream paper, botanical illustration and editorial hierarchy while retaining Apple navigation, forms, sheets and segmented controls. It is not a pixel clone of another app.

- `Documentation/overview.png`: actual simulator screens.
- `Documentation/ritual-drag.mp4`: actual continuous drag/reveal recording.
- `design-qa.md`: combined source/render comparison, dark/celadon and large-type checks.
- `Resources/ARTWORK.md`: Azure GPT Image 2 artwork provenance and local processing.
- `Resources/Fonts/OFL.txt`: bundled Noto Serif SC license. A hosted test verifies that the named font really loads.

Full XCUITest attachments and raw recordings are ignored under `artifacts/`.

## Reproduction

Use Xcode 26.6 with the iOS 26.5 simulator SDK. The deployment target is iOS 18. Runtime tests were performed on iOS 26.5; iOS 18 availability guards were compiled but an iOS 18 simulator was not used.

```sh
python3 native/scripts/generate-project.py
env TZ=America/Los_Angeles \
  CLANG_MODULE_CACHE_PATH=/tmp/suji-tool-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/suji-tool-clang-cache \
  swift test --package-path native/Core --scratch-path /tmp/suji-tool-build
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath native/DerivedDataSigned \
  -parallel-testing-enabled NO test
```

Do not disable simulator signing: Keychain and App Group operations require the included entitlements. Never build concurrently in the same DerivedData directory. UI tests use a Debug-only in-memory notebook and do not replace a user's persistent data.

## Still requires live service or physical-device verification

- Full production account/device coverage beyond the managed DeepSeek smoke check above.
- Supabase email delivery, Google OAuth, token refresh against the real backend, password-reset email and callback delivery; schema and redirect configuration need the user's project settings.
- Real headphones, incoming calls, long background sessions, audio quality, haptics, thermal behavior and device performance.
- OS notification permission denial/delivery and real cold-launch notification tap timing.
- Home-screen widget rendering, OS-controlled midnight refresh and tapping the installed widget.
- Distribution signing, release archive, App Store review and physical iOS-version coverage.

The original rebuild changed no production schema and made no live AI/auth success claim. The managed-AI follow-up above adds a separate usage table/function and verifies the deployed provider path. Subscriptions and gift commerce remain outside the approved scope.
