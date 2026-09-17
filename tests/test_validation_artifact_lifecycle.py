"""Disposable history is optional; present evidence and source checks are not."""
import ast
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

import validate_repo as validator


REPORT_OWNERS = {
    'validate_six_marchland_seats',
    'validate_six_marchland_local_retinues',
    'validate_six_marchland_warworks',
    'validate_six_marchland_retinue_heirloom_trials',
    'validate_twelve_command_relic_marches',
    'validate_six_field_muster_commission_skirmishes',
    'validate_six_twin_hold_defense_vigils',
    'validate_six_three_relic_pilgrimages',
    'validate_six_triune_arcanum_trials',
    'validate_six_grand_arcanum_convocations',
    'validate_six_great_work_charter_races',
    'validate_six_grand_muster_assemblies',
    'validate_six_field_mastery_convocations',
    'validate_six_twin_command_field_councils',
    'validate_six_relief_route_convoy_runs',
    'validate_six_fogbreak_survey_expeditions',
    'validate_six_frontier_treasury_commissions',
    'validate_six_border_oath_standard_seizures',
    'validate_six_garrison_warrant_musters',
    'validate_six_setbound_regalia_assemblies',
    'validate_eight_commanders_proving_roads',
    'validate_eight_commander_doctrine_expeditions',
    'validate_twelve_marchland_warband_musters',
    'validate_twelve_marchland_grand_route_operations',
    'validate_ten_commander_dominion_sieges',
    'validate_uncrowned_circuit_campaign',
}


class ValidationArtifactLifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Execute the actual report guards/assertions in isolation, not copies of
        # their predicates. This avoids rerunning every art/content scan per case.
        cls.branches = {}
        tree = ast.parse(Path(validator.__file__).read_text(encoding='utf-8'))
        for owner in tree.body:
            if not isinstance(owner, ast.FunctionDef):
                continue
            for node in ast.walk(owner):
                if (isinstance(node, ast.If) and isinstance(node.test, ast.Call)
                        and isinstance(node.test.func, ast.Name)
                        and node.test.func.id == 'historical_smoke_report_available'):
                    variable = node.test.args[0].id
                    code = compile(ast.Module(body=[node], type_ignores=[]),
                                   validator.__file__, 'exec')
                    if owner.name in cls.branches:
                        raise AssertionError('Duplicate report guard: ' + owner.name)
                    cls.branches[owner.name] = variable, code

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='heroes-report-policy-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.policy = patch.multiple(validator, REQUIRE_HISTORICAL_SMOKE_REPORTS=False,
                                     MISSING_HISTORICAL_SMOKE_REPORTS=set())
        self.policy.start()
        self.addCleanup(self.policy.stop)

    def run_branch(self, owner, payload=None, raw=None):
        path = self.root / owner / 'report.json'
        if payload is not None or raw is not None:
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps(payload) if raw is None else raw, encoding='utf-8')
        variable, code = self.branches[owner]
        errors = []
        scope = dict(vars(validator), errors=errors)
        scope[variable] = path
        exec(code, scope)
        return errors

    def test_policy_is_limited_to_exact_non_rmg_report_owners(self):
        self.assertEqual(set(self.branches), REPORT_OWNERS)

    def test_all_26_missing_reports_are_optional_not_runtime_success(self):
        for owner in REPORT_OWNERS:
            with self.subTest(owner=owner):
                self.assertEqual(self.run_branch(owner), [])
        self.assertEqual(len(validator.MISSING_HISTORICAL_SMOKE_REPORTS), 26)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            validator.print_historical_smoke_report_summary()
        self.assertIn('absent: 26', output.getvalue())
        self.assertIn('NOT run or counted as passed', output.getvalue())

    def test_strict_mode_requires_each_report(self):
        validator.REQUIRE_HISTORICAL_SMOKE_REPORTS = True
        for owner in REPORT_OWNERS:
            with self.subTest(owner=owner):
                errors = self.run_branch(owner)
                self.assertEqual(len(errors), 1)
                self.assertIn('consolidated smoke report is missing', errors[0])

    def test_all_present_failed_reports_still_fail(self):
        for owner in REPORT_OWNERS:
            with self.subTest(owner=owner):
                self.assertTrue(self.run_branch(owner, {'ok': False}))
        self.assertFalse(validator.MISSING_HISTORICAL_SMOKE_REPORTS)

    def test_all_malformed_reports_still_fail(self):
        for owner in REPORT_OWNERS:
            with self.subTest(owner=owner), self.assertRaises(json.JSONDecodeError):
                self.run_branch(owner, raw='{invalid json')
        self.assertFalse(validator.MISSING_HISTORICAL_SMOKE_REPORTS)

    def test_invalid_report_path_is_not_treated_as_deleted_history(self):
        path = self.root / 'report.json'
        path.mkdir()
        errors = []
        self.assertFalse(validator.historical_smoke_report_available(path, errors, 'missing'))
        self.assertTrue(errors)
        self.assertFalse(validator.MISSING_HISTORICAL_SMOKE_REPORTS)

    def test_broken_symlink_fails_on_any_platform(self):
        # No Windows symlink privilege is needed to exercise this path contract.
        path = Mock(spec=Path)
        path.is_file.return_value = False
        path.exists.return_value = False
        path.is_symlink.return_value = True
        errors = []
        self.assertFalse(validator.historical_smoke_report_available(path, errors, 'missing'))
        self.assertTrue(errors)
        self.assertFalse(validator.MISSING_HISTORICAL_SMOKE_REPORTS)

    def test_valid_report_and_counter_corruption_in_both_modes(self):
        good = dict(ok=True, case_count=6, live_build_count=6, live_recruit_count=6,
                    production_battle_count=18, live_throne_claim_count=6,
                    witness_handoff_count=6, scenario_victory_count=6,
                    save_round_trip_count=6, campaign_complete=True,
                    save_version=9, single_consolidated_smoke=True)
        for strict in (False, True):
            validator.REQUIRE_HISTORICAL_SMOKE_REPORTS = strict
            with self.subTest(strict=strict):
                self.assertEqual(self.run_branch('validate_uncrowned_circuit_campaign', good), [])
                bad = dict(good, production_battle_count=0)
                self.assertTrue(self.run_branch('validate_uncrowned_circuit_campaign', bad))

    def test_real_owner_still_checks_content_when_report_is_absent(self):
        original = validator.load_json

        def corrupt_campaign(path):
            payload = original(path)
            if path == validator.CONTENT_DIR / 'campaigns.json':
                for row in payload['items']:
                    if row['id'] == 'campaign_uncrowned_circuit':
                        row['name'] = ''
            return payload

        errors = []
        with patch.object(validator, 'load_json', side_effect=corrupt_campaign):
            validator.validate_uncrowned_circuit_campaign(errors)
        self.assertTrue(any('complete player-facing campaign copy' in e for e in errors), errors)
        self.assertFalse(any('report is missing' in e for e in errors), errors)

    def test_real_owner_still_checks_smoke_source(self):
        original = Path.read_text
        target = validator.ROOT / 'tests/uncrowned_circuit_campaign_smoke.gd'

        def broken_script(path, *args, **kwargs):
            return '' if path == target else original(path, *args, **kwargs)

        errors = []
        with patch.object(Path, 'read_text', broken_script):
            validator.validate_uncrowned_circuit_campaign(errors)
        self.assertTrue(any('missing exact proof' in e for e in errors), errors)

    def test_strict_option_is_exposed_by_real_cli(self):
        result = subprocess.run([sys.executable, '-B', validator.__file__, '--help'],
                                capture_output=True, text=True, check=True)
        self.assertIn('--require-historical-smoke-reports', result.stdout)


if __name__ == '__main__':
    unittest.main()
