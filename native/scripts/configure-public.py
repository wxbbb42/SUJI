#!/usr/bin/env python3
"""Copy only Supabase's public app configuration; never copy model or service keys."""
import pathlib, plistlib, os
from urllib.parse import urlparse
root = pathlib.Path(__file__).resolve().parents[1]
values = {}
for source in [root.parent/'.env', root.parent/'.env.local']:
    if source.exists():
        for line in source.read_text().splitlines():
            line=line.strip()
            if not line or line.startswith('#') or '=' not in line: continue
            key,value=line.split('=',1)
            if key in ['EXPO_PUBLIC_SUPABASE_URL','EXPO_PUBLIC_SUPABASE_ANON_KEY']:
                values[key]=value.strip().strip('"\'')
for key in ['EXPO_PUBLIC_SUPABASE_URL','EXPO_PUBLIC_SUPABASE_ANON_KEY']:
    if os.getenv(key): values[key]=os.environ[key]
url=values.get('EXPO_PUBLIC_SUPABASE_URL',''); anon=values.get('EXPO_PUBLIC_SUPABASE_ANON_KEY','')
if urlparse(url).scheme=='https' and urlparse(url).hostname and len(anon)>30 and 'your-' not in url:
    (root/'Resources/PublicConfig.plist').write_bytes(plistlib.dumps({'SUPABASE_URL':url,'SUPABASE_ANON_KEY':anon}))
    print('Prepared public Supabase configuration. No private keys copied.')
else:
    print('No complete public Supabase configuration found; local mode remains available.')
