"""The new-faction probe retains the common paid action and input assertions."""
import contextlib
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import town_scene_layer_regression as layers
import packaged_town_scene_layer_regression as packaged


class EmbercourtSequenceTests(unittest.TestCase):
    def test_civic_rejects_wrong_save_faction_or_combined_sequence(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-civic-') as temporary:
            save=Path(temporary)/'wrong.json'
            save.write_text('{}\n')
            for flags,message in [([], 'requires --faction embercourt'),
                                  (['--faction','embercourt'], 'exact earned nonterminal Medium11 Day-17 save'),
                                  (['--faction','embercourt','--embercourt-riverworks-growth'],'select one normal construction sequence')]:
                args=['probe','--embercourt-civic-growth','--save',str(save),'--resolution','1280x720','--label','unit_wrong_civic']+flags
                with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                    layers.main()
                self.assertEqual(stop.exception.code,2)
                self.assertIn(message,stderr.getvalue())
                run.assert_not_called()
        for flags in ({'supply':True},{'riverworks':True}):
            with self.assertRaisesRegex(ValueError,'select one normal construction sequence'):
                layers.embercourt_growth_script(civic=True,**flags)

    def test_civic_keeps_paid_ore_daily_complete_save_and_all_prior_input(self):
        script=layers.embercourt_growth_script(civic=True)
        self.assertEqual(layers.EMBERCOURT_CIVIC_IDS,['building_embercourt_lantern_court','building_embercourt_relief_quay'])
        for token in ('validation_request_end_turn()', 'validation_confirm_end_turn()', 'attempt<=28',
                      'validation_select_build_plan(id)', 'validation_confirm_build_plan()',
                      'validation_perform_town_action("market:buy:ore:1")', 'TownRules.perform_market_action(control',
                      'normalized(session.to_dict())==normalized(control.to_dict())', 'prior_built+[id]',
                      'growth construction costs changed', 'growth allowed a second same-day build', 'earned_growth_save.json'):
            self.assertIn(token,script)
        for id in layers.EMBERCOURT_IDS+layers.EMBERCOURT_GROWTH_IDS+layers.EMBERCOURT_SUPPLY_IDS+layers.EMBERCOURT_RIVERWORKS_IDS+layers.EMBERCOURT_CIVIC_IDS:
            self.assertIn(id,script)
        for token in ('__GROWTH_IDS__','__INSPECTION_IDS__','prepare_riverworks_defense','await layer_visibility_fixture()'):
            self.assertNotIn(token,script)
        headless,removed=packaged.headless_script(script)
        self.assertTrue(removed)
        for token in ('check(', 'SaveService.', 'Input.parse_input_event', 'layer_controller('):
            self.assertEqual(headless.count(token),script.count(token))

    def test_paid_trade_control_preserves_live_dictionary_order(self):
        self.assertIn('control.from_dict(session.to_dict())',layers.RIGGING_ORE_PURCHASE)
        self.assertNotIn('control.from_dict(before)',layers.RIGGING_ORE_PURCHASE)
        self.assertIn('paid Trade control changed live recruit option order',layers.RIGGING_ORE_PURCHASE)
        self.assertIn('normalized(session.to_dict())==normalized(control.to_dict())',layers.RIGGING_ORE_PURCHASE)
        self.assertIn('paid_trade_state_mismatch',layers.RIGGING_ORE_PURCHASE)

    def test_lantern_overlap_keeps_actual_alpha_and_own_building_routes(self):
        self.assertIn('var lantern_painted: bool=lantern._has_point(',layers.EXTRA)
        self.assertIn('"building_embercourt_lantern_court" if lantern_painted else id',layers.EXTRA)
        self.assertIn('presses[0]==(0 if lantern_painted else 1)',layers.EXTRA)
        self.assertIn('Vector2(0.90,0.35)',layers.EXTRA)
        self.assertIn('foreground Bargebow Slip did not own its visible Oath roof overlap',layers.EXTRA)

    def test_riverworks_rejects_wrong_save_faction_or_combined_sequence(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-riverworks-') as temporary:
            save=Path(temporary)/'wrong.json'
            save.write_text('{}\n')
            for flags,message in [([], 'requires --faction embercourt'),
                                  (['--faction','embercourt'], 'exact earned nonterminal Medium11 Day-10 save'),
                                  (['--faction','embercourt','--embercourt-supply-growth'],'select one normal construction sequence')]:
                args=['probe','--embercourt-riverworks-growth','--save',str(save),'--resolution','1280x720','--label','unit_wrong_riverworks']+flags
                with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                    layers.main()
                self.assertEqual(stop.exception.code,2)
                self.assertIn(message,stderr.getvalue())
                run.assert_not_called()
        with self.assertRaisesRegex(ValueError,'select one normal construction sequence'):
            layers.embercourt_growth_script(supply=True,riverworks=True)

    def test_riverworks_retains_paid_authoritative_daily_and_full_save_controls(self):
        script=layers.embercourt_growth_script(riverworks=True)
        for token in ('validation_request_end_turn()', 'validation_confirm_end_turn()', 'attempt<=28',
                      'validation_select_build_plan(id)', 'validation_confirm_build_plan()',
                      'validation_perform_town_action("market:buy:ore:1")', 'TownRules.perform_market_action(control',
                      'normalized(session.to_dict())==normalized(control.to_dict())', 'prior_built+[id]',
                      'predecessor in active.built_buildings', 'growth construction costs changed',
                      'growth allowed a second same-day build', 'earned_growth_save.json'):
            self.assertIn(token,script)
        self.assertEqual(len(layers.EMBERCOURT_RIVERWORKS_IDS),6)
        for token in ('__GROWTH_IDS__','__INSPECTION_IDS__','building_id!="building_veilmourn_tideglass_chapel"','await layer_visibility_fixture()'):
            self.assertNotIn(token,script)
        headless,removed=packaged.headless_script(script)
        self.assertTrue(removed)
        for token in ('check(', 'SaveService.', 'Input.parse_input_event', 'layer_controller('):
            self.assertEqual(headless.count(token),script.count(token))

    def test_supply_rejects_wrong_save_faction_or_combined_sequence(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-supply-') as temporary:
            save=Path(temporary)/'wrong.json'
            save.write_text('{}\n')
            for flags,message in [([], 'requires --faction embercourt'),
                                  (['--faction','embercourt'], 'exact earned nonterminal Medium11 Day-5 save'),
                                  (['--faction','embercourt','--embercourt-growth'],'select one normal construction sequence')]:
                args=['probe','--embercourt-supply-growth','--save',str(save),'--resolution','1280x720','--label','unit_wrong_supply']+flags
                with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                    layers.main()
                self.assertEqual(stop.exception.code,2)
                self.assertIn(message,stderr.getvalue())
                run.assert_not_called()

    def test_defense_policy_is_ordinary_and_exclusive_to_riverworks(self):
        script=layers.embercourt_growth_script(riverworks=True)
        for token in ('session.day not in [10,11,12]', 'riverworks_defense_days.append(session.day)',
                      'TownRules.get_recruit_actions(session)', 'TownRules.recruit_active_town(control',
                      'TownRules.transfer_in_active_town(control', 'shell.validation_perform_town_action(action_id)',
                      'defensive recruits were not paid for', 'defensive transfers emptied the field army',
                      'defensive UI diverged from complete authoritative result',
                      'interrupted_growth_save.json', 'ordinary_growth_visit_interruption'):
            self.assertIn(token,script)
        for old_script in (layers.embercourt_growth_script(),layers.embercourt_growth_script(supply=True)):
            self.assertNotIn('prepare_riverworks_defense',old_script)
        headless,_=packaged.headless_script(script)
        for token in ('check(', 'SaveService.', 'Input.parse_input_event', 'layer_controller('):
            self.assertEqual(headless.count(token),script.count(token))

    def test_supply_retains_normal_trades_turns_upgrades_and_complete_save_controls(self):
        script=layers.embercourt_growth_script(supply=True)
        for token in ('validation_request_end_turn()', 'validation_confirm_end_turn()', 'attempt<=28',
                      'validation_select_build_plan(id)', 'validation_confirm_build_plan()',
                      'validation_perform_town_action("market:buy:ore:1")', 'TownRules.perform_market_action(control',
                      'normalized(session.to_dict())==normalized(control.to_dict())', 'prior_built+[id]',
                      'predecessor in active.built_buildings', 'growth construction costs changed',
                      'growth allowed a second same-day build', 'earned_growth_save.json'):
            self.assertIn(token,script)
        for token in ('__GROWTH_IDS__','__INSPECTION_IDS__','building_id!="building_veilmourn_tideglass_chapel"','await layer_visibility_fixture()'):
            self.assertNotIn(token,script)
        headless,removed=packaged.headless_script(script)
        self.assertTrue(removed)
        for token in ('check(', 'SaveService.', 'Input.parse_input_event', 'layer_controller('):
            self.assertEqual(headless.count(token),script.count(token))

    def test_growth_rejects_wrong_earned_save_before_launch(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-growth-') as temporary:
            save=Path(temporary)/'wrong.json'
            save.write_text('{}\n')
            args=['probe','--faction','embercourt','--embercourt-growth','--save',str(save),'--resolution','1280x720','--label','unit_wrong_growth']
            with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                layers.main()
            self.assertEqual(stop.exception.code,2)
            self.assertIn('exact earned nonterminal Medium11 Market save',stderr.getvalue())
            run.assert_not_called()

    def test_growth_rejects_wrong_faction_or_second_sequence(self):
        for flags,message in [([], 'requires --faction embercourt'), (['--faction','embercourt','--harbor-growth'],'select one normal construction sequence')]:
            args=['probe','--embercourt-growth','--save','/nonexistent.json','--resolution','1280x720','--label','unit_wrong_growth']+flags
            with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                layers.main()
            self.assertEqual(stop.exception.code,2)
            self.assertIn(message,stderr.getvalue())
            run.assert_not_called()

    def test_growth_keeps_paid_daily_save_and_upgrade_controls_in_release(self):
        script=layers.embercourt_growth_script()
        self.assertNotIn('__GROWTH_IDS__',script)
        self.assertNotIn('__INSPECTION_IDS__',script)
        self.assertNotIn('await layer_visibility_fixture()',script)
        for token in ('validation_request_end_turn()', 'validation_confirm_end_turn()', 'validation_select_build_plan(id)',
                      'validation_confirm_build_plan()', 'prior_built+[id]', 'predecessor in active.built_buildings',
                      'growth construction costs changed', 'growth allowed a second same-day build', 'earned_growth_save.json'):
            self.assertIn(token,script)
        headless,removed=packaged.headless_script(script)
        self.assertTrue(removed)
        for token in ('check(', 'SaveService.', 'Input.parse_input_event', 'layer_controller('):
            self.assertEqual(headless.count(token),script.count(token))

    def test_wrong_save_is_rejected_before_engine_launch(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-input-') as temporary:
            save=Path(temporary)/'wrong.json'
            save.write_text('{}\n')
            args=['probe','--faction','embercourt','--save',str(save),'--resolution','1280x720','--label','unit_wrong_ember']
            with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                layers.main()
            self.assertEqual(stop.exception.code,2)
            self.assertIn('exact recorded nonterminal Medium11 Day-1 save',stderr.getvalue())
            run.assert_not_called()

    def test_bellwake_sequence_cannot_run_against_embercourt(self):
        args=['probe','--faction','embercourt','--late-harbor-growth','--save','/nonexistent.json','--resolution','1280x720','--label','unit_wrong_faction']
        with patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
            layers.main()
        self.assertEqual(stop.exception.code,2)
        self.assertIn('Bellwake growth sequences cannot run against Embercourt',stderr.getvalue())
        run.assert_not_called()

    def test_wrong_developed_fixture_is_rejected_before_engine_launch(self):
        with tempfile.TemporaryDirectory(prefix='town-ember-developed-') as temporary:
            opening=Path(temporary)/'opening.json'
            developed=Path(temporary)/'wrong-developed.json'
            opening.write_text('{}\n')
            developed.write_text('{"day":43}\n')
            args=['probe','--faction','embercourt','--presentation-only','--save',str(opening),'--developed-save',str(developed),'--resolution','1280x720','--label','unit_wrong_developed']
            # Isolate the second input boundary. The production opening hash
            # is separately required and tested, never changed on disk.
            with patch.object(layers,'EMBERCOURT_SAVE_SHA256',hashlib.sha256(opening.read_bytes()).hexdigest()), patch('sys.argv',args), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()) as stderr, self.assertRaises(SystemExit) as stop:
                layers.main()
            self.assertEqual(stop.exception.code,2)
            self.assertIn('exact recorded Medium Day-43 fixture',stderr.getvalue())
            run.assert_not_called()

    def test_common_controls_survive_faction_and_headless_adaptation(self):
        script=layers.embercourt_script(layers.SCRIPT)
        self.assertIn('String(a.id)=="build:building_market_square"',script)
        self.assertIn('check(int(cost.get("gold",0))==1000',script)
        self.assertIn('if resource!="gold": check(int(cost[resource])==0',script)
        self.assertIn('built_before+[building_id]',script)
        self.assertIn('earned_growth_save.json',script)
        self.assertIn('get_tree().current_scene._commit_build_action(building_id)',script)
        self.assertNotIn('building_veilmourn_bell_harbor',script)
        for token in ('SaveService.', 'Input.parse_input_event', 'layer_controller(', 'inspect_market_constructed()', 'button._has_point('):
            self.assertGreaterEqual(script.count(token),layers.SCRIPT.count(token))
        headless,removed=packaged.headless_script(script)
        self.assertGreater(len(removed),0)
        self.assertEqual(headless.count('check('),script.count('check('))
        self.assertEqual(headless.count('SaveService.'),script.count('SaveService.'))


if __name__=='__main__':
    unittest.main()
