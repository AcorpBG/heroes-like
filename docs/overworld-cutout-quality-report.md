# Original overworld cutout recovery

Phase 6 parent: `art-overworld-cutout-quality-20260909`.
First cohort: `art-overworld-cutout-batch04-20260909`, 2026-09-09.
Requirements: `docs/overworld-cutout-quality-requirements.md`.
This report accepts only the resource-sheet cohort, not the entire runtime pool.

## Cause and implemented correction

The original generated batch-04 sheet has intact paintings on a nonuniform pink
backing with white dividers. Its old extraction retained divider pixels and matte
fringes while incorrectly making some painted snow, glass and water transparent.
The source/trim cutouts were byte-identical to the damaged runtime PNGs, so changing
imports alone could not restore them. No missing content id or fallback resolver
caused this cohort's defect.

Owner-approved deterministic recovery is implemented in
`tools/prepare_overworld_cutout_art.py`. The exact recipe, original manifest rows,
source/before hashes, retained before PNGs and output provenance are under
`art/overworld/source/generated/cutout_recovery_20260909/batch04/`.
The original sheet SHA-256 remains
`8b5091ec6a85380c799672fce7ef97320fe933e286a4acb931bf08ad0e64508f`.

Exact foreground RGB matches establish integer source-minus-canvas offsets
`[-99,215,528,841]` along both sheet axes. Inspected rectangles exclude gutters
and the outer-sheet corner residue. There is no scaling, warping or repositioning:
each recovered cell returns to its existing 512x512 canvas. Matte coverage is fit
against neighboring source background/foreground colors; contaminated color is
recovered from the nearest intact paint, avoiding the red/green artifacts caused
by assuming a uniform `(255,0,255)` key. The recipe explicitly protects the reef's
intentional pink coral. This material-specific recovery must not be applied
indiscriminately to other purple artwork.

All 15 previously unrepaired batch members now have registered runtime and trimmed
rasters: Floodplain Sluice Camp, Ironstep Ore Pit, Reef Coin Assay, Frostwood Cutting
Yard, Aetherglass Lens House, Sunfall Aetherglass Yard, Embergrain Warm Granary,
Charcoal Embergrain Store, Peatwax Reed Yard, Verdant Graft Nursery, Brass Scrip
Mint, Underway Brass Scrip Press, Memory Salt Pan, Wind Press and Saw Chain.
Cinder Ore Face remains unchanged. The recovery restores 5,519 fully opaque pixels
that were previously transparent, including 2,972 in Frostwood and 1,037 in Memory
Salt Pan. Source-neutral opaque color/detail is checked pixel-for-pixel.

No generated replacement was needed. The two earlier opaque-checkerboard imagegen
attempts remain rejected and are not packaged.

## Runtime and preservation evidence

Evidence root: `.artifacts/overworld_cutout_quality_20260909/`.
The Python-owned `tests/overworld_cutout_batch_regression.py` checks all 15 exact
authored and native/adopted resolver identities and decoded renderer textures.
Resolver coverage dictionaries are not inserted into a world. Actual captures
use three already-explored original placements from the earned Medium Day-97
pre-outcome checkpoint, without moving a hero, injecting fog or changing records:

| Asset | Native placement suffix | Coordinates |
| --- | --- | --- |
| Floodplain Sluice Camp | `object_0976` | `(63,27,0)` |
| Reef Coin Assay | `object_1001` | `(30,19,0)` |
| Aetherglass Lens House | `object_1182` | `(9,33,0)` |

Full placement prefix: `native_h3maped_93c0f05a_`. Exact save:
`generated_full_match_quality_20260906/medium_match_11_continuation_01/data/godot/app_userdata/heroes-like/saves/autosave.json`,
SHA-256 `1734cf2274e00eb763b94db4f814f4ffc73e30bb9377a9225b36bcc3780e0fcc`.
All input bytes remain unchanged. Within-run complete-state comparison excludes
nothing; actual SaveService save/load and ordinary re-entry preserve every field.
The six before/source/package saved outputs also match across runs after removing
only the SaveService envelope timestamp `saved_at_unix`.

