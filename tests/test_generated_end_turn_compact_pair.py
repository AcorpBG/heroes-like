"""Exact-revision controls reject partial or dirty production comparisons."""
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import generated_end_turn_compact_pair as pair


class RevisionPreflightTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='heroes-pair-unit-', dir='/dev/shm')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.changed = ['scripts/core/A.gd', 'scenes/B.tscn', 'scenes/C.gd']
        for name in self.changed:
            (self.root/name).parent.mkdir(parents=True, exist_ok=True)
            (self.root/name).write_text('fixture')
        self.dirty = b''
        self.untracked = b''
        self.missing_old = False
        for target, replacement in [('ROOT',self.root), ('git',self.git)]:
            mock = patch.object(pair, target, replacement)
            mock.start()
            self.addCleanup(mock.stop)
        mock = patch.object(pair.subprocess, 'run', side_effect=lambda *args, **kwargs: SimpleNamespace(returncode=int(self.missing_old)))
        mock.start()
        self.addCleanup(mock.stop)

    def git(self, *args):
        if args[:2] == ('diff','--name-only'):
            return '\n'.join(self.changed).encode()
        if args[:2] == ('diff','HEAD'):
            return self.dirty
        if args[:2] == ('ls-files','--others'):
            return self.untracked
        self.fail('unexpected Git request: '+str(args))

    def test_every_changed_script_and_scene_is_selected(self):
        self.assertEqual(pair.reference_files('a'*40), sorted(self.changed))

    def test_no_production_change_is_not_a_performance_control(self):
        self.changed = []
        with self.assertRaisesRegex(ValueError, 'reference must differ'):
            pair.reference_files('a'*40)

    def test_unsupported_production_families_are_rejected(self):
        for name in ['art/tile.png','content/units.json','bin/native.so','src/native.cpp','project.godot','scenes/asset.png']:
            with self.subTest(name=name):
                self.changed = ['scripts/core/A.gd', name]
                with self.assertRaisesRegex(ValueError, 'review native, content, art'):
                    pair.reference_files('a'*40)

    def test_deleted_runtime_file_is_rejected(self):
        self.changed = ['scenes/Missing.gd']
        with self.assertRaisesRegex(ValueError, 'added/deleted'):
            pair.reference_files('a'*40)

    def test_added_runtime_file_is_rejected(self):
        self.missing_old = True
        with self.assertRaisesRegex(ValueError, 'added/deleted'):
            pair.reference_files('a'*40)

    def test_dirty_tracked_production_is_rejected(self):
        self.dirty = b'changed source'
        with self.assertRaisesRegex(ValueError, 'worktree must match HEAD'):
            pair.reference_files('a'*40)

    def test_untracked_production_is_rejected(self):
        self.untracked = b'scripts/new.gd'
        with self.assertRaisesRegex(ValueError, 'worktree must match HEAD'):
            pair.reference_files('a'*40)


if __name__ == '__main__':
    unittest.main()
