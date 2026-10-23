# Save Test Retirement

Owner decision D-e, 2026-10-23 (`docs/native-rules-engine-transition.md`, Phase 7): the tests that call the private save functions that slice 7.12 deletes, or that rewrite `SaveService.gd`'s source, are retired by the `docs/rmg-test-retirement.md` process. They were retired on 2026-10-23 with 7.12 (`native-rules-phase7-12-saves-20261023`).

## Why

Saves run native. Slice 7.12 moved every `SaveService` function (the save format, slot summaries and their cache, the transactional write and its recovery, the restore, the save screens' texts), `SessionStateStore.normalize_payload` with its helpers and `HeroCommandRules.restore_empty_hero_armies` to C++ (`src/gdextension/rules/core/port/save_service_*.cpp`, `save_session_payload.cpp`, the human table in `human_registry.cpp`). The 64 `SaveService` functions that the game, the tools and the tests still call are thin wrappers over their port, and so is `SessionStateStore.normalize_payload`. The other GDScript bodies are gone, among them three legacy functions only a test called (`validation_build_in_session_save_surface_direct_legacy`, `_build_in_session_save_surface_direct_legacy`, `_describe_summary_resume_recap_direct_legacy`).

Saves are covered by:
- the core suite: `save_summary_deferred_payload_report` (summaries and payloads), `random_map_final_writeout_export_save_schema_report` (a new game's package save and restore), `map_package_api_skeleton_report` and `settings_transactional_persistence_regression`;
- the 7.12 check: the five D9 save copies give the same summaries, sessions, screen texts and written files on main and on the branch, and the files each side writes load to the same session on the other; the payload saves, slot actions, recovery, failed writes, the progression file and six changed copies give the same answers (transition doc, Phase 7, "Slice 7.12").

Git history keeps the retired tests.

## Retired (3 tests)

A deleted private function: `generated_large_town_explicit_save_surface_regression` (the two legacy surface builders and `_manual_summary_for_session`) and `overworld_hero_actions_refresh_cache_regression` (`_live_session_summary_from_payload`, `_live_summary_for_manual_slot`, `_resume_target_for_session`, `_summary_watch_state_line`, `_first_meaningful_line`, `_line_with_prefix`).

`SaveService.gd`'s source rewritten into a counting copy: `save_stored_recap_regression.py`, which compared stored recaps against a GDScript `SaveService` from an old commit.

`tests/full_play_validation_suite.py` no longer lists `generated_large_town_explicit_save_surface_regression`, and its adapter for that test is gone.

## Kept

- `ai_hero_task_state_normalizer_preservation_report` still reads `SaveService.gd` to check that the save layer holds no AI task rules; the wrappers hold none.
- The tests that hash `SaveService.gd` or its compiled `.gdc` as an owner of a profile (`generated_end_turn_profile.py`, the packaged cutout regressions) hash the wrapper file.
