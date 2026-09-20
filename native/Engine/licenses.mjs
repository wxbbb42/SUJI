import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url));
const lock=JSON.parse(await readFile(path.join(here,'package-lock.json'),'utf8'));
const sections=['SUJI local computation engine — third-party notices\n\nThe following code is included in the JavaScriptCore engine. Versions are pinned by native/Engine/package-lock.json. Font, artwork and audio notices are distributed separately.'];
for(const [directory,entry] of Object.entries(lock.packages).sort(([a],[b])=>a.localeCompare(b))) {
  if(!directory || entry.dev || !directory.startsWith('node_modules/'))continue;
  const pkg=JSON.parse(await readFile(path.join(here,directory,'package.json'),'utf8'));
  let license;
  for(const name of ['LICENSE','LICENSE.md','LICENSE.txt']) {
    try { license=await readFile(path.join(here,directory,name),'utf8'); break; } catch(error) { if(error.code!=='ENOENT')throw error; }
  }
  // Astronomy Engine's published package embeds its complete MIT grant in source.
  if(!license && pkg.name==='astronomy-engine' && entry.version==='2.1.19' && pkg.license==='MIT') {
    const source=await readFile(path.join(here,directory,'astronomy.js'),'utf8');
    const header=source.match(/^\/\*\*[\s\S]*?\*\//)?.[0];
    if(header?.includes('MIT License') && header.includes('Copyright (c) 2019-2023 Don Cross') &&
       header.includes('Permission is hereby granted, free of charge') && header.includes('SOFTWARE.'))license=header;
  }
  if(!license)throw new Error(`Missing distributable license for ${pkg.name}`);
  sections.push(`${pkg.name} ${entry.version} (${pkg.license})\n${'='.repeat(60)}\n${license.trim()}`);
}
sections.push(await readFile(path.join(here,'validation/research-qizheng/catalogue/ATTRIBUTION.md'),'utf8'));
await writeFile(process.env.SUJI_NOTICES_OUTPUT ?? path.resolve(here,'../Resources/ThirdPartyNotices.txt'),sections.join('\n\n')+'\n');
