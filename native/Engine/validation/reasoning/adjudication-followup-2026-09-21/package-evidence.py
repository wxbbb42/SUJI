"""Package final synthetic captures only; keep historical evidence untouched."""
import hashlib
import json
import pathlib
import subprocess
import sys
import tarfile

root = pathlib.Path.cwd()
folder = pathlib.Path(sys.argv[1])
out = pathlib.Path(__file__).resolve().parent
members = []
for domain, count in [('divination', 65), ('astronomy', 16)]:
    base = folder / domain
    fixtures = json.loads((base / 'fixtures.json').read_text())
    assert len(fixtures) == count
    assert len(json.loads((base / 'final-native-capacity-report.json').read_text())) == count
    assert json.loads((base / 'final-wire-decoder-report.json').read_text())['passed'] == count
    for name in ['fixtures.json', 'final-native-capacity-report.json', 'final-wire-decoder-report.json']:
        members.append(base / name)
    for index in range(count):
        members.extend(base / f'{prefix}-{index}.json' for prefix in ['final-wire-request', 'final-expected-facts'])


def record(path, relative_to):
    content = path.read_bytes()
    return {'path': str(path.relative_to(relative_to)), 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest()}

archive = out / 'final-capacity-evidence.tar.gz'
with tarfile.open(archive, 'w:gz') as bundle:
    for path in members:
        info = bundle.gettarinfo(str(path), arcname=str(path.relative_to(folder)))
        info.uid = info.gid = 0
        info.uname = info.gname = ''
        with path.open('rb') as contents:
            bundle.addfile(info, contents)

sources = list((root / 'native/Core/Sources/SujiCore').glob('*.swift'))
sources += [p for p in (root / 'native/Engine/src').rglob('*') if p.suffix in ['.ts', '.json'] and '__tests__' not in p.parts]
sources += [root / p for p in ['native/Engine/bridge.ts', 'native/Engine/timezone.js', 'native/Engine/build.mjs', 'native/Engine/package-lock.json', 'native/Resources/mingli.js', 'native/Resources/engine-fixtures.json', 'supabase/functions/suji-chat/handler.mjs']]
sources += [p for p in out.iterdir() if p.suffix in ['.swift', '.mjs', '.cjs', '.py']]
manifest = {
    'scope': 'Final actual ChatClient HTTP captures and full fact expectations; synthetic fixtures, no provider request. All source hashes describe the capture code, independent of later documentation commits.',
    'baselineCommit': '1a55f46809d16eddf2537cb891ec25ed0d40f800',
    'captureBaseCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'workingTreeCapture': True,
    'members': [record(path, folder) for path in members],
    'archive': record(archive, root),
    'sources': [record(path, root) for path in sorted(set(sources))],
}
(out / 'final-capacity-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print(f'Archived {len(members)} files; {archive.stat().st_size} bytes')
