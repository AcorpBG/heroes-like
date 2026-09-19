# Overworld Hero and Creature Readability

Owner direction, 2026-09-18: improve/regenerate overworld creature and hero art,
especially the tiny hero visiting a town and encounters lost against some
biomes; scale them coherently and consider an outline. Phase 6 child
`art-overworld-actor-readability-20260918`, derived from `project.md` and `PLAN.md`.
This is an art/runtime presentation slice, not another RMG placement change.

## Requirements

The six-creature [expanded idle batch](creature-idle-expansion.md) supersedes the
two-pose baseline below for Roadwardens, Fenhounds, Lanternmoths, Gallowshells,
Knotstags and Wake Mantas. Each now has eight painted poses in both views; the
other 154 units retain the baseline. The extraction tool supports either count.

### Overworld creature idle playback (2026-09-19)

Owner-selected follow-up `animation-overworld-creature-idle-20260919` now plays
the original painted battle idle pairs on overworld creatures. These are two
distinct anatomical poses per unit, not a sway/scale transform of a still image.
Heroes and authored encounter buildings retain their separate presentation.
Explicit actor identities cover all 51 generated neutral profiles (46 unit
appearances); ordinary unit guards resolve through their existing primary unit.
Generated guards also carry `prefer_identity_landmark`, so the creature identity
must be resolved before that static-landmark branch.

`tools/pack_overworld_creature_idle.py` copies the existing accepted idle pixels
into 160 compact strips, retaining one shared crop and anatomical ground anchor
per clip. Source art, battle clips and provenance are unchanged. The manifest
`art/overworld/creature_idle.json` records exact source indices/crops/hashes.
The strips total 20,809,811 PNG bytes / 59.64 MiB decoded RGBA across the roster,
versus 1,324 MiB for the full battle sheets; textures load per encountered type.

`OverworldCreatureIdle.gd` and its shader use placement-specific stable timing,
the existing creature extent and alpha-edge contrast. The cached scenery painter
preserves ordering; idle playback does not redraw the map or allocate frames.
Reduced Motion/high contrast hold the resting pose. Existing exploration gates
remove hidden actors; no positions, armies, simulation RNG or save fields change.
Restarting the client adopts this presentation on existing maps and saves.

Validation: Windows Godot import and 365 focused runtime/render checks pass,
including real generated guard routing, all 51 profiles, 160 idle registrations,
six visually inspected body types at 74px and larger scale, independent phase,
anchors, unchanged map command generation, fog removal, saved-state equality and
static reduced-motion pixels. All 160 extracted pairs contain distinct frames.
The initial probe failed because its scenario fog was not normalized; the fixture
was corrected. The sandbox emits an unrelated Windows root-certificate warning;
there are no GDScript/shader errors in the completed run. No full suite,
Linux/package run or whole-match playtest was performed for this focused slice.
Temporary images/logs/profiles are removed after inspection; rebuild with:

```text
python -B tools/pack_overworld_creature_idle.py
python -B tests/overworld_creature_idle_regression.py --godot <Godot executable> --output <task-owned directory inside repository>
```

1. Inspect actual hero and encounter art plus its live resolution/draw path,
   including all factions, generated neutral identities and moving AI heroes.
   Record the deficient silhouettes and the exact town-visitor shrink cause.
2. Use built-in image generation for original replacement raster art. Preserve
   faction/creature/character identity and distinct live mappings. Strong painted
   silhouettes, readable light/mid/dark masses, consistent elevated map view,
   real transparency, no portrait card, scenery base, fake placeholder or copied
   game art. Preserve originals and generation prompts/provenance; package only
   the selected runtime derivatives through the established pipeline.
3. Size actors by painted bounds while preserving aspect and ground anchors.
   Town visitors must remain recognizably hero-sized rather than shrink twice;
   entering/leaving town or moving must not cause a scale pop. Do not distort
   buildings, move the logical visitor, or enlarge gameplay footprints/hit rules.
4. Apply a restrained alpha-following contrast treatment where useful for
   player heroes, enemy commanders and neutral monsters. It must work on dark
   mire/lava and light snow/sand without a rectangular halo or giant marker.
   Preserve ownership/selection and reduced-motion behavior; do not leak fog.
5. Inspect actual small/wide gameplay captures, including town arrival and
   hostile silhouettes in contrasting biomes. Correct concrete failures before
   completion; an attractive source painting alone is not runtime acceptance.

## Implementation targets and boundaries

`scenes/overworld/OverworldMapView.gd`, its shared actor presentation helper,
`art/overworld/actor_sprites.json` and existing generated-neutral mappings,
original generated/trimmed/runtime art and provenance, existing preparation
tooling, and Python-owned focused regression. Preserve battle unit/hero portrait
art, IDs, armies, quantities, neutral compositions, entrances/pathing, native
RMG, RNG, fog authority, save schema and unrelated UI/assets. Do not replace
distinct hero/creature identities with shared generic tokens.

