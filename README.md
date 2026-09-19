# 有时 · SUJI

一款原生 iPhone self-care App：日签、问道、静心与自我观察。**SwiftUI 是唯一维护的客户端**，支持 iOS 18 及以上。

旧 Expo / React Native 构建已退役，页面、客户端依赖和构建入口均已移除。退役前的完整代码可从 Git 提交 `328bcff` 找回；历史设计文档位于 `docs/archive/expo`。

唯一客户端工程为 `native/Suji.xcodeproj`。CI 会拒绝重新加入旧客户端目录、根目录 npm 构建入口及 Expo / React Native 依赖；`native/Engine` 和 `supabase` 的独立工具链继续维护。

## 运行

使用 Xcode 26 或更新版本打开 `native/Suji.xcodeproj`，选择 **Suji** scheme 和 iPhone 模拟器，直接运行。原生工程、历法引擎 bundle 和资源已纳入版本控制，启动 App 无需安装 Node.js。

账户与 AI 的公开配置：

```sh
cp .env.example .env.local
# 填写 Supabase URL 和公开 publishable / anon key
python3 native/scripts/configure-public.py
python3 native/scripts/generate-project.py
```

AI 需要登录，统一通过 Supabase 调用 **DeepSeek Flash**。用户无需填写模型或密钥；DeepSeek key 只存放在服务端。日签、日记和静心可离线使用。

详细操作、设备签名、账号迁移与产品边界见 [SwiftUI 开发指南](native/README.md)，后端部署见 [Supabase 指南](supabase/README.md)。

## 结构

- `native/App`：SwiftUI 页面与原生服务。
- `native/Core`：Swift 模型、网络、归档和核心测试。
- `native/Widget`：WidgetKit 小组件。
- `native/Engine`：纯计算 TypeScript 源码、测试和独立工具链，编译后由 JavaScriptCore 离线运行。
- `native/Resources`：原生素材、字体、引擎 bundle 与对照 fixtures。
- `supabase`：登录后使用的 AI 转发接口、配额迁移与后端测试。
- `docs/mingli`、`scripts`：算法文献和知识库维护工具。

## 验证

```sh
# 检查仓库只保留原生客户端
python3 native/scripts/check-native-only.py

# Swift 核心逻辑及跨时区引擎一致性
TZ=America/Los_Angeles swift test --package-path native/Core

# 原生 App、Widget 和集成/UI 测试；保留模拟器签名以使用 Keychain / App Group
xcodebuild -project native/Suji.xcodeproj -scheme Suji \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# 修改算法时：独立安装、类型检查、测试并重新生成资源
npm ci --prefix native/Engine
npm run typecheck --prefix native/Engine
npm test --prefix native/Engine
npm run build --prefix native/Engine

# 后端测试
npm ci --prefix supabase
npm test --prefix supabase

# 更新知识库索引（无 npm 依赖）
node scripts/ingest-mingli-kb.mjs
```

命理计算约定、独立开源/文献研究、已修缺陷与验证边界见 [命理验证记录](docs/mingli/validation/PLAN.md)。四柱使用精确交节、固定 UTC+08 和子初换日；调候条目保留出处与条件，尚不自动取用。问道将盘面快照绑定到本次资料，起盘重试沿用原盘，命理解读核对通过后才展示。

已执行的检查与尚需实机验证的项目见 [验证记录](native/VERIFICATION.md)。传统算法保留明确的简化边界，不作为医疗、财务或人生决策建议；当前版本尚未发布到 App Store。

## License

Private — All Rights Reserved. 第三方运行库授权随 App 附带在 `native/Resources/ThirdPartyNotices.txt`；字体与素材授权见同目录。

命理引擎的独立资料、逐日历表对照、规则修复与模型评测限制见 [验证记录](docs/mingli/validation/PLAN.md)。最新构建与测试证据见 [原生验证](native/VERIFICATION.md)。
