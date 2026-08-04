#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "resolve_release_delivery.py"
SPEC = importlib.util.spec_from_file_location("resolve_release_delivery", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
delivery_policy = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = delivery_policy
SPEC.loader.exec_module(delivery_policy)


class ReleaseDeliveryPolicyTest(unittest.TestCase):
	def test_version_tag_push_delivers_matching_draft(self) -> None:
		resolved = delivery_policy.resolve_delivery(
			"push", "v0.1.0-rc1", "tag", "0.1.0-rc1", False
		)
		self.assertTrue(resolved.deliver_draft)
		self.assertEqual(resolved.release_tag, "v0.1.0-rc1")

	def test_ordinary_manual_run_remains_artifact_only(self) -> None:
		resolved = delivery_policy.resolve_delivery(
			"workflow_dispatch", "main", "branch", "0.1.0-rc1", False
		)
		self.assertFalse(resolved.deliver_draft)
		self.assertEqual(resolved.release_tag, "")

	def test_explicit_manual_delivery_requires_matching_tag_ref(self) -> None:
		resolved = delivery_policy.resolve_delivery(
			"workflow_dispatch", "v0.1.0-rc1", "tag", "0.1.0-rc1", True
		)
		self.assertTrue(resolved.deliver_draft)
		with self.assertRaisesRegex(ValueError, "existing version tag"):
			delivery_policy.resolve_delivery(
				"workflow_dispatch", "main", "branch", "0.1.0-rc1", True
			)

	def test_delivery_rejects_version_tag_mismatch(self) -> None:
		with self.assertRaisesRegex(ValueError, "does not match"):
			delivery_policy.resolve_delivery(
				"push", "v0.1.0-rc2", "tag", "0.1.0-rc1", False
			)


if __name__ == "__main__":
	unittest.main()
