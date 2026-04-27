# SUJI（岁吉）

中式美学 self-care App — 手撕黄历 / AI 解读 / 命理可视化。给焦虑的年轻人一份有仪式感的精神自留地。

## 技术栈

- **客户端**：Expo SDK 54 + React Native 0.81 + React 19 + TypeScript（strict）
- **路由**：expo-router（文件系统路由）
- **状态**：Zustand
- **3D / 动效**：react-three-fiber + drei + expo-gl，Reanimated 4
- **后端**：Supabase（Auth + Postgres + Realtime）
- **AI**：通过后端代理 OpenAI / Anthropic
- **命理引擎**：lunisolar（农历/干支/节气）+ iztro（紫微）+ 自研 bazi/qimen/liuyao
- **测试**：jest + jest-expo + @testing-library/react-native

## 仓库地图

```
app/         expo-router 屏幕（_layout.tsx 是主题/Provider 入口）
components/  按领域分子目录：ai/ bazi/ calendar/ chat/ divination/ qimen/
lib/         纯逻辑：ai/ bazi/ ziwei/ qimen/ liuyao/ marriage/ store/ supabase/ utils/ design/ calendar/
constants/   Colors.ts（其他 design tokens 散落在 _layout.tsx — 待统一）
supabase/    schema / migrations / edge functions
docs/        PRD / ARCHITECTURE / TASKS / DESIGN_GUIDELINE / ONBOARDING
docs/superpowers/  plans/ 与 specs/（功能级设计稿）
```

## 关键事实

- **Auth providers**：Google + Email，**不再支持 Apple Sign-In**（2026-04-24 移除）。新代码不要加回 Apple。
- **语言**：代码、注释、commit 都可中英混用（参考 `git log` 风格：`qimen: 用神选择…`）。文档以中文为主。
- **跑测试**：`npm test`。新功能要尽量带单测，命理算法尤其需要（参见 `lib/__tests__/`）。
- **平台优先级**：iOS。Android / Web 是 expo 顺带产出，不阻塞 iOS 体验。

## 工作规约

- **任何视觉 / UI / 动效 / Slide / Mock 任务** — 严格遵循 @docs/DESIGN_GUIDELINE.md，并先对齐 @docs/AESTHETIC_DIRECTION.md 的岁吉美学方向（已在下方 import）。
- **新增功能 / 较大重构** — 先看 `docs/PRD.md` 对齐产品意图，看 `docs/ARCHITECTURE.md` 对齐技术决策，必要时在 `docs/superpowers/specs/` 写 spec、在 `plans/` 写实施计划。
- **任务进度** — `docs/TASKS.md` 是 ground truth，完成项就划掉。
- **风险动作**（覆盖未提交改动、删分支、`--force` push、改 supabase 生产 schema）— 做之前先确认，不要默认执行。
- **不当的"补全"** — 不要凭感觉给命理算法加占位逻辑；不确定的规则就明确标 TODO 并停下来问。命理结果是产品核心，错一条规则可能毁信任。

## 导入

@docs/DESIGN_GUIDELINE.md
@docs/AESTHETIC_DIRECTION.md
