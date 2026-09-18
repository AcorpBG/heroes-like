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

    def test_scenery_families_are_explicit_and_fully_backed(self):
        manifest = json.loads((ROOT / 'art/overworld/native_scenery.json').read_text())
        assets = json.loads((ROOT / 'art/overworld/manifest.json').read_text())['object_assets']
        self.assertEqual(manifest['presentation_version'], 2)
        self.assertEqual(manifest['source_types']['134']['landscape_family'], 'rock')
        self.assertEqual(manifest['source_types']['135']['landscape_family'], 'woods')
        self.assertEqual(manifest['source_types']['137']['landscape_family'], 'conifers')
        for policy in manifest['source_types'].values():
            if 'landscape_family' not in policy:
                self.assertTrue(policy['asset_ids'])
                continue
            palettes = manifest['landscape_palettes'][policy['landscape_family']]
            self.assertEqual(len(palettes), 9)
            for biome, candidates in palettes.items():
                self.assertTrue(candidates, biome)
                for asset in candidates:
                    entry = assets[asset]
                    self.assertTrue((ROOT / entry['path'].removeprefix('res://')).is_file())
                    self.assertTrue(entry.get('source_manifest') or entry.get('source_generated_atlas'))

    def test_portable_resource_proxies_are_one_time_not_production_sites(self):
        catalog = json.loads((ROOT / 'content/homm3_re_reward_object_proxy_catalog.json').read_text())['entries']
        objects = {o['id']:o for o in json.loads((ROOT / 'content/map_objects.json').read_text())['items']}
        sites = {s['id']:s for s in json.loads((ROOT / 'content/resource_sites.json').read_text())['items']}
        pickups = [row for row in catalog if row['homm3_re_object_type_id'] == 79]
        self.assertEqual({row['homm3_re_object_subtype'] for row in pickups}, set(range(7)))
        for row in pickups:
            obj, site = objects[row['native_proxy_object_id']], sites[row['native_proxy_site_id']]
            self.assertEqual(obj['resource_site_id'], site['id'])
            self.assertTrue(obj['visitable'])
            self.assertEqual(obj['interaction']['cadence'], 'one_time')
            self.assertFalse(obj['interaction']['remains_after_visit'])
            self.assertEqual(set(site['rewards']), {row['native_resource_id']})
            self.assertFalse(site.get('persistent_control') or site.get('control_income') or site.get('resource_outputs'))
        for site_id in ['site_wood_wagon', 'site_ore_crates', 'site_aetherglass_lens_house', 'site_peatwax_reed_yard', 'site_embergrain_warm_granary', 'site_memory_salt_pan', 'site_reef_coin_assay']:
            self.assertTrue(sites[site_id]['persistent_control'], site_id)

    def test_live_site_contracts_not_stale_object_summaries_decide_eligibility(self):
        registry = json.loads((ROOT / 'content/random_map_object_eligibility.json').read_text())
        pool = next(p for p in registry['authored_pools'] if p['id'] == 'guarded_reward')
        self.assertTrue(pool['require_live_guard_contract'])
        self.assertNotIn('exclude_runtime_statuses', pool)
        objects = json.loads((ROOT / 'content/map_objects.json').read_text())['items']
        sites = {s['id']:s for s in json.loads((ROOT / 'content/resource_sites.json').read_text())['items']}
        eligible = [o for o in objects if o.get('primary_class') == 'guarded_reward_site']
        self.assertEqual(len(eligible), 32)
        for obj in eligible:
            site = sites[obj['resource_site_id']]
            contract = site['guarded_reward_contract']
            self.assertTrue(site['runtime_boundary']['guard_resolution_runtime_adopted'])
            self.assertFalse(contract['metadata_only_guard_contract'])
            self.assertEqual(contract['resource_site_id'], site['id'])
            self.assertTrue(contract['guard_encounter_id'] and contract['guard_army_group_id'])


if __name__ == '__main__': unittest.main()
