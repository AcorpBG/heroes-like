#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


SCHEMA_ID = "heroes_like_release_promotion_verification_v1"
CANDIDATE_SCHEMA_ID = "heroes_like_release_candidate_v1"
INDEX_SCHEMA_ID = "heroes_like_release_index_v3"
PRODUCT_ID = "heroes-like"
REVISION_PATTERN = re.compile(r"[0-9a-f]{40}")
PRERELEASE_VERSION_PATTERN = re.compile(
	r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
	r"-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*(?:\+[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?"
)
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")
EXPECTED_STATES = ("draft-prerelease", "public-prerelease")


def prerelease_version_from_tag(tag: str) -> str:
	if not tag.startswith("v"):
		raise ValueError("release tag must start with v")
	version = tag[1:]
	if PRERELEASE_VERSION_PATTERN.fullmatch(version) is None:
		raise ValueError("public prerelease promotion requires a SemVer prerelease tag")
	return version


def validate_policy(event_name: str, workflow_ref: str, tag: str, confirmation: str) -> str:
	version = prerelease_version_from_tag(tag)
	if event_name != "workflow_dispatch":
		raise ValueError("release promotion must be manually dispatched")
	if workflow_ref != "refs/heads/main":
		raise ValueError("release promotion must run from refs/heads/main")
	expected_confirmation = f"publish-prerelease:{tag}"
	if confirmation != expected_confirmation:
		raise ValueError(f"confirmation must equal {expected_confirmation}")
	return version


def safe_revision(value: str) -> str:
	if REVISION_PATTERN.fullmatch(value) is None:
		raise ValueError("tag revision must be a full lowercase Git object id")
	return value


def expected_asset_names(version: str) -> tuple[str, ...]:
	return tuple(
		sorted(
			(
				"SHA256SUMS",
				f"heroes-like-{version}-linux-x86_64.run",
				f"heroes-like-{version}-linux-x86_64.tar.gz",
				f"heroes-like-{version}-windows-x86_64.setup.exe",
				f"heroes-like-{version}-windows-x86_64.zip",
				"release-candidate-result.json",
				"release-index.json",
			)
		)
	)


def expected_payload_names(version: str) -> tuple[str, ...]:
	return tuple(
		sorted(
			(
				f"heroes-like-{version}-linux-x86_64.run",
				f"heroes-like-{version}-linux-x86_64.tar.gz",
				f"heroes-like-{version}-windows-x86_64.setup.exe",
				f"heroes-like-{version}-windows-x86_64.zip",
			)
		)
	)


def load_json(path: Path, label: str) -> dict[str, Any]:
	try:
		payload = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, json.JSONDecodeError) as exc:
		raise ValueError(f"{label} is not readable JSON: {exc}") from exc
	if not isinstance(payload, dict):
		raise ValueError(f"{label} must contain a JSON object")
	return payload


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def _release_state_matches(release: dict[str, Any], expected_state: str) -> bool:
	draft = release.get("draft") is True
	prerelease = release.get("prerelease") is True
	published_at = release.get("published_at")
	if expected_state == "draft-prerelease":
		return draft and prerelease and published_at in (None, "")
	return not draft and prerelease and isinstance(published_at, str) and published_at != ""


