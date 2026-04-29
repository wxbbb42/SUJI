# 有时 · 命理知识库

> Goal: make every algorithm rule, AI prompt, UI copy, and design choice **easily grounded in sources**.

This is not a dump of occult text. It is a source-grounded working knowledge base for product design and engineering.

## Structure

- `sources.json` — stable bibliography/source registry. Every source has a durable `id`.
- `claims.json` — atomic claims / rules / product policies mapped to source ids and repo refs.
- `SOURCES.generated.md` — generated human-readable index. Do not edit by hand.
- `source-index.json` — generated compact machine index for prompts / tooling.

## Source tiers

- **A** — classical / primary texts. Best for algorithms, terms, and traditional rule definitions.
- **B** — modern academic / serious research. Best for history, cultural framing, product language, and compliance.
- **C** — software libraries, calculators, websites. Best for engineering cross-checks; never enough alone for theory.
- **D** — modern school/practitioner/web materials. Useful but must be labeled and cross-checked.

## Ingest principles

1. **Stable source ids first**: new material must attach to an existing `sourceId` or create one.
2. **Claims are atomic**: one rule/idea per claim, with `sourceIds`, `repoRefs`, `confidence`, and `status`.
3. **Classic texts can be excerpted; modern copyrighted books cannot be bulk-ingested**.
   - For modern copyrighted material, keep only bibliography, short quotations where legally appropriate, page references, and our own notes.
4. **Algorithm rules need stronger evidence than UI atmosphere**.
   - Engine/table rule: usually A + fixture/cross-check.
   - Product framing: B + internal design policy is acceptable.
   - Website/library: C tier, useful for verification but not final theory.
5. **Contested entries are allowed**.
   - Mark disagreement explicitly instead of silently picking the convenient source.

## Workflow

```bash
npm run kb:mingli
```

The script validates `sources.json` / `claims.json` and regenerates:

- `docs/mingli/SOURCES.generated.md`
- `docs/mingli/source-index.json`

## How to cite in future design docs

Use source ids directly:

```md
This flow uses a “traditional frame + modern self-observation” voice.
Sources: `academic-mingli-history-lu`, `journal-zhouyi-research`, policy claim `product.no-absolute-fortune-claims`.
```

For code comments:

```ts
// Source: bazi-sanming-tonghui; Claim: bazi.hidden-stems.table
```

## Current gaps

- 紫微斗数古籍还只是 candidate metadata；需要补版本、卷次、摘录和 fixture 对照。
- 六爻只记录了《周易》和《火珠林》候选；纳甲、世应、用神体系需要继续拆 claim。
- 奇门需要把已实现的地盘/天盘/寄宫规则拆成 claim，并标出三源验证状态。
