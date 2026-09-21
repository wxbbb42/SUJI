// Regenerate the DEBUG-only UI data with actual local engines, never a model.
// Run from any directory: node native/UITests/generate-mingli-audit-fixture.mjs
import { build } from '../Engine/node_modules/esbuild/lib/main.js';
import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import vm from 'node:vm';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const native = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const engine = path.join(native, 'Engine');
const result = await build({
  stdin: {
    contents: `
      import { HexagramEngine } from './src/divination/HexagramEngine';
      import { QimenEngine } from './src/qimen/QimenEngine';
      export const liuyao = new HexagramEngine().cast({
        question: '合成验收：整理一个待办决定', questionType: 'general',
        castTime: new Date('2026-09-19T04:00:00Z'), lineValues: [6,7,8,9,8,7]
      });
      export const qimen = new QimenEngine().setup({
        question: '合成验收：比较两个生活方案', questionType: 'career',
        setupTime: new Date('2026-09-19T04:00:00Z')
      });
    `,
    resolveDir: engine, loader: 'ts',
  },
  bundle: true, format: 'iife', globalName: 'Fixture', write: false,
  tsconfig: path.join(engine, 'tsconfig.json'),
});
const context = vm.createContext({});
vm.runInContext(await readFile(path.join(engine, 'timezone.js'), 'utf8'), context);
vm.runInContext(result.outputFiles[0].text, context);
const data = { liuyao: context.Fixture.liuyao, qimen: context.Fixture.qimen };
const sha = createHash('sha256').update(await readFile(path.join(native, 'Resources/mingli.js'))).digest('hex');
await writeFile(path.join(native, 'App/Debug/MingliDetailAuditData.swift'),
  `#if DEBUG\n// UI-only synthetic inputs, calculated from the local engines; no model output.\n// Source bundle SHA256: ${sha}\nenum MingliDetailAuditData {\n    static let engineRevision = "${sha}"\n    static let json = #"""\n${JSON.stringify(data)}\n"""#\n}\n#endif\n`);
console.log(`Generated deterministic UI data for bundle ${sha}.`);
