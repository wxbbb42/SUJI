# Reproduce: python3 retrieve-classical.py /tmp/suji-classical-refetch
import urllib.request,urllib.parse,json,hashlib,concurrent.futures
from pathlib import Path
from html.parser import HTMLParser
import sys
root=Path(sys.argv[1]).resolve()
root.mkdir(parents=True,exist_ok=True)
# Fetch pinned revisions into a separate reproduction directory.
revisions={'tushu567':1942530,'xingxue1':626726,'xingxue2':784366}
class Plain(HTMLParser):
 def __init__(self):super().__init__();self.parts=[]
 def handle_data(self,s):self.parts.append(s)
 def handle_starttag(self,t,a):
  if t in ('p','br','h2','h3','div'):self.parts.append('\n')
def fetch(item):
 key,title=item
 u='https://zh.wikisource.org/w/api.php?'+urllib.parse.urlencode(dict(action='parse',oldid=revisions[key],prop='text|revid',format='json'))
 req=urllib.request.Request(u,headers={'User-Agent':'SUJI-research'})
 try:
  raw=urllib.request.urlopen(req,timeout=25).read();d=json.loads(raw);h=d['parse']['text']['*'];p=Plain();p.feed(h);s=''.join(p.parts)
  (root/(key+'.api.json')).write_bytes(raw);(root/(key+'.txt')).write_text(s)
  info=dict(key=key,title=title,url=u,revision=d['parse']['revid'],sha256=hashlib.sha256(raw).hexdigest(),textSHA256=hashlib.sha256(s.encode()).hexdigest())
  print(json.dumps(info,ensure_ascii=False),flush=True)
  for term in ['安命度法','安命法','定命宮','紫氣','紫炁','羅㬋']:
   start=0
   for _ in range(3):
    i=s.find(term,start)
    if i<0:break
    print(key,term,s[max(i-60,0):i+950],flush=True);start=i+len(term)
  return info
 except Exception as e:print(key,str(e),flush=True);return dict(key=key,error=str(e))
items=[('tushu567','欽定古今圖書集成/博物彙編/藝術典/第567卷'),('xingxue1','星學大成 (四庫全書本)/卷01'),('xingxue2','星學大成 (四庫全書本)/卷02')]
rows=list(concurrent.futures.ThreadPoolExecutor(3).map(fetch,items));(root/'sources-initial.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
