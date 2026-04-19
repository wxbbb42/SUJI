# 岁吉 SUJI — 协作者上手指南

欢迎来和我们一起做岁吉 🎋。这份指南假设你**没写过代码**,每一步都写得尽量清楚。走完大概 1 – 2 小时(其中下载 Xcode 就要 30 – 60 分钟,可以并行做别的)。

走完你会拥有:
- 本机跑起来的岁吉 App(跑在 iPhone 17 Pro 模拟器里)
- 改任何代码 / 颜色 / 文案后,**保存即热重载**,立刻看到效果
- 把改动推到 GitHub 让团队看到的能力

---

## 目录

1. [需要准备的东西](#1-需要准备的东西)
2. [一次性环境安装](#2-一次性环境安装)
3. [拿到代码并跑起来](#3-拿到代码并跑起来)
4. [日常开发循环](#4-日常开发循环)
5. [Git 协作流程(重点)](#5-git-协作流程重点)
6. [常见问题 & 排坑](#6-常见问题--排坑)

---

## 1. 需要准备的东西

- **一台 Mac**(Apple Silicon M1/M2/M3/M4 最佳,Intel 也行)
- **GitHub 账号**,并已被邀请进 `wxbbb42/SUJI` 仓库(没收到邀请让 Xiaoben 加你)
- **硬盘空闲空间 ≥ 30 GB**(主要给 Xcode)

---

## 2. 一次性环境安装

这一节所有步骤**只需要做一次**。之后写代码就不用管了。

### 2.1 Xcode(iOS 模拟器来源,最慢的一步)

1. 打开 **App Store**,搜「Xcode」→ 安装(大约 **15 GB**,首次下载非常慢,可以挂着)
2. 装完打开一次 Xcode,接受协议,等它自动装完附加组件
3. 打开**终端**(按 `⌘ + 空格`,输入「终端」回车),粘贴以下命令回车。这一步让命令行工具指向刚装的 Xcode:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
   会让你输入 Mac 密码(就是开机密码,输入时不显示任何东西,输完回车即可)
4. Xcode 里:**Settings → Platforms**,点 iOS 旁的下载按钮,装一个 **Simulator Runtime**(iOS 17 或更新都行)

### 2.2 Homebrew(Mac 的软件包管理器)

终端粘贴:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
照提示走完(会让你输密码,可能还让你按回车确认)。装完**把终端最后输出的两行 `echo ... >> ~/.zprofile` 之类的命令也执行一下**(官方安装脚本会告诉你具体命令),否则下次开终端找不到 brew。

### 2.3 Node 20(岁吉用的 JS 运行时)

⚠️ **必须是 Node 20**,更新的 Node 24 会让 Metro 崩溃,装过的话不要用。

```bash
brew install node@20
```

然后让 Node 20 默认可用 —— 如果你用的是 **fish** shell(命令行提示符显示是「❯」那种):
```bash
echo 'fish_add_path /opt/homebrew/opt/node@20/bin' >> ~/.config/fish/config.fish
```

如果用的是 **zsh**(默认,提示符是「%」):
```bash
echo 'export PATH="/opt/homebrew/opt/node@20/bin:$PATH"' >> ~/.zshrc
```

**关了终端重新开一个**,然后验证:
```bash
node --version
```
应该显示 `v20.x.x`。不对就别往下走,找 Xiaoben。

### 2.4 CocoaPods(iOS 依赖管理)

```bash
brew install cocoapods
```

### 2.5 Git(你 Mac 已经有了)

用 Git 需要告诉它你是谁,这样提交记录会写上你的名字:
```bash
git config --global user.name "你的名字"
git config --global user.email "你的GitHub邮箱"
```

### 2.6 编辑器(写代码用)

推荐 **Cursor**(https://cursor.com),基于 VS Code 但内置 AI 助手,非程序员改代码体验好很多。问它「这段代码是干嘛的」或「我想把这个按钮颜色改成红色,应该改哪里」它会直接指给你看。

下载 → 安装 → 打开即可。

### 2.7 GitHub Desktop(可选,推荐)

如果你不想在终端里敲 `git` 命令,装 **GitHub Desktop**(https://desktop.github.com)—— 图形化界面,点按钮就能完成 commit / pull / push。

---

## 3. 拿到代码并跑起来

### 3.1 克隆仓库

在终端里,切到你放项目的目录(以「文稿」为例):
```bash
cd ~/Documents
git clone https://github.com/wxbbb42/SUJI.git
cd SUJI
```

(如果用 GitHub Desktop:**File → Clone Repository → 选 SUJI**)

### 3.2 获取 `.env` 文件 ⚠️

仓库里**没有** `.env` 文件(里面有 Supabase + Google 的密钥,不能提交到公开 Git)。

→ **找 Xiaoben 要一份 `.env`**,把这个文件放到项目根目录(`~/Documents/SUJI/.env`)。

### 3.3 装项目依赖

终端里(确保当前目录是 `~/Documents/SUJI`):
```bash
npm install
```
大约 10 – 30 秒。

### 3.4 启动模拟器

```bash
open -a Simulator
```

第一次会慢一点,最终出现一个 iPhone 17 Pro 的窗口就对了。

### 3.5 生成 iOS 原生项目 + 构建

```bash
npx expo prebuild --platform ios
cd ios && pod install && cd ..
```

pod install 大约 2 – 5 分钟,这是在下载 iOS 端的原生依赖(一次性,以后增量更新就很快)。

### 3.6 编译 + 安装到模拟器(首次 5 – 10 分钟)

```bash
cd ios
xcodebuild \
  -workspace app.xcworkspace \
  -scheme app \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build \
  build
cd ..
```

等出现 `** BUILD SUCCEEDED **` 就对了。

然后装到模拟器并启动:
```bash
xcrun simctl install booted ios/build/Build/Products/Debug-iphonesimulator/app.app
xcrun simctl launch booted app.suiji.ios
```

### 3.7 启动 Metro(JS 热重载服务器)

**新开一个终端窗口**(现有的不要关),进项目:
```bash
cd ~/Documents/SUJI
npx expo start --dev-client
```

看到 `Waiting on http://localhost:8081` 就 OK。App 会自动连上,几秒后模拟器里看到岁吉的启动动画 🎉

> **以后每次要跑:只需做 3.4(启动模拟器)+ 3.7(启动 Metro),其他都不用重做**,除非你更新了依赖或改了原生配置(那种情况我会在 commit message 里说明)。

---

## 4. 日常开发循环

典型一天的流程:

1. **开工前拉最新代码**(重要,避免和别人冲突):
   ```bash
   cd ~/Documents/SUJI
   git pull
   ```
   或 GitHub Desktop 点 **Fetch origin → Pull origin**。

2. **启动环境**(只要模拟器 + Metro):
   - 打开模拟器:`open -a Simulator`
   - 新终端:`cd ~/Documents/SUJI && npx expo start --dev-client`

3. **在 Cursor 打开项目**,改代码。

4. **保存文件(⌘S)** → 模拟器里 **自动热重载**(1 – 2 秒看到效果)。
   - 如果没自动刷新,在模拟器按 **⌘R**(强制重载)
   - 如果 UI 错乱,按 **⌘D** 打开开发菜单,选 Reload

5. **改满意后,commit + push**(见下一节)。

### 你最可能改的文件

| 改什么 | 去哪儿看 |
|---|---|
| 颜色 / 间距 / 字体 / 阴影 / 圆角 | `lib/design/tokens.ts`(**设计 token 的唯一源**,改这里全局生效) |
| 登录页 | `app/auth.tsx` |
| 日历页(首页) | `app/(tabs)/index.tsx` + `components/calendar/` |
| 问道(AI 对话) | `app/(tabs)/insight.tsx` + `components/chat/` |
| 静心(白噪音) | `app/(tabs)/ambiance.tsx` |
| 我的 / 设置 | `app/(tabs)/profile.tsx` + `app/settings.tsx` |
| 引导页 | `app/onboarding.tsx` |
| 图片 / 音效 / 字体 | `assets/` |
| 设计语言规则(要先读!) | `.impeccable.md` |

⚠️ **改视觉之前先读 `.impeccable.md`**,这是我们的「设计圣经」,定义了 Neo-Tactile Warmth 的颜色撞色、圆角、阴影哲学。**不要硬编码颜色**,所有颜色从 `lib/design/tokens.ts` 导入。

---

## 5. Git 协作流程(重点)

### 5.1 核心概念(一分钟速通)

- **commit**:把你本机的改动打个包,带上说明文字。只在你本机存着。
- **push**:把你本机的 commit 推到 GitHub,别人才能看到。
- **pull**:把 GitHub 上别人的新 commit 拉到本机。

### 5.2 推荐流程 — 每改一个功能建一个分支

**不要**直接在 `main` 分支改代码。正确流程:

```bash
# 1. 先切回 main 并拉最新
git checkout main
git pull

# 2. 建一个新分支做你的事(名字能看懂即可)
git checkout -b design/onboarding-polish

# 3. 改代码,改完 commit
git add <你改的文件路径>        # 比如 git add app/auth.tsx lib/design/tokens.ts
git commit -m "design: 登录页按钮加大 + 阴影柔化"

# 4. 推到远端(第一次要加 -u origin <分支名>)
git push -u origin design/onboarding-polish
```

然后去 GitHub 页面点 **Compare & pull request**,请 Xiaoben review。Xiaoben 合并后,你的改动才进 main。

### 5.3 commit message 怎么写

项目里的 commit 信息风格是中文 + 动词前缀,简短清楚:

- `design: ...` — 视觉改动
- `polish: ...` — 微调优化已有设计
- `fix: ...` — 修 bug
- `feat: ...` — 加新功能
- `refactor: ...` — 重构但不改行为
- `docs: ...` — 只改文档

例子:
- ✅ `design: Onboarding 第二页改用琥珀黄撞色`
- ✅ `polish: 日历页卡片圆角从 16 → 20`
- ✅ `fix: 设置页登录按钮在无账号时不显示`
- ❌ `update` / `修改` / `lalala`(说了等于没说)

### 5.4 如果你只想用图形界面(GitHub Desktop)

- **拉取新代码**:点顶栏 **Fetch origin** → 出现 **Pull origin** 按钮就点它
- **切分支**:顶栏 **Current Branch** 下拉 → **New Branch**
- **提交**:左下写 summary,点 **Commit to <分支名>**
- **推送**:点顶栏 **Push origin**
- **提 Pull Request**:Commits 推上去后点顶栏 **Create Pull Request**(会跳到 GitHub 网页)

### 5.5 如果你和别人改到同一个文件(冲突)

`git pull` 可能报 `CONFLICT`。这是 Git 说「同一行我分不清该保留谁的版本」。

**别慌**。打开 Cursor,冲突的文件里会有这样的标记:
```
<<<<<<< HEAD
你本地的版本
=======
远端别人的版本
>>>>>>> main
```

选一个留下(或手动合并两者),删掉所有 `<<<<<<<` `=======` `>>>>>>>` 标记。保存后:
```bash
git add <冲突的文件>
git commit
```

搞不定就**先别自己硬搞**,找 Xiaoben 远程一起看。

---

## 6. 常见问题 & 排坑

### Q1:模拟器黑屏 / App 进不去
**A**:在模拟器窗口菜单 **Device → Erase All Content and Settings**,清掉然后重跑第 3.6 和 3.7。

### Q2:`npx expo run:ios` 报 "No code signing certificates"
**A**:因为你 iPhone 插着(或 WiFi 配对着)。要么**拔掉 iPhone 的 USB**,要么用我们第 3.6 的 `xcodebuild` 命令(已经带了 `-sdk iphonesimulator`,强制用模拟器)。

### Q3:Metro 崩溃 / 报 `WebSocket is not open`
**A**:十有八九是你的 Node 版本不对。验证:
```bash
node --version
```
必须是 `v20.x.x`。如果是 24 或更高,回到 2.3 重做。

### Q4:`pod install` 卡住不动
**A**:大陆网络常见问题。让 Xiaoben 配一个代理,或改用镜像源。紧急情况可以找 Xiaoben 把生成好的 `ios/Pods/` 打包发你。

### Q5:改了代码但模拟器没反应
**A**:
1. 保存文件了吗?(⌘S)
2. Metro 终端是不是崩了?(看有没有红字报错)
3. 模拟器里 **⌘R** 强制刷新
4. 都不行,重启 Metro:终端 ⌃C 退出,再 `npx expo start --dev-client`

### Q6:改了颜色没生效 / 看起来还是老颜色
**A**:
- 确认你改的是 `lib/design/tokens.ts`,而不是硬编码在组件里(如果某个组件里写死了 `#FF0000`,那是早期代码,告诉 Xiaoben)
- **⌘R** 刷新模拟器

### Q7:我 push 失败了,报 "rejected non-fast-forward"
**A**:有人在你之前推了新 commit 到同一分支。先拉下来再推:
```bash
git pull --rebase
git push
```

### Q8:我不小心提交了不该提交的东西
**A**:**先别慌也别继续操作**。截图当前终端状态发给 Xiaoben,他帮你撤。贸然 `git reset --hard` 可能丢你的工作。

### Q9:我完全卡住了,看不懂报错
**A**:把报错**完整截图**发给 Xiaoben,带上你刚才执行的命令。比你自己硬猜 10 分钟效率高。

---

## 最后

有任何不清楚的地方,直接问 Xiaoben。这份文档会随着项目更新,看到 main 分支上有改动记得同步。

祝玩得开心 🎋
