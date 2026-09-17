# Graphical and Usability Cohesion

Owner-directed Phase 6 parent `ux-graphical-usability-cohesion-20260917`, derived
from `project.md` and the six suggestions explicitly approved by the owner.

## Acceptance and ownership

1. `ux-battlefield-composition-20260917`: reduce visual dominance of normal grid
   and selected hexes; use consistent grounded shadows/foot markers and readable
   unit captions without changing body footprints or poses. The persistent
   battle log collapses into a recent-event strip and expands by keyboard/mouse;
   all retained events survive either view. High contrast stays readable.
   Owners: BattleBoardView, BattleMessageLog, BattleShell.
2. `ux-army-direct-manipulation-20260917`: drag/drop and exact numeric splits are
   alternatives to current click/keyboard operation. Preview the recipient,
   quantity and legal destination before commitment; reject stale/foreign drags
   and invalid partial swaps. Reuse authoritative army operations and do not
   allow remote transfers or recruitment. Owners: ArmyStackBar, shared slot
   control, TownShell/OverworldShell legality-query integration as needed.
3. `ux-overworld-interactable-highlight-20260917`: hold Alt or use an accessible
   toggle to identify visible available, guarded, visited and exhausted sites.
   Keep actual raster objects underneath; use compact labelled UI markers, not
   replacement art. No undiscovered or other-level objects are exposed. Bound
   drawing to the viewport and refresh derived state outside the animation loop.
   Owners: OverworldMapView, OverworldShell and read-only presentation helper.
4. `ux-scouted-prebattle-inspection-20260917`: selection/inspection presents a
   bounded card with disclosed enemy stacks, approximate comparative strength,
   terrain and guarded reward when known. Never expose hidden defenders, native
   internals or promise exact casualties. Inspection must not move/cast/attack;
   commitment keeps the established order path. Owners: OverworldShell and
   a shared read-only inspection model/view.
5. `ux-town-construction-preview-20260917`: hover/focus a construction option to
   preview its exact existing raster/position in the town scene with cost,
   prerequisites and useful effect text. No preview building gains a hotspot or
   enters saved/built state. Clear on close/selection changes; actual construction
   uses the same rectangle with a short reduced-motion-aware transition. Cover
   all factions and upgrades. Owners: TownShell, TownStageView.
6. `ux-interface-style-cohesion-20260917`: shared typography/spacing/control
   states across primary gameplay screens and their new controls. Keep original
   painted buttons/frames; readable disabled and keyboard focus states, bounded
   short labels with full names available on hover/focus. No full-screen text
   dashboards. Owners: FrontierVisualKit and primary UI integration points.

## Validation and boundaries

Implement the full coordinated batch before the consolidated test round.
Python-owned Godot acceptance must exercise actual controls/routes, preview
non-mutation, stale input rejection, fog/level filtering, exact construction
rectangles, log retention and primary screen bounds at 1280x720/1920x1080.
Inspect real screenshots at both sizes. Reuse the existing battle, army, town,
targeting, spellbook and accessibility tests; name baseline exceptions rather
than weakening assertions. Run `python3 -B tests/validate_repo.py`,
`git diff --check`, both official packaging export smokes, focused immutable
Linux/Windows package probes and payload parity checks.

Complete each child only with implemented behavior and passing relevant checks;
complete the parent only after integrated acceptance. Finish cleanup of owned
disposable evidence/exports and temporary profiles, preserve originals/caches/
saves/RMG/unrelated files, commit coherent work, push and verify origin/main.
No new asset generation, combat/economy tuning, movement/scouting changes,
save migration, native RMG changes, broad cleanup or release-readiness claim.

## Implemented behavior

- Battlefield grid/foot markers use restrained alpha and short exact-hex corner
  brackets; high contrast retains full outlines. Captions account for the unit's
  authored size; a long single-word name no longer becomes only an ellipsis.
  The recent-event strip expands without losing history or its reading position.
- Army slot buttons support actual engine drag/drop, All/Half/One/Exact, a
  quantity field, legal-destination borders and a recipient preview. Drag data
  belongs to one bar/revision and cannot outlive a refresh. Existing TownRules /
  HeroCommandRules still perform transfers. Exact controls and history expansion
  update keyboard/controller focus routes.
- Sites/Alt labels canonical resource, artifact, encounter and town records only
  within the existing visibility/level rules. Decorative native map records do
  not become interactions. A small idle-safe observer tracks Alt, focus and
  modal ownership; normal animation processing stays idle. Labels are derived
  on state changes, indexed by tile and drawn only within the camera bounds.
- Inspect opens a painted read-only scout dialog with existing disclosed unit
  icons/counts, qualitative army comparison, actual encounter terrain and known
  reward. A placement's world biome does not override battle terrain. Unscouted
  tiles/guards do not disclose stacks; no town garrisons are invented or exposed.
- Hover/focus previews use the exact existing faction layer, cover-crop and
  upgrade plot. Preview entries are drawing-only, never built state or hotspots.
  View placement folds the ledger onto the opposite edge; confirmation follows
  the same paid construction path. Built art fades in at its final rectangle.
  The ledger is promoted in input order as well as canvas depth, fixing edge
  rails intercepting foreground clicks.
