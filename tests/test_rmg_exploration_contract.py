"""Focused classification, raster provenance and reward-band invariants."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ExplorationContract(unittest.TestCase):
    def test_shared_classifier_matches_original_art_inventory(self):
        manifest = json.loads((ROOT / 'art/overworld/native_scenery.json').read_text())
        types = sorted(map(int, manifest['source_types']))
        code = '#include "runtime_object_classification.hpp"\n#include <iostream>\nint main(){for(int i=0;i<256;++i)if(std::string(aurelion::runtime_object_kind(i))=="decorative_obstacle")std::cout<<i<<"\\n";}\n'
        with tempfile.TemporaryDirectory(prefix='heroes-scenery-classifier-') as tmp:
            executable = Path(tmp) / 'probe'
            subprocess.run(['c++', '-std=c++17', '-I', str(ROOT / 'src/gdextension/include'), '-x', 'c++', '-', '-o', str(executable)], input=code, text=True, check=True)
            actual = list(map(int, subprocess.check_output([str(executable)], text=True).split()))
        self.assertEqual(actual, types)
        self.assertTrue({116,121,126,127,128,130,131,132,133,151,153,158,206,208,209,211}.issubset(types))
        for filename in ['map_package_service.cpp', 'rmg_native_batch_export_cli.cpp']:
            text = (ROOT / 'src/gdextension/src' / filename).read_text()
            self.assertIn('return aurelion::runtime_object_kind(type_id);', text)

    def test_semantic_bodies_use_existing_original_rasters(self):
        policies = json.loads((ROOT / 'art/overworld/native_scenery.json').read_text())['source_types']
        assets = json.loads((ROOT / 'art/overworld/manifest.json').read_text())['object_assets']
        for entry in policies.values():
            self.assertIn(entry['mode'], ['biome_palette', 'semantic_raster'])
            if entry['mode'] == 'semantic_raster':
                self.assertTrue(entry['asset_ids'])
            for asset in entry.get('asset_ids', []):
                path = ROOT / assets[asset]['path'].removeprefix('res://')
                self.assertTrue(path.is_file(), asset)
                self.assertTrue(assets[asset].get('source_generated') or assets[asset].get('source_generated_atlas') or assets[asset].get('source_manifest'), asset)
                self.assertEqual(path.read_bytes()[:8], b'\x89PNG\r\n\x1a\n')
        self.assertNotEqual(policies['126']['mode'], 'biome_palette')
        self.assertNotEqual(policies['127']['mode'], 'biome_palette')

    def test_random_artifact_bands_are_populated_and_distinct(self):
        registry = json.loads((ROOT / 'content/random_map_object_eligibility.json').read_text())
        bands = registry['artifact_rarities_by_source_type']
        self.assertEqual(bands, {'66':'common','67':'uncommon','68':'rare','69':'epic'})
        artifacts = json.loads((ROOT / 'content/artifacts.json').read_text())['items']
        for source, rarity in bands.items():
            candidates = {a['id'] for a in artifacts if a['rarity'] == rarity}
            self.assertGreaterEqual(len(candidates), 2)
            self.assertEqual(registry['source_type_pools'][source], 'artifact_reward')
        self.assertEqual(registry['source_type_pools']['16'], 'guarded_reward')


if __name__ == '__main__': unittest.main()
