#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass


VERSION_PATTERN = re.compile(r"[0-9A-Za-z][0-9A-Za-z._+-]*")


@dataclass(frozen=True)
class Delivery:
	deliver_draft: bool
	release_tag: str


def resolve_delivery(
	event_name: str,
	ref_name: str,
	ref_type: str,
	version: str,
	create_draft_release: bool,
) -> Delivery:
	if VERSION_PATTERN.fullmatch(version) is None:
		raise ValueError("candidate version is invalid")

	deliver = event_name == "push" or create_draft_release
	if not deliver:
		return Delivery(False, "")
	if ref_type != "tag":
		if event_name == "workflow_dispatch":
			raise ValueError(
				"manual draft delivery requires dispatching the workflow from an existing version tag"
			)
		raise ValueError("automatic draft delivery requires a version-tag push")

	expected_tag = f"v{version}"
	if ref_name != expected_tag:
		raise ValueError(f"release tag {ref_name} does not match candidate version {version}")
	return Delivery(True, ref_name)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Resolve fail-closed draft release delivery policy.")
	parser.add_argument("--event-name", required=True)
	parser.add_argument("--ref-name", required=True)
	parser.add_argument("--ref-type", required=True)
	parser.add_argument("--version", required=True)
	parser.add_argument("--create-draft-release", choices=("true", "false"), default="false")
	return parser.parse_args()


def main() -> int:
	args = parse_args()
	try:
		delivery = resolve_delivery(
			args.event_name,
			args.ref_name,
			args.ref_type,
			args.version,
			args.create_draft_release == "true",
		)
	except ValueError as exc:
		print(f"resolve_release_delivery: {exc}", file=sys.stderr)
		return 1
	print(f"deliver_draft={str(delivery.deliver_draft).lower()}")
	print(f"release_tag={delivery.release_tag}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
