# First-cast question confirmation (F6a)

This batch addresses an input-integrity failure, not complete event adjudication. Cross-turn clarification/rebinding, Qimen conditional timing, broader Liuyao efficacy and final core acceptance remain open. No Qizheng Siyu, independent lunar-mansion or zodiac module is added.

## Retained failure

The first `qimen-question-conditions` case in `native/Engine/validation/reasoning/core-f4-final-results.json` explicitly asks about signing a new office lease. The actual provider call `call_00_38IbWgAki7a6Um1N8aoe8763` retained the question, `questionType:event`, `subject:self` and `timeHorizon:near`, but omitted `event`. The resulting engine report correctly treated the event as missing. The archived provider result is unchanged.

The permanent test preserves that call. It requires an explicit edit before confirming event mode, then verifies that `签下新办公室租约` reaches the actual bundled Qimen and Liuyao engines. No regex invents an event, subject, or partner from gender.

## Delivered behavior

The SwiftUI chat pauses before the first uncached Qimen/Liuyao calculation and shows the original question plus editable proposed question, subject, category, event and time horizon. The user can correct the model's suggestions. Event mode requires a nonblank event (up to 200 Unicode scalars); the question is limited to 1600. Explicit “仅核对盘面” permits an absent event. Unknown subject and unspecified horizon remain unresolved, visibly described as such. Confirmation does not establish a chosen 用神 or any date/outcome.

The orchestrator validates the entire proposed batch before requesting confirmation, prepares each new method once, checks returned identity/schema/context and saves all confirmations before invoking any tool. Duplicate aliases share accepted arguments. Save errors or cancellation prevent calculation. Confirmations retain the proposed call, accepted call, source user-entry UUID, context, purpose and confirmation timestamp. The original question timestamp remains the cast reference time.

Failed/no-result retry uses stored confirmed arguments. Completed receipts take priority and are neither reconfirmed nor recast. Context/entry mismatches fail closed; optional metadata preserves decoding of old archives. Same-call repeated completion and stale sheet callbacks do not resume a continuation twice. Account/birth changes are checked again at confirmation, persistence and execution.

Confirmed intent is carried as user context, separately from calculation evidence, into writing, history replay and verification. The writer explicitly prioritizes corrected inputs and reference-only scope. The verifier receives confirmations before the bounded original question: independent review demonstrated that appending them after a maximum-size original silently truncated them. The permanent regression passes two maximum-size supplementary-plane confirmations through the real `ReadingVerifier.messages` builder. Independent probes additionally cover BMP and six-byte JSON-escaped scalar inputs.

## Validation and limits

- Core regressions exercise the archived omission, unknown/reference-only context, invalid lengths/selections, whole-batch validation, mixed methods/aliases, cancellation, wrong identity/scope/schema, failed persistence, saved-argument retry, completed-chart reuse, archive compatibility, actual engine inputs, intent replay and verifier capacity.
- Native service tests use the real `ChatSession`, `AppStore`/SwiftData, bundled JavaScriptCore engine and `ChatClient` request parsing. A local URLProtocol returns the archived planner-shaped omission; authentication/provider transport is synthetic. They verify no receipt before confirmation, corrected event, saved metadata, restored retry, cancellation and account isolation. Gate tests also cover outdated callbacks and double taps.
- The DEBUG-only UI fixture uses the production ChatView/confirmation sheet, orchestrator and actual bundled engine, and labels its data synthetic. It sends no AI request and uses no real account. UI tests cover disabled confirmation for the missing event, editing and actual cast, and cancellation at the largest accessibility text size.
- Independent review scripts/results/source hashes are under `native/Engine/validation/reasoning/f6-independent-review/`.

No new live-provider or deployed-Supabase end-to-end claim is made. Confirmation establishes what the user accepted, not that a model extracted every nuance, that arbitrary text contains only one event, or that free prose is fully verified. Older completed casts are retained, not retroactively reinterpreted. Supplementing a question in a new conversation turn still needs the separate F6b original-chart re-adjudication flow.

Final local counts and remote commit acceptance are recorded in the core completion plan when available.
