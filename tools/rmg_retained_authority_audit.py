#!/usr/bin/env python3
"""Compare fresh, unassisted native payloads with retained H3MapEd captures.

Offline equality is final-writeout evidence only, not earlier private-state
parity or proof of arbitrary seeds, allocator histories, or gameplay adoption.
No owner bytes are supplied to generation. CLI diagnostic refusal without a
same-run authority join is preserved and recorded, never bypassed for gameplay.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from rmg_no_godot_guard import guard_report
from rmg_h3maped_redirected_memory_payload_extract import build_memory_maps

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT / ".artifacts/rmg_recovery"
CASES = [
    ("small", 59, 1, "land", 2, "small_seed59_2h0c_weak_memory_stream_redirect_raw_dump_20260715a"),
    ("small", 62, 1, "normal_water", 1, "small_seed62_1h1c_weak_normal_water_memory_stream_redirect_raw_dump_20260717b"),
    ("small", 60, 1, "islands", 1, "small_seed60_1h1c_weak_islands_memory_stream_redirect_raw_dump_20260717a"),
    ("small", 68, 2, "land", 1, "small_seed68_1h1c_weak_two_level_land_memory_stream_redirect_raw_dump_20260718a"),
    ("small", 69, 2, "normal_water", 1, "small_seed69_1h1c_weak_two_level_normal_water_same_run_authority_20260718a"),
    ("small", 70, 2, "islands", 1, "small_seed70_1h1c_weak_two_level_islands_same_run_authority_20260718a"),
    ("medium", 10, 1, "land", 1, "medium_seed10_1h1c_weak_memory_stream_authority_20260716a"),
    ("medium", 10, 1, "normal_water", 1, "medium_seed10_1h1c_weak_normal_water_memory_stream_redirect_raw_dump_20260716a"),
    ("medium", 63, 1, "islands", 1, "medium_seed63_1h1c_weak_islands_memory_stream_redirect_raw_dump_20260717a"),
    ("medium", 13, 2, "land", 1, "medium_seed13_two_level_payload_authority_20260717a"),
    ("medium", 71, 2, "normal_water", 1, "medium_seed71_1h1c_weak_two_level_normal_water_same_run_authority_20260718a"),
    ("medium", 72, 2, "islands", 1, "medium_seed72_1h1c_weak_two_level_islands_same_run_authority_20260718a"),
    ("large", 11, 1, "land", 1, "large_seed11_1h1c_weak_memory_stream_redirect_raw_dump_20260715a"),
    ("large", 64, 1, "normal_water", 1, "large_seed64_1h1c_weak_normal_water_memory_stream_redirect_raw_dump_20260717a"),
    ("large", 66, 1, "islands", 1, "large_seed66_1h1c_weak_islands_memory_stream_redirect_raw_dump_20260718a"),
    ("large", 73, 2, "land", 1, "large_seed73_1h1c_weak_two_level_land_same_run_authority_20260718a"),
    ("large", 74, 2, "normal_water", 1, "large_seed74_1h1c_weak_two_level_normal_water_same_run_authority_20260718a"),
    ("large", 75, 2, "islands", 1, "large_seed75_1h1c_weak_two_level_islands_same_run_authority_20260718a"),
    ("xlarge", 12, 1, "land", 1, "xlarge_seed12_1h1c_weak_memory_stream_redirect_raw_dump_20260715a"),
    ("xlarge", 65, 1, "normal_water", 1, "xlarge_seed65_1h1c_weak_normal_water_same_run_authority_20260718a"),
    ("xlarge", 67, 1, "islands", 1, "xlarge_seed67_1h1c_weak_islands_same_run_authority_20260718a"),
    ("xlarge", 76, 2, "land", 1, "xlarge_seed76_1h1c_weak_two_level_land_same_run_authority_20260718a"),
    ("xlarge", 77, 2, "normal_water", 1, "xlarge_seed77_1h1c_weak_two_level_normal_water_same_run_authority_20260718a"),
    ("xlarge", 78, 2, "islands", 1, "xlarge_seed78_1h1c_weak_two_level_islands_same_run_authority_20260718a"),
]


def compare_bytes(native, owner):
    mismatch = next((i for i, (a, b) in enumerate(zip(native, owner)) if a != b), None)
    if mismatch is None and len(native) != len(owner):
        mismatch = min(len(native), len(owner))
    return {"exact": native == owner, "native_bytes": len(native), "owner_bytes": len(owner), "first_mismatch": mismatch, "native_sha256": hashlib.sha256(native).hexdigest(), "owner_sha256": hashlib.sha256(owner).hexdigest()}


def compare_private_grid(native_log, owner_ledger):
    """Join explicit caller PCs; merge overlapping dumps without losing cell 0."""
    phases = {}
    for line in native_log.read_text().splitlines():
        if line.startswith("RMG_TRACE_WORKFLOW_GRID "):
            fields = dict(re.findall(r"(\w+)=(\S+)", line))
            cells = phases.setdefault(fields["phase"], {})
            index = int(fields["cell"])
            if index in cells:
                raise ValueError("multiple invocations need an explicit call-order join")
            cells[index] = fields
    owners = json.loads(owner_ledger.read_text())
    joins = {"0x004a8c25": ("after_0x4a8260_0x4a8c25", "ebx"), "0x004a8c2c": ("after_0x4a4c8e_0x4a8c2c", "ebx"), "0x0049eb8d": ("after_0x49a1ef_0x4ac83d", "ecx")}
    rows = []
    for event in owners["events"]:
        phase, register = joins[event["address"]]
        memory, _, conflicts = build_memory_maps(event["memory_lines"])
        if conflicts:
            raise ValueError(str(conflicts))
        generator = event["registers"][register]
        base, width, height, levels = [memory[generator + offset] for offset in (20, 24, 28, 32)]
        cell_count = width * height * levels
        cells = phases[phase]
        if set(cells) != set(range(cell_count)):
            raise ValueError("native grid coverage differs from owner dimensions")
        mismatch = {}
        first = {}
        for i in range(cell_count):
            for j, key in enumerate(("w10", "w14", "w18", "w1c", "w20", "w24", "w28", "w2c"), 4):
                owner = memory[base + i * 48 + j * 4]
                native = int(cells[i][key], 16)
                if owner != native:
                    mismatch[key] = mismatch.get(key, 0) + 1
                    first.setdefault(key, {"cell": i, "native": native, "owner": owner})
        rows.append({"owner_pc": event["address"], "native_phase": phase, "cells": cell_count, "words_per_cell": 8, "mismatch_counts": mismatch, "first_mismatch": first, "exact": not mismatch})
    if not rows:
        raise ValueError("no private-state checkpoints")
    return {"native_log": str(native_log), "owner_ledger": str(owner_ledger), "owner_ui_options": owners.get("ui_options"), "note": "Only +0x10 through +0x2c compared. Pointer/object-vector contents and other phases are not certified. Historical profile joins remain explicit in the audit report.", "checkpoints": rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="retained_matrix")
    parser.add_argument("--analyze-only", action="store_true")
    parser.add_argument("--private-log", type=Path)
    parser.add_argument("--owner-ledger", type=Path)
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("unsafe label")
    out = ROOT / ".artifacts/rmg_start_audit_20260905" / args.label
    if args.private_log or args.owner_ledger:
        if not args.private_log or not args.owner_ledger:
            parser.error("private comparison requires both --private-log and --owner-ledger")
        out.mkdir(parents=True, exist_ok=False)
        report = compare_private_grid(args.private_log, args.owner_ledger)
        (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report))
        return 0 if all(r["exact"] for r in report["checkpoints"]) else 1
    if not args.analyze_only:
        if guard_report("retained_authority_audit")["status"] != "pass":
            parser.error("Godot is running; native evidence must run separately")
        out.mkdir(parents=True, exist_ok=False)
    rows = []
    for size, seed, levels, water, humans, folder in CASES:
        case_id = f"{size}_{levels}_{water}_{seed}"
        owner = RECOVERY / folder / "final_payload.bin"
        case_out = out / case_id
        config = f"{case_id}:{size}:2:{seed}:{water}:{levels}:{humans}:{2-humans}:{['land','normal_water','islands'].index(water)}:2:-1:{humans}:{humans}:{2-humans}:0:-1"
        row = {"id": case_id, "config": config, "owner": str(owner.relative_to(ROOT))}
        if not owner.exists():
            row.update(exact=False, blocker="retained_owner_payload_missing")
            rows.append(row)
            continue
        if not args.analyze_only:
            cmd = [sys.executable, "tools/rmg_native_batch_export.py", "--out", str(case_out), "--controlled-case", config, "--include-unsupported", "--emit-final-h3m-payload"]
            with (out / (case_id + ".log")).open("w") as log:
                run = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
            row["wrapper_returncode"] = run.returncode
        manifest_path = case_out / "wrapper_manifest.json"
        manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
        row["wrapper_status"] = manifest.get("status")
        row["wrapper_blocked_reason"] = manifest.get("blocked_reason")
        native_path = case_out / (case_id + ".final_payload.bin")
        if native_path.exists():
            row.update(compare_bytes(native_path.read_bytes(), owner.read_bytes()))
        else:
            row.update(exact=False, blocker="native_diagnostic_final_payload_missing")
        rows.append(row)
        print(json.dumps({k: row.get(k) for k in ("id", "exact", "first_mismatch", "native_bytes", "owner_bytes", "blocker")}), flush=True)
    report = {"all_retained_payloads_exact": all(r["exact"] for r in rows), "case_count": len(rows), "exact_count": sum(r["exact"] for r in rows), "native_authority_bytes_supplied": False, "new_executable_capture": False, "earlier_private_state_parity_claimed": False, "cases": rows}
    (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["all_retained_payloads_exact"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