- Shared painted controls retain their art, with readable disabled text, a
  restrained normal focus border, full high-contrast focus, common caption/body
  sizing, word-aware compact labels and full accessible descriptions. The 720p
  sidebar removes duplicated portrait/heading space to keep new controls and
  the command footer on screen.

## Reproduction and evidence

Use fresh labels/output directories. The Python-owned runner isolates user
profiles and applies the same probe through SHA-locked exported releases:

```sh
python3 -B tests/graphical_usability_regression.py --label fresh-small --render --resolution 1280x720 --timeout-seconds 240
python3 -B tests/graphical_usability_regression.py --label fresh-wide --render --resolution 1920x1080 --timeout-seconds 240
python3 -B tests/army_stack_bar_regression.py --label fresh-army --render --timeout-seconds 180
python3 -B tests/battle_message_log_regression.py --label fresh-log --render --timeout-seconds 180
python3 -B tests/spellbook_regression.py --label fresh-book --timeout-seconds 180
python3 -B tests/combat_vfx_regression.py --label fresh-vfx --timeout-seconds 180
python3 -B tests/menu_and_turn_readability_regression.py --label fresh-menu --render --timeout-seconds 240
python3 -B tests/targeting_commit_regression.py --label fresh-targeting --render --timeout-seconds 180
PYTHONPATH=. python3 -B tests/test_town_scene_layers.py
python3 -B tests/validate_repo.py
git diff --check
```

For exports, set `HEROES_PACKAGING_LINUX_ARTIFACT_DIR` and
`HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR` to fresh task-owned directories before
running the official `packaging_*_export_smoke.py` tests, sequentially. Then:

```sh
python3 -B tests/graphical_usability_regression.py --platform linux --binary <linux>/export/heroes-like.x86_64 --pack <linux>/export/heroes-like.pck --label fresh-linux --render --resolution 1920x1080
python3 -B tests/graphical_usability_regression.py --platform windows --binary <windows>/export/heroes-like.exe --pack <windows>/export/heroes-like.pck --wine-prefix <new-prefix> --label fresh-windows --resolution 1280x720
```

The historical army fixture addresses a hidden Logistics tab. The new Python
wrapper opens the current Town Log while preserving all original slot, save,
battle-entry and survivor assertions; the obsolete route is not counted as a
passing live test. Town layer tests require the repository on `PYTHONPATH`.
Windows Wine probes are headless and do not certify Windows GPU presentation.
Full-repository validation explicitly does not count the 26 absent historical
smoke reports as executed tests. Disposable evidence is removed after recording
results under the owner's cleanup policy; original art, caches, saves and RMG
recovery are retained.

## Accepted results — 2026-09-17

- Coordinated source probe: 4,197 checks at 1280x720. Immutable Linux release:
  4,197 at 1920x1080. Windows release under Wine: 4,178 headless checks. Each
  covers 804 exact scenic preview placements across all six factions and all
  32 town templates. Rendered runs exercise real pointer drag, Alt press/release,
  log expansion/Tab focus, scout opening and paid construction confirmation.
- Existing retained battle log: 87; shared spellbook: 4,627; combat effects:
  1,817; targeting/commit: 95; main-menu/turn readability: 61; town-layer Python
  tests: 31. The current
  Town Log army wrapper passes both viewport sizes, slot transfers, split/merge/
  swap rejection, save restoration and battle survivor slot order.
- Full repository validation passes. Its 26 absent historical smoke reports
  remain explicitly unexecuted, not implicitly passed. Six source-string
  expectations now describe the intentional visual constants/signatures; no
  validation domain was removed. `git diff --check` passes.
- Official Linux and Windows exports/startup pass. Windows also completes the
  existing 23-step generated-map/Town construction flow with no fatal runtime
  matches, and both Wine prefixes pass lifecycle cleanup. The focused package
  probes leave each export unchanged and preserve the complete probe source.
- Each PCK is 648,444,232 bytes with 8,911 entries. All 8,910 non-platform
  entries are identical; only `project.binary` differs. All 12 changed/new
  compiled UI owners are present. No asset or native library was changed.
- Actual small/wide battle, scout, overworld and construction screenshots were
  inspected, including all six faction previews, expanded log, exact quantity
  preview and the scenery-first main menu. Controls fit without clipping or
  interception. These are fixture/layout checks, not a claim that all art or
  every gameplay situation is finished; Windows GPU presentation is untested.

Accepted immutable PCK SHA-256 values:

```text
Linux   52205832eee51c72624e540e290d33c1cf157b2fff48e692ac4c073b51f82bbe
Windows 88d79c4aca1fb1a7d1e66234a319a4f20c9e7c7c16969745a20030291167dc88
Probe   c6d20cf49e8c2a4b1dbd290277108c91d3430476364d36d3ac0f700196ab49e4
```

Cleanup removed 3.18 GB of rebuildable task-owned reports, screenshots, logs and
test packages after recording these results and checking there were no open
files. The remaining 3.1 MB of Wine user data/saves is retained under the task's
`preserved-user-data` directory. Managed Wine environments and isolated probe
profiles were already cleaned by their lifecycle helpers; no task profile
remains in `/tmp`. No source, original art/provenance, cache or RMG recovery
material was removed. The three pre-existing unrelated untracked paths remain
untouched and are excluded from this change.
