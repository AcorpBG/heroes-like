"""Complete Duskfen art uses the earned, paid faction chain and real supply."""
import contextlib
import copy
import io
import json
import unittest
from unittest.mock import patch

import town_scene_layer_regression as layers
from packaged_town_scene_layer_regression import headless_script
from test_town_scene_layers import validate_scene_layers
from tools import prepare_town_scene_layers as preparation


class MireclawFactionSequenceTests(unittest.TestCase):
    def test_exact_remaining_authored_chain_has_no_invented_prerequisites(self):
        town=next(t for t in json.loads((layers.ROOT/'content/towns.json').read_text())['items'] if t['id']=='town_duskfen')
        buildings={b['id']:b for b in json.loads((layers.ROOT/'content/buildings.json').read_text())['items']}
        built=set(town['starting_building_ids'])|set(layers.MIRECLAW_IDS)|set(layers.MIRECLAW_GROWTH_IDS)
        self.assertEqual(len(layers.MIRECLAW_FACTION_IDS),13)
        self.assertEqual(set(layers.MIRECLAW_FACTION_IDS),set(town['buildable_building_ids'])-built)
        self.assertEqual(set(preparation.MIRECLAW_FACTION_BRIEFS),set(layers.MIRECLAW_FACTION_IDS))
        for id in layers.MIRECLAW_FACTION_IDS:
            self.assertTrue(set(buildings[id]['requires'])<=built,id)
            built.add(id)

    def test_paid_progression_supply_and_complete_state_checks_are_preserved(self):
        script=layers.mireclaw_faction_script()
        for fragment in ('shell._on_confirm_build_pressed()', 'field.validation_confirm_end_turn()',
                         'complete_saved_state_equal', 'mireclaw_expected_build(id,actions[0])',
                         'TownRules.recruit_active_town(control,', 'native_h3maped_ce8e40cc_object_0950_required_sources',
                         'field._on_map_tile_pressed(tile)', 'validation_confirm_quick_resolve_confirmation()',
                         'scene.get_node("%Continue").pressed.emit()', 'OverworldRules.hero_position(session)==origin',
                         'await prepare_duskfen_faction_defense()', 'defense_day_%d_save.json',
                         'session.day>=29 and (session.day-1)%7==0',
                         'defense_units.append("unit_gorefen_ripper")',
                         '"all" if unit_id=="unit_gorefen_ripper" else "half"',
                         'pending_court_turn_save.json', 'TOWN_LAYER_CHECK_FAILED ',
                         'shell._on_recruit_action_pressed(action_id.trim_prefix("recruit:"))',
                         'shell._on_transfer_action_pressed(action_id)',
                         'if errors.is_empty(): await layer_visibility_fixture()',
                         ').size()>battles_before', ').size()>reports_before',
                         'upgrade erased saved predecessor', 'faction_chain_developed.png'):
            self.assertIn(fragment,script)
        self.assertNotIn('normal opening has no affordable construction control',script)
        for target in (r'session\.day',r'session\.overworld\.resources',r'session\.scenario_status'):
            self.assertNotRegex(script,target+r'\s*=(?!=)')
        self.assertEqual(script.count('await inspect_scene_layers(visible)'),1)
        headless,removed=headless_script(script)
        self.assertTrue(removed)
        for fragment in ('check(', 'SaveService.', 'Input.parse_input_event', 'validation_confirm_quick_resolve_confirmation'):
            self.assertEqual(script.count(fragment),headless.count(fragment))

    def test_wrong_earned_input_and_conflicting_modes_reject_before_engine(self):
        for extra in ([],['--mireclaw-growth'],['--mireclaw-developed-input'],['--faction','veilmourn']):
            argv=['probe','--faction','mireclaw','--mireclaw-faction-growth','--save',str(layers.ROOT/'content/towns.json'),'--resolution','1280x720','--label','wrong_faction_input']+extra
            with patch('sys.argv',argv), patch.object(layers,'run_probe') as run, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as stopped:
                layers.main()
            self.assertEqual(stopped.exception.code,2)
            run.assert_not_called()

    def test_earned_developed_replay_is_read_only_and_keeps_complete_input(self):
        script=layers.mireclaw_developed_script()
        run=script.split('func run()',1)[1].split('\nfunc ',1)[0]
        self.assertIn('read_only_earned_developed_input_not_paid_replay',run)
        self.assertIn('await inspect_scene_layers(visible)',run)
        self.assertIn('normalized(session.to_dict())==before_input',run)
        self.assertIn('SaveService.save_session(session.to_dict(),3)',run)
        self.assertIn('earned_growth_save.json',run)
        self.assertNotIn('inspect_harbor_growth()',run)
        self.assertNotIn('prepare_duskfen_faction_defense()',run)
        self.assertNotIn('prepare_late_court_supply()',run)
        self.assertIn('footer.has_point(old_point)',script)
        self.assertIn('Antler exposed roof is still covered by navigation',script)
        headless,removed=headless_script(script)
        self.assertTrue(removed)
        for fragment in ('check(', 'SaveService.', 'Input.parse_input_event'):
            self.assertEqual(script.count(fragment),headless.count(fragment))
        with patch('sys.argv',['probe','--faction','mireclaw','--mireclaw-developed-input','--save',str(layers.ROOT/'content/towns.json'),'--resolution','1280x720','--label','wrong_developed_input']), patch.object(layers,'run_probe') as engine, contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            layers.main()
        engine.assert_not_called()

    def test_every_remaining_mapping_and_the_court_site_are_required(self):
        payload=json.loads((layers.ROOT/'content/town_building_scene_art_manifest.json').read_text())
        missing=copy.deepcopy(payload)
        for id in layers.MIRECLAW_FACTION_IDS: missing['factions']['faction_mireclaw'].pop(id)
        self.assertTrue(any(error.startswith('Missing constructible Duskfen scene mapping:') for error in validate_scene_layers(missing)))
        moved=copy.deepcopy(payload)
        court=moved['factions']['faction_mireclaw']['building_mireclaw_oathmire_court']
        court['normalized_rect'][0]+=0.01
        court['ground_anchor'][0]+=0.01
        errors=validate_scene_layers(moved)
        for field in ('scenic site','ground anchor'):
            self.assertIn('building_mireclaw_oathmire_court moved the building_mireclaw_nightglass_dominion '+field,errors)


if __name__=='__main__':
    unittest.main()
