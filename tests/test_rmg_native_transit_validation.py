"""Missing, partial or non-boolean transit evidence must never count as passing."""
import copy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "transit_validation", Path(__file__).resolve().parents[1] / "tools/rmg_native_transit_validation.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class NativeTransitValidationTests(unittest.TestCase):
    def good_report(self):
        return {"checks": dict.fromkeys(MODULE.GLOBAL_CHECKS, True), "trips": [
            {"placement_id": str(i), "checks": dict.fromkeys(MODULE.TRIP_CHECKS, True)}
            for i in range(8)
        ]}

    def test_every_global_check_required(self):
        self.assertEqual(MODULE.failures(self.good_report()), [])
        for check in MODULE.GLOBAL_CHECKS:
            report = self.good_report()
            del report["checks"][check]
            self.assertEqual(MODULE.failures(report), [check])

    def test_every_trip_check_requires_literal_true(self):
        for check in MODULE.TRIP_CHECKS:
            for value in [False, 1, None]:
                with self.subTest(check=check, value=value):
                    report = self.good_report()
                    report["trips"][3]["checks"][check] = value
                    self.assertEqual(MODULE.failures(report), [f"3: {check}"])

    def test_missing_gate_or_all_evidence_fails(self):
        report = copy.deepcopy(self.good_report())
        report["trips"].pop()
        self.assertIn("missing_trip_evidence", MODULE.failures(report))
        self.assertTrue(MODULE.failures({}))

    def test_duplicate_gate_evidence_does_not_cover_both_ends(self):
        report = self.good_report()
        report["trips"][7]["placement_id"] = report["trips"][0]["placement_id"]
        self.assertIn("missing_unique_gate_evidence", MODULE.failures(report))

    def good_portal_report(self):
        ends, gates = [], []
        for source, target in (("a", "b"), ("b", "a")):
            gates.append({"placement_id": source, "h3m_type_id": 45, "native_transit": {"destinations": [{"target_placement_id": target}]}})
            ends.append({"placement_id": source, "checks": dict.fromkeys(("legacy_exact_group_restore", "not_authored_local_offset", "missing_destination_fails_validation"), True), "trips": [{"target_placement_id": target, "checks": dict.fromkeys(("context_action_reaches_exact_exit", "one_movement_no_claim_or_reward", "save_roundtrip_keeps_position_group_and_fog", "occupied_exit_rejected_without_cost"), True)}]})
        representative = {"shape": "45:1", "checks": dict.fromkeys(("ai_exact_selected_destination", "ai_no_claim_rewards", "ai_real_approach_path", "ai_full_advance_uses_gate", "ai_routes_to_real_target_through_gate", "production_save_keeps_position_contracts_and_fog", "real_approach_then_saved_choice_spends_one_total"), True)}
        return {"checks": {"disk_package_roundtrip": True, "native_navigation_field_unit_edges": True}, "gates": gates, "portals": {"contract_errors": [], "legacy_errors": [], "ends": ends, "representatives": [representative]}}

    def test_portal_checks_and_full_source_destination_coverage_required(self):
        report = self.good_portal_report()
        self.assertEqual(MODULE.portal_failures(report, 2), [])
        report["portals"]["ends"][0]["trips"] = []
        report["portals"]["ends"][0]["checks"]["arrival_only_or_stranded_is_explicit"] = True
        self.assertIn("a: destination_coverage", MODULE.portal_failures(report, 2))
        report = self.good_portal_report()
        report["portals"]["ends"][0]["trips"][0]["checks"]["occupied_exit_rejected_without_cost"] = 1
        self.assertIn("a -> b: occupied_exit_rejected_without_cost", MODULE.portal_failures(report, 2))
        self.assertTrue(MODULE.portal_failures({}, 2))

    def test_missing_or_duplicate_portal_evidence_fails(self):
        report = self.good_portal_report()
        report["portals"]["ends"][1] = copy.deepcopy(report["portals"]["ends"][0])
        self.assertIn("missing_unique_portal_evidence", MODULE.portal_failures(report, 2))
        report = self.good_portal_report()
        report["portals"]["ends"][0]["trips"].append(copy.deepcopy(report["portals"]["ends"][0]["trips"][0]))
        self.assertIn("a: destination_coverage", MODULE.portal_failures(report, 2))

    def test_representative_only_mode_cannot_claim_full_endpoint_coverage(self):
        report = self.good_portal_report()
        report["portals"]["ends"] = []
        self.assertIn("representative_only_coverage_not_declared", MODULE.portal_failures(report, 2, True))
        report["portals"]["representatives_only"] = True
        self.assertEqual(MODULE.portal_failures(report, 2, True), [])
        self.assertIn("missing_unique_portal_evidence", MODULE.portal_failures(report, 2))
        report["portals"]["representatives"] = []
        self.assertIn("missing_portal_shape_gameplay_evidence", MODULE.portal_failures(report, 2, True))

    def test_multi_exit_requires_independent_hero_credit_evidence(self):
        report = self.good_portal_report()
        report["gates"][0]["native_transit"]["destinations"].append({"target_placement_id": "c"})
        for value in [None, False, 1]:
            report["portals"]["multihero_credit"] = {"ok": value}
            self.assertIn("multihero_pending_credit_not_preserved", MODULE.portal_failures(report, 2))
        report["portals"]["multihero_credit"] = {"ok": True}
        self.assertNotIn("multihero_pending_credit_not_preserved", MODULE.portal_failures(report, 2))

    def test_continuous_journey_requires_real_towns_steps_turns_and_battle(self):
        report = {"checks": {"disk_package_roundtrip": True, "native_navigation_field_unit_edges": True},
                  "objects": [{"kind": "town", "placement_id": name} for name in ("home", "target")],
                  "journey": {"ok": True, "starting_town_id": "home", "journeys": [{"town_id": "target", "ok": True,
                      "steps": [{"result": {"ok": True}, "cost": 1}], "passages": [{}, {}], "turns": [{}],
                      "battles": [{"completed": True, "state": "victory", "remote_towns_unchanged": True, "overworld_checkpoint": True}]}]}}
        self.assertEqual(MODULE.journey_failures(report, True), [])
        for key, expected in (("steps", "target: paid_live_steps"), ("passages", "islands_multi_passage_and_turn_evidence"),
                              ("turns", "islands_multi_passage_and_turn_evidence"), ("battles", "islands_field_battle_preserves_remote_towns")):
            missing = copy.deepcopy(report)
            missing["journey"]["journeys"][0].pop(key)
            self.assertIn(expected, MODULE.journey_failures(missing, True))
        report["journey"]["journeys"].append(copy.deepcopy(report["journey"]["journeys"][0]))
        self.assertIn("journey_source_town_coverage", MODULE.journey_failures(report, True))
        self.assertTrue(MODULE.journey_failures({}, True))


if __name__ == "__main__":
    unittest.main()
