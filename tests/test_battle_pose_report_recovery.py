"""Interrupted roster evidence must never be reported as completed acceptance."""
import json
import unittest

from battle_readability_regression import parse_probe_report


class PoseReportRecoveryTests(unittest.TestCase):
    def checkpoint(self, ok=True):
        return 'BATTLE_POSE_UNIT_REPORT '+json.dumps({
            'unit_id':'unit_river_guard','ok':ok,'checks':100,
            'failures':[] if ok else ['corpse missing'],'pose_events':[]})+'\n'

    def final(self, ok=True):
        return 'BATTLE_READABILITY_REPORT '+json.dumps({
            'ok':ok,'checks':100,'failures':[] if ok else ['clip missing']})+'\n'

    def test_timeout_preserves_completed_unit_without_passing(self):
        report=parse_probe_report(self.checkpoint(),124,True)
        self.assertFalse(report['ok'])
        self.assertTrue(report['timed_out'])
        self.assertEqual(report['completed_unit_checkpoints'][0]['checks'],100)
        self.assertIn('no final report',report['failures'])

    def test_zero_exit_and_partial_units_are_not_completion(self):
        self.assertFalse(parse_probe_report(self.checkpoint(),0)['ok'])

    def test_failed_checkpoint_preserves_its_exact_errors(self):
        report=parse_probe_report(self.checkpoint(False),1)
        self.assertEqual(report['completed_unit_checkpoints'][0]['failures'],['corpse missing'])

    def test_success_requires_final_report_and_clean_exit(self):
        self.assertTrue(parse_probe_report(self.checkpoint()+self.final(),0)['ok'])
        self.assertFalse(parse_probe_report(self.final(),143)['ok'])
        self.assertFalse(parse_probe_report(self.final(),124,True)['ok'])

    def test_runtime_error_invalidates_otherwise_green_report(self):
        self.assertFalse(parse_probe_report('SCRIPT ERROR: broken\n'+self.final(),0)['ok'])

    def test_assertion_failure_stays_failed(self):
        self.assertFalse(parse_probe_report(self.final(False),0)['ok'])

    def test_green_summary_cannot_override_failed_unit(self):
        self.assertFalse(parse_probe_report(self.checkpoint(False)+self.final(),0)['ok'])


if __name__=='__main__':
    unittest.main()
