# Copilot instructions for SUJI

## Commands

- Install dependencies: `npm install`
- Start Expo dev client: `npm run start`
- Run iOS app: `npm run ios`
- Run Android app: `npm run android`
- Run web preview: `npm run web`
- Run all tests: `npm test`
- Run tests serially: `npm test -- --runInBand`
- Run a single test file: `npm test -- lib/bazi/__tests__/structural.test.ts --runInBand`
- Type-check: `npx tsc --noEmit`
- Ingest mingli knowledge base: `npm run kb:mingli`

Jest uses `jest-expo` and only matches `**/__tests__/**/*.test.(ts|tsx)`.

## Architecture

SUJI is an Expo SDK 54 / React Native 0.81 / React 19 app using TypeScript strict mode and `expo-router`. Routes live in `app/`; `app/_layout.tsx` loads fonts, initializes Supabase auth through `useAuthStore.initialize()`, and defines stack screens. The main product surface is the tab group in `app/(tabs)`: 日历, 问道, 静心, 我的.

UI components are grouped by domain under `components/`, while deterministic business logic lives under `lib/`. The most important split is:

- `components/*`: React Native presentation and interactions.
- `lib/bazi`, `lib/ziwei`, `lib/qimen`, `lib/divination`, `lib/calendar`: local命理 engines and pure logic.
- `lib/ai`: provider config, streaming chat, thinker/interpreter orchestration, and tool handlers.
- `lib/store`: Zustand stores persisted with AsyncStorage.
- `lib/supabase`: Supabase client and profile CRUD/sync.

State is intentionally split. `useUserStore` persists birth data, BYOK AI provider/model/key, onboarding state, and serialized命盘 caches under `suiji-user-store`. `useChatStore` persists recent chat messages separately under `suiji-chat-store` and keeps the latest 100 messages. `useAuthStore` tracks Supabase session/user state and starts profile sync after auth initialization.

Supabase currently stores only profile fields from `lib/store/profileSync.ts`: birth date, gender, birth city/longitude, AI provider/model/base URL, and onboarding state. API keys and derived命盘 caches stay local only; do not add `api_key` or cache fields to cloud schema. Auth is Google + email/password; do not reintroduce Apple Sign-In.

AI chat is BYOK/client-direct today. `app/settings.tsx` writes provider settings to `useUserStore`, `getChatConfig()` maps them to OpenAI, DeepSeek, or custom OpenAI-compatible endpoints, and `app/(tabs)/insight.tsx` chooses orchestration when a命盘 cache exists or 六爻 is forced. `sendOrchestrated()` runs a two-phase flow: Phase A is the thinker with tool calls (`get_domain`, bazi, ziwei, liuyao, qimen) and a max tool loop; Phase B is the interpreter streaming a生活化 answer. A custom `baseUrl` ending in `/responses` uses the Responses API; Azure-style URLs use `api-key` headers.

The命理 engines are local and accuracy-sensitive. `BaziEngine` wraps `lunisolar` plugins and true solar time; `ZiweiEngine` wraps `iztro` and normalizes palace names to include `宫`; `QimenEngine` includes explicit MVP caveats in `method.caveats`. Cache serialized命盘 through `lib/mingli/cache.ts` envelopes so schema migrations can be detected and repaired.

## Project conventions

Use `@/*` imports for repository-root paths. Keep TypeScript strict; prefer concrete types and guards over `any`.

For visual/UI/motion work, align with `docs/AESTHETIC_DIRECTION.md`, `docs/DESIGN_GUIDELINE.md`, and `.impeccable.md`. The product aesthetic is Neo-Chinese tactile self-care: warm paper surfaces, ink-like text, small cinnabar/vermilion accents, whitespace, seals, daily objects, and modern grids. Avoid red/gold fortune-app clichés, dense bagua/symbol backgrounds, neon tech gradients, generic card-grid AI aesthetics, and emoji. Start from `lib/design/tokens.ts` (`Colors`, `Space`, `Radius`, `Type`, `Shadow`, `Motion`, `Size`) rather than inventing raw colors or spacing.

React Native UI should use `StyleSheet`, tokenized spacing/color/type, iOS-first touch targets (`Size.buttonMd` is 44), and `react-native-reanimated` spring feedback for pressable/tactile interactions. The app prioritizes iOS; Android and web should not block iOS experience unless the task explicitly targets them.

Do not treat every doc target as implemented. `README.md` and `CLAUDE.md` describe the current hardening/prototype state; `docs/PRD.md` and `docs/ARCHITECTURE.md` include future goals and may be aspirational. For larger features, read PRD/architecture for intent, but verify current code before wiring behavior.

Do not invent命理 rules or present MVP shortcuts as complete traditional inference. If a rule is uncertain, leave an explicit TODO/caveat and add or update fixtures/tests near the relevant engine, especially under `lib/__tests__`, `lib/bazi/__tests__`, `lib/qimen/__tests__`, `lib/ai/tools/__tests__`, or the domain-specific test directory.

AI output should maintain the product stance: self-care and self-awareness, not deterministic fortune-telling. User-facing interpretation should translate technical terms into warm, modern language and avoid absolute predictions or fear-inducing phrases like `犯太岁` / `破财`.

Docs are primarily Chinese; code, comments, and commits may mix Chinese and English. When task progress changes, `docs/TASKS.md` is the ground-truth checklist.
