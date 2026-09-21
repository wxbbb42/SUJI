import base64
import importlib.util
import json
import os
import pathlib
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'configure_public', pathlib.Path(__file__).resolve().parents[1] / 'configure-public.py'
)
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


def jwt(role):
    payload = base64.urlsafe_b64encode(json.dumps({'role': role}).encode()).decode().rstrip('=')
    return 'test.' + payload + '.test'


class PublicConfigTests(unittest.TestCase):
    def test_only_public_credentials_are_accepted(self):
        self.assertTrue(config.is_public_key(jwt('anon')))
        self.assertTrue(config.is_public_key('sb_publishable_' + 'x' * 32))
        for secret in [jwt('service_role'), jwt('authenticated'), 'sb_secret_' + 'x' * 32,
                       'sk-' + 'x' * 32, 'not-a-jwt', 'test.invalid.test']:
            self.assertFalse(config.is_public_key(secret))

    @patch.dict(os.environ, {}, clear=True)
    def test_legacy_file_is_migrated_but_private_values_are_not_copied(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory) / 'native'
            (root.parent / '.env').write_text(
                'EXPO_PUBLIC_SUPABASE_URL=https://example.supabase.co\n'
                'EXPO_PUBLIC_SUPABASE_ANON_KEY=' + jwt('anon') + '\n'
                'DEEPSEEK_API_KEY=private-test-value\nSUPABASE_SERVICE_ROLE_KEY=private-test-value\n'
            )
            self.assertTrue(config.configure(root))
            data = plistlib.loads((root / 'Resources/PublicConfig.plist').read_bytes())
            self.assertEqual(set(data), set(config.PUBLIC_KEYS))
            self.assertNotIn('private-test-value', str(data))

    @patch.dict(os.environ, {}, clear=True)
    def test_local_file_then_environment_override_legacy_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory) / 'native'
            (root.parent / '.env').write_text(
                'EXPO_PUBLIC_SUPABASE_URL=https://old.supabase.co\n'
                'EXPO_PUBLIC_SUPABASE_ANON_KEY=' + jwt('anon') + '\n'
            )
            (root.parent / '.env.local').write_text('SUPABASE_URL=https://local.supabase.co\n')
            self.assertTrue(config.configure(root))
            destination = root / 'Resources/PublicConfig.plist'
            self.assertEqual(plistlib.loads(destination.read_bytes())['SUPABASE_URL'], 'https://local.supabase.co')
            with patch.dict(os.environ, {'SUPABASE_URL': 'https://env.supabase.co'}):
                self.assertTrue(config.configure(root))
            self.assertEqual(plistlib.loads(destination.read_bytes())['SUPABASE_URL'], 'https://env.supabase.co')

    @patch.dict(os.environ, {}, clear=True)
    def test_private_key_in_public_field_cannot_overwrite_existing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory) / 'native'
            destination = root / 'Resources/PublicConfig.plist'
            destination.parent.mkdir(parents=True)
            destination.write_bytes(b'existing config')
            (root.parent / '.env.local').write_text(
                'SUPABASE_URL=https://example.supabase.co\nSUPABASE_ANON_KEY=' + jwt('service_role') + '\n'
            )
            self.assertFalse(config.configure(root))
            self.assertEqual(destination.read_bytes(), b'existing config')


if __name__ == '__main__':
    unittest.main()
