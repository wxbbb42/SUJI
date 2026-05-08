# source-texts/ — 古籍原文本地仓库

> 把命理古籍原文落到 repo 里，让 reading-notes / claims / fixture 可以稳定引用，不依赖网络（WebFetch 在 sandbox 内被拒，且网络转载本身可信度不一）。

---

## 为什么要建这个

1. **网络访问不可靠**：Claude Code sandbox 拒绝 WebFetch；商业站转载页面随时可能改版/下线。
2. **底本可控**：本地版本由你（用户）逐章录入，附底本元数据，比网络转载有可信度优势。
3. **可被 reading-notes 直接引用**：reading-note 里的 `evidence` 字段可以从"《XXX》（网络转载）"升级到"《XXX》中州古籍 2008 版 p.123"。
4. **claims 可升级 source tier**：当前 claims.json 中很多 source 是 D-tier-online，本地化原文后可升 B-tier 或 A-tier。

---

## 目录结构

```
source-texts/
├── README.md          ← 你正在看
├── MANIFEST.md        ← 录入进度跟踪表（[ ] 待填 / [x] 已填）
└── bazi/
    ├── ziping-zhenquan/      P0 子平真诠评注（沈孝瞻原著 + 徐乐吾评注）
    ├── ditianshui-chanwei/   P0 滴天髓阐微（任铁樵注）
    ├── qiongtong-baojian/    P0 穷通宝鉴（栏江网，余春台辑 / 徐乐吾评）
    ├── yuanhai-ziping/       P1 渊海子平（徐升）
    ├── sanming-tonghui/      P1 三命通会（万民英）
    └── shenfeng-tongkao/     P1 神峰通考（张神峰）
```

紫微 / 奇门 / 六爻等其他门派暂不建——Path C 当前只动 BaziEngine。

---

## 录入约定

每个章节文件已经预置 frontmatter，**只需填三件事**：

```markdown
---
book: 子平真诠评注
chapter: 论用神
edition: [底本]                    ← 你填：例如 "中华书局 2018 年点校本"
fillStatus: empty                 ← 录入完改为 "filled"
filledBy: [谁录的]                ← 你填
filledAt: [yyyy-mm-dd]            ← 你填
---
```

正文部分按以下结构粘贴：

```markdown
## 原文

（把白文/原文粘贴在这里。简体优先；繁体也可以，我能识别。）

## 评注（如有）

（任铁樵注、徐乐吾评等粘贴在这里，与原文分开。）

## 你的录入备注（可选）

（你录入时发现的疑点、缺页、版本异同等。）
```

---

## 版权与隐私

- 这些文本是**仓库私有，不对外发布**——SUJI 的 supabase 数据库只存推算结果，不存古籍原文。
- 古籍底本本身大都已进入公共领域（成书均在 1949 年前），但**点校本/评注本的现代整理者享有版权**。仅作 SUJI 内部算法参考用，不要把任一章节再公开发布。
- 如果未来要开源 SUJI 代码，**这个文件夹应加进 `.gitignore`**（届时 reading-notes 可以保留，但 source-texts 应当排除）。当前 repo 私有，可以入 git。

---

## 工作流

1. 你按 `MANIFEST.md` 的优先级，挑一章填进对应 .md 文件
2. 你填完后告诉我"X 章已填"
3. 我读这章 + 之前已有的 reading-note，更新 reading-notes（加引文）+ 升级 claims.json 中相关 claim 的 source tier + notes
4. 当某个 P0 书填到 80% 以上，Phase 1.1 验收正式通过 → 启动 Phase 2

---

## 我（Claude）会做什么、不会做什么

- ✅ 我会按文件名/frontmatter **读你录入的内容**，提取引文 ≤100 字符，更新 reading-notes 和 claims。
- ✅ 我会维护 `MANIFEST.md` 的 fillStatus，让你随时知道还差什么。
- ❌ 我**不会编**任何文本——所有 .md 文件初始都是空 frontmatter + 提示，不预填任何"原文"。
- ❌ 我**不会修改**你已录入的内容（除非你明确让我做格式 normalize），避免污染底本。