def verify_release_metadata(
	release: dict[str, Any],
	tag: str,
	version: str,
	revision: str,
	expected_state: str,
) -> list[dict[str, Any]]:
	if expected_state not in EXPECTED_STATES:
		raise ValueError(f"unsupported release state {expected_state}")
	if int(release.get("id", 0)) <= 0:
		raise ValueError("release id must be positive")
	if str(release.get("tag_name", "")) != tag:
		raise ValueError("release tag does not match requested tag")
	if str(release.get("target_commitish", "")) != revision:
		raise ValueError("release target commit does not match the exact tag revision")
	if not _release_state_matches(release, expected_state):
		raise ValueError(f"release is not in required {expected_state} state")

	assets = release.get("assets", [])
	if not isinstance(assets, list):
		raise ValueError("release assets must be an array")
	expected_names = set(expected_asset_names(version))
	names: list[str] = []
	asset_ids: list[int] = []
	normalized: list[dict[str, Any]] = []
	for raw_asset in assets:
		if not isinstance(raw_asset, dict):
			raise ValueError("release asset records must be objects")
		name = str(raw_asset.get("name", ""))
		if not name or Path(name).name != name or "/" in name or "\\" in name:
			raise ValueError("release asset name is unsafe")
		asset_id = int(raw_asset.get("id", 0))
		if asset_id <= 0:
			raise ValueError(f"release asset {name} has invalid id")
		size = int(raw_asset.get("size", -1))
		if size <= 0:
			raise ValueError(f"release asset {name} must be non-empty")
		if str(raw_asset.get("state", "")) != "uploaded":
			raise ValueError(f"release asset {name} is not fully uploaded")
		created_at = str(raw_asset.get("created_at", ""))
		updated_at = str(raw_asset.get("updated_at", ""))
		raw_digest = raw_asset.get("digest", "")
		asset_digest = raw_digest if isinstance(raw_digest, str) else ""
		if not created_at or not updated_at:
			raise ValueError(f"release asset {name} is missing timestamps")
		names.append(name)
		asset_ids.append(asset_id)
		normalized.append(
			{
				"created_at": created_at,
				"digest": asset_digest,
				"id": asset_id,
				"name": name,
				"size": size,
				"updated_at": updated_at,
			}
		)
	if len(names) != len(set(names)):
		raise ValueError("release contains duplicate asset names")
	if len(asset_ids) != len(set(asset_ids)):
		raise ValueError("release contains duplicate asset ids")
	if set(names) != expected_names:
		missing = sorted(expected_names - set(names))
		extra = sorted(set(names) - expected_names)
		raise ValueError(f"release asset set mismatch: missing={missing} extra={extra}")
	return sorted(normalized, key=lambda item: item["name"])


def parse_sha256sums(path: Path) -> dict[str, str]:
	checksums: dict[str, str] = {}
	try:
		lines = path.read_text(encoding="ascii").splitlines()
	except (OSError, UnicodeDecodeError) as exc:
		raise ValueError(f"SHA256SUMS is not readable ASCII: {exc}") from exc
	for line in lines:
		if not line.strip():
			continue
		match = re.fullmatch(r"([0-9a-f]{64})  ([^/\\]+)", line)
		if match is None:
			raise ValueError("SHA256SUMS contains a malformed row")
		digest, name = match.groups()
		if name in checksums:
			raise ValueError(f"SHA256SUMS contains duplicate entry {name}")
		checksums[name] = digest
	return checksums


def _records_by_path(value: Any, label: str) -> dict[str, dict[str, Any]]:
	if not isinstance(value, list):
		raise ValueError(f"release index {label} must be an array")
	records: dict[str, dict[str, Any]] = {}
	for record in value:
		if not isinstance(record, dict):
			raise ValueError(f"release index {label} entries must be objects")
		path = str(record.get("path", ""))
		if not path or Path(path).name != path:
			raise ValueError(f"release index {label} contains unsafe path")
		if path in records:
			raise ValueError(f"release index {label} duplicates {path}")
		records[path] = record
	return records


