#!/usr/bin/env python3
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "verify_release_promotion.py"
SPEC = importlib.util.spec_from_file_location("verify_release_promotion", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
promotion = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = promotion
SPEC.loader.exec_module(promotion)

TAG = "v0.1.0-alpha.1"
VERSION = "0.1.0-alpha.1"
REVISION = "a" * 40
CONFIRMATION = f"publish-prerelease:{TAG}"


def digest(payload: bytes) -> str:
	return hashlib.sha256(payload).hexdigest()


class PromotionFixture:
	def __init__(self, root: Path) -> None:
		self.assets_dir = root / "assets"
		self.assets_dir.mkdir()
		self.payloads = {
			f"heroes-like-{VERSION}-linux-x86_64.run": b"linux installer\n",
			f"heroes-like-{VERSION}-linux-x86_64.tar.gz": b"linux archive\n",
			f"heroes-like-{VERSION}-windows-x86_64.setup.exe": b"windows installer\n",
			f"heroes-like-{VERSION}-windows-x86_64.zip": b"windows archive\n",
		}
		for name, payload in self.payloads.items():
			(self.assets_dir / name).write_bytes(payload)

		linux_archive = f"heroes-like-{VERSION}-linux-x86_64.tar.gz"
		windows_archive = f"heroes-like-{VERSION}-windows-x86_64.zip"
		linux_installer = f"heroes-like-{VERSION}-linux-x86_64.run"
		windows_installer = f"heroes-like-{VERSION}-windows-x86_64.setup.exe"
		self.index = {
			"schema_id": promotion.INDEX_SCHEMA_ID,
			"product_id": promotion.PRODUCT_ID,
			"version": VERSION,
			"source_revision": REVISION,
			"archives": [
				self._record(linux_archive, "linux-x86_64"),
				self._record(windows_archive, "windows-x86_64"),
			],
			"installers": [
				{
					**self._record(linux_installer, "linux-x86_64"),
					"source_archive_path": linux_archive,
					"source_archive_sha256": digest(self.payloads[linux_archive]),
				},
				{
					**self._record(windows_installer, "windows-x86_64"),
					"source_archive_path": windows_archive,
					"source_archive_sha256": digest(self.payloads[windows_archive]),
				},
			],
		}
		self.result = {
			"schema_id": promotion.CANDIDATE_SCHEMA_ID,
			"ok": True,
			"version": VERSION,
			"source_revision": REVISION,
			"release_verification": {
				"schema_id": promotion.INDEX_SCHEMA_ID,
				"ok": True,
				"version": VERSION,
				"source_revision": REVISION,
			},
		}
		self.write_json("release-index.json", self.index)
		self.write_json("release-candidate-result.json", self.result)
		checksum_rows = [
			f"{digest(self.payloads[name])}  {name}"
			for name in sorted(self.payloads)
		]
		(self.assets_dir / "SHA256SUMS").write_text("\n".join(checksum_rows) + "\n", encoding="ascii")
		self.release = self.release_metadata("draft-prerelease")

	def _record(self, name: str, platform: str) -> dict[str, object]:
		return {
			"path": name,
			"platform": platform,
			"sha256": digest(self.payloads[name]),
			"size_bytes": len(self.payloads[name]),
		}

	def write_json(self, name: str, payload: dict[str, object]) -> None:
		(self.assets_dir / name).write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8")

	def release_metadata(self, state: str) -> dict[str, object]:
		assets = []
		for index, name in enumerate(sorted(path.name for path in self.assets_dir.iterdir()), start=1):
			path = self.assets_dir / name
			assets.append(
				{
					"id": 1000 + index,
					"name": name,
					"size": path.stat().st_size,
					"state": "uploaded",
					"created_at": "2026-08-05T00:00:00Z",
					"updated_at": "2026-08-05T00:00:00Z",
					"digest": f"sha256:{promotion.sha256_file(path)}",
				}
			)
		return {
			"id": 77,
			"tag_name": TAG,
			"target_commitish": REVISION,
			"draft": state == "draft-prerelease",
			"prerelease": True,
			"published_at": None if state == "draft-prerelease" else "2026-08-05T00:10:00Z",
			"assets": assets,
		}

	def refresh_release_sizes(self) -> None:
		sizes = {path.name: path.stat().st_size for path in self.assets_dir.iterdir()}
		for asset in self.release["assets"]:
			asset["size"] = sizes[asset["name"]]


class ReleasePromotionPolicyTest(unittest.TestCase):
	def test_policy_requires_manual_main_prerelease_and_exact_confirmation(self) -> None:
		self.assertEqual(
			promotion.validate_policy("workflow_dispatch", "refs/heads/main", TAG, CONFIRMATION),
			VERSION,
		)
		for args, message in (
			(("push", "refs/heads/main", TAG, CONFIRMATION), "manually dispatched"),
			(("workflow_dispatch", "refs/heads/release", TAG, CONFIRMATION), "refs/heads/main"),
			(("workflow_dispatch", "refs/heads/main", TAG, "publish-prerelease:v0.1.0-alpha.2"), "confirmation"),
			(("workflow_dispatch", "refs/heads/main", "v0.1.0", "publish-prerelease:v0.1.0"), "SemVer prerelease"),
		):
			with self.subTest(args=args), self.assertRaisesRegex(ValueError, message):
				promotion.validate_policy(*args)

	def test_full_draft_and_public_verification_preserve_fingerprint(self) -> None:
		with tempfile.TemporaryDirectory() as temp_value:
			fixture = PromotionFixture(Path(temp_value))
			fixture.release["assets"][0]["digest"] = None
			before = promotion.verify_promotion(
				fixture.release,
				fixture.assets_dir,
				TAG,
				REVISION,
				"draft-prerelease",
			)
			self.assertEqual(before["asset_count"], 7)
			self.assertEqual(before["payload_checksum_count"], 4)
			public_release = fixture.release_metadata("public-prerelease")
			after = promotion.verify_promotion(
				public_release,
				fixture.assets_dir,
				TAG,
				REVISION,
				"public-prerelease",
				expected_fingerprint=before["promotion_fingerprint"],
			)
			self.assertEqual(after["promotion_fingerprint"], before["promotion_fingerprint"])

	def test_cli_writes_a_full_verification_result(self) -> None:
		with tempfile.TemporaryDirectory() as temp_value:
			root = Path(temp_value)
			fixture = PromotionFixture(root)
			release_path = root / "release.json"
			result_path = root / "verification.json"
			release_path.write_text(json.dumps(fixture.release), encoding="utf-8")
			completed = subprocess.run(
				[
					sys.executable,
					str(MODULE_PATH),
					"--event-name",
					"workflow_dispatch",
					"--workflow-ref",
					"refs/heads/main",
					"--tag",
					TAG,
					"--confirmation",
					CONFIRMATION,
					"--tag-revision",
					REVISION,
					"--release-json",
					str(release_path),
					"--assets-dir",
					str(fixture.assets_dir),
					"--expected-state",
					"draft-prerelease",
					"--result-json",
					str(result_path),
				],
				capture_output=True,
				text=True,
				check=False,
			)
			self.assertEqual(completed.returncode, 0, completed.stderr)
			result = json.loads(result_path.read_text(encoding="utf-8"))
			self.assertTrue(result["ok"])
			self.assertRegex(result["promotion_fingerprint"], r"^[0-9a-f]{64}$")

	def test_release_metadata_rejects_state_revision_and_asset_identity_drift(self) -> None:
		with tempfile.TemporaryDirectory() as temp_value:
			fixture = PromotionFixture(Path(temp_value))
			cases = []
			wrong_state = copy.deepcopy(fixture.release)
			wrong_state["draft"] = False
			wrong_state["published_at"] = "2026-08-05T00:10:00Z"
			cases.append((wrong_state, "required draft-prerelease state"))
			wrong_revision = copy.deepcopy(fixture.release)
			wrong_revision["target_commitish"] = "b" * 40
			cases.append((wrong_revision, "exact tag revision"))
			missing = copy.deepcopy(fixture.release)
			missing["assets"].pop()
			cases.append((missing, "asset set mismatch"))
			extra = copy.deepcopy(fixture.release)
			extra["assets"].append({**extra["assets"][0], "id": 9999, "name": "unexpected.bin"})
			cases.append((extra, "asset set mismatch"))
			duplicate_name = copy.deepcopy(fixture.release)
			duplicate_name["assets"][1]["name"] = duplicate_name["assets"][0]["name"]
			cases.append((duplicate_name, "duplicate asset names"))
			duplicate_id = copy.deepcopy(fixture.release)
			duplicate_id["assets"][1]["id"] = duplicate_id["assets"][0]["id"]
			cases.append((duplicate_id, "duplicate asset ids"))
			for release, message in cases:
				with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
					promotion.verify_promotion(release, fixture.assets_dir, TAG, REVISION, "draft-prerelease")

	def test_payload_rejects_schema_version_size_and_checksum_drift(self) -> None:
		mutations = (
			"candidate_schema",
			"candidate_version",
			"candidate_revision",
			"index_size",
			"github_size",
			"checksum",
			"missing_download",
			"extra_download",
		)
		for mutation in mutations:
			with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp_value:
				fixture = PromotionFixture(Path(temp_value))
				if mutation == "candidate_schema":
					fixture.result["schema_id"] = "wrong"
					fixture.write_json("release-candidate-result.json", fixture.result)
					fixture.refresh_release_sizes()
				elif mutation == "candidate_version":
					fixture.result["version"] = "0.1.0-alpha.2"
					fixture.write_json("release-candidate-result.json", fixture.result)
					fixture.refresh_release_sizes()
				elif mutation == "candidate_revision":
					fixture.result["source_revision"] = "b" * 40
					fixture.write_json("release-candidate-result.json", fixture.result)
					fixture.refresh_release_sizes()
				elif mutation == "index_size":
					fixture.index["archives"][0]["size_bytes"] += 1
					fixture.write_json("release-index.json", fixture.index)
					fixture.refresh_release_sizes()
				elif mutation == "github_size":
					fixture.release["assets"][0]["size"] += 1
				elif mutation == "checksum":
					checksum_path = fixture.assets_dir / "SHA256SUMS"
					checksum_path.write_text(checksum_path.read_text(encoding="ascii").replace("a", "b", 1), encoding="ascii")
					fixture.refresh_release_sizes()
				elif mutation == "missing_download":
					(fixture.assets_dir / sorted(fixture.payloads)[0]).unlink()
				elif mutation == "extra_download":
					(fixture.assets_dir / "extra.txt").write_text("extra\n", encoding="ascii")
				with self.assertRaises(ValueError):
					promotion.verify_promotion(fixture.release, fixture.assets_dir, TAG, REVISION, "draft-prerelease")

	def test_post_publish_fingerprint_rejects_asset_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temp_value:
			fixture = PromotionFixture(Path(temp_value))
			before = promotion.verify_promotion(fixture.release, fixture.assets_dir, TAG, REVISION, "draft-prerelease")
			public_release = fixture.release_metadata("public-prerelease")
			public_release["assets"][0]["id"] = 9090
			with self.assertRaisesRegex(ValueError, "identity changed"):
				promotion.verify_promotion(
					public_release,
					fixture.assets_dir,
					TAG,
					REVISION,
					"public-prerelease",
					expected_fingerprint=before["promotion_fingerprint"],
				)

	def test_workflow_is_manual_prerelease_only_and_reverifies_after_publish(self) -> None:
		workflow = (ROOT / ".github" / "workflows" / "release-promotion.yml").read_text(encoding="utf-8")
		for token in (
			"workflow_dispatch:",
			"confirmation:",
			"contents: read",
			"contents: write",
			"actions/checkout@v6",
			"if: github.ref == 'refs/heads/main'",
			"ref: main",
			"--policy-only",
			'--workflow-ref "$GITHUB_REF"',
			'git fetch --force --no-tags --depth=1 origin "refs/tags/$RELEASE_TAG:refs/tags/$RELEASE_TAG"',
			"draft-prerelease",
			"public-prerelease",
			"releases/assets/$asset_id",
			"gh release edit",
			"--draft=false",
			"--prerelease",
			"--latest=false",
			"--expected-fingerprint",
		):
			self.assertIn(token, workflow)
		self.assertEqual(workflow.count("contents: write"), 1)
		self.assertEqual(workflow.count("releases/assets/$asset_id"), 2)
		self.assertEqual(workflow.count("gh release edit"), 1)
		for forbidden in (
			"push:",
			"schedule:",
			"gh release create",
			"gh release upload",
			"gh release download",
			"gh release delete",
			"--clobber",
			"--latest=true",
			"tools/build_release_candidate.py",
			"tools/package_release.py",
			"actions/upload-artifact",
		):
			self.assertNotIn(forbidden, workflow)


if __name__ == "__main__":
	unittest.main()
