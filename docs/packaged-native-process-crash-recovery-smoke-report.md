# Packaged Native Process Crash Recovery Smoke Report

Slice: `packaging-native-process-crash-recovery-10184`

## Implemented Behavior

- Desktop builds keep five rotated Godot engine logs under `user://logs`.
- `RuntimeIssueLog` atomically writes a process-owned marker at startup and removes it only during normal autoload shutdown.
- If the marker survives, the next launch consumes it once and records `previous_session_unclean_exit` with a bounded tail from the newest previous rotated log.
- Existing support-bundle path and key redaction apply to every recovered line. The bundle remains local-only and excludes saves, campaign progression, credentials, and telemetry.

## Runtime Proof

`tests/packaged_native_process_crash_recovery_smoke.py` exports a Linux release PCK into isolated user data, launches `OS.crash()` from the packaged crash fixture, then launches the packaged recovery scene. The second process must recover exactly one issue containing the fixture marker, export it through the existing support bundle, and remove its own marker on clean exit.

```bash
python3 tests/packaged_native_process_crash_recovery_smoke.py
```

The same project settings and autoload code ship in Linux and Windows exports. This slice does not claim minidumps, symbolication, remote submission, native Windows hardware certification, signing, or overall release readiness.
