# Coherent Overworld Object Scale

Owner-directed Phase 6 slice: `art-overworld-object-scale-coherence-20260917`.
Strategic source: `project.md`; tactical source: `PLAN.md`.

## Requirements

Inspect the full authored object categories and their live generated-package
render paths, including resource pickups, artifacts, structures, encounters,
decorative bodies and the hero/town size references. The owner identified the
treasure chests and purple bottle-shaped pickups in the Medium-map capture as
oversized. Identify those exact resource/asset/profile paths before changing them.

Use a deliberate readable world-scale hierarchy: handheld items and loose
supplies smaller than people and durable structures, without turning pickups
into invisible specks. Physical-looking objects sharing a scale class must not
inflate because their package collision footprint or transparent canvas differs.
Keep original aspect ratio and grounded placement; inspect contact shadows and
outlines at the corrected size. Use original generated art only when the source
cannot be made coherent through presentation sizing. Preserve source/provenance.

No changes to content IDs, quantities, placement, pathing/body masks, action
coordinates, click/keyboard targets, fog, gameplay, native generation, RNG or
save authority. No arbitrary per-map coordinate overrides, procedural replacement
art, unrelated town/combat/UI/terrain changes or release-readiness claim.

## Implementation and acceptance

- Trace and review all active map-object art/profile classes and representative
  authored/generated contexts; record concrete outliers and retained categories.
- Add a Python-owned runtime regression for semantic size bounds, asset coverage,
  package-footprint independence of small items, grounding/aspect, selection and
  unchanged session state. Capture real generated gameplay and a labeled gallery
  at 1280x720 and 1920x1080; inspect images, not only assertions.
- Run relevant existing sprite, scenery and interaction tests; run
  `python3 -B tests/validate_repo.py` and `git diff --check`.
- Run `tests/packaging_linux_export_smoke.py` and
  `tests/packaging_windows_export_smoke.py`, focused packaged gameplay on both,
  and verify payload parity. Report actual sizes; no arbitrary package ceiling.
- Record results here, then remove task-owned disposable captures/logs/packages
  per AGENTS.md while preserving caches/saves, original art/provenance and RMG.

## Findings and results

The deterministic Medium screenshot traces to `kind=reward_reference` records:
`site_reef_coin_assay` → `resource_pickup_gold` and `site_memory_salt_pan` →
`resource_pickup_memory_salt`. The art resolver already selected the correct
original coffer/reliquary, but the scale resolver borrowed the mine/production
site's 2x2/3x3 profile, producing 1.22/1.35-tile portable items. The renderer now
carries the placement kind in a detached presentation profile, sizes portable
items from one world tile, and excludes them from building-sized minimums.
Loose supplies use 0.56 tiles and handheld artifacts 0.42; larger world objects,
heroes, towns and authoritative footprints are unchanged. Contact shading follows
the reduced painted base and portable outlines are thinner.

The full 2,167-entry raster inventory also exposed 35 blurry states in four
remaining 48px atlases (opened minor caches, active land transit, opened route
controls, and sovereign habitats). Their existing original paintings and repaired
high-resolution alpha masters are repacked into 192px cells. No new painting or
generated replacement is needed. `object_raster_density.json` is an explicit
presentation-only density layer keyed by the same asset IDs and bound to the
original path/region. Historical atlases, state mappings and repair proofs remain
intact; the new recipe/proof records original source hashes and reproducible
derived PNGs. It does not silently replace source identity/provenance metadata.

## Validation results (2026-09-17)

The catalog covers 2,167 raster identities, including 422 authored map objects,
377 resource-site definitions and both collectible states, 69 field artifacts,
encounter/hero/town references and the decorative/blocker library. All 23 catalog
pages were inspected; oversized gallery subjects are explicitly fitted thumbnails,
not evidence of their world size. The separate 35-state density gallery was
inspected after repacking: sharper detail, preserved aspect/alpha, no new matte
boxes or procedural replacements. The real Medium map was inspected at 1280x720
and 1920x1080, including normal fog and a clearly diagnostic revealed viewpoint.
Pickups remain recognizable, grounded and subordinate to actors/structures.

The exact Medium seed is `medium-random-screenshot-10230`, translated native
template/profile 042, four players, land, one level, 72x72. Its 298 resource
placements retain identical IDs, sites, asset identities, coordinates and logical
footprints against the pre-change inventory: 188 loose reward references,
24 mines, 79 resource sites and 7 neutral dwellings. Twenty-three gold coffers
change from 1.22 to 0.56 tiles; eleven Memory-Salt reliquaries from 1.35 to 0.56.
The originals already have suitable painting quality; their incorrect apparent
size was not a reason to regenerate them. Other portable pickups and all 69
handheld artifacts follow the corrected class rules, not hand-tuned seed positions.

