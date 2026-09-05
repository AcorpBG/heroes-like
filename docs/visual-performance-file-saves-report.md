# Visual, Performance, And File Saves Review

Slice: `ux-visual-performance-file-saves-review-20260904` — Phase 6. Owner scope: actual visual improvement, measured runtime improvement, and file-based saving. Status: completed 2026-09-05; this is not release certification.

## Implementation

The Riverwatch identity test previously accepted a guessed broad aspect range, not the intended image. It now compares the manifest-resolved live texture against the canonical runtime PNG after the importer's alpha-edge processing. Current painted aspect is 1.012605; drawing preserves it inside the unchanged 2.90x3.72 visual envelope and 3x2 logical footprint. The town's dark multi-pixel cutout outline is now a subtle subpixel edge, and the tall command rail uses subdued original wood art instead of stretching a square ornamental frame behind labels. No art was generated or replaced in this review.

Manual saving now creates named `.save.json` files under the existing `user://saves/` directory. Overworld, Town, Battle, and Results open the shared file browser, then route the chosen filename through their existing commit, checkpoint, feedback and recovery paths. The main menu lists actual files, including occupied legacy slots; empty fixed slots are not presented as a limit. Autosave and campaign progression remain separate. Save version 9 and payload semantics are unchanged.

Names reject traversal, control characters and Windows-reserved forms; Linux applies the same case-insensitive identity policy. Occupied files require explicit confirmation tied to their current SHA-256. Same-size external edits invalidate named-file summary caches. Unlimited named-file libraries cache compact summaries rather than one entire world per file. Named files participate in the existing candidate/backup transaction recovery. No implicit migration deletes old saves. Physical Enter requests replacement confirmation without activating Cancel on its release; Escape/controller Back cancels without changing the session, scene, or file.

Save preparation now transfers already detached normalized autosave branches instead of copying them again, skips nested JSON key sorting, and validates committed bytes against the already parsed candidate without parsing the entire map twice. A byte-hash receipt skips redundant semantic recovery of an unchanged, successfully written file; any external edit or transaction sidecar forces ordinary recovery. Candidate validation, exact committed readback, rollback and restore normalization remain.

## Evidence and validation

Evidence directory: `.artifacts/visual_performance_file_saves_review/`.

- `named_save_files_report.json`: PASS — nine independent named files after create/delete/UI cases, Unicode names, invalid names, case-insensitive collision handling, explicit/stale overwrite consent, failed writes, recovery, external changes, compact summary caches, legacy saves, deletion, all four shipping Save buttons, physical Enter/Escape/controller Back, main-menu browsing and actual scene routing.
- `save_files_1920x1080.png` and `save_files_1280x720.png`: live save-dialog captures.
- `.artifacts/overworld_town_proportion_environs_10236/report.json` and its dual-resolution captures: loaded-pixel equality, aspect/grounding, exact blocker bodies and unchanged session authority. These replace the older guessed-aspect evidence.
- `large_baseline.log`: isolated deterministic 108x108 case, seed `large-runtime-profile-10225`, scenario `native_h3maped_c2520619_skirmish`, signature `7362cf00`. Baseline save 4178.184 ms; end-turn wall time 10448.619 ms.
- `large_final.log`: PASS — identical scenario/signature and 2961 exact source object records after named-file restore. Snapshot/autosave write 2036.600 ms versus 4178.184 ms before (51% lower in this matched run); the new named-file write separately measured 2132.960 ms. End turn 8589.058 ms versus 10448.619 ms before. Cold/warm target selection 447/198 ms, hover 96 ms, adjacent movement 376 ms and Town entry/exit 1831 ms were effectively unchanged. These are wall-clock measurements from one isolated before/after workload, not a claim that every machine or map is now fast.
- `transaction.log`, `legacy_delete.log`, `large_manual_regression.log`: PASS — interrupted writes/backup recovery, deletion authority and physical Large Town legacy compatibility, including failure rollback and warm-summary work budgets. The timing regression was rerun alone after a concurrent graphics test pushed one refresh over its unchanged 1000 ms budget.
- `faction_towns.log`, `generated_town_scale.log`, `landmarks.log`: PASS — 26 authored town identities; deterministic 108x108 generated-map scale, containment and exact click/pathing authority at both resolutions; landmark readability.
- Refreshed serial Linux and Windows package checks: PASS, both PCKs 248369356 bytes (1630644 bytes below the unchanged ceiling). Linux ELF/startup and Windows PE/DLL/startup under fresh Wine prefixes pass. Both actual packaged executables also complete generated setup → Overworld → player Town (`linux-generated-flow/live_validation_report.json` and `.artifacts/packaging_windows_export_smoke/generated-flow/live_validation_report.json`). This does not certify native Windows hardware, graphics/audio, signing, or installers.
- `legacy_overwrite.log`: PASS — all four routes, occupied/corrupt/empty legacy files, exclusive parent mouse blocking, physical cancel/confirm, exact file/session/routing preservation and neighboring modal ownership.
- `repo_final.log`: `VALIDATION PASSED`; `git diff --check`: clean. Live screenshots at both resolutions were opened and visually inspected; town proportions, softened edges, command rail and save-dialog controls remain readable and within the viewport.

The Large Town legacy slot regression uses an explicitly exposed compatibility fixture for its old physical controls; the named-file regression presses unmodified shipping Save buttons. Narrow Town cancel coverage uses the current construction ledger rather than the retired collapsible orders sidebar. The Overworld neighboring-owner case now cancels the actual file browser above the Command drawer, rather than trying to focus a deliberately hidden legacy picker, and waits for the drawer's deferred responsive layout before taking its baseline. Authority comparisons exclude animated draw counters, audio crossfade interpolation and Results ambient-particle drift but retain exact session, camera/route geometry, audio layer/signature/record authority, files and routing. A first concurrent export attempt collided on Godot's shared `/tmp/tmpproject.binary`; final platform evidence uses serial exports. These are validation-method corrections, not gameplay changes.

Reproduction commands (runtime tests should use isolated `XDG_DATA_HOME`):

```sh
python3 tests/named_save_files_regression.py
python3 tests/overworld_town_proportion_environs_report.py
godot4 --headless --path . --audio-driver Dummy res://tests/large_generated_map_runtime_profile_report.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/generated_large_town_explicit_save_surface_regression.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/save_transactional_commit_regression.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/save_slot_delete_regression.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/manual_save_overwrite_regression.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/overworld_faction_town_sprite_runtime_report.tscn
godot4 --headless --path . --audio-driver Dummy res://tests/overworld_generated_large_town_scale_runtime_report.tscn
python3 tests/validate_repo.py
git diff --check
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
```

Known separate issues: the pre-existing renderer texture-RID shutdown warning and the broad visual smoke's ordinary field-hero command-marker assertion are not claimed fixed. Large-map generation and AI planning still require further performance work; this review must not imply the whole game is release-ready.
