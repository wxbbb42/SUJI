# 有时 · SwiftUI

A standalone native iPhone app for daily rituals, reflection and a quiet breathing space. All screens use SwiftUI; the existing deterministic TypeScript algorithms run locally through JavaScriptCore. No Metro, WebView, React Native runtime or server is required to launch.

![Native simulator screens](Documentation/overview.png)

## Open and run

1. Open `native/Suji.xcodeproj` with Xcode 26 or later.
2. Select the **Suji** scheme and an iPhone simulator, then Run.
3. For a physical iPhone, set your Apple development team for both **Suji** and **SujiWidget**, register their bundle identifiers and the shared group `group.app.suji.native`, then run on iOS 18 or later.

The generated project, local Swift package, engine bundle and app icon are included. Signing is deliberately enabled on the simulator because Keychain and App Group access require entitlements. Do not use `CODE_SIGNING_ALLOWED=NO` for runtime validation. The `SUJIDEV123` application identifier in `App/Simulator.entitlements` applies only to simulator builds; physical builds use Xcode's provisioning.

```sh
python3 native/scripts/generate-project.py
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath native/DerivedData build
```

## Product flows

- **今日**: local-calendar ritual with continuous paper curl, an accessible reveal button, saved daily quote/action, seven recorded days, a real share image, and mood notes.
- **问道**: native streamed replies, stop/retry, persistent conversation history, eight deterministic tools, expandable evidence, six-line hexagrams and the traditional spatial qimen grid.
- **静心**: 3/5/10-minute breathing sessions, pause/resume, independent rain/stream/wind/fire gains, 24 seasonal combinations, standalone playback and sleep timer. Sounds are original procedural synthesis; see `Resources/AUDIO.md`.
- **我的**: birth records, true solar time, four pillars, five elements, twelve ziwei palaces, annual/decadal content, candidate-time comparisons with explicit adoption/undo, relationship insights, journal editing and monthly reflection.
- **Settings**: warm paper, deep ink, celadon and system appearance, tone and AI provider, account-scoped local storage, explicit cloud profile sync, versioned archive import/export, morning and seasonal notifications, and deletion of the current local notebook.
- **WidgetKit**: small/medium home-screen widgets share only the current daily card. At local midnight an old snapshot becomes an invitation to open the app; yesterday's card is never labelled as today's.

AI reflection is user initiated. The app explains when birth-derived data, messages or journal entries are sent to the user's selected service. There are no simulated AI replies. Model credentials stay in the iOS Keychain and are separate for each local account scope.

## AI configuration

In **我的 → 设置**, enter an HTTPS service URL, model and API key. Chat Completions and Responses endpoints are supported, including Azure endpoint URLs. Authentication automatically uses Azure `api-key` for Azure hosts and bearer authentication for standard compatible services. Real provider requests require your own configuration.

## Accounts and migration

The optional `Resources/PublicConfig.plist` contains only `SUPABASE_URL` and `SUPABASE_ANON_KEY`. It is ignored by git. To reuse the old app's public configuration from `.env`/`.env.local`, run:

```sh
python3 native/scripts/configure-public.py
python3 native/scripts/generate-project.py
```

Private model keys and Supabase service-role credentials are never copied. Configure `suji-native://auth/callback` and `suji-native://auth/reset` as allowed redirects in the existing Supabase project's auth settings before using Google OAuth or password recovery. Email/Google and the existing `profiles` table are supported; no production schema changes are made.

The SwiftData notebook is stored in the app’s private container, with CloudKit disabled. Only the daily widget snapshot is written to the App Group. A prerelease shared notebook, if present, is migrated into the private store after a verified private backup; existing private rows win conflicts, and unrelated shared files are retained. Switching accounts saves the active notebook and loads an independent `local` or `user:<id>` notebook. Cloud push/pull is explicit. The existing cloud schema restores birth metadata, onboarding state, model URL and model name only; it does not contain conversations, journals, rituals or AI keys.

A separate app cannot automatically read the old React Native sandbox. Import accepts the native version-1 JSON archive and exported Zustand containers named `suiji-user-store` and `suiji-chat-store` (or `userStore` / `chatStore`). Old API keys and derived chart caches are discarded. If an old installation has no export facility, cloud recovery restores only the fields above. Keep an external backup before replacing a notebook.

## Verification

```sh
# Domain, native engine parity, streaming/network, archives, clocks and scheduling
TZ=America/Los_Angeles swift test --package-path native/Core
# Keychain, SwiftData account isolation, widget payload and native UI flows
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
# Original algorithms and TypeScript baseline
npm test -- --runInBand
npx tsc --noEmit
```

UI tests use an in-memory notebook via a Debug-only test launch argument and attach actual simulator screenshots. They do not overwrite a user's persistent notebook. The test run contains no live AI/auth requests with user credentials. See `VERIFICATION.md` for executed results and remaining physical-device/online checks.

To regenerate the deterministic engine and independent Node fixtures:

```sh
npm ci --prefix native/tooling
node native/Engine/build.mjs
```

Fixtures compare the original Node algorithms running in Beijing time with JavaScriptCore under a different host timezone, including midnight, night-zi, leap-day, longitude and solar-term boundaries. Equality is evidence of migration parity, not validation of traditional claims.

## Method boundaries

Birth calculations currently require civil Beijing time (`Asia/Shanghai`) with explicit longitude. Historical daylight-saving and worldwide timezone conversion are not validated. The 23:00–23:59 calibration path is explicitly unavailable because the old candidate engine does not support it. Qimen and several pattern/timing rules retain MVP approximations; their metadata remains visible. Relationship views show interpretable stem/branch relationships instead of an unsupported compatibility score. The existing algorithms contain distinct traditional interpretations; forecasts are cultural reflection, not medical, financial or life-decision advice.

The app is not an App Store release. Real device haptics, prolonged audio quality/background behavior and live account/provider delivery need device credentials and final release testing. Paid subscriptions and gift-commerce were deliberately excluded from this approved rebuild.

## Visual direction

The final native interface follows the user's [Figma moodboard](https://www.figma.com/design/Nk1dbVHGGPwvg0JwjxS5v6/Untitled?node-id=1-17): cream paper, olive ink, botanical detail and editorial whitespace. It keeps native TabView, NavigationStack, segmented controls, sheets and forms. The original ginkgo illustration was generated with Azure GPT Image 2; asset provenance and prompt are documented in `Resources/ARTWORK.md`.

The paper ritual bends continuously with the user's drag, returns below the threshold, and completes with restrained feedback. [Actual simulator motion](Documentation/ritual-drag.mp4) is included. Reduce Motion keeps an equivalent reveal operation. The design comparison and accessibility evidence are in `design-qa.md`.

## Typography

Chinese editorial text uses bundled **Noto Serif SC**, Copyright 2012 Google Inc., under SIL Open Font License 1.1. The font is distributed with its license at `Resources/Fonts/OFL.txt`; it is loaded offline and respects Dynamic Type. Source: [Google Fonts / Noto Serif SC](https://github.com/google/fonts/tree/main/ofl/notoserifsc). Body text and controls use the system font.
