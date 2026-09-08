"""Driver preflight controls; runtime reports prove actual paid progression."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import town_scene_layer_regression as layers


class LateHarborSequenceTests(unittest.TestCase):
    def test_order_preserves_content_dependencies_and_upgrade(self):
        buildings = {b['id']: b for b in json.loads((layers.ROOT/'content/buildings.json').read_text())['items']}
        town = next(t for t in json.loads((layers.ROOT/'content/towns.json').read_text())['items'] if t['id']=='town_veilmourn_bellwake_harbor')
        all_buildings = set(town['starting_building_ids']+town['buildable_building_ids'])
        built = all_buildings - set(layers.LATE_HARBOR_IDS)
        self.assertEqual(len(built), 16)
        self.assertEqual(len(layers.LATE_HARBOR_IDS), len(set(layers.LATE_HARBOR_IDS)))
        for building_id in layers.LATE_HARBOR_IDS:
            with self.subTest(building_id=building_id):
                building = buildings[building_id]
                self.assertNotIn(building_id, built)
                self.assertTrue(set(building.get('requires', [])).issubset(built))
                if building.get('upgrade_from'):
                    self.assertIn(building['upgrade_from'], built)
                built.add(building_id)
        self.assertEqual(built, all_buildings)

    def test_altered_save_is_rejected_before_any_engine_launch(self):
        with tempfile.TemporaryDirectory(prefix='town-late-input-') as temporary:
            save = Path(temporary)/'not-earned.json'
            save.write_text('{}\n')
            args = ['town_scene_layer_regression.py', '--late-harbor-growth', '--save', str(save),
                    '--resolution', '1280x720', '--label', 'unit_invalid_late_save']
            with patch('sys.argv', args), patch.object(layers, 'run_probe') as launch:
                with contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                    layers.main()
                self.assertEqual(stop.exception.code, 2)
                self.assertIn('exact recorded nonterminal earned Day-14 save', stderr.getvalue())
                launch.assert_not_called()

    def test_sequences_are_mutually_exclusive(self):
        args = ['town_scene_layer_regression.py', '--late-harbor-growth', '--rigging-magic-growth',
                '--save', '/nonexistent-input-must-not-be-read.json', '--resolution', '1280x720', '--label', 'unit_ambiguous_sequence']
        with patch('sys.argv', args), patch.object(layers, 'run_probe') as launch:
            with contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                layers.main()
            self.assertEqual(stop.exception.code, 2)
            self.assertIn('select one normal construction sequence', stderr.getvalue())
            launch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
