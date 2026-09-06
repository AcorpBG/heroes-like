"""Complete-match acceptance must never promote a partial driver run."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from generated_full_match_quality import acceptance_failures, resume_prefix


class FullMatchAcceptanceTests(unittest.TestCase):
    def valid(self):
        return {'ok': True, 'returncode': 0, 'runtime_errors': [], 'failures': [],
                'final': {'status': 'victory', 'scene': 'res://scenes/results/ScenarioOutcomeShell.tscn'},
                'checkpoint_labels': ['opening', 'mid_match', 'terminal'],
                'counts': {key: 1 for key in ['town_build', 'town_recruit', 'battle', 'battle_report', 'end_turn', 'target_explore']}}

    def test_complete_victory_and_developed_defeat(self):
        for outcome in ['victory', 'defeat']:
            report = self.valid()
            report['final']['status'] = outcome
            self.assertEqual(acceptance_failures(report), [])

    def test_turn_limit_and_unknown_status_fail(self):
        for outcome in ['in_progress', 'timeout', '', 'completed']:
            report = self.valid()
            report['final']['status'] = outcome
            self.assertIn('no legitimate terminal outcome', acceptance_failures(report))

    def test_early_loss_does_not_certify_mid_match(self):
        report = self.valid()
        report['final']['status'] = 'defeat'
        report['checkpoint_labels'] = ['opening', 'terminal']
        self.assertTrue(acceptance_failures(report))

    def test_real_outcome_and_casualty_handoff_required(self):
        report = self.valid()
        report['final']['scene'] = 'res://scenes/battle/BattleShell.tscn'
        report['counts']['battle_report'] = 0
        failures = acceptance_failures(report)
        self.assertIn('real outcome scene not reached', failures)
        self.assertIn('battle_report coverage missing', failures)

    def test_native_errors_nonzero_exit_and_driver_failure_fail(self):
        for key, value in [('returncode', 124), ('runtime_errors', ['ERROR: native failure']), ('failures', ['stalled route']), ('ok', False)]:
            report = self.valid()
            report[key] = value
            self.assertTrue(acceptance_failures(report))

    def test_classifier_does_not_mutate_report(self):
        report = self.valid()
        before = copy.deepcopy(report)
        acceptance_failures(report)
        self.assertEqual(report, before)

    def test_resume_preserves_only_observed_checkpoint_prefix(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, case = self.resume_fixture(Path(temporary))
            saved, rows, metadata = resume_prefix(source, case)
            self.assertEqual(json.loads(saved)['day'], 8)
            self.assertEqual(len(rows), 3)
            self.assertEqual(metadata['counts'], {'setup': 1, 'save_resume': 2})
            self.assertEqual(metadata['checkpoint_labels'], ['opening', 'mid_match'])
            self.assertNotIn('battle', metadata['counts'])

    def test_resume_rejects_unproven_checkpoint_or_different_setup(self):
        for change in ['config', 'day', 'terminal', 'error', 'missing_log']:
            with self.subTest(change=change), tempfile.TemporaryDirectory() as temporary:
                source, case = self.resume_fixture(Path(temporary))
                if change == 'config':
                    case['seed'] = 'different'
                elif change in ['day', 'terminal']:
                    path = source/'data/godot/app_userdata/heroes-like/saves/slot2.json'
                    state = json.loads(path.read_text())
                    state['day' if change == 'day' else 'scenario_status'] = 9 if change == 'day' else 'defeat'
                    path.write_text(json.dumps(state))
                else:
                    log = source/'runtime.log'
                    log.write_text('ERROR: failed\n'+log.read_text() if change == 'error' else '')
                with self.assertRaises(ValueError):
                    resume_prefix(source, case)

    def test_autosave_resume_requires_recorded_turn_and_exact_position_resources(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, case = self.resume_fixture(Path(temporary))
            save_path = source/'data/godot/app_userdata/heroes-like/saves/autosave.json'
            state = json.loads((save_path.parent/'slot2.json').read_text())
            state['overworld'].update(hero_position={'x':3,'y':4},resources={'gold':100})
            save_path.write_text(json.dumps(state))
            row = {'serial':5,'kind':'end_turn','result':{'ok':True},'state':{'day':8,'status':'in_progress','hero':{'x':3,'y':4},'resources':{'gold':100}}}
            with (source/'actions.jsonl').open('a') as log:
                log.write(json.dumps(row)+'\n')
            with (source/'runtime.log').open('a') as log:
                log.write('GENERATED_FULL_MATCH_ACTION '+json.dumps(row)+'\n')
            self.assertEqual(resume_prefix(source, case, True)[2]['source_checkpoint'], 'end_turn_autosave')
            state['overworld']['resources']['gold'] = 101
            save_path.write_text(json.dumps(state))
            with self.assertRaises(ValueError):
                resume_prefix(source, case, True)

    def resume_fixture(self, source):
        case = {'seed': 'test', 'size': 'homm3_medium', 'players': 2, 'faction': 'faction_embercourt', 'hero': ''}
        path = source/'data/godot/app_userdata/heroes-like/saves/slot2.json'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({'day':8, 'difficulty':'normal', 'scenario_status':'in_progress', 'overworld':{'players':[{'human':True,'faction_id':'faction_embercourt'}], 'resource_nodes':[]}}))
        rows = [{'serial':1, 'kind':'setup', 'result':{k:case[k] for k in ['seed','size','players']}, 'state':{'day':1}},
                {'serial':2, 'kind':'save_resume', 'result':{'label':'opening','complete_state_equal':True}, 'state':{'day':1}},
                {'serial':3, 'kind':'save_resume', 'result':{'label':'mid_match','complete_state_equal':True}, 'state':{'day':8}},
                {'serial':4, 'kind':'battle', 'result':{}, 'state':{'day':9}}]
        (source/'actions.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in rows))
        (source/'runtime.log').write_text(''.join('GENERATED_FULL_MATCH_ACTION '+json.dumps(row)+'\n' for row in rows))
        return source, case


if __name__ == '__main__':
    unittest.main()
