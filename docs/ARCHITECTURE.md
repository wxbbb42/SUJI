# 岁吉 — 技术架构文档

## 技术栈总览

| 层面 | 技术 | 版本/说明 |
|---|---|---|
| 语言 | TypeScript | 严格模式 |
| 框架 | React Native + Expo | SDK 52+ |
| 路由 | Expo Router | 文件系统路由 |
| 3D | react-three-fiber + @react-three/drei | expo-gl 渲染 |
| 物理 | @react-three/cannon | 纸张撕裂物理 |
| 状态管理 | Zustand | 轻量，TS 友好 |
| 后端 | Supabase | Auth + PostgreSQL + Realtime |
| AI | OpenAI / Anthropic API | 通过后端代理调用 |
| 八字 | hkargc/paipan (JS) | 排盘核心算法 |
| 音频 | expo-av | 音效 + 白噪音 |
| 支付 | expo-in-app-purchases / RevenueCat | iOS 订阅 |
| Widget | Expo Modules + WidgetKit | Swift 桥接 |
| 推送 | expo-notifications + APNs | 定时提醒 |

---

## 架构图

```
┌─────────────────────────────────────────┐
│              iOS App (Expo)              │
│                                         │
│  ┌─────────┐  ┌──────────┐  ┌────────┐ │
│  │ 手撕黄历 │  │ AI 对话   │  │ 命盘   │ │
│  │ R3F/GL  │  │ Chat UI  │  │ 可视化  │ │
│  └────┬────┘  └────┬─────┘  └───┬────┘ │
│       │            │            │       │
│  ┌────▼────────────▼────────────▼────┐  │
│  │         Zustand Store             │  │
│  │  (用户状态/八字数据/对话/设置)      │  │
│  └────────────────┬──────────────────┘  │
│                   │                     │
│  ┌────────────────▼──────────────────┐  │
│  │         lib/ 核心逻辑              │  │
│  │  bazi/ | calendar/ | ai/ | audio/ │  │
│  └────────────────┬──────────────────┘  │
└───────────────────┼─────────────────────┘
                    │ HTTPS
┌───────────────────▼─────────────────────┐
│           Supabase Backend               │
│                                          │
│  ┌──────────┐  ┌───────────────────────┐ │
│  │ Auth     │  │ Edge Functions        │ │
│  │ (Apple/  │  │ - /api/ai-chat        │ │
│  │  WeChat) │  │ - /api/daily-fortune  │ │
│  └──────────┘  │ - /api/bazi-report    │ │
│                └───────────────────────┘ │
│  ┌──────────┐  ┌───────────────────────┐ │
│  │ Database │  │ Storage               │ │
│  │ (用户/   │  │ (音景文件/            │ │
│  │  对话/   │  │  分享卡片缓存)        │ │
│  │  情绪)   │  │                       │ │
│  └──────────┘  └───────────────────────┘ │
└──────────────────────────────────────────┘
                    │
          ┌─────────▼──────────┐
          │   AI Provider API   │
          │  (OpenAI / Claude)  │
          └────────────────────┘
```

---

## 数据模型

### users
```sql
id UUID PRIMARY KEY
apple_id TEXT UNIQUE
birth_datetime TIMESTAMPTZ  -- 出生时间（加密存储）
birth_location TEXT          -- 出生地（用于真太阳时）
lunar_birth TEXT             -- 农历生日
bazi_data JSONB              -- 排盘结果缓存
tone_preference TEXT DEFAULT 'warm'  -- AI 语气偏好
theme TEXT DEFAULT 'paper'
subscription_tier TEXT DEFAULT 'free'
created_at TIMESTAMPTZ
```

### conversations
```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users
messages JSONB[]    -- {role, content, timestamp}
mood_tag TEXT        -- 情绪标签
created_at TIMESTAMPTZ
```

### emotion_diary
```sql
id UUID PRIMARY KEY
user_id UUID REFERENCES users
date DATE
mood_score INT (1-5)
mood_tags TEXT[]
note TEXT
ai_insight TEXT      -- AI 月末生成
created_at TIMESTAMPTZ
```

### daily_fortunes
```sql
id UUID PRIMARY KEY
date DATE UNIQUE
ganzhi TEXT          -- 干支
solar_term TEXT      -- 节气（如有）
base_fortune JSONB   -- 通用运势内容
created_at TIMESTAMPTZ
```

---

## AI Prompt 架构

### 系统人设 (System Prompt)
```
你是「岁吉」— 一位融合中式哲学智慧与现代心理学的疗愈伙伴。

你的特质：
- 用温暖、有同理心的语言表达
- 将传统命理概念翻译为现代人能理解的自我认知语言
- 永远不说"算命"、"预测未来"，而是"自我觉察"、"能量趋势"
- 给出的建议基于正念和积极心理学框架
- 适时引用中式哲学（道家、禅宗）的智慧，但不说教

你拥有的信息：
- 用户的八字排盘数据（四柱、十神、五行分布）
- 今日干支与运势基调
- 用户的历史对话和情绪记录

禁止：
- 做出具体预测（"你下个月会升职"）
- 使用迷信话术（"犯太岁"、"破财"）
- 替代专业心理咨询
```

---

## 关键技术挑战

### 1. 手撕 3D 效果
- 使用 `react-three-fiber` 渲染纸张 mesh
- `@react-three/cannon` 处理物理模拟
- 自定义 shader 实现纸张纹理 + 毛边效果
- 手势用 `react-native-gesture-handler` 映射到 3D 空间

### 2. 八字排盘准确性
- 使用 paipan 库的核心算法
- 需要处理真太阳时（根据出生地经度修正）
- 节气边界精确到分钟级

### 3. AI 响应一致性
- 构建结构化 prompt template
- 将排盘数据以 JSON 注入 context
- 缓存每日通用运势，减少 API 调用
- 流式输出提升对话体验

### 4. 离线体验
- 八字排盘算法纯本地运行
- 缓存近 7 天的每日运势
- 音景文件预下载
- AI 对话需要网络（显示优雅的离线提示）
