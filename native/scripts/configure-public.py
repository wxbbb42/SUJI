#!/usr/bin/env python3
"""Prepare public Supabase app configuration, including legacy env migration."""
import base64
import json
import os
import pathlib
import plistlib
from urllib.parse import urlparse


PUBLIC_KEYS = ('SUPABASE_URL', 'SUPABASE_ANON_KEY')


def public_values(values):
    """Canonical names win within each source; legacy names are migration-only."""
    return {
        key: values.get(key) or values.get('EXPO_PUBLIC_' + key)
        for key in PUBLIC_KEYS
        if values.get(key) or values.get('EXPO_PUBLIC_' + key)
    }


def is_public_key(value):
    if value.startswith('sb_publishable_'):
        return len(value) > 30 and 'REPLACE' not in value
    # Inspect only the public role; this is not a replacement for server JWT validation.
    try:
        parts = value.split('.')
        if len(parts) != 3:
            return False
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + '=' * (-len(parts[1]) % 4)))
        return isinstance(payload, dict) and payload.get('role') == 'anon'
    except (ValueError, UnicodeError):
        return False


def configure(root):
    values = {}
    for source in [root.parent / '.env', root.parent / '.env.local']:
        if not source.exists():
            continue
        parsed = {}
        for line in source.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, value = line.split('=', 1)
            parsed[key.strip()] = value.strip().strip('"\'')
        values.update(public_values(parsed))
    values.update(public_values(os.environ))
    url = values.get('SUPABASE_URL', '')
    anon = values.get('SUPABASE_ANON_KEY', '')
    valid_url = urlparse(url).scheme == 'https' and urlparse(url).hostname and 'your_project' not in url.lower()
    if not valid_url or not is_public_key(anon):
        print('No valid public Supabase configuration found; existing app configuration left unchanged.')
        return False
    destination = root / 'Resources' / 'PublicConfig.plist'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(plistlib.dumps({key: values[key] for key in PUBLIC_KEYS}))
    print('Prepared public Supabase configuration. No private keys copied.')
    return True


if __name__ == '__main__':
    configure(pathlib.Path(__file__).resolve().parents[1])
