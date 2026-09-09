"""Complete Sunvault art, upgrade identity, real orders and batch-only fixtures."""
import copy
import hashlib
import json
import unittest

import sunvault_town_opening as opening
import town_sunvault_faction_regression as variants
import town_mireclaw_variant_regression as shared
from packaged_town_scene_layer_regression import headless_script
from test_town_scene_layers import validate_scene_layers


class SunvaultFactionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((variants.ROOT/'content/town_building_scene_art_manifest.json').read_text())
        cls.towns = [t for t in json.loads((variants.ROOT/'content/towns.json').read_text())['items'] if t['faction_id']=='faction_sunvault']
        cls.buildings = {b['id']:b for b in json.loads((variants.ROOT/'content/buildings.json').read_text())['items']}
        cls.scenarios = {s['id']:s for s in json.loads((variants.ROOT/'content/scenarios.json').read_text())['items']}

    def test_complete_five_town_union(self):
        union = {b for t in self.towns for b in t['starting_building_ids']+t['buildable_building_ids']} - {'building_town_hall'}
        self.assertEqual(len(self.towns),5)
        self.assertEqual(len(union),29)
        self.assertEqual(union,set(variants.IDS))
        self.assertEqual(union,set(self.manifest['factions']['faction_sunvault']))

    def test_all_missing_identities_fail_closed(self):
        malformed=copy.deepcopy(self.manifest)
        malformed['factions']['faction_sunvault']={}
        errors=validate_scene_layers(malformed)
        for id in variants.IDS:
            self.assertTrue(any('Missing authored Sunvault scene mapping' in e and id in e for e in errors),id)

    def test_all_originals_are_distinct(self):
        rows=self.manifest['factions']['faction_sunvault']
        for key in ('source_sha256','runtime_sha256','runtime_path'):
            self.assertEqual(len({rows[id][key] for id in variants.IDS}),29)

    def test_four_upgrades_keep_their_sites_and_ancestors(self):
        rows=self.manifest['factions']['faction_sunvault']
        briefs=json.loads((variants.ROOT/variants.BRIEFS_PATH).read_text())
        upgrades={id:self.buildings[id]['upgrade_from'] for id in variants.IDS if self.buildings[id].get('upgrade_from')}
        self.assertEqual(len(upgrades),4)
        for id,base in upgrades.items():
            self.assertEqual(briefs[id]['scene_bounds'],briefs[base]['scene_bounds'])
            self.assertEqual(rows[id]['ground_anchor'],rows[base]['ground_anchor'])
            self.assertIn(base,self.buildings[id]['requires'])

    def test_shared_variant_site_is_mutually_exclusive(self):
        pair={'building_sunvault_meridian_seven_facet_orrery','building_sunvault_splitprism_heliograph_battery'}
        for town in self.towns:
            self.assertFalse(pair<=set(town['starting_building_ids']+town['buildable_building_ids']))

    def test_authored_purchases_have_real_prerequisites_and_stores(self):
        towns={t['id']:t for t in self.towns}
        for scenario_id,id in variants.AUTHORED_ORDERS.items():
            scenario=self.scenarios[scenario_id]
            placement=next(t for t in scenario['towns'] if t['owner']=='player')
            built=set(placement.get('built_buildings',[])+towns[placement['town_id']]['starting_building_ids'])
            self.assertNotIn(id,built)
            self.assertTrue(set(self.buildings[id]['requires'])<=built)
            for resource,cost in self.buildings[id]['cost'].items():
                self.assertGreaterEqual(scenario['starting_resources'].get(resource,0),cost)

    def test_starter_is_not_fabricated_paid_progression(self):
        constructible={b for t in self.towns for b in t['buildable_building_ids']} - {'building_town_hall'}
        self.assertEqual(len(constructible),28)
        self.assertNotIn('building_shard_yard',constructible)
        self.assertIn('building_mirror_forge',constructible)
        script=variants.script_text()
        self.assertIn('exercised.size()==28',script)
        self.assertIn('small_fixture.duplicate(true)',script)
        self.assertNotIn('fixture: Dictionary=earned.duplicate(true)',script)
        self.assertIn('map_size.width*small_fixture.overworld.map_size.height==60',script)

    def test_real_large_request_and_runtime_hero_identity(self):
        script=opening.script_text()
        self.assertIn('homm3_large',script)
        self.assertIn('hero_solera',script)
        self.assertNotIn('hero_sunvault_solera_prismarch',script)

    def test_complete_rule_input_save_controls_retained(self):
        script=variants.script_text()
        self.assertGreater(script.count('check('),shared.script_text().count('check('))
        for text in ('normalized(session.to_dict())==expected','detached_developed_not_earned_progression','JOY_BUTTON_A','SaveService.load_session(3)','generated_large_market'):
            self.assertIn(text,script)
        headless,removed=headless_script(script)
        self.assertTrue(removed)
        self.assertEqual(script.count('check('),headless.count('check('))
        self.assertIn('Vector2i(2048,1079)',variants.script_for_resolution('2048x1079'))

    def test_prior_mireclaw_probe_unchanged(self):
        self.assertEqual(hashlib.sha256(shared.script_for_resolution('1280x720').encode()).hexdigest(),
                         '652b07f38a8e73f7b9c31bae6acf24b7d0dff50847c00d727f75470b2130d6ae')


if __name__=='__main__':
    unittest.main()
