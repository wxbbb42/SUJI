# Native rebuild verification

Date: 2026-09-19. Branch: `codex/swiftui-rebuild`; original Expo baseline: `08574c4`.

This is a native implementation and simulator verification record, not an App Store release certificate. Screens run in SwiftUI, deterministic TypeScript code runs locally in JavaScriptCore, and native services own persistence, audio, credentials and networking.

## Executed checks

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

- Real model-provider streaming and errors with the user's URL/key/model.
- Supabase email delivery, Google OAuth, token refresh against the real backend, password-reset email and callback delivery; schema and redirect configuration need the user's project settings.
- Real headphones, incoming calls, long background sessions, audio quality, haptics, thermal behavior and device performance.
- OS notification permission denial/delivery and real cold-launch notification tap timing.
- Home-screen widget rendering, OS-controlled midnight refresh and tapping the installed widget.
- Distribution signing, release archive, App Store review and physical iOS-version coverage.

No production schema was changed. No live AI/auth success is claimed. Subscriptions and gift commerce were excluded from the approved scope.
