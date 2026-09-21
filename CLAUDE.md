# SUJI（有时）

SwiftUI 是唯一维护的 iPhone 客户端。旧 Expo / React Native 构建已退役，不再添加 Expo 页面、Metro 配置、Zustand store 或客户端 provider key 设置。

## 仓库地图

- `native/App`：SwiftUI 功能页面、主题与原生服务。
- `native/Core`：Swift Package；账户、聊天、归档、工具编排与领域模型。
- `native/Widget`：WidgetKit，仅共享每日卡片快照。
- `native/Engine/src`：本地确定性历法与命理算法，原 `lib/` 的保留部分。
- `native/Resources`：随 App 分发的引擎 bundle、字体、素材与 parity fixtures。
- `supabase`：Auth / profiles 迁移、托管 DeepSeek 接口和限流测试。
- `docs/mingli`：算法来源、规则边界、文献与阅读记录。
- `docs/archive/expo`：历史设计，不是当前实现或待办的依据。

## 当前约束

- iOS 18+，Xcode 26+；页面使用 SwiftUI，音频使用 AVAudioEngine，持久化使用 SwiftData，账号凭据存放 Keychain。
- AI 需要登录，固定使用 Supabase → DeepSeek Flash；模型密钥仅存服务端。不要恢复 BYOK 或通过旧归档配置改变 provider 路由。
- 原生本地 notebook 按账号隔离，云端 profile 同步由用户主动触发。不要把日记、会话或密钥混入 profiles。
- JavaScriptCore 仅运行本地计算；保留 TypeScript 源码用于复现和验证，不引入 JavaScript UI / 网络运行时。
- 算法规则需要可追溯的出处和边界，不凭感觉补全；保留不确定性和现有 fixtures。
- 当前视觉依据为 `native/design-qa.md`、`native/App/Design` 和 `.impeccable.md`；尊重 Dynamic Type、Reduce Motion 与标准 Apple 导航。

## 验证与文档

运行方式、产品状态和范围以 `README.md`、`native/README.md`、`native/VERIFICATION.md` 为准。按改动运行相关检查：

```sh
TZ=America/Los_Angeles swift test --package-path native/Core
xcodebuild -project native/Suji.xcodeproj -scheme Suji -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
npm ci --prefix native/Engine
npm run typecheck --prefix native/Engine
npm test --prefix native/Engine
npm run build --prefix native/Engine
npm ci --prefix supabase
npm test --prefix supabase
```

新增 Swift 文件后重新运行 `python3 native/scripts/generate-project.py`。修改引擎后提交重新生成的 bundle / fixtures，再验证 Swift 跨时区 parity。不要在同一 DerivedData 目录并行构建，也不要关闭模拟器签名：Keychain 和 App Group 需要 entitlements。

`.env.local` 和 `native/Resources/PublicConfig.plist` 只承载公开 Supabase 配置并被忽略。`supabase/.env.local` 属于后端密钥，不能提交、打印或打包进 App。
