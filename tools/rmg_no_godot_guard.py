#!/usr/bin/env python3
"""Shared no-Godot process guard for native RMG Python tooling.

RMG parity work on this host must not start or share memory with Godot. The
native export wrapper already uses a standalone CLI; this helper lets related
RMG validation commands fail fast when an engine process is still active.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any


def active_godot_processes() -> list[dict[str, str]]:
    proc_root = Path("/proc")
    if not proc_root.exists():
        return []
    current_pid = os.getpid()
    matches: list[dict[str, str]] = []
    for entry in proc_root.iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == current_pid:
            continue
        try:
            comm = (entry / "comm").read_text(encoding="utf-8", errors="ignore").strip()
            raw_cmdline = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        cmdline_parts = [part.decode("utf-8", errors="ignore") for part in raw_cmdline.split(b"\0") if part]
        executable = Path(cmdline_parts[0]).name if cmdline_parts else comm
        marker = f"{comm} {executable}".lower()
        if "godot" not in marker:
            continue
        matches.append(
            {
                "pid": str(pid),
                "comm": comm,
                "executable": executable,
                "cmdline": " ".join(cmdline_parts[:8]),
            }
        )
    return matches


def guard_report(context: str) -> dict[str, Any]:
    matches = active_godot_processes()
    return {
        "schema_id": "rmg_no_godot_process_guard_v1",
        "status": "pass" if not matches else "fail",
        "context": context,
        "active_process_count": len(matches),
        "active_processes": matches,
        "policy": "native_rmg_python_tools_refuse_to_run_while_godot_is_active_on_memory_constrained_hosts",
    }


def print_failure(report: dict[str, Any]) -> None:
    print(
        "RMG_NO_GODOT_GUARD status=fail context=%s active_process_count=%s"
        % (report.get("context", ""), report.get("active_process_count", 0)),
        file=sys.stderr,
    )


def main() -> int:
    context = sys.argv[1] if len(sys.argv) > 1 else "manual"
    report = guard_report(context)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
