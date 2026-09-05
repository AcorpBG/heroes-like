#!/usr/bin/env python3
"""Profile existing live scene/router playthroughs in isolated save storage."""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import resource
import signal
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/full_play_runtime_20260905"
FLOWS = {
    "skirmish": "boot_to_skirmish_resolved_outcome",
    "campaign": "boot_to_campaign_full_arc",
    "strategic": "boot_to_skirmish_strategic_soak",
}


def summarize(records: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for row in records:
        groups[(row.get("surface", ""), row.get("phase", ""), row.get("event", ""))].append(row)
    result = []
    for key, rows in groups.items():
        times = sorted(float(r.get("total_ms", 0)) for r in rows)
        buckets = defaultdict(float)
        for row in rows:
            for name, value in row.get("buckets_ms", {}).items():
                if isinstance(value, (int, float)):
                    buckets[name] += value
        result.append({"surface": key[0], "phase": key[1], "event": key[2], "count": len(rows), "inclusive_total_ms": sum(times), "p50_ms": times[len(times) // 2], "p95_ms": times[min(len(times) - 1, int(len(times) * .95))], "max_ms": times[-1], "inclusive_buckets": dict(sorted(buckets.items(), key=lambda r: -r[1]))})
    return sorted(result, key=lambda row: -row["inclusive_total_ms"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--flow", choices=FLOWS, default="skirmish")
    parser.add_argument("--resolution", choices=["1920x1080", "1280x720"], default="1920x1080")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--accessibility", choices=["auto", "disabled"], default="auto")
    parser.add_argument("--functional-only", action="store_true", help="Disable profiling for independent concurrent behavior verification; not timing evidence")
    parser.add_argument("--timeout", type=int, default=1200)
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must use lowercase letters, digits, underscores or hyphens")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_PROFILE_LOG="0" if args.functional_only else "1", HEROES_LIVE_PROFILE_CAPTURE_STATES="1", HEROES_LIVE_PROFILE_SESSION_SEED="full_play_20260905", HEROES_LIVE_PROFILE_RESOLUTION=args.resolution)
    cmd = [shutil.which("godot4") or "godot", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", args.accessibility, "--resolution", args.resolution]
    if args.headless:
        cmd.append("--headless")
    else:
        cmd = ["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + cmd
    cmd += ["--", "--live-validation-flow=" + FLOWS[args.flow], "--live-validation-output=" + str(out / "live")]
    print("Running " + " ".join(cmd), flush=True)
    timed_out = False
    with (out / "runtime.log").open("w") as log:
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            returncode = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            returncode = 124
    live_path = out / "live/live_validation_report.json"
    live = json.loads(live_path.read_text()) if live_path.is_file() else {}
    profile_path = out / "data/godot/app_userdata/heroes-like/debug/heroes_profile.jsonl"
    records = [json.loads(line) for line in profile_path.read_text().splitlines() if line.strip()] if profile_path.is_file() else []
    errors = [line for line in (out / "runtime.log").read_text().splitlines() if line.startswith(("SCRIPT ERROR:", "ERROR:")) or "leaked" in line]
    result = {
        "ok": returncode == 0 and bool(live.get("ok", False)) and not errors,
        "returncode": returncode, "timed_out": timed_out, "runtime_errors": errors,
        "flow": FLOWS[args.flow], "resolution": args.resolution,
        "headless": args.headless, "accessibility": args.accessibility,
        "functional_only": args.functional_only,
        "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "peak_child_rss_kib": resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        "live_report": str(live_path), "profile_path": str(profile_path),
        "step_count": len(live.get("steps", [])), "summary": summarize(records),
        "note": "Nested profile totals are inclusive; do not sum as wall time. Real flows use tactical orders and shipped Quick Resolve; inspect individual steps for coverage. Rendered evidence uses the explicitly recorded accessibility backend and software GPU, not hardware certification.",
    }
    (out / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "summary"}))
    for row in result["summary"][:15]:
        print(json.dumps(row))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
