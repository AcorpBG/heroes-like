"""Complete-match acceptance must never promote a partial driver run."""
import copy
import unittest

from generated_full_match_quality import acceptance_failures


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


if __name__ == '__main__':
    unittest.main()
