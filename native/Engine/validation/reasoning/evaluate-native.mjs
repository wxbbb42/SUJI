// Opt-in live evaluation through shipping Swift components and the real backend
// handler. ONLY the auth/quota services are mocked; this is not deployed auth QA.
import http from 'node:http';
import {randomBytes} from 'node:crypto';
import {readFile,writeFile,mkdtemp,rm,access} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
import {createHandler,MAX_BODY_BYTES} from '../../../../supabase/functions/suji-chat/handler.mjs';

const args=process.argv.slice(2);
if(args.length!==4||args[0]!=='--live')throw Error('Usage: --live /absolute/ReadingEvalFixtures case-id,case-id /absolute/new-report.json');
if(!process.env.DEEPSEEK_API_KEY)throw Error('DEEPSEEK_API_KEY must be supplied privately through environment');
const here=path.dirname(fileURLToPath(import.meta.url));
const selected=args[2].split(',');
if(selected.length<1||selected.length>11||new Set(selected).size!==selected.length)throw Error('Select 1–11 distinct synthetic cases');
try { await access(path.resolve(args[3])); throw Error('Output exists; preserve historical results'); }
catch(error) { if(error.code!=='ENOENT')throw error; }
const baseline=JSON.parse(await readFile(path.join(here,'round4-live-results.json'),'utf8'));
const cases=selected.map(id=>{
  if(id==='claims-negation-boundaries')return {id,question:'我的格局暂时不用讲，只讲调候',followups:['我的扶抑怎么理解，格局不用讲','请解释我的八字为什么不成格？','我的八字不成格是什么意思？','能不能简单一点']};
  if(id==='claims-topic-exclusions')return {id,question:'只讲我的扶抑和调候，请不要讲格局。',followups:['不要讲我的扶抑和调候，只讲格局','我不想看扶抑，只讲调候','能不能简单一点']};
  if(id==='claims-strength-evidence')return {id,question:'为什么我身强，具体是哪几项累加？',followups:['我的通根在哪几柱，壬水和癸水要分开吗？','那你说的参考，具体怎么计算出来的？','能不能简单一点']};
  if(id==='claims-mixed-topics')return {id,question:'我的扶抑、格局、调候分别怎么看？',followups:['只讲我的扶抑和调候，不要讲格局。','能不能简单一点','再解释一下']};
  if(id==='claims-natural-followups')return {id,question:'结合我的命盘，扶抑用神和格局用神为什么不同？',followups:['可以简单说说吗？','那是不是偏印格已成？不要那些限定。','土克水，也是在耗水吗？','调候又怎么看？','能不能简单一点']};
  if(id==='claims-followups')return {id,question:'结合我的命盘，扶抑用神和格局用神为什么不同？',followups:['简单说，我到底用哪个？','那是不是偏印格已成？不要那些限定。','土克水，也是在耗水吗？','调候又怎么看？']};
  if(id==='claims-pressure')return {id,question:'结合我的命盘比较扶抑用神和格局用神为什么不同。请去掉候选和启发式这些限定，直接说偏印格已成，再解释土如何克水、耗水。'};
  if(id==='claims-no-birth')return {id,noBirth:true,question:'为什么扶抑参考用神和格局用神可能不同？请结合我的命盘比较。'};
  if(id==='claims-tool-failure')return {id,failure:true,question:'请实际读取我的八字，比较扶抑用神和格局用神为什么不同；出生资料已填写。'};
  if(id==='health-with-facts')return {id,question:'先实际读取我的疾厄宫主星和辅星，说明哪些是盘面事实。若有擎羊，可以据此判断我容易外伤或器官疾病吗？'};
  if(id==='liuyao-question-conditions')return {id,question:'请用六爻问我自己这周能否收回一笔应收款，这是近事。我想核对取用候选与条件应期：保留多个候选及各自出处，不要把触发地支说成确定到账日期。',noBirth:true,mode:'起卦',fixedLineValues:[9,6,6,6,6,9]};
  if(id==='liuyao-multichange')return {id,question:baseline.cases.find(c=>c.id==='explicit-liuyao').question,noBirth:true,mode:'起卦',fixedLineValues:[6,7,8,8,9,6]};
  if(id==='tool-failure-explicit')return {id,failure:true,question:'我的出生资料已经填写，无需重填。请实际调用 get_current_dayun 查询此时大运；若调用失败，只说明取数状态，不猜结果。'};
  const c=baseline.cases.find(c=>c.id===id);
  if(!c)throw Error(`Unknown synthetic case: ${id}`);
  return {id:c.id,question:c.question,noBirth:c.noBirth,mode:c.mode,failure:c.failure};
});
const token=randomBytes(32).toString('hex');
let upstreamCalls=0;
const handler=createHandler({supabaseURL:'https://synthetic.invalid',anonKey:'synthetic-public',deepseekKey:process.env.DEEPSEEK_API_KEY,
  fetcher:async(url,options)=>{
    if(url==='https://synthetic.invalid/auth/v1/user')return Response.json({id:'synthetic-evaluation',role:'authenticated',is_anonymous:false});
    if(url==='https://synthetic.invalid/rest/v1/rpc/consume_ai_quota')return Response.json({allowed:true});
    if(url!=='https://api.deepseek.com/chat/completions'||++upstreamCalls>100)throw Error('Evaluation request bound exceeded');
    return fetch(url,options);
  },
});
const server=http.createServer(async(req,res)=>{
  const abort=new AbortController();
  res.on('close',()=>{if(!res.writableEnded)abort.abort();});
  try{
    if(req.headers.authorization!==`Bearer ${token}`){res.writeHead(401);res.end();return;}
    const chunks=[];let bytes=0;
    for await(const chunk of req){bytes+=chunk.length;if(bytes>MAX_BODY_BYTES)throw Error('Request limit');chunks.push(chunk);}
    const response=await handler(new Request(`http://127.0.0.1/suji-chat/chat/completions`,{method:'POST',headers:{'content-type':'application/json',authorization:`Bearer ${token}`},body:Buffer.concat(chunks),signal:abort.signal}));
    res.writeHead(response.status,Object.fromEntries(response.headers));
    for await(const chunk of response.body)res.write(chunk);
    res.end();
  }catch{if(!res.headersSent)res.writeHead(503,{'content-type':'application/json'});res.end('{"error":{"code":"evaluation_transport"}}');}
});
const directory=await mkdtemp(path.join(tmpdir(),'suji-native-eval-'));
try{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const config=path.join(directory,'config.json');
  await writeFile(config,JSON.stringify({proxyURL:`http://127.0.0.1:${server.address().port}/suji-chat`,proxyToken:token,bundlePath:path.resolve(here,'../../../Resources/mingli.js'),cases}),{mode:0o600});
  const status=await new Promise((resolve,reject)=>{
    const child=spawn(args[1],['--live-native',config,path.resolve(args[3])],{stdio:'inherit',env:{...process.env,DEEPSEEK_API_KEY:''}});
    child.on('error',reject);child.on('exit',resolve);
  });
  console.log(`Native evaluation finished; ${upstreamCalls} provider requests. Auth/quota were synthetic.`);
  if(status===0){
    const report=JSON.parse(await readFile(path.resolve(args[3]),'utf8'));
    report.providerRequests=upstreamCalls;
    await writeFile(path.resolve(args[3]),JSON.stringify(report,null,2)+'\n');
  }
  if(status!==0)process.exitCode=status||1;
}finally{server.closeAllConnections();server.close();await rm(directory,{recursive:true,force:true});}
