#!/usr/bin/env python3
"""Check recovered template-selection order against H3MapEd reference manifests."""

from __future__ import annotations

import argparse
import glob
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CATALOG = Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json")
DEFAULT_MANIFEST_GLOB = (
    ".artifacts/rmg_20seed_2p_small_h3maped_20260605/"
    "small_2p_seed_*_manual20/controlled_reference_manifest.json"
)


def rng_first(seed: int) -> int:
    state = (seed * 0x343FD + 0x269EC3) & 0xFFFFFFFF
    return (state >> 16) & 0x7FFF


def player_filter_allows(filter_payload: dict[str, Any], humans: int, players: int) -> bool:
    return (
        humans >= int(filter_payload.get("min_human", 0))
        and humans <= int(filter_payload.get("max_human", 8))
        and players >= int(filter_payload.get("min_total", 0))
        and players <= int(filter_payload.get("max_total", 8))
    )


def accepted_templates(catalog: dict[str, Any], size_score: int, humans: int, players: int) -> list[dict[str, Any]]:
    accepted: list[dict[str, Any]] = []
    for index, template in enumerate(catalog.get("templates", [])):
        if not isinstance(template, dict):
            continue
        if size_score < int(template.get("min_size", 0)) or size_score > int(template.get("max_size", 0)):
            continue
        human_range = template.get("supported_human_range", [0, 0])
        player_range = template.get("supported_total_player_range", [0, 0])
        if not (
            humans >= int(human_range[0])
            and humans <= int(human_range[1])
            and players >= int(player_range[0])
            and players <= int(player_range[1])
            and players >= humans
        ):
            continue
        human_owners: set[int] = set()
        player_owners: set[int] = set()
        for zone in template.get("zones", []):
            if not isinstance(zone, dict):
                continue
            if not player_filter_allows(zone.get("player_filter", {}), humans, players):
                continue
            owner = zone.get("ownership", -2)
            if not isinstance(owner, (int, float)) or owner < 0 or owner >= 8:
                continue
            role = zone.get("type", "")
            if role == "human_start":
                human_owners.add(int(owner))
                player_owners.add(int(owner))
            elif role == "computer_start":
                player_owners.add(int(owner))
        if len(human_owners) < humans or len(player_owners) < players:
            continue
        accepted.append(
            {
                "source_catalog_index": index,
                "name": template.get("name", ""),
            }
        )
    return accepted


def find_observed_source_catalog_index(payload: Any) -> int | None:
    if isinstance(payload, dict):
        if "observed_source_catalog_index" in payload:
            return int(payload["observed_source_catalog_index"])
        for value in payload.values():
            found = find_observed_source_catalog_index(value)
            if found is not None:
                return found
    elif isinstance(payload, list):
        for value in payload:
            found = find_observed_source_catalog_index(value)
            if found is not None:
                return found
    return None


def seed_from_manifest_path(path: Path) -> int:
    match = re.search(r"seed_(\d+)_", str(path))
    if not match:
        raise ValueError(f"cannot infer seed from {path}")
    return int(match.group(1))


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    accepted = accepted_templates(catalog, args.size_score, args.humans, args.players)
    rows: list[dict[str, Any]] = []
    for text_path in sorted(glob.glob(str(args.manifest_glob))):
        path = Path(text_path)
        payload = json.loads(path.read_text(encoding="utf-8"))
        seed = seed_from_manifest_path(path)
        rng_value = rng_first(seed)
        selected_index = rng_value % len(accepted)
        predicted = accepted[selected_index]["source_catalog_index"]
        observed = find_observed_source_catalog_index(payload)
        rows.append(
            {
                "seed": seed,
                "rng_value": rng_value,
                "selected_vector_index": selected_index,
                "predicted_source_catalog_index": predicted,
                "predicted_template_name": accepted[selected_index]["name"],
                "observed_source_catalog_index": observed,
                "matches": predicted == observed,
                "manifest": str(path),
            }
        )
    return {
        "schema_id": "rmg_h3maped_template_selection_reference_check_v1",
        "catalog": str(args.catalog),
        "manifest_glob": str(args.manifest_glob),
        "size_score": args.size_score,
        "humans": args.humans,
        "players": args.players,
        "accepted_template_count": len(accepted),
        "accepted_source_catalog_indices": [row["source_catalog_index"] for row in accepted],
        "case_count": len(rows),
        "match_count": sum(1 for row in rows if row["matches"]),
        "all_match": all(row["matches"] for row in rows),
        "rows": rows,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--manifest-glob", type=Path, default=Path(DEFAULT_MANIFEST_GLOB))
    parser.add_argument("--size-score", type=int, default=1)
    parser.add_argument("--humans", type=int, default=2)
    parser.add_argument("--players", type=int, default=2)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    report = build_report(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if report["all_match"] else "fail"
    print(
        "RMG_H3MAPED_TEMPLATE_SELECTION_REFERENCE_CHECK "
        f"status={status} matches={report['match_count']}/{report['case_count']} "
        f"accepted={report['accepted_template_count']} out={args.out}"
    )
    return 0 if report["all_match"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
