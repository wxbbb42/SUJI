"""Verify every reused archived byte hash and exact Unicode excerpt range."""
import hashlib, json
from pathlib import Path
base=Path(__file__).resolve().parent
manifest=json.loads((base/'selected-passages.json').read_text())
for item in manifest['passages']:
    raw=(base/item['htmlFile']).read_bytes()
    text_bytes=(base/item['sourceFile']).read_bytes()
    text=text_bytes.decode('utf-8')
    assert hashlib.sha256(raw).hexdigest()==item['htmlSHA256']
    assert hashlib.sha256(text_bytes).hexdigest()==item['textSHA256']
    quote=text[item['startUnicode']:item['endUnicode']]
    assert quote==item['quote']
    assert hashlib.sha256(quote.encode()).hexdigest()==item['quoteSHA256']
print(f"PASS: {len(manifest['passages'])} source excerpts; raw HTML/text SHA256 and Unicode ranges verified")
