# Native rebuild verification

Date: 2026-09-19. Branch: `codex/swiftui-rebuild`; original Expo baseline: `08574c4`.

This is a native implementation and simulator verification record, not an App Store release certificate. Screens run in SwiftUI, deterministic TypeScript code runs locally in JavaScriptCore, and native services own persistence, audio, credentials and networking.

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
