# Visual, Performance, And File Saves Review

Owner direction: inspect previous work, improve actual visual quality and performance, and replace fixed save slots with file-based saves. Phase 6 child: `ux-visual-performance-file-saves-review-20260904`; strategy: `project.md`.

## Required behavior

Visual evidence must come from current live imports, not only source PNGs or renderer dimensions. Compare the loaded Riverwatch raster to the canonical runtime PNG and inspect normal fog-enabled gameplay at 1920x1080 and 1280x720. Preserve original manifest-backed art, aspect, controls, ownership, click/pathing geometry, and existing progression.

Profile the established `large-runtime-profile-10225` Large-map case with isolated saves before and after. Optimize measured redundant runtime/storage work while retaining signature `7362cf00`, authoritative object/state data, transaction verification and recoverability. Do not tune generation rules or hide work from wall-clock measurements.

Manual saving must allow any number of named files in the game save directory, with creation, explicit overwrite confirmation, clear errors, browsing, loading and deletion. File identity must be validated for both Windows and Linux, reject traversal/reserved names, preserve existing three-slot files and autosave, and keep version-9 payloads loadable. Cancelling dialogs and failed writes must leave live session and prior saves intact. No migration that destroys existing saves.

## Validation

Use focused Python-owned runners, existing Godot runtime owners where necessary, live screenshots inspected by the agent, save compatibility/recovery tests, deterministic Large-map profiling and round-trip checks, `python3 tests/validate_repo.py`, `git diff --check`, and `python3 tests/packaging_linux_export_smoke.py` / `python3 tests/packaging_windows_export_smoke.py`. Both packages must stay below 250000000 bytes. Completion requires all three implementation areas, not just reports or this document.

Out of scope: Native RMG semantics, gameplay/balance, unrelated art families/cleanup, package ceiling changes, release certification or publication.