`batch04_before97_1280` and `batch04_before97_1920` capture the old art and fail the
15 expected texture comparisons, with all other checks passing and zero engine
errors. The earlier Day-46 attempt had no explored affected placements and is
diagnostic only. Initial after-run raw-PNG comparisons exposed a test-oracle error:
Godot's unchanged `fix_alpha_border` import changes decoded RGB, including partial
alpha. Merely ignoring fully transparent RGB was insufficient. The final oracle
independently loads the source PNG in an empty project and applies the existing
`Image.fix_alpha_edges` operation. All 15 resulting hashes match fresh default
Godot imports and the verified stronger-lossless imports; gameplay receives only
expected hashes, never loose texture overrides. No import or runtime setting was
changed to make a comparison pass.

`batch04_source_final_1280`, `batch04_source_final_1920`,
`batch04_packaged_linux` and `batch04_packaged_windows` each pass **124 checks**,
including full decoded RGBA equality, manifest-backed resolution, no procedural
fallback at the original tiles, native masks/record preservation and complete
save/load. All six final source screenshots were visually inspected at 1280x720
and 1920x1080: corrected subjects, no sheet frames, readable unclipped controls.
The whole-cohort contact sheet and critical individual cutouts were also inspected.
All three rendered Linux-package views were separately inspected; they preserve
the corrected art and unclipped controls (whole-screen animation frames are not
claimed pixel-identical to the source screenshots).
Windows evidence is headless Wine, not physical Windows/GPU certification.

## Consolidated acceptance and packages

- 15 focused Python tests cover nonuniform-key recovery, white and coral
  preservation, scoped purple controls, exact original alignment, restored opaque
  detail, no dividers/out-of-region magenta, reproducibility, corrupt sources and
  swapped content-id rejection. Every retained old cutout fails current visible
  pixel acceptance.
- `python3 tests/validate_repo.py` passes, including the new fail-closed source,
  provenance, manifest and exact regenerated-raster validation.
- Existing distinct/decorative sprite, movement-input ownership, full-route and
  permanent-fog reports pass. Their combined evidence is under the prior shared
  artifact root as `cutout_batch04_shared` and `cutout_batch04_fog`.
- Both established export smokes pass (`linux_export/report.json`,
  `windows_export/report.json`), including their startup/native/generated flow
  checks. Both isolated actual packages pass the identical cohort/save probe;
  only screenshot operations are omitted on headless Wine.
- Each PCK is **286,695,444 bytes / 5,482 entries**. Their member sets match;
  only `project.binary` differs between platforms. Against the retained prior
  Linux release there are no added/removed members: 15 corrected `.ctex` payloads,
  the Overworld manifest and the UID cache differ; all other payloads are unchanged.
  Source sheets, before rasters and recovery metadata are excluded from packages.
- Production worktree changes are exactly 30 selected runtime/trim PNGs and 15
  provenance additions within the one Overworld manifest. Every other manifest
  field, content record, gameplay/native/renderer script and prior Cinder control
  is unchanged. There is no fixed package-size ceiling.

Linux PCK SHA-256:
`677ae53f89b2b783173c7a06bfe9ec65d680f7a5d9076ba57fd78381b4ed766e`.
Windows PCK SHA-256:
`355acfce6104756793574e6e226a87dec623a446452db29ef6722a283fcbc770`.

Reproduce preparation with `python3 -B tools/prepare_overworld_cutout_art.py
--output <fresh-preview-dir> [--install]`; focused tests with
`python3 -B -m unittest discover -s tests -p 'test_overworld_cutout*.py'`.
Run the source probe using `--batch batch04 --label <fresh> --resolution
<1280x720|1920x1080>`. The packaged wrapper adds `--platform`, `--binary`, `--pack`
and a fresh `--wine-prefix` for Windows. Use the established platform artifact-dir
environment variables when rerunning exports, preserving prior evidence.

## Remaining parent work

The full 1,214-row runtime pool is **not accepted** by this cohort. Review and
recovery of remaining map-object/decorative/resource/state/artifact/encounter/
town/hero assets remains the next child. The initial 191 color-screened candidates
were not confirmed defect totals; legitimate colored materials still require
individual review. Existing other-object fringes visible in these maps are not
hidden or declared fixed. No release-readiness claim is made.
