#!/usr/bin/env python3
"""The slice tracker (ops/progress.json), PLAN.md's slice lines and the project files' size budgets.

Every agent uses it: Claude, Codex, pi and Proca. The rules are in AGENTS.md, "Project files".

    python tools/progress.py status                 # current slice, counts, open slices, file sizes
    python tools/progress.py next                   # open slices, the active ones first
    python tools/progress.py add ID "Title" --goal "goal, files, owner decision" [--docs docs/a.md ...]
    python tools/progress.py set-status ID in_progress|blocked|paused|pending [--goal "..."]
    python tools/progress.py set-status ID completed --summary "what changed" [--commit SHA]
    python tools/progress.py archive [--days 30] [--dry-run]
    python tools/progress.py check                  # budgets and entry lengths; tools/core_suite.py runs it

`add` and `set-status` edit both files: the slice's entry in ops/progress.json and its line under
"## Open work" in PLAN.md. A completed slice leaves "## Open work" and gets one line at the top of
"## Recently completed". `archive` moves completed entries older than --days to the month's file in
ops/progress-archive/ and docs/plan-history/. Ported from Proca's heroes-progress skill, 2026-10-27.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUDGETS = {"AGENTS.md": 14 * 1024, "PLAN.md": 60 * 1024, "ops/progress.json": 300 * 1024}
GOAL_MAX = 600
SUMMARY_MAX = 300
OPEN_STATUSES = ("in_progress", "blocked", "pending", "paused")
DONE_STATUSES = ("completed", "superseded")
PLAN_OPEN = "## Open work"
PLAN_DONE = "## Recently completed"
PROGRESS_ARCHIVE = Path("ops/progress-archive")
PLAN_ARCHIVE = Path("docs/plan-history")


def today() -> str:
    return date.today().isoformat()


def stamp() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load(root: Path) -> dict:
    return json.loads((root / "ops" / "progress.json").read_text(encoding="utf-8"))


def save(root: Path, data: dict) -> None:
    text = json.dumps(data, indent=1, ensure_ascii=False) + "\n"
    (root / "ops" / "progress.json").write_text(text, encoding="utf-8", newline="\n")


def slices(data: dict) -> list[dict]:
    return [s for s in data.get("plannedSlices", []) if isinstance(s, dict)]


def find(data: dict, sid: str) -> dict | None:
    return next((s for s in slices(data) if s.get("id") == sid), None)


def read_plan(root: Path) -> list[str]:
    return (root / "PLAN.md").read_text(encoding="utf-8").split("\n")


def write_plan(root: Path, lines: list[str]) -> None:
    (root / "PLAN.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")


def section(lines: list[str], heading: str) -> tuple[int, int]:
    """Index of the heading line and of the line where its section ends."""
    start = lines.index(heading)
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start, end


def plan_line_index(lines: list[str], sid: str) -> int | None:
    start, end = section(lines, PLAN_OPEN)
    prefix = f"- `{sid}` ("
    return next((i for i in range(start, end) if lines[i].startswith(prefix)), None)


def open_line(item: dict) -> str:
    docs = item.get("docs") or []
    tail = f" See {', '.join(f'`{d}`' for d in docs)}." if docs else ""
    return f"- `{item['id']}` ({item['status'].replace('_', ' ')}): {item['goal']}{tail}"


def done_line(item: dict) -> str:
    commit = f" ({item['commit']})" if item.get("commit") else ""
    return f"- {item['completedAt']} `{item['id']}`{commit}: {item['summary']}"


def set_current(data: dict, item: dict) -> None:
    data["currentSliceId"] = item["id"]
    data["currentSliceTitle"] = item.get("title", item.get("summary", ""))
    data["currentSliceStatus"] = item["status"]
    data["updatedAt"] = stamp()


def cmd_status(root: Path) -> int:
    data = load(root)
    print(f"project: {data.get('project')}  phase: {data.get('currentPhase')}")
    print(f"current slice: {data.get('currentSliceId')} [{data.get('currentSliceStatus')}]")
    counts = Counter(s.get("status") for s in slices(data))
    print("slices in the tracker: " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    print_open(data)
    print("\nfile sizes:")
    for rel, limit in BUDGETS.items():
        size = (root / rel).stat().st_size
        print(f"  {rel}: {size / 1024:.1f} KB of {limit // 1024} KB")
    return 0


def print_open(data: dict) -> None:
    rank = {s: i for i, s in enumerate(OPEN_STATUSES)}
    items = sorted((s for s in slices(data) if s.get("status") in rank), key=lambda s: (rank[s["status"]], s["id"]))
    print("\nopen slices:")
    for s in items:
        print(f"- {s['id']} [{s['status']}] {s.get('title', '')}")
        print(f"  {s.get('goal', '')}")
    if not items:
        print("(none)")


def cmd_add(root: Path, sid: str, title: str, goal: str, docs: list[str], status: str) -> int:
    data = load(root)
    if find(data, sid):
        sys.exit(f"slice {sid} exists already")
    if len(goal) > GOAL_MAX:
        sys.exit(f"goal is {len(goal)} characters; at most {GOAL_MAX}")
    item = {"id": sid, "title": title, "status": status, "goal": goal, "docs": docs, "updatedAt": today()}
    data.setdefault("plannedSlices", []).insert(0, item)
    set_current(data, item)
    lines = read_plan(root)
    start, _ = section(lines, PLAN_OPEN)
    lines.insert(start + 2, open_line(item))
    save(root, data)
    write_plan(root, lines)
    print(f"added {sid} [{status}] to ops/progress.json and PLAN.md")
    return 0


def cmd_set_status(root: Path, sid: str, status: str, goal: str | None, summary: str | None, commit: str | None) -> int:
    data = load(root)
    item = find(data, sid)
    if item is None:
        sys.exit(f"slice id not found: {sid}")
    lines = read_plan(root)
    at = plan_line_index(lines, sid)
    if status in DONE_STATUSES:
        if not summary:
            sys.exit("a completed or superseded slice needs --summary (what changed, at most 300 characters)")
        done = {"id": sid, "status": status, "completedAt": today(), "summary": summary}
        if commit:
            done["commit"] = commit
        if len(done_line(done)) > SUMMARY_MAX:
            sys.exit(f"the PLAN.md line would be {len(done_line(done))} characters; at most {SUMMARY_MAX}")
        item.clear()
        item.update(done)
        if at is not None:
            del lines[at]
        start, _ = section(lines, PLAN_DONE)
        lines.insert(start + 2, done_line(done))
    else:
        item["status"] = status
        item["updatedAt"] = today()
        if goal:
            if len(goal) > GOAL_MAX:
                sys.exit(f"goal is {len(goal)} characters; at most {GOAL_MAX}")
            item["goal"] = goal
        if at is None:
            start, _ = section(lines, PLAN_OPEN)
            lines.insert(start + 2, open_line(item))
        else:
            lines[at] = open_line(item)
    set_current(data, item)
    save(root, data)
    write_plan(root, lines)
    print(f"{sid} -> {status} in ops/progress.json and PLAN.md")
    return 0


def cmd_archive(root: Path, days: int, dry_run: bool) -> int:
    cutoff = (date.today() - timedelta(days=days)).isoformat()
    data = load(root)
    keep, move = [], {}
    for s in slices(data):
        if s.get("status") in DONE_STATUSES and str(s.get("completedAt", "9999")) < cutoff:
            move.setdefault(str(s["completedAt"])[:7], []).append(s)
        else:
            keep.append(s)
    lines = read_plan(root)
    start, end = section(lines, PLAN_DONE)
    plan_move: dict[str, list[str]] = {}
    kept_lines = []
    for line in lines[start + 1:end]:
        m = re.match(r"- (\d{4}-\d{2}-\d{2}) ", line)
        if m and m.group(1) < cutoff:
            plan_move.setdefault(m.group(1)[:7], []).append(line)
        else:
            kept_lines.append(line)
    moved = sum(len(v) for v in move.values())
    moved_lines = sum(len(v) for v in plan_move.values())
    print(f"older than {cutoff}: {moved} tracker entries, {moved_lines} PLAN.md lines")
    if dry_run or not (moved or moved_lines):
        return 0
    for month, items in move.items():
        path = root / PROGRESS_ARCHIVE / f"{month}.json"
        old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"plannedSlices": []}
        old["plannedSlices"] = items + old["plannedSlices"]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(old, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    for month, month_lines in plan_move.items():
        path = root / PLAN_ARCHIVE / f"{month}.md"
        text = path.read_text(encoding="utf-8").rstrip("\n") + "\n" if path.exists() else f"# Completed slices, {month}\n\n"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text + "\n".join(month_lines) + "\n", encoding="utf-8", newline="\n")
    data["plannedSlices"] = keep
    data["updatedAt"] = stamp()
    save(root, data)
    write_plan(root, lines[:start + 1] + kept_lines + lines[end:])
    print("archived")
    return 0


def problems(root: Path) -> list[str]:
    out = []
    for rel, limit in BUDGETS.items():
        size = (root / rel).stat().st_size
        if size > limit:
            fix = "shorten it" if rel == "AGENTS.md" else "run `python tools/progress.py archive` or shorten it"
            out.append(f"{rel} is {size / 1024:.1f} KB, over its {limit // 1024} KB budget: {fix}")
    data = load(root)
    seen = set()
    for s in slices(data):
        sid = s.get("id", "?")
        if sid in seen:
            out.append(f"progress.json: duplicate slice id {sid}")
        seen.add(sid)
        status = s.get("status")
        if status in OPEN_STATUSES:
            if len(s.get("goal", "")) > GOAL_MAX:
                out.append(f"progress.json: {sid} goal is over {GOAL_MAX} characters")
        elif status in DONE_STATUSES:
            if len(s.get("summary", "")) > SUMMARY_MAX:
                out.append(f"progress.json: {sid} summary is over {SUMMARY_MAX} characters")
        else:
            out.append(f"progress.json: {sid} has status {status!r}")
    lines = read_plan(root)
    for heading, limit in ((PLAN_OPEN, GOAL_MAX + 120), (PLAN_DONE, SUMMARY_MAX)):
        if heading not in lines:
            out.append(f"PLAN.md has no '{heading}' section")
            continue
        start, end = section(lines, heading)
        for line in lines[start + 1:end]:
            if len(line) > limit:
                out.append(f"PLAN.md '{heading}': line over {limit} characters: {line[:70]}...")
    return out


def cmd_check(root: Path) -> int:
    found = problems(root)
    for p in found:
        print(p)
    if not found:
        print("project files within budget")
    return 1 if found else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(ROOT), help="checkout to work on (default: this one)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sub.add_parser("next")
    sub.add_parser("check")
    sp = sub.add_parser("add")
    sp.add_argument("slice_id")
    sp.add_argument("title")
    sp.add_argument("--goal", required=True)
    sp.add_argument("--docs", nargs="*", default=[])
    sp.add_argument("--status", default="pending", choices=OPEN_STATUSES)
    sp = sub.add_parser("set-status")
    sp.add_argument("slice_id")
    sp.add_argument("status", choices=OPEN_STATUSES + DONE_STATUSES)
    sp.add_argument("--goal")
    sp.add_argument("--summary")
    sp.add_argument("--commit")
    sp = sub.add_parser("archive")
    sp.add_argument("--days", type=int, default=30)
    sp.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    root = Path(args.root)
    if args.cmd == "status":
        return cmd_status(root)
    if args.cmd == "next":
        print_open(load(root))
        return 0
    if args.cmd == "check":
        return cmd_check(root)
    if args.cmd == "add":
        return cmd_add(root, args.slice_id, args.title, args.goal, args.docs, args.status)
    if args.cmd == "set-status":
        return cmd_set_status(root, args.slice_id, args.status, args.goal, args.summary, args.commit)
    return cmd_archive(root, args.days, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
