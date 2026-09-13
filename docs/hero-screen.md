# Owned Hero Screen

Owner-directed Phase 6 slice: `ui-owned-hero-screen-20260913`. Completed 2026-09-13.

## Requirements

- Double-click an owned hero in the Overworld roster to open that exact hero's sheet. Single-click continues selecting/centering. Provide a keyboard/controller inspection route, Escape/Back, and focus restoration.
- Show original hero portrait, identity, level/experience, command stats, movement/mana, seven army slots with unit details, equipped and carried artifacts with effects, and learned specializations with ranks and pending progression information.
- Use existing authoritative hero/army/artifact/progression rules and original registry-backed art. Inspection must not mutate state, consume movement, change equipment, choose upgrades, or alter saves. Inspecting an inactive hero must not show the active hero's army or artifacts.
- Keep information readable at 1280x720 and 1920x1080. Use a portrait-led modal sheet with compact stats/army and tabbed detail space, not more permanent Overworld panels. Block underlying map commands while open and reject stale/non-owned targets or input during committed turns.

## Scope and validation

Targets: `scenes/overworld/OverworldShell.gd`, reusable `scenes/shared/HeroSheet.gd`, read-only `HeroCommandRules.hero_inspection_snapshot`, focused Python-owned input/state/layout regressions and the shared packaged-probe owner's hash selector, and this document/PLAN/tracker.

Run focused source and Linux/Windows packaged tests, Town double-click non-regression, `python3 tests/validate_repo.py`, both official export smokes and `git diff --check`. Inspect actual small/wide screenshots. Retain final evidence, clean task-owned temporary files, preserve caches and unrelated untracked files, then commit/push and verify origin/main.

Non-goals: new gameplay, equipment/army transfer UI, balance, art generation, native RMG, town interiors, save schema or unrelated cleanup. Existing management/progression actions remain authoritative and available outside this read-only sheet.

## Evidence

Implemented a modal portrait-led sheet with three scrollable tabs. Roster Enter/controller Confirm and mouse double-click inspect; mouse single-click still selects/centers. The sheet traps focus, restores the originating card, and blocks underlying Overworld commands. Content is copied before normalization; active mirrors are read without committing them. Attack/defense include equipped artifact and specialization bonuses, power/knowledge are command values, unit stats are explicitly labeled base values, and unlearned development focus is distinguished from learned ranks. Existing army/equipment/progression management stays in its current authoritative flows.

Initial visual testing caught and corrected deferred wrapped-label minimum sizing when reopening other heroes. Actual viewport dimensions are asserted, not inferred from command-line flags.

Evidence root: `.artifacts/hero-sheet-20260913/`.

| Check | Result / evidence |
| --- | --- |
| Source, 1280x720 | 528 checks passed; `source-acceptance-small/report.json` and inspected captures |
| Linux release, 1920x1080 | 528 checks passed; `linux-packaged/report.json`, immutable-export/compiled-owner proof and inspected captures |
| Windows release, 1280x720 | 528 checks passed; `windows-packaged/report.json`, same SHA-locked probe and compiled-owner proof |
| Town roster entry | 18 checks passed; `.artifacts/town_roster_double_click_20260911/hero-sheet-nonregression/report.json` |
| Official Linux/Windows export smokes | Both passed; `linux/report.json`, `windows/report.json`, including Windows generated-map/Town/build flow |
| Package parity | Passed; `package-parity.json`. 516,833,864-byte packs, 8,519 members each; only `project.binary` differs |
| Modal validator | Settings and hero guards must consume/return before ordinary commands; focused check passed and removing either consume call is rejected |
| Full repository | Passed; `repository-validation-final.log`. Initial run found only a Settings-guard line-order assertion, corrected without weakening either guard |

The probe checks actual pointer single/double clicks, invalid clicks, ownership/stale IDs, committed-turn rejection, keyboard/controller Confirm, Escape/focus restoration and focus containment. It compares complete session dictionaries across inspection, verifies current active mirrors, distinct inactive-hero state, empty armies and the seven-slot layout, unit details, equipped/carried artifacts and positive equipment/specialization stat bonuses. All 66 authored hero identities resolve portraits and independent snapshots; six faction presentations were rendered and visually inspected. Army/equipment details scroll inside their tab, not over the map.

Reproduction:

```sh
python3 -B tests/hero_sheet_regression.py --label review-source --render --resolution 1280x720
python3 -B tests/hero_sheet_regression.py --platform linux --binary .artifacts/hero-sheet-20260913/linux/export/heroes-like.x86_64 --pack .artifacts/hero-sheet-20260913/linux/export/heroes-like.pck --label review-linux --render --resolution 1920x1080
python3 -B tests/hero_sheet_regression.py --platform windows --binary .artifacts/hero-sheet-20260913/windows/export/heroes-like.exe --pack .artifacts/hero-sheet-20260913/windows/export/heroes-like.pck --wine-prefix /root/dev/heroes-like/.artifacts/hero-sheet-20260913/review-wine-prefix --label review-windows
python3 tests/validate_repo.py
git diff --check
```

Use fresh labels/prefixes. Windows evidence is headless Wine execution, not physical Windows GPU certification. This is an inspection screen, not a new equipment editor or progression system, and does not claim whole-game release readiness.

Cleanup removed seven superseded task-owned capture directories (20,892,794 apparent bytes), after checking for open files/processes. Final evidence/packages, original art, caches and unrelated untracked files remain. Disposable probe directories/profiles and Wine system prefixes are automatically cleaned by the established runners; retained Wine user data and cleanup receipts are preserved.
