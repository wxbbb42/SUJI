import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

// Node's platform math libraries can differ in the last bits. Match the
// existing JSC parity allowance only for astronomy coordinate fields. Never
// round production/cache data or loosen identity, time or other-tool checks.
const angularFields='(sevenBodies\\.positions|mansions\\.(positions|boundaries))\\.\\d+\\.(longitudeDegrees|latitudeDegrees|rightAscensionDegrees|declinationDegrees|entryDegrees|widthDegrees|nextRightAscensionDegrees|distanceToBoundaryDegrees)$';
const natalAnglePath=new RegExp('^result\\.'+angularFields);
const toolAnglePath=new RegExp('^(result\\.result|request\\.astronomy)\\.'+angularFields);
export function compareFixtures(actual, expected) {
  const differences=[];
  if(!Array.isArray(actual)||!Array.isArray(expected)||actual.length!==expected.length) return ['fixture count/type differs'];
  expected.forEach((fixture,index)=>{
    const request=fixture.request;
    const astronomy=request?.command==='natal-astronomy'||(request?.command==='tool'&&request.name==='get_natal_astronomy');
    const anglePath=request?.command==='natal-astronomy'?natalAnglePath:toolAnglePath;
    function compare(a,b,path) {
      if(a===b)return;
      if(astronomy&&anglePath.test(path)&&typeof a==='number'&&typeof b==='number'&&Number.isFinite(a)&&Number.isFinite(b)&&Math.abs(a-b)<=1e-9)return;
      if(Array.isArray(a)&&Array.isArray(b)&&a.length===b.length) {a.forEach((v,i)=>compare(v,b[i],path+'.'+i));return;}
      if(a&&b&&typeof a==='object'&&typeof b==='object'&&!Array.isArray(a)&&!Array.isArray(b)) {
        const ak=Object.keys(a).sort(),bk=Object.keys(b).sort();
        if(JSON.stringify(ak)===JSON.stringify(bk)){for(const key of ak)compare(a[key],b[key],path?path+'.'+key:key);return;}
      }
      differences.push(`fixture ${index} ${path}: ${JSON.stringify(a)} != ${JSON.stringify(b)}`);
    }
    compare(actual[index],fixture,'');
  });
  return differences;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href) {
  const root=fileURLToPath(new URL('../../',import.meta.url));
  const relative='native/Resources/engine-fixtures.json';
  const expected=JSON.parse(execFileSync('git',['show','HEAD:'+relative],{cwd:root,encoding:'utf8',maxBuffer:16*1024*1024}));
  const actual=JSON.parse(readFileSync(new URL('../Resources/engine-fixtures.json',import.meta.url),'utf8'));
  const differences=compareFixtures(actual,expected);
  if(differences.length){console.error(differences.slice(0,10).join('\n'));process.exitCode=1;}
  else console.log(`Engine fixtures match: ${actual.length}; astronomy angles within 1e-9 degrees, all other fields exact.`);
}
