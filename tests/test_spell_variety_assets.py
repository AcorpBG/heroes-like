#!/usr/bin/env python3
"""Fail closed on missing art, generic routing and incorrect effect families."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('spell_assets', ROOT / 'tools/prepare_spell_variety_assets.py')
assets = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assets)


class SpellVarietyAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='spell-variety-assets-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / assets.SOURCE.relative_to(ROOT)
        self.runtime = self.root / assets.RUNTIME.relative_to(ROOT)
        self.manifest = self.root / assets.MANIFEST.relative_to(ROOT)
        for folder in (self.source, self.runtime, self.manifest.parent):
            folder.mkdir(parents=True, exist_ok=True)
        # Only JSON is mutable; original art is read through symlinks. Tests
        # never create replacement paintings or modify retained originals.
        for folder, destination in ((assets.SOURCE, self.source), (assets.RUNTIME, self.runtime)):
            for path in folder.iterdir():
                if path.suffix == '.json':
                    (destination / path.name).write_bytes(path.read_bytes())
                elif path.suffix == '.png':
                    (destination / path.name).symlink_to(path)
        self.manifest.write_bytes(assets.MANIFEST.read_bytes())
        (self.manifest.parent / 'spells.json').symlink_to(ROOT / 'content/spells.json')
        overrides = dict(ROOT=self.root, SOURCE=self.source, RUNTIME=self.runtime, MANIFEST=self.manifest)
        context = patch.multiple(assets, **overrides)
        context.start()
        self.addCleanup(context.stop)
        self.briefs = json.loads((self.source / 'briefs.json').read_text())
        self.first = self.briefs['families'][0]
        self.spell = self.first['spell_ids'][0]

    @staticmethod
    def edit_json(path, change):
        value = json.loads(path.read_text())
        change(value)
        path.write_text(json.dumps(value))

    def test_approved_batch_reproduces(self):
        result = assets.prepare(check=True)
        self.assertEqual((result['explicit_battle_spells'], result['former_shared_spells'], result['families']), (97, 44, 21))

    def test_missing_mapping_fails(self):
        self.edit_json(self.manifest, lambda value: value['spell_cues'].pop(self.spell))
        with self.assertRaisesRegex(ValueError, 'incorrect live cue metadata'):
            assets.prepare(check=True)

    def test_shared_ward_route_fails(self):
        self.edit_json(self.manifest, lambda value: value['spell_cues'].update({self.spell: 'vfx_spell_command_ward'}))
        with self.assertRaisesRegex(ValueError, 'incorrect live cue metadata'):
            assets.prepare(check=True)

    def test_wrong_school_fails(self):
        self.edit_json(self.source / 'briefs.json', lambda value: value['families'][0].update(school_id='wrong_school'))
        with self.assertRaisesRegex(ValueError, 'semantically wrong family'):
            assets.prepare(check=True)

    def test_wrong_motion_fails(self):
        self.edit_json(self.manifest, lambda value: value['cues']['vfx_' + self.spell].update(motion_profile='ward'))
        with self.assertRaisesRegex(ValueError, 'incorrect live cue metadata'):
            assets.prepare(check=True)

    def test_wrong_runtime_asset_fails(self):
        runtime = self.runtime / ('family_' + self.first['id'] + '.png')
        runtime.unlink()  # Remove only the disposable symlink, never its target.
        runtime.symlink_to(self.source / (self.first['id'] + '_source.png'))
        with self.assertRaisesRegex(ValueError, 'runtime does not match retained source'):
            assets.prepare(check=True)

    def test_duplicate_painting_fails(self):
        second = self.briefs['families'][1]
        source = self.source / (second['id'] + '_source.png')
        source.unlink()
        source.symlink_to(self.source / (self.first['id'] + '_source.png'))
        with self.assertRaisesRegex(ValueError, 'duplicate effect artwork'):
            assets.prepare(check=True)

    def test_provenance_tampering_fails(self):
        self.edit_json(self.source / 'manifest.json', lambda value: value['items'][0].update(source_sha256='wrong'))
        with self.assertRaisesRegex(ValueError, 'Source provenance'):
            assets.prepare(check=True)


if __name__ == '__main__':
    unittest.main()
