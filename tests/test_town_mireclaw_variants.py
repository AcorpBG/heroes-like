"""Exact variant coverage, non-aliasing and truthful probe boundaries."""
import copy
import json
import unittest

import town_mireclaw_variant_regression as variants
from packaged_town_scene_layer_regression import headless_script
from test_town_scene_layers import validate_scene_layers


class MireclawVariantTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((variants.ROOT/'content/town_building_scene_art_manifest.json').read_text())
        cls.towns = json.loads((variants.ROOT/'content/towns.json').read_text())['items']
        cls.buildings = {b['id']:b for b in json.loads((variants.ROOT/'content/buildings.json').read_text())['items']}

    def test_every_mireclaw_town_has_exact_layers(self):
        towns = [t for t in self.towns if t['faction_id']=='faction_mireclaw']
        self.assertEqual(len(towns),7)
        required = {b for t in towns for b in t['starting_building_ids']+t['buildable_building_ids']} - {'building_town_hall'}
        self.assertEqual(len(required),31)
        self.assertEqual(required,set(self.manifest['factions']['faction_mireclaw']))

    def test_missing_variant_fails_existing_strict_validator(self):
        malformed = copy.deepcopy(self.manifest)
        for building in variants.IDS:
            del malformed['factions']['faction_mireclaw'][building]
        errors = validate_scene_layers(malformed)
        self.assertTrue(any('Missing authored Mireclaw variant' in e for e in errors))
        for building in variants.IDS:
            self.assertTrue(any(building in e for e in errors))

    def test_simultaneous_names_are_not_shared_art(self):
        rows = self.manifest['factions']['faction_mireclaw']
        for stem in ('floodtide_forge','nightglass_dominion'):
            a,b = 'building_'+stem,'building_mireclaw_'+stem
            self.assertTrue(any({a,b} <= set(t['buildable_building_ids']) for t in self.towns))
            for key in ('source_sha256','runtime_sha256','ground_anchor','runtime_path'):
                self.assertNotEqual(rows[a][key],rows[b][key])

    def test_shared_variant_sites_cannot_coexist(self):
        pairs = [('building_smugglers_flotilla','building_war_drum_circle'),
                 ('building_mireclaw_hollowreed_moonwax_ossuary','building_mireclaw_moonbite_votive_drum_court')]
        for a,b in pairs:
            for town in self.towns:
                self.assertFalse({a,b} <= set(town['starting_building_ids']+town['buildable_building_ids']))

    def test_real_orders_have_authored_prerequisites_and_stores(self):
        scenarios = {s['id']:s for s in json.loads((variants.ROOT/'content/scenarios.json').read_text())['items']}
        towns = {t['id']:t for t in self.towns}
        for scenario_id,building_id in variants.AUTHORED_ORDERS.items():
            scenario = scenarios[scenario_id]
            placement = next(t for t in scenario['towns'] if t['owner']=='player')
            built = set(placement.get('built_buildings',[])+towns[placement['town_id']]['starting_building_ids'])
            self.assertNotIn(building_id,built)
            self.assertTrue(set(self.buildings[building_id]['requires']) <= built)
            for resource,cost in self.buildings[building_id]['cost'].items():
                self.assertGreaterEqual(scenario['starting_resources'].get(resource,0),cost)

    def test_probe_retains_input_save_and_fixture_boundaries(self):
        script = variants.script_text()
        self.assertEqual(script.count('func run() -> void:'),1)
        self.assertEqual(script.count('func mireclaw_expected_build('),1)
        self.assertNotIn('__IDS__',script)
        self.assertNotIn('__AUTHORED__',script)
        real = script.split('# Real authored Day-1 orders:')[1].split('# Detached developed view fixtures:')[0]
        for injected in ('built_buildings=', 'resources[', 'owner=', 'session.day='):
            self.assertNotIn(injected,real)
        self.assertIn('normalized(session.to_dict())==expected',script)
        self.assertIn('detached_developed_not_earned_progression',script)
        headless,removed = headless_script(script)
        self.assertGreater(len(removed),0)
        self.assertEqual(script.count('check('),headless.count('check('))
        self.assertIn('JOY_BUTTON_A',headless)
        self.assertIn('SaveService.load_session(3)',headless)

    def test_nonstandard_capture_resolution_is_explicit(self):
        original = variants.script_text()
        for resolution in ('1280x720','1920x1080'):
            self.assertEqual(variants.script_for_resolution(resolution),original)
        wide = variants.script_for_resolution('2048x1079')
        setting = 'SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))'
        explicit = 'get_window().content_scale_size = Vector2i(2048,1079)\n\tget_window().size = Vector2i(2048,1079)'
        self.assertEqual(wide,original.replace(setting,explicit))
        self.assertNotIn(setting,wide)
        with self.assertRaises(ValueError):
            variants.script_for_resolution('unexpected-size')


if __name__ == '__main__':
    unittest.main()
