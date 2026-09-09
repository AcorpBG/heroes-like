"""Exact Veilmourn scene union, authored orders and preserved probe controls."""
import copy
import hashlib
import json
import unittest

import town_veilmourn_variant_regression as variants
import town_mireclaw_variant_regression as shared
from packaged_town_scene_layer_regression import headless_script
from test_town_scene_layers import validate_scene_layers


class VeilmournVariantTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((variants.ROOT/'content/town_building_scene_art_manifest.json').read_text())
        cls.towns = json.loads((variants.ROOT/'content/towns.json').read_text())['items']
        cls.buildings = {b['id']: b for b in json.loads((variants.ROOT/'content/buildings.json').read_text())['items']}

    def test_complete_five_town_union(self):
        towns = [t for t in self.towns if t['faction_id']=='faction_veilmourn']
        required = {b for t in towns for b in t['starting_building_ids']+t['buildable_building_ids']} - {'building_town_hall'}
        self.assertEqual(len(towns), 5)
        self.assertEqual(len(required), 27)
        self.assertEqual(required, set(self.manifest['factions']['faction_veilmourn']))

    def test_missing_variants_fail_strict_validation(self):
        malformed = copy.deepcopy(self.manifest)
        for building in variants.IDS:
            del malformed['factions']['faction_veilmourn'][building]
        errors = validate_scene_layers(malformed)
        for building in variants.IDS:
            self.assertTrue(any('Missing authored Veilmourn variant' in e and building in e for e in errors))

    def test_five_distinct_originals_and_sites(self):
        rows = self.manifest['factions']['faction_veilmourn']
        for key in ('source_sha256', 'runtime_sha256', 'runtime_path'):
            self.assertEqual(len({rows[b][key] for b in variants.IDS}), 5)
        self.assertEqual(len({tuple(rows[b]['ground_anchor']) for b in variants.IDS}), 5)

    def test_authored_orders_need_no_injected_state(self):
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

    def test_shared_rule_input_save_assertions_are_retained(self):
        script = variants.script_text()
        self.assertEqual(script.count('check('), shared.script_text().count('check('))
        for old in ('faction_mireclaw', 'town_moonbite_reedshrine', 'unchanged_earned_duskfen'):
            self.assertNotIn(old,script)
        self.assertIn('exercised.size()==5',script)
        self.assertIn('normalized(session.to_dict())==expected',script)
        self.assertIn('detached_developed_not_earned_progression',script)
        headless, removed = headless_script(script)
        self.assertTrue(removed)
        self.assertEqual(script.count('check('), headless.count('check('))
        self.assertIn('JOY_BUTTON_A',headless)
        self.assertIn('SaveService.load_session(3)',headless)
        self.assertIn('Vector2i(2048,1079)',variants.script_for_resolution('2048x1079'))

    def test_accepted_mireclaw_probe_body_unchanged(self):
        self.assertEqual(hashlib.sha256(shared.script_for_resolution('1280x720').encode()).hexdigest(),
                         '652b07f38a8e73f7b9c31bae6acf24b7d0dff50847c00d727f75470b2130d6ae')


if __name__ == '__main__':
    unittest.main()
