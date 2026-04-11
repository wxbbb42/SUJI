# 岁吉 (SuiJi)

> 中式美学 self-care App — 手撕黄历 × AI 情绪疗愈

## 产品定位

以「情绪价值」和「中式审美」为核心的数字自留地。通过极简的交互仪式和 AI 的温情解读，让年轻人在现代焦虑中找到精神寄托。

**不是算命工具，是 self-care 伴侣。**

## 技术栈

- **前端:** React Native + Expo (TypeScript)
- **3D:** react-three-fiber + expo-gl
- **后端:** Supabase (Auth / Database / Storage)
- **AI:** GPT-4o / Claude API
- **八字排盘:** hkargc/paipan (JavaScript)

## 快速开始

```bash
npm install
npx expo start
```

## 项目结构

```
suiji/
├── app/                  # Expo Router 页面
│   ├── (tabs)/           # Tab 导航
│   │   ├── index.tsx     # 首页：手撕黄历
│   │   ├── insight.tsx   # AI 哲人对话
│   │   ├── profile.tsx   # 命盘/个人
│   │   └── ambiance.tsx  # 音景/正念
│   ├── _layout.tsx       # 根布局
│   └── onboarding.tsx    # 引导页（录入生辰）
├── components/           # 可复用组件
│   ├── calendar/         # 手撕黄历 3D 组件
│   ├── chat/             # AI 对话组件
│   ├── bazi/             # 八字可视化组件
│   └── ui/               # 通用 UI 组件
├── lib/                  # 核心逻辑
│   ├── bazi/             # 八字排盘算法
│   ├── calendar/         # 农历/干支/节气
│   ├── ai/               # AI prompt & API
│   └── supabase/         # 后端客户端
├── assets/               # 静态资源
│   ├── fonts/            # 中式字体
│   ├── sounds/           # 撕纸音效、白噪音
│   ├── textures/         # 纸张纹理
│   └── images/           # 插图素材
├── constants/            # 主题色、节气数据等
├── docs/                 # 产品文档
│   ├── PRD.md            # 完整 PRD
│   ├── FEATURES.md       # Feature Set
│   ├── ARCHITECTURE.md   # 技术架构
│   └── TASKS.md          # 开发任务清单
└── supabase/             # Supabase 配置
    └── migrations/       # 数据库迁移
```

## License

Private - All Rights Reserved