## Consolidated validation and completion

- Focused identity/art/alpha/aspect/painted-size checks across live actor routes.
- Real town visitor, movement/arrival, enemy playback, ownership/selection and
  fog fixtures; unchanged logical positions/collision and complete save state.
- Visually inspect 1280x720 and 1920x1080 captures against contrasting biomes;
  identify inspection fixtures separately from normal-fog gameplay.
- Existing hero/encounter/scenery/scale regressions, fresh asset import,
  `python3 -B tests/validate_repo.py`, official Linux and Windows export/package
  smokes and parity. Consolidate after the coherent art/render batch, not after
  each individual generated image.
- Update the source-backed results here and truthful PLAN/progress status,
  commit/push only validated scoped work, then verify remote HEAD and Git status.
- Cleanup exact task-owned disposable files after inspection/reporting; preserve
  source/generated art, prompts/provenance, caches, saves, native RMG recovery
  and the unrelated pre-existing retention-policy/tool/cache files.

## Initial diagnosis

The previous town visitor combined a 0.76 tile-sized draw rectangle with a
0.68 sprite factor (0.5168 of a tile before transparent image padding), versus
0.86 for the field hero. Heroes and most hostile paths sized the source
canvas rather than painted bounds. Generated identity encounters use painted
bounds but did not receive the player hero's silhouette outline. These were
presentation defects; no placement or gameplay change is required.

## Implemented correction

- 112 individually generated, identity-referenced original raster paintings:
  66 hero appearances (60 personal identities plus six faction heroes) and
  46 neutral appearances covering all 51 generated encounter profiles. The
  five shared pairs already represent the same leading unit, not a generic
  replacement. Authored camps, structures and encounter landmarks retain their
  existing appropriate paintings.
- Built-in image generation only. Exact prompts, input references and hashes,
  output hashes and generator provenance are in
  `art/overworld/source/generated/actor_readability_20260918/generation.json`.
  The originals are retained there; corresponding alpha crops are under
  `art/overworld/source/trimmed/actor_readability_20260918/`; aspect-fitted
  384x384 runtime PNGs are under `art/overworld/runtime/actors_20260918/`.
  `tools/prepare_overworld_actor_art.py` reproducibly crops/fits the real art;
  it does not paint or synthesize stand-ins. Original alpha is not applied twice.
- An explicit presentation manifest is loaded after historical object mappings.
  The old `art/overworld/manifest.json`, its identity tables, encounter profiles
  and content IDs are unchanged. A mismatched original path/region or missing
  raster raises an error; focused validation rejects incomplete, aliased or
  incorrectly identified replacement mappings and altered source/derived pixels.
- Player heroes and AI commanders use aspect-preserved painted bounds with a
  one-tile maximum dimension. Town visitors no longer shrink their rectangle or
  sprite; the existing foot anchor and movement interpolation remain unchanged.
  Generated creatures use the existing 1.08-tile encounter extent, now grounded
  by painted feet. Visual overhang is not a larger collision/click footprint.
- `OverworldActorStyle.gd` owns per-view cached alpha masks. A dark outer edge
  and finer pale inner edge separate original silhouettes from both light and
  dark terrain, bounded to 1.15–2 screen pixels. No rectangle/card/background
  is added. Player, enemy commander, neutral, faction and unit-icon routes share
  this treatment; remembered-state tint and movement modulation are preserved.

## Validation commands and scope

The Python-owned `tests/overworld_actor_readability_regression.py` exercises
all live hero and generated-neutral identities, painted aspect/scale/grounding,
mask alpha and cache reuse, six faction town-visitor fixtures, travel interpolation
and unchanged complete save state. Medium seed 4 uses the production generated
map setup and normal fog. Town visitors and the labelled four-biome catalogs are
explicit inspection fixtures, not claimed earned gameplay. The separate Large
scenery/animation regression performs actual player orders and enemy playback.

Reproduce the consolidated acceptance with:

```sh
python3 -B -m unittest discover -s tests -p test_overworld_actor_art.py -v
python3 -B tests/overworld_actor_readability_regression.py --label source --render --resolution 1280x720 --timeout-seconds 300
python3 -B tests/overworld_object_scale_regression.py --label actors-object-scale --timeout-seconds 300
MENU_TURN_GENERATED=1 OVERWORLD_ANIMATION_MAP_SIZE=large python3 -B tests/overworld_living_scenery_regression.py --label actors-large --render --resolution 1280x720 --timeout-seconds 300
python3 -B tests/validate_repo.py
python3 -B tests/packaging_linux_export_smoke.py
python3 -B tests/packaging_windows_export_smoke.py
git diff --check
```

