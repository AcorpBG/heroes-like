"""Audit measurement regressions, not assertions that known game defects pass."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("audit", Path(__file__).resolve().parents[1] / "tools/rmg_start_placement_audit.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import rmg_retained_authority_audit as retained


class StartAuditTests(unittest.TestCase):
    def test_diagonal_both_sides_blocked(self):
        self.assertNotIn((1, 1, 0), audit.distances((0, 0, 0), 2, 2, {(1, 0, 0), (0, 1, 0)}))

    def test_diagonal_one_side_open(self):
        self.assertEqual(1, audit.distances((0, 0, 0), 2, 2, {(1, 0, 0)})[(1, 1, 0)])

    def test_levels_not_flattened_in_native_graph(self):
        self.assertEqual(4, len(audit.distances((0, 0, 1), 2, 2, {(1, 0, 0), (0, 1, 0)})))

    def test_blocked_origin_does_not_hide_can_escape(self):
        self.assertEqual(4, len(audit.distances((0, 0, 0), 2, 2, {(0, 0, 0)})))

    def test_complete_shape_matrix_and_unique_cases(self):
        rows = audit.matrix()
        self.assertEqual(len(rows), len({r["id"] for r in rows}))
        self.assertEqual(24, sum(r["id"].startswith("matrix_") for r in rows))

    def test_failed_case_is_evidence_not_crash(self):
        self.assertFalse(audit.analyze({"id": "unsupported", "ok": False, "error_code": "unsupported"})["ok"])

    def test_byte_compare_detects_truncation_and_mutation(self):
        self.assertTrue(retained.compare_bytes(b"abc", b"abc")["exact"])
        self.assertEqual(2, retained.compare_bytes(b"abc", b"ab")["first_mismatch"])
        self.assertEqual(1, retained.compare_bytes(b"axc", b"abc")["first_mismatch"])

    def test_retained_matrix_has_exactly_24_shapes(self):
        self.assertEqual(24, len({(size, levels, water) for size, _, levels, water, _, _ in retained.CASES}))

    def test_private_comparison_merges_overlap_and_rejects_missing_words(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "native.log"
            ledger = root / "owner.json"
            log.write_text("RMG_TRACE_WORKFLOW_GRID phase=after_0x49a1ef_0x4ac83d cell=0 " + " ".join(f"w{k}=0x00000000" for k in ["10", "14", "18", "1c", "20", "24", "28", "2c"]) + "\n")
            memory = [{"address": 120, "words": [1024, 1, 1, 1]}, {"address": 1024, "words": [0] * 12}, {"address": 1024, "words": [0] * 4}]
            data = {"events": [{"address": "0x0049eb8d", "registers": {"ecx": 100}, "memory_lines": memory}]}
            ledger.write_text(json.dumps(data))
            self.assertTrue(retained.compare_private_grid(log, ledger)["checkpoints"][0]["exact"])
            memory[1]["words"].pop()
            ledger.write_text(json.dumps(data))
            with self.assertRaises(KeyError):
                retained.compare_private_grid(log, ledger)


if __name__ == "__main__":
    unittest.main()