def verify_downloaded_assets(
	assets_dir: Path,
	version: str,
	revision: str,
	metadata_assets: list[dict[str, Any]],
) -> dict[str, str]:
	if not assets_dir.is_dir():
		raise ValueError("downloaded assets directory does not exist")
	entries = list(assets_dir.iterdir())
	if any(not entry.is_file() or entry.is_symlink() for entry in entries):
		raise ValueError("downloaded assets directory must contain regular files only")
	actual_names = {entry.name for entry in entries}
	expected_names = set(expected_asset_names(version))
	if actual_names != expected_names:
		missing = sorted(expected_names - actual_names)
		extra = sorted(actual_names - expected_names)
		raise ValueError(f"downloaded asset set mismatch: missing={missing} extra={extra}")

	result = load_json(assets_dir / "release-candidate-result.json", "release candidate result")
	if result.get("ok") is not True or str(result.get("schema_id", "")) != CANDIDATE_SCHEMA_ID:
		raise ValueError("release candidate result did not report verified success")
	if str(result.get("version", "")) != version:
		raise ValueError("release candidate version does not match tag")
	if str(result.get("source_revision", "")) != revision:
		raise ValueError("release candidate source revision does not match tag")
	verification = result.get("release_verification", {})
	if not isinstance(verification, dict) or verification.get("ok") is not True:
		raise ValueError("release candidate verification payload is missing or failed")
	if str(verification.get("schema_id", "")) != INDEX_SCHEMA_ID:
		raise ValueError("release candidate verification schema is invalid")
	if str(verification.get("version", "")) != version or str(verification.get("source_revision", "")) != revision:
		raise ValueError("release candidate verification identity drifted")

	index = load_json(assets_dir / "release-index.json", "release index")
	if str(index.get("schema_id", "")) != INDEX_SCHEMA_ID or str(index.get("product_id", "")) != PRODUCT_ID:
		raise ValueError("release index schema or product id is invalid")
	if str(index.get("version", "")) != version or str(index.get("source_revision", "")) != revision:
		raise ValueError("release index identity does not match tag")
	archives = _records_by_path(index.get("archives"), "archives")
	installers = _records_by_path(index.get("installers"), "installers")
	expected_archives = {
		f"heroes-like-{version}-linux-x86_64.tar.gz",
		f"heroes-like-{version}-windows-x86_64.zip",
	}
	expected_installers = {
		f"heroes-like-{version}-linux-x86_64.run",
		f"heroes-like-{version}-windows-x86_64.setup.exe",
	}
	if set(archives) != expected_archives or set(installers) != expected_installers:
		raise ValueError("release index does not contain the exact two archives and two installers")

	computed_hashes = {name: sha256_file(assets_dir / name) for name in sorted(actual_names)}
	checksums = parse_sha256sums(assets_dir / "SHA256SUMS")
	if set(checksums) != set(expected_payload_names(version)):
		raise ValueError("SHA256SUMS must contain exactly the four packaged payloads")
	for name, expected_digest in checksums.items():
		if computed_hashes[name] != expected_digest:
			raise ValueError(f"downloaded payload checksum mismatch for {name}")

	for name, record in {**archives, **installers}.items():
		digest = str(record.get("sha256", ""))
		if SHA256_PATTERN.fullmatch(digest) is None or digest != computed_hashes[name]:
			raise ValueError(f"release index checksum mismatch for {name}")
		if int(record.get("size_bytes", -1)) != (assets_dir / name).stat().st_size:
			raise ValueError(f"release index size mismatch for {name}")

	linux_installer = installers[f"heroes-like-{version}-linux-x86_64.run"]
	windows_installer = installers[f"heroes-like-{version}-windows-x86_64.setup.exe"]
	for installer, archive_name in (
		(linux_installer, f"heroes-like-{version}-linux-x86_64.tar.gz"),
		(windows_installer, f"heroes-like-{version}-windows-x86_64.zip"),
	):
		if str(installer.get("source_archive_path", "")) != archive_name:
			raise ValueError("installer source archive path is invalid")
		if str(installer.get("source_archive_sha256", "")) != computed_hashes[archive_name]:
			raise ValueError("installer source archive checksum is invalid")

	metadata_by_name = {str(asset["name"]): asset for asset in metadata_assets}
	for name in sorted(actual_names):
		asset = metadata_by_name[name]
		path = assets_dir / name
		if int(asset["size"]) != path.stat().st_size:
			raise ValueError(f"GitHub asset size mismatch for {name}")
		digest = str(asset.get("digest", ""))
		if digest and digest != f"sha256:{computed_hashes[name]}":
			raise ValueError(f"GitHub asset digest mismatch for {name}")
	return computed_hashes


def promotion_fingerprint(
	release_id: int,
	tag: str,
	version: str,
	revision: str,
	metadata_assets: list[dict[str, Any]],
	hashes: dict[str, str],
) -> str:
	payload = {
		"release_id": release_id,
		"source_revision": revision,
		"tag": tag,
		"version": version,
		"assets": [
			{
				"created_at": asset["created_at"],
				"id": asset["id"],
				"name": asset["name"],
				"size": asset["size"],
				"updated_at": asset["updated_at"],
				"sha256": hashes[str(asset["name"])],
			}
			for asset in metadata_assets
		],
	}
	encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
	return hashlib.sha256(encoded).hexdigest()


