# Packaged Runtime Issue Log Smoke Report

Slice: `packaged-runtime-issue-log-smoke-20260523-10184`

## Scope

This slice adds a package-safe runtime issue reporting baseline. It registers `RuntimeIssueLog` as an autoload, writes sanitized issue records to `user://debug/heroes_runtime_issues.jsonl`, writes the latest issue snapshot to `user://debug/heroes_last_runtime_issue.json`, and proves the service works from a focused scene launched out of an exported PCK.

This specific v1 smoke does not claim native process crash capture, remote telemetry upload, binary export readiness, clean-machine smoke coverage, or release readiness. Native-process abnormal-exit recovery is proved separately by `tests/packaged_native_process_crash_recovery_smoke.py` and `docs/packaged-native-process-crash-recovery-smoke-report.md`.

## Implemented Gate

- Added `scripts/autoload/RuntimeIssueLog.gd`.
- Registered `RuntimeIssueLog` in `project.godot`.
- Runtime issue records include schema, timestamp, severity, surface, event, bounded message, sanitized metadata, session metadata, app metadata, and platform metadata.
- Added `tests/packaged_runtime_issue_log_report.tscn` and `tests/packaged_runtime_issue_log_report.gd`.
- Added `tests/packaged_runtime_issue_log_smoke.py` to export `.artifacts/packaged_runtime_issue_log_smoke/heroes-like.pck`.
- The smoke launches:

```bash
godot --headless --main-pack .artifacts/packaged_runtime_issue_log_smoke/heroes-like.pck --scene res://tests/packaged_runtime_issue_log_report.tscn --quit-after 120 -- --report-json=.artifacts/packaged_runtime_issue_log_smoke/scene_report.json
```

- The packaged scene clears the issue log, emits one `error` issue, verifies JSONL and latest-snapshot files exist, reads the last record back, and checks sanitized metadata.

## Validation Command

```bash
python3 tests/packaged_runtime_issue_log_smoke.py
```

Future release packaging still needs native minidump/symbol policy, clean-machine validation, native Windows hardware certification, signing, release-channel integration, and final support workflow decisions.