Use fresh task-owned `HEROES_PACKAGING_LINUX_ARTIFACT_DIR`,
`HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR` and
`HEROES_BATTLE_READABILITY_ARTIFACT_DIR` directories. The actor probe also accepts
`--platform linux|windows --binary <export> --pack <pck>`; use `--render` for
Linux and `--render-windows --wine-prefix <new-prefix>` for Windows/Wine. Repeat
at 1920x1080. Package acceptance uses compiled game owners and a SHA-locked test
bootstrap, not loose replacement game scripts. Official smokes additionally
enter a generated map. Windows/Wine is not a claim of physical Windows testing.

Existing Godot reports: `overworld_faction_hero_sprite_runtime_report.tscn`,
`overworld_enemy_commander_sprite_runtime_report.tscn`,
`overworld_small_map_visual_scale_runtime_report.tscn`, and
`OVERWORLD_OBJECT_SCALE_CONTRACT_ONLY=1` with `overworld_visual_smoke.tscn`.
Their hero expectations now match this intentional size change. The commander
fallback fixture previously used Town Assault, which already has an exact
landmark; it now isolates an unmapped faction/unit case and separately verifies
the authored landmark priority. Existing town outline and pickup-order assertions
were aligned with their already-shipped values, without changing those assets.

## Acceptance results (2026-09-18)

- Eight Python art tests pass, including wrong-identity, generic-path and
  missing-roster negative controls, exact source/trim/runtime pixels and alpha.
- Focused rendered source 1280x720: 297,566 assertions; isolated Linux release
  1920x1080: 297,564; Windows/Wine release 1280x720: 297,566. All pass with no
  engine/script errors. Counts include sampled alpha comparisons, not that many
  distinct gameplay scenarios. All 112 sprites, 66 hero/AI identities and 51
  neutral profiles resolve through the actual runtime paths.
- Existing hero, enemy commander, small-map scale and focused visual-scale
  reports pass. Object-scale regression: 6,836 checks pass. Large 108x108 real
  travel, AI move/action playback, fog, skip/reduced motion and save checks:
  492 pass. Its 120 idle scenery updates take 275 microseconds and five state
  rebuilds 81,204 microseconds in this run; this is a bounded render-path check,
  not a whole-game framerate claim.
- Full `tests/validate_repo.py` passes. It explicitly reports 26 absent historical
  disposable smoke outputs; it does not pretend to have rerun those smokes.
- Fresh import and official Linux/Windows exports exercise boot and generated
  map entry. Both final PCKs contain 9,145 members and are 664,106,484 bytes;
  all members match except platform-specific `project.binary`. All 112 actor
  imports and the exact current actor manifest are present. Generated originals
  and trimmed source art are excluded. Current `project.md` does not impose the
  historical 250 MB ceiling.
- Inspected actual 1280x720 and 1920x1080 normal-fog generated-map captures,
  all six faction town visitors, and the full actor catalog against mire, snow,
  lava and sand. Feet stay grounded, proportions remain intact and silhouettes
  separate from the ground; no actor-owned rectangular background or new UI
  clipping was introduced. Windows has an existing missing-font glyph in the
  unrelated army-transfer hint; this slice does not change that text/font.
- Generated terrain SHA-256 stays
  `0b87a3d85a5cb77e7b1fe7117215a28ab4383724178079d3dc259249e5836f4d`
  and collision SHA-256
  `bf80cf2718aa20840b8f486c01ae79e1757b52e696724ec058c727ef9a5ba9e5`
  across source and both packages; complete session dictionaries are unchanged
  by actor rendering. No native code/content/gameplay/save-schema edits.

The first rendered run caught a shared-outline helper assuming an actor-only
payload field on an authored landmark. It now derives edge width from the
actual draw rectangle; the reruns above include the corrected landmark route.
Original art, provenance and reproducible tests are permanent deliverables;
task screenshots, reports, logs and test packages are disposable under the
owner's retention policy, rather than permanent file-existence requirements.

Final cleanup removed 193 task-owned disposable files (3,254,875,662 logical
bytes; 3,255,382,016 allocated bytes recovered): reports, screenshots, logs,
intermediate/final test exports and disposable editor/debug profile files.
Wine system prefixes were also removed by the existing lifecycle helper;
user-data saves, map packages needed by them and caches remain. No active process
held the selected cleanup targets. Original/generated/trimmed/runtime art,
provenance, all native RMG material and the pre-existing unrelated retention
document/tool/cache were untouched. One Windows exporter invocation received
SIGTERM after writing its successful report; a complete repeat exited zero,
and its PCK SHA-256 remained
`5c31c975bf4c446e5115b9423a1096ca9e6fe9c951b71358a61c216a32d7ac56`.
