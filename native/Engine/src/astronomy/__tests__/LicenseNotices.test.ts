import { mkdtempSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join,resolve } from 'path';
import { spawnSync } from 'child_process';

test('pinned production astronomy MIT notice is distributable even though package omits a LICENSE file',()=>{
  const scratch=mkdtempSync(join(tmpdir(),'suji-astronomy-notice-'));
  try {
    const output=join(scratch,'notices.txt');
    const result=spawnSync(process.execPath,['licenses.mjs'],{cwd:resolve(__dirname,'../../..'),env:{...process.env,SUJI_NOTICES_OUTPUT:output},encoding:'utf8'});
    expect({status:result.status,stderr:result.stderr}).toEqual({status:0,stderr:''});
    const text=readFileSync(output,'utf8');
    expect(text).toContain('astronomy-engine 2.1.19 (MIT)');
    expect(text).toContain('Copyright (c) 2019-2023 Don Cross');
    expect(text).toContain('Permission is hereby granted, free of charge');
    expect(text).not.toMatch(/pyswisseph/);
    expect(text).toContain(readFileSync(resolve(__dirname,'../../../validation/research-qizheng/catalogue/ATTRIBUTION.md'),'utf8'));
  } finally {rmSync(scratch,{recursive:true,force:true});}
});
