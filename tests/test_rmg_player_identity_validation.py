"""Fail-closed result classification for the Python-owned live player probe."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "player_validation", Path(__file__).resolve().parents[1] / "tools/rmg_player_identity_validation.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PlayerIdentityValidationTests(unittest.TestCase):
    def test_every_required_check_must_be_true(self):
        row = {"id": "six_players", "checks": dict.fromkeys(MODULE.CHECKS, True)}
        self.assertEqual(MODULE.failures([row]), [])
        for check in MODULE.CHECKS:
            with self.subTest(check=check):
                broken = {"id": row["id"], "checks": {**row["checks"], check: False}}
                self.assertEqual(MODULE.failures([broken]), [{"case": row["id"], "check": check}])

    def test_missing_adoption_is_not_success(self):
        self.assertEqual(len(MODULE.failures([{"id": "eight_players"}])), len(MODULE.CHECKS))

    def test_missing_check_or_numeric_truth_does_not_pass(self):
        check = "production_battle_save_preserves_ownership"
        row = {"id": "teams", "checks": dict.fromkeys(MODULE.CHECKS, True)}
        del row["checks"][check]
        self.assertEqual(len(MODULE.failures([row])), 1)
        row["checks"][check] = 1
        self.assertEqual(len(MODULE.failures([row])), 1)


if __name__ == "__main__":
    unittest.main()