Unchanged baseline authority hashes, checked in source and both packages:

- Terrain: `0b87a3d85a5cb77e7b1fe7117215a28ab4383724178079d3dc259249e5836f4d`.
- Blocked tiles: `10567142109b668531b348088ae1de74fbb0d0786de699efdae284bca29d7e91`.

Passed acceptance:

- `python3 -B tests/overworld_object_scale_regression.py --label final-small --render --resolution 1280x720 --timeout-seconds 480`: **6,793 checks**. All raster paths/aspects, six pickup identities across six logical spans and four zoom extents, grounding/outlines, real mine controls, unchanged session/content and generous tile selection outside the smaller sprite.
- Same probe through the SHA-locked isolated Linux release bootstrap at 1920x1080: **6,793 checks**. Windows/Wine release at 1280x720 headless: **6,791 checks**, omitting only two image-dimension checks. Every gameplay/art assertion retained; compiled renderer hashes recorded during the run; exports unchanged by probes.
- `python3 -B -m unittest discover -s tests -p test_overworld_object_density.py -v`: **5 tests**. Complete original-to-runtime proof, missing/mismatched identities, undersized/swapped regions and byte-for-byte reproducible repacking.
- Existing distinct map-object report: **422 objects**; decorative report: **200 distinct assignments**, native binding and no procedural fallback; landmark report: semantic ladder, outlines, **7 towns**, painted bounds, click routing and session authority pass. Rendered landmark invocation uses `--audio-driver Dummy --accessibility disabled` on this headless host.
- Existing generated Medium living-scenery/travel/fog/save/AI probe: **587 checks** pass. Its output label `generated-large` was a label mistake, not a Large result; the environment selected Medium.
- `python3 -B tests/validate_repo.py`: **VALIDATION PASSED**, exit 0. This does not claim deleted historical smoke outputs were rerun.
- Official Linux/Windows export/startup checks pass; Windows additionally completes **23 generated Overworld/Town construction steps**. Wine cleanup succeeds and retains user data. PCKs are **646,634,724 bytes each**, **8,861 entries**, byte-identical except `project.binary`; the new density JSON matches source and all four imported atlases exist in both. Runtime PNG addition is 1,729,980 bytes; source art is excluded from packages. No arbitrary package-size ceiling is imposed.
- `git diff --check`: pass.

### Broader-test exceptions, not hidden passes

Two historical broad reports stop on demonstrably pre-existing expectations:
`overworld_visual_smoke.tscn` insists `ResourceChip` is beneath `CommandBand`,
although baseline HEAD and current scene place it in `ResourceStrip`;
`overworld_small_map_visual_scale_runtime_report.tscn` requires a town outline
factor of at least 0.010 although baseline HEAD and current renderer use 0.003.
Town sizing, outline and resource-bar layout are unchanged in this slice. The
focused current landmark and generated-map scale tests above pass. These two
legacy reports were run, failed and are not counted as passes.

An additional optional Large living-scenery probe reaches 573 checks with one
failure, `generated map has no live scenery`: its initial 108x108-map viewport
contains zero eligible animated entries. The 14-entry animation manifest, fog,
placement and animation selection are unchanged; none of the 35 density repairs
overlap those animation identities. Other Large travel/turn checks complete, but
this is **not a passing Large scenery result** and the visibility/fixture
assumption remains a separate follow-up. No animation assertion was weakened.
An initial landmark launcher also hit the host AccessKit/ALSA setup issues; the
explicit disabled-accessibility/dummy-audio invocation passed cleanly.

This is object-presentation completion, not full-game or physical Windows-GPU
certification. Windows coverage here is an isolated release executable under Wine.

## Reproduction and retention

`tools/prepare_overworld_object_density.py --check` rebuilds derivatives in memory
and compares exact bytes. Without `--check` it reproduces the checked-in four
runtime atlases, 35 trimmed cells, density manifest and source-bound proof. The
frozen recipe cannot be silently initialized again. Original paintings, historical
repair proofs and legacy atlases remain unchanged. `OBJECT_SCALE_GALLERY=1` adds
the full catalog captures to the focused probe; `=density` captures only the
35 repacked identities and is not the full asset-coverage run.

After recording results, removed 33 verified task-owned capture/log/export targets:
**1,600,974,130 logical bytes** (1,601,277,952 allocated file bytes), all reproducible.
No process held a target open. The three temporary Wine prefixes had already been
removed by their lifecycle helpers, retaining user data. No task-owned `/tmp`
residue remained. Preserved originals, generated/trimmed art and provenance,
caches, saves/user data, source maps, native RMG recovery and unrelated files.
No disposable screenshot is a validator prerequisite. The remaining 14 MiB in
the task directory is retained user data, not test-export/capture accumulation.
