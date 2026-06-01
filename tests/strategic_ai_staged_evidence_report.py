#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REPORT_ID = "STRATEGIC_AI_STAGED_EVIDENCE_REPORT"
STRICT_SEED_TARGET = 100
STRICT_TURN_TARGET = 56


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} did not contain a JSON object")
    return data


def _slice_text(slice_row: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("summary", "notes", "validation"):
        value = slice_row.get(key)
        if isinstance(value, list):
            parts.extend(str(item) for item in value)
        elif value is not None:
            parts.append(str(value))
    return " ".join(parts)


def _ordinal_range_for(slice_row: dict[str, Any]) -> tuple[int, int, str] | None:
    slice_id = str(slice_row.get("id", ""))
    match = re.search(r"strategic-ai-eight-week-shard-offset(\d+)(?:-count(\d+))?", slice_id)
    if match:
        offset = int(match.group(1))
        count = int(match.group(2) or "1")
        return offset + 1, offset + count, "strict_56_turn_shard"
    match = re.search(r"strategic-ai-production-shard-offset(\d+)", slice_id)
    if match:
        offset = int(match.group(1))
        return offset + 1, offset + 5, "strict_56_turn_shard"
    if slice_id == "strategic-ai-broader-handoff-generalization-10184":
        return 1, 3, "focused_smoke"
    return None


def _collect_slices(progress: dict[str, Any]) -> list[dict[str, Any]]:
    rows = progress.get("plannedSlices", [])
    if not isinstance(rows, list):
        return []
    slices: list[dict[str, Any]] = []
    seen: set[str] = set()
    for value in rows:
        if not isinstance(value, dict):
            continue
        slice_id = str(value.get("id", ""))
        if slice_id in seen:
            continue
        if _ordinal_range_for(value) is None:
            continue
        seen.add(slice_id)
        slices.append(value)
    return slices


def _covered_ordinals(slices: list[dict[str, Any]], scope: str) -> set[int]:
    covered: set[int] = set()
    for slice_row in slices:
        ordinal_range = _ordinal_range_for(slice_row)
        if ordinal_range is None:
            continue
        start, end, row_scope = ordinal_range
        if row_scope != scope:
            continue
        if str(slice_row.get("status", "")) != "completed":
            continue
        for ordinal in range(start, end + 1):
            covered.add(ordinal)
    return covered


def _find_residual_diagnostics(slices: list[dict[str, Any]]) -> list[dict[str, Any]]:
	rows: list[dict[str, Any]] = []
	for slice_row in slices:
		if str(slice_row.get("status", "")) != "completed":
			continue
		text = _slice_text(slice_row)
		diagnostic_id = _residual_diagnostic_id(text)
		if diagnostic_id != "":
			rows.append({
				"slice_id": str(slice_row.get("id", "")),
				"diagnostic_id": diagnostic_id,
				"status": str(slice_row.get("status", "")),
				"detail": _compact(text, 360),
			})
	return rows


def _residual_diagnostic_id(text: str) -> str:
	if re.search(r"unreachable_active_target_count=[1-9]\d*", text, re.I):
		return "unreachable_active_target"
	if re.search(r"(retained|remained|remaining|residual)[^.]{0,120}unreachable active target", text, re.I):
		return "unreachable_active_target"
	if re.search(r"stalled_turn_count=[1-9]\d*", text, re.I):
		return "stalled_turn"
	if re.search(r"stalled turns [1-9]\d*", text, re.I):
		return "stalled_turn"
	if re.search(r"one recovered no-event/stalled", text, re.I):
		return "stalled_turn"
	if re.search(r"no battle arrival despite ongoing pressure|no natural tactical arrival|remaining pacing/validation", text, re.I):
		return "no_battle_arrival"
	return ""


def _compact(text: str, limit: int) -> str:
    cleaned = re.sub(r"\s+", " ", text).strip()
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: limit - 3].rstrip() + "..."


def build_report(root: Path) -> dict[str, Any]:
    progress_path = root / "ops" / "progress.json"
    progress = _load_json(progress_path)
    slices = _collect_slices(progress)
    strict_covered = _covered_ordinals(slices, "strict_56_turn_shard")
    smoke_covered = _covered_ordinals(slices, "focused_smoke")
    all_required = set(range(1, STRICT_SEED_TARGET + 1))
    strict_missing = sorted(all_required - strict_covered)
    smoke_only = sorted((smoke_covered & all_required) - strict_covered)
    residual_diagnostics = _find_residual_diagnostics(slices)
    completed_strict_slice_count = sum(
        1
        for row in slices
        if str(row.get("status", "")) == "completed"
        and (_ordinal_range_for(row) or (0, 0, ""))[2] == "strict_56_turn_shard"
    )
    report = {
        "report_id": REPORT_ID,
        "status": "pass" if not strict_missing and not residual_diagnostics else "needs_attention",
        "production_ready": False,
        "policy": {
            "native_rmg_generated_maps_only": True,
            "authored_scenario_balance_surface": False,
            "balance_content_changes_allowed": False,
        },
        "strict_target": {
            "seed_count": STRICT_SEED_TARGET,
            "turn_count": STRICT_TURN_TARGET,
        },
        "coverage": {
            "completed_strict_slice_count": completed_strict_slice_count,
            "strict_covered_seed_ordinals": sorted(strict_covered),
            "strict_covered_seed_count": len(strict_covered),
            "strict_missing_seed_ordinals": strict_missing,
            "focused_smoke_seed_ordinals": sorted(smoke_covered),
            "smoke_only_seed_ordinals": smoke_only,
        },
        "residual_diagnostics": residual_diagnostics,
        "blocker_rows": _blocker_rows(strict_missing, smoke_only, residual_diagnostics),
        "recommended_next_slices": _recommended_next_slices(strict_missing, residual_diagnostics),
    }
    return report


def _blocker_rows(
    strict_missing: list[int],
    smoke_only: list[int],
    residual_diagnostics: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if strict_missing:
        rows.append({
            "blocker_id": "strategic_ai_staged_strict_56_turn_coverage_gap",
            "severity": "remaining_validation",
            "summary": "Some Native RMG seed ordinals have only earlier short-smoke evidence or no strict 56-turn shard evidence.",
            "missing_seed_ordinals": strict_missing,
            "smoke_only_seed_ordinals": smoke_only,
        })
    if residual_diagnostics:
        rows.append({
            "blocker_id": "strategic_ai_staged_residual_diagnostics_need_classification",
            "severity": "production_gap",
            "summary": "Committed shard evidence still contains residual stalled/unreachable/no-arrival diagnostics that must be classified or fixed before production-ready AI can be claimed.",
            "diagnostic_count": len(residual_diagnostics),
        })
    return rows


def _recommended_next_slices(
    strict_missing: list[int],
    residual_diagnostics: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if strict_missing:
        rows.append({
            "id": "strategic-ai-strict-opening-seed-shard-10184",
            "summary": "Run current Native RMG 56-turn tactical/strategic AI evidence for missing opening seed ordinals before claiming 1-100 staged coverage.",
            "seed_ordinals": strict_missing,
        })
    if residual_diagnostics:
        rows.append({
            "id": "strategic-ai-residual-diagnostic-hardening-10184",
            "summary": "Classify residual unreachable/stalled/no-arrival evidence with current harness semantics, then fix real tactical/strategic AI defects without balance-content edits.",
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    report = build_report(args.root.resolve())
    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print(f"{REPORT_ID} {json.dumps(report, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