def verify_promotion(
	release: dict[str, Any],
	assets_dir: Path | None,
	tag: str,
	revision: str,
	expected_state: str,
	metadata_only: bool = False,
	expected_fingerprint: str = "",
) -> dict[str, Any]:
	version = prerelease_version_from_tag(tag)
	revision = safe_revision(revision)
	metadata_assets = verify_release_metadata(release, tag, version, revision, expected_state)
	result: dict[str, Any] = {
		"schema_id": SCHEMA_ID,
		"ok": True,
		"expected_state": expected_state,
		"release_id": int(release["id"]),
		"tag": tag,
		"version": version,
		"source_revision": revision,
		"asset_count": len(metadata_assets),
		"assets": metadata_assets,
		"metadata_only": metadata_only,
	}
	if metadata_only:
		if expected_fingerprint:
			raise ValueError("metadata-only verification cannot compare a payload fingerprint")
		return result
	if assets_dir is None:
		raise ValueError("full verification requires downloaded assets")
	hashes = verify_downloaded_assets(assets_dir, version, revision, metadata_assets)
	fingerprint = promotion_fingerprint(int(release["id"]), tag, version, revision, metadata_assets, hashes)
	if expected_fingerprint:
		if SHA256_PATTERN.fullmatch(expected_fingerprint) is None:
			raise ValueError("expected promotion fingerprint is invalid")
		if fingerprint != expected_fingerprint:
			raise ValueError("release or asset identity changed during promotion")
	result.update(
		{
			"metadata_only": False,
			"payload_checksum_count": len(expected_payload_names(version)),
			"downloaded_asset_hashes": dict(sorted(hashes.items())),
			"promotion_fingerprint": fingerprint,
		}
	)
	return result


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Verify fail-closed public prerelease promotion inputs.")
	parser.add_argument("--event-name", required=True)
	parser.add_argument("--workflow-ref", required=True)
	parser.add_argument("--tag", required=True)
	parser.add_argument("--confirmation", required=True)
	parser.add_argument("--tag-revision")
	parser.add_argument("--release-json", type=Path)
	parser.add_argument("--assets-dir", type=Path)
	parser.add_argument("--expected-state", choices=EXPECTED_STATES)
	parser.add_argument("--expected-fingerprint", default="")
	parser.add_argument("--metadata-only", action="store_true")
	parser.add_argument("--policy-only", action="store_true")
	parser.add_argument("--result-json", type=Path)
	return parser.parse_args()


def write_result(path: Path | None, payload: dict[str, Any]) -> None:
	if path is not None:
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
	print(json.dumps(payload, sort_keys=True))


def main() -> int:
	args = parse_args()
	version = validate_policy(args.event_name, args.workflow_ref, args.tag, args.confirmation)
	if args.policy_only:
		if any((args.tag_revision, args.release_json, args.assets_dir, args.expected_state, args.expected_fingerprint)) or args.metadata_only:
			raise ValueError("policy-only verification cannot accept release payload arguments")
		write_result(
			args.result_json,
			{
				"schema_id": SCHEMA_ID,
				"ok": True,
				"policy_only": True,
				"tag": args.tag,
				"version": version,
			},
		)
		return 0
	if not args.tag_revision or args.release_json is None or args.expected_state is None:
		raise ValueError("release verification requires tag revision, release JSON, and expected state")
	release = load_json(args.release_json, "GitHub release metadata")
	result = verify_promotion(
		release,
		args.assets_dir,
		args.tag,
		args.tag_revision,
		args.expected_state,
		args.metadata_only,
		args.expected_fingerprint,
	)
	write_result(args.result_json, result)
	return 0


if __name__ == "__main__":
	try:
		raise SystemExit(main())
	except (OSError, ValueError) as exc:
		print(f"verify_release_promotion: {exc}", file=sys.stderr)
		raise SystemExit(1)
