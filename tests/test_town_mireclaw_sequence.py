"""The Mireclaw art packet must use real generated and paid progression."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import mireclaw_town_opening as opening
import town_scene_layer_regression as layers
from packaged_town_scene_layer_regression import headless_script


class MireclawTownSequenceTests(unittest.TestCase):
    def test_opening_uses_production_setup_and_save(self):
        script=opening.SCRIPT
        for fragment in ('Setup.build_random_map_player_config("10"',
                         '"faction_mireclaw","hero_vaska"',
                         'Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)',
                         'Setup.start_random_map_skirmish_session_from_setup(setup)',
                         'OverworldRules.set_active_town_visit',
                         'SaveService.save_session', 'SaveService.load_session',
                         'JSON.stringify(restored.to_dict())'):
            self.assertIn(fragment,script)
        for fragment in ('session.day=', 'session.overworld.resources=', 'towns[0].built_buildings='):
            self.assertNotIn(fragment,script)

    def test_mireclaw_keeps_shared_complete_input_checks(self):
        script=layers.mireclaw_script(layers.SCRIPT)
        for fragment in ('painted-alpha/cover-crop pointer ownership',
                         'independent_catalog_pixel_ownership',
                         'missing declared art fell back to catalog',
                         'layer_controller(JOY_BUTTON_A)',
                         'layer_controller(JOY_BUTTON_B)',
                         'layer_action("ui_accept")', 'layer_action("ui_cancel")',
                         'main building no longer opens the construction ledger',
                         'constructed market changed complete save/resume',
                         'complete Town save/resume changed gameplay state'):
            self.assertIn(fragment,script)

    def test_paid_market_and_pens_order_have_full_rule_controls(self):
        script=layers.mireclaw_script(layers.SCRIPT)
        for fragment in ('String(a.id)=="build:building_market_square"',
                         'for id in ["building_mire_pens"]:',
                         'TownRules.build_active_town(control,id)',
                         'Market UI diverged from complete authoritative build state',
                         'Mire Pens UI diverged from complete authoritative build state',
                         'shell.validation_select_build_plan(id)',
                         'shell.validation_confirm_build_plan()',
                         'field.validation_confirm_end_turn()',
                         'scene_layers/faction_mireclaw/%s.png',
                         'earned_market_save.json','earned_growth_save.json'):
            self.assertIn(fragment,script)
        self.assertIn('await inspect_scene_layers(["building_blackbranch_den","building_wayfarers_hall","building_market_square"])',script)
        self.assertEqual(script.count('func inspect_harbor_growth()'),1)
        self.assertEqual(script.count('func mireclaw_expected_build('),1)
        self.assertNotIn('__GROWTH_IDS__',script)

    def test_headless_package_omits_captures_only(self):
        script=layers.mireclaw_script(layers.SCRIPT)
        headless,removed=headless_script(script)
        self.assertTrue(removed)
        for fragment in ('check(', 'SaveService.', 'Input.parse_input_event'):
            self.assertEqual(script.count(fragment),headless.count(fragment))
        for fragment in ('Market UI diverged from complete authoritative build state',
                         'Mire Pens UI diverged from complete authoritative build state',
                         'await inspect_scene_layers(', 'layer_controller(JOY_BUTTON_A)',
                         'SaveService.save_session', 'scene_layers/faction_mireclaw/%s.png'):
            self.assertEqual(script.count(fragment),headless.count(fragment))

    def test_batch_follows_authored_dependencies_and_preserves_paid_authority(self):
        towns=json.loads((layers.ROOT/'content/towns.json').read_text())['items']
        town=next(t for t in towns if t['id']=='town_duskfen')
        buildings={b['id']:b for b in json.loads((layers.ROOT/'content/buildings.json').read_text())['items']}
        built=set(town['starting_building_ids'])|{'building_market_square'}
        self.assertEqual(len(layers.MIRECLAW_GROWTH_IDS),9)
        for id in layers.MIRECLAW_GROWTH_IDS:
            self.assertIn(id,town['buildable_building_ids'])
            self.assertTrue(set(buildings[id]['requires'])<=built,id)
            built.add(id)
        script=layers.mireclaw_script(layers.SCRIPT,batch_growth=True)
        for fragment in ('field.validation_confirm_end_turn()', 'shell._on_confirm_build_pressed()',
                         'purchase_mireclaw_materials(id)', 'TownRules.perform_market_action(control,action)',
                         'Mire Pens UI diverged from complete authoritative build state',
                         'upgrade erased saved predecessor', 'growth changed complete save/resume',
                         'batch_developed.png'):
            self.assertIn(fragment,script)
        for target in (r'session\.day',r'session\.overworld\.resources'):
            self.assertNotRegex(script,target+r'\s*=(?!=)')
        self.assertNotIn('__GROWTH_IDS__',script)

    def test_batch_sweeps_combined_input_once_not_every_purchase(self):
        script=layers.mireclaw_script(layers.SCRIPT,batch_growth=True)
        growth=script.split('func inspect_harbor_growth()',1)[1].split('func mireclaw_expected_build',1)[0]
        self.assertEqual(growth.count('await inspect_scene_layers(visible)'),1)
        self.assertNotIn('await inspect_scene_layers([id])',growth)
        self.assertIn('await inspect_mireclaw_new_building(id)',growth)
        self.assertNotIn('validation_select_build_plan(',growth)
        self.assertNotIn('validation_confirm_build_plan(',growth)
        self.assertIn('ordinary ledger selection changed full state',growth)
        self.assertIn('OverworldRules._runtime_normalized_signatures=normalization_cache',script)
        self.assertIn('build control clone changed full input',script)
        self.assertIn('complete_saved_state_equal',growth)
        headless,removed=headless_script(script)
        self.assertTrue(removed)
        for fragment in ('check(', 'SaveService.', 'Input.parse_input_event', 'validation_confirm_build_plan'):
            self.assertEqual(script.count(fragment),headless.count(fragment))

    def test_wrong_opening_is_rejected_before_engine_launch(self):
        with tempfile.TemporaryDirectory(prefix='mireclaw-wrong-save-') as work:
            save=Path(work)/'opening.json'
            save.write_text('{}\n')
            argv=['probe','--faction','mireclaw','--save',str(save),'--resolution','1280x720','--label','unit_wrong_mireclaw']
            with patch('sys.argv',argv), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stopped:
                layers.main()
            self.assertEqual(stopped.exception.code,2)
            self.assertIn('exact recorded nonterminal generated Duskfen Day-1 save',stderr.getvalue())
            run.assert_not_called()

    def test_foreign_sequence_is_rejected_before_input_or_engine(self):
        argv=['probe','--faction','mireclaw','--harbor-growth','--save','/nonexistent-opening.json','--resolution','1280x720','--label','unit_foreign_growth']
        with patch('sys.argv',argv), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stopped:
            layers.main()
        self.assertEqual(stopped.exception.code,2)
        self.assertIn('Bellwake growth sequences require --faction veilmourn',stderr.getvalue())
        run.assert_not_called()


if __name__=='__main__':
    unittest.main()
