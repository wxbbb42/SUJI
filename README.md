# 岁吉 (SUJI)

> 中式美学 self-care App — 命理可视化 × AI 解读 × 日常仪式感。

## 产品定位

岁吉不是传统“算命工具”，而是把八字、紫微、六爻、奇门等传统体系转译成现代人能理解的自我观察语言。产品目标是：用克制的中式审美、轻量的交互和可追溯的命理依据，提供有仪式感的 self-care 体验。

## 当前实现状态

这是一个仍在 hardening 的 Expo / React Native 项目。当前 repo 已包含：

- Expo Router 页面：日历首页、问道/AI 对话、命盘页、设置、登录/注册、引导页
- 本地命理引擎：`bazi`、`ziwei`、`divination`、`qimen`
- AI 编排原型：thinker（工具推演）+ interpreter（生活化解读）
- Supabase Auth / profiles 同步基础设施
- Jest 测试覆盖核心工具和部分组件规则

还在打磨中的部分：

- 奇门、格局、应期等规则仍有 MVP 简化项，不能当作完整传统排盘实现
- 3D 手撕黄历组件是概念实现，首页目前以稳定日期卡片为主
- AI 当前支持 BYOK 客户端直连 provider；生产级后端代理仍是后续目标
- 文档中的目标功能（订阅、Widget、推送、音景等）不代表已完成

## 技术栈

- **客户端**：Expo SDK 54 + React Native 0.81 + React 19 + TypeScript strict
- **路由**：expo-router
- **状态管理**：Zustand + AsyncStorage persist
- **3D / 动效**：react-three-fiber + drei + expo-gl，Reanimated 4
- **后端**：Supabase Auth + Postgres profiles
- **AI**：OpenAI / DeepSeek / Anthropic / custom OpenAI-compatible；支持 Responses API / Azure AI Foundry URL
- **命理引擎**：lunisolar、iztro、自研 bazi / qimen / liuyao
- **测试**：jest + jest-expo + @testing-library/react-native

## 快速开始

```bash
npm install
npx expo start --dev-client
```

常用检查：

```bash
npm test -- --runInBand
npx tsc --noEmit
```

## 环境配置

Supabase 使用 Expo public env：

```bash
EXPO_PUBLIC_SUPABASE_URL=...
EXPO_PUBLIC_SUPABASE_ANON_KEY=...
```

数据库 schema 见：

```txt
supabase/migrations/0001_init_profiles.sql
```

AI API key 当前由用户在 App 设置页配置，并保存在本机；`profiles` 表不会上传 `api_key`。

## 项目结构

```txt
app/          Expo Router 页面与导航
components/   UI / AI / calendar / bazi / divination / qimen 组件
lib/          核心逻辑：ai、bazi、calendar、divination、qimen、store、supabase、ziwei
supabase/     数据库迁移
docs/         PRD、架构、美学、设计规范、任务清单
assets/       静态资源
```

## 开发约定

- 命理算法不要凭感觉补规则；不确定的地方保留 TODO，并配测试或 fixture
- 新功能优先补单测，尤其是命理 engine、AI tools 和 orchestrator
- 视觉 / UI / 动效改动先看 `docs/AESTHETIC_DIRECTION.md` 和 `docs/DESIGN_GUIDELINE.md`
- 风险动作（生产 schema、删除数据、force push）先确认

## License

Private - All Rights Reserved
