#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

from validate_repo import build_all_interactable_object_footprint_audit, items_index, load_json  # noqa: E402


REPORT_ID = "ALL_INTERACTABLE_OBJECT_FOOTPRINT_AUDIT"
RMG_CATALOG_PATH = ROOT / "scripts" / "core" / "RandomMapGeneratorRules.gd"
RMG_RUNTIME_SPLIT_EXCEPTIONS = {
    "rmg_primary_town_anchor": "Generated towns intentionally preserve a 3x2 intended body and current 1x1 runtime body until the later multitile town runtime slice.",
}


def main() -> int:
    map_objects = items_index(load_json(ROOT / "content" / "map_objects.json"))
    authored = build_all_interactable_object_footprint_audit(map_objects)
    rmg = audit_rmg_catalog()
    failures = list(authored["failures"]) + list(rmg["failures"])
    payload = {
        "ok": not failures,
        "authored_checked_count": authored["checked_count"],
        "authored_exception_count": authored["exception_count"],
        "rmg_checked_count": rmg["checked_count"],
        "rmg_runtime_split_exceptions": rmg["runtime_split_exceptions"],
        "failures": failures,
    }
    print(f"{REPORT_ID} {json.dumps(payload, sort_keys=True)}")
    return 0 if not failures else 1


def audit_rmg_catalog() -> dict:
    catalog = extract_rmg_catalog()
    failures: list[str] = []
    checked = 0
    runtime_split_exceptions: list[dict] = []
    for record in catalog:
        if not isinstance(record, dict):
            failures.append("RMG catalog contains a non-dictionary record")
            continue
        action_mask = record.get("action_mask", {}) if isinstance(record.get("action_mask", {}), dict) else {}
        if not bool(action_mask.get("visitable", False)):
            continue
        checked += 1
        catalog_id = str(record.get("id", ""))
        body_keys = {tile_key(tile) for tile in record.get("body_mask", []) if isinstance(tile, dict)}
        runtime_body_keys = {tile_key(tile) for tile in record.get("runtime_body_mask", record.get("body_mask", [])) if isinstance(tile, dict)}
        visit_mask = record.get("visit_mask", []) if isinstance(record.get("visit_mask", []), list) else []
        if not visit_mask:
            failures.append(f"{catalog_id}: visitable RMG catalog record has no visit_mask")
            continue
        for tile in visit_mask:
            key = tile_key(tile)
            if key not in body_keys:
                failures.append(f"{catalog_id}: visit_mask tile {key} is outside body_mask")
            if key not in runtime_body_keys:
                if catalog_id in RMG_RUNTIME_SPLIT_EXCEPTIONS:
                    runtime_split_exceptions.append({"catalog_id": catalog_id, "tile": key, "reason": RMG_RUNTIME_SPLIT_EXCEPTIONS[catalog_id]})
                elif str(record.get("deferred_runtime_application", "")):
                    runtime_split_exceptions.append({"catalog_id": catalog_id, "tile": key, "reason": str(record.get("deferred_runtime_application", ""))})
                else:
                    failures.append(f"{catalog_id}: visit_mask tile {key} is outside runtime_body_mask without a deferred runtime exception")
    return {
        "checked_count": checked,
        "runtime_split_exceptions": runtime_split_exceptions,
        "failures": failures,
    }


def extract_rmg_catalog() -> list:
    text = RMG_CATALOG_PATH.read_text(encoding="utf-8")
    match = re.search(r"const OBJECT_FOOTPRINT_CATALOG := (\[.*?\n\])\n\nclass DeterministicRng", text, re.S)
    if not match:
        raise RuntimeError("Could not locate OBJECT_FOOTPRINT_CATALOG in RandomMapGeneratorRules.gd")
    literal = match.group(1)
    literal = re.sub(r"\btrue\b", "True", literal)
    literal = re.sub(r"\bfalse\b", "False", literal)
    return ast.literal_eval(literal)


def tile_key(tile: dict) -> str:
    return f"{int(tile.get('x', -999))},{int(tile.get('y', -999))}"


if __name__ == "__main__":
    raise SystemExit(main())
