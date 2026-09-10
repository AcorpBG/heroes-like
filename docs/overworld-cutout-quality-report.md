# Original overworld cutout recovery

Phase 6 parent: `art-overworld-cutout-quality-20260909`.
First cohort: `art-overworld-cutout-batch04-20260909`, 2026-09-09.
Requirements: `docs/overworld-cutout-quality-requirements.md`.
The dated cohorts below are bounded acceptances, not whole-pool completion.

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

## Remaining map sheets: 159 further original cutouts

2026-09-09 checkpoint within the **in-progress**
`art-overworld-cutout-runtime-pool-20260909` child. The other 11 original
`map_object_distinct_atlas_20260504_batch_*.png` sheets have the same baked-in
matte/divider damage. All 159 unrepaired members are now recovered. The three
already-repaired members (Marsh Listener Post, Wreck Quay, Moss Oath Cache) and
the whole earlier batch-04 sheet remain unchanged. Together these cover all
178 original map-sheet members, not all 1,214 runtime manifest rows.

`tools/prepare_overworld_cutout_pool.py` uses the accepted original matte engine
with explicit source-space material regions for violet crystals, bellflowers,
petals and magic. Opaque neutral paint and protected chromatic interiors retain
exact source RGB. Unprotected edges use a separate neutral foreground field so
nearby purple crystals cannot recolor unrelated backing. No replacement art,
global desaturation, runtime drawing or gameplay code change was needed.
Recipe, original manifest rows, exact before PNGs and source/tool/output hashes:
`art/overworld/source/generated/cutout_recovery_20260909/map_sheets/`.

Independent opaque RGB matches prove each old cutout's source origin; reviewed
per-sheet rectangles exclude the actual irregular dividers, not an assumed
uniform grid. Batch 02 also had a genuine split error: the Caravanserai painting
extends past the presumed first-column boundary, and its right half appeared
in Ember Signal Brazier. Their complete separate paintings are recovered and
recentered by integer translation on the same 512x512 canvases. The other 157
retain the original source-to-canvas translation. There is no resampling or
warping; all manifest anchors/profiles and gameplay footprints stay unchanged.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `maps_before_1280` / `maps_before_1920`: 159 expected texture mismatches
  against the initial recovery preview, no other failed checks or engine errors.
  These are actual old-art captures, not final-output acceptance.
- `maps_source_1280` / `maps_source_1920`: **1,176 checks pass each** against
  the final installed rasters. All 159 authored and native/adopted identities
  resolve to exact decoded RGBA textures. Actual captures/checks use 14 distinct
  original, already-explored placements in the same unchanged earned Day-97 save;
  five screenshots per resolution sample five source groups. No hero/fog/record
  injection. All ten final source screenshots, all 11 source/recovered contact
  sheets and representative old-art gameplay captures were visually inspected.
- The save does not contain an active Caravanserai placement. Its Brazier at
  `(58,4)` was collected on Day 54 and already uses separate state art. Their
  complete source paintings and exact runtime textures are tested, but neither
  is misrepresented as an earned active-placement screenshot.
- **28 focused Python tests pass** (15 prior + 13 new): exact source recovery,
  independent pixel alignment, scoped color/detail preservation, strict cutout
  bounds, irregular-cell separation, provenance and fail-closed corrupt source/
  swapped identity detection. Every retained before raster fails visible-pixel
  acceptance. `python3 tests/validate_repo.py` passes with the new reconstruction
  validator. Shared distinct/decorative sprite, input ownership, full-route and
  fog reports pass (`cutout_maps_shared` / `cutout_maps_fog` in the established
  generated-full-match artifact root).

Preparation: `python3 -B tools/prepare_overworld_cutout_pool.py --output
<fresh-preview-dir> [--install]`. The existing source and packaged probes select
this cohort with `--batch map_sheets`; their other arguments remain as above.

Final package and save acceptance:

- The first Windows cohort probe (`maps_packaged_windows`) failed parsing its
  large environment-variable expectation payload, then faulted; it is not a
  passing result. The Python-owned harness now transfers that read-only JSON
  through a file and verifies its full SHA-256 before resolving any asset.
  No loose texture, world override or weakened assertion was introduced.
- `maps_source_file_1280`, `maps_source_file_1920`,
  `maps_packaged_linux_file` and `maps_packaged_windows_file` each pass **1,177
  checks**, adding the exact expectation-transfer check. There are zero engine
  errors. The four after/package saves equal both before saves in full, omitting
  only the envelope's `saved_at_unix`; within-run comparisons exclude nothing.
  All 159 texture hashes match the independent source oracle on each platform.
  Representative final file-transfer captures were re-inspected at both sizes;
  all five preceding Linux-package captures of these same final rasters were
  also inspected. Windows remains headless Wine, not GPU certification.
- Official Linux export/startup (`map_sheets_linux_confirm/report.json`) and
  Windows export/startup/generated gameplay (`map_sheets_windows_export/report.json`)
  pass. The initial Linux terminal session returned 143 despite a successful
  export/boot report; the separate confirmation completed with exit 0 and a
  byte-identical PCK. Its exact isolated release passed the final cohort probe.
- Both PCKs contain **286,565,204 bytes / 5,482 entries**, matching member sets,
  and differ only in `project.binary`. Against the preceding batch-04 release,
  exactly 159 selected textures, the Overworld manifest and UID cache differ;
  no members are added/removed and no other payload changes. Source/before/
  preparation files are excluded. There is no fixed size ceiling.
- Production changes are exactly 159 runtime PNGs, their 159 matching trimmed
  PNGs, and provenance additions on those same manifest rows. All other fields,
  content records, runtime/native scripts and prior repaired controls remain
  unchanged. The unrelated untracked retention files remain untouched.

Linux PCK SHA-256:
`bf4b9ff91ee34ad4a77b346afd6d3d408481287ea2526ff092bf504a97b56439`.
Windows PCK SHA-256:
`b9ee40b2bce1bdd9486ca1f263f7dc9fcf39dbbaf58ce27816a27f6bce3f05a2`.

## Older decorations: 185 further accepted art corrections

2026-09-09: all 200 members of the 13 original decoration sheets have explicit
dispositions. This checkpoint integrates 183 recovered original paintings,
one exact Brasspipe neighbor-sliver removal and one original generated Heatglass
replacement. Fifteen inspected clean base archetypes remain byte-identical,
including their differently sized trimmed sources. The 185 runtime PNGs and
their trimmed derivatives are installed and pass consolidated acceptance below.
This is a bounded checkpoint, not runtime-pool or parent completion.

`tools/prepare_overworld_decoration_cutouts.py` and the `decorations/` packet
under `art/overworld/source/generated/cutout_recovery_20260909/` retain exact
original rows, source/before hashes, reviewed rectangles, material regions,
before rasters and reproducible source/trim/runtime provenance. Opaque source
RGB independently establishes the older distinct-sheet transform: 1254-pixel
sheet divisions `[0,314,627,941,1254]`, then each cell proportionally bilinear-fit
to its original 512 canvas. Actual divider locations differ; their feathered
edges were not removed by the old extraction. The correction removes the
inspected gutters and faint backing without changing the original scale.
Six previously clipped batch-12 paintings use recorded vertical translations
of -23, -3, -55, -40, -50 and -43 pixels; none is stretched. Brasspipe loses only
the detached preceding-cliff fragment above y=70; every remaining RGBA pixel,
its 460x483 trim size and `(26,14)` canvas placement are preserved.

Heatglass's original painting could not be cleanly separated from its backing
without gray holes or a pink patch. The owner-approved built-in image workflow
repainted that same low, passable scenic glass field. Its first checkerboard RGB
output and subsequent opaque-wisp candidate were rejected. The accepted source
uses a recorded solid-color extraction and a targeted soft-vapor edit; all three
prompts and source hashes are in `decorations/heatglass_generation.json`.
The new original source is `heatglass_haze_replacement_final.png`; proportional
fitting keeps the former painted envelope `[20,65,492,423]` on the same canvas.
The authoritative row names the new source instead of falsely naming the old
atlas as its current painting. Original atlas provenance remains in the recipe.

The live render owner is unchanged. Authored `object_id`/family/direct mappings
resolve through `_decorative_object_asset_id`. Native collision-body records
instead use the existing separate cohesive biome palette; this cohort does not
substitute older authored art into those bodies. All ids, profiles, body masks,
content records, game rules and saved state remain unchanged.

Before evidence: `decor_before_1280` and `decor_before_1920` each perform 8,498
checks and fail only the expected 185 decoded-texture comparisons against the
initial recovery preview. No engine errors occur. They preserve the same earned
Medium Day-97 save, check 2,380 native body presentations, then open unmodified
normal starts of Third Hearths and Ninefold Confluence. Four naturally visible
affected placements in Ninefold produce three unique authored art captures;
Third Hearths has eight affected placements but none initially visible, so no
fog is injected to manufacture coverage. The fourth screenshot is an unchanged
native collision-body control. Real SaveService round trips preserve each
complete session; no fields are excluded within a run.

Final acceptance under `.artifacts/overworld_cutout_quality_20260909/`:

- **14 decoration Python tests plus 28 prior cutout tests pass**. The first
  decoration test run exposed eight genuinely shaved source edges. The reviewed
  rectangles now retain those original pixels while excluding the actual white
  gutter. Strict source-boundary checks reject future clipped paint; regression
  inputs reinstate the original Quarry/Soot crop errors and must fail. Earlier
  previews/exports are retained as intermediate evidence, not final acceptance.
- `decor_source_final_1280` and `decor_source_final_1920` each pass **8,498 checks**:
  all 185 exact authored/family/direct identities, independently decoded full
  RGBA, actual map rendering, 2,380 unchanged native collision-body presentations,
  and complete save/load/re-entry. No engine errors. All eight final source
  screenshots were visually inspected: corrected authored decorations without
  sheet frames, intact fog and unclipped controls at 1280x720 and 1920x1080.
  All 13 source/recovered contact sheets and the accepted generated Heatglass
  cutout were inspected separately. Not every asset occurs in these live views;
  exact resolver/texture coverage is not claimed as 185 active-placement captures.
- `decor_packaged_linux_final` and `decor_packaged_windows_final` pass the same
  **8,498 checks** inside isolated actual releases. The four Linux-package
  screenshots were separately inspected. Windows is headless Wine with all
  assertions retained and only screenshot operations omitted, not hardware/GPU
  certification. The Linux terminal returned 143 after writing its complete
  passing report; `decor_packaged_linux_exit_confirm` independently repeats the
  same package/probe successfully with terminal exit 0. The first confirmation
  also produced a passing report but the same terminal anomaly; it is retained.
- All seven native saved outputs from both before runs, both final source runs,
  Linux final/first-confirmation and Windows final match in full excluding only
  `saved_at_unix`. Authored starts have independently created session ids, so
  their complete equality is asserted within each run, not across different
  factory-created sessions. `decorations_delivery_preservation.json` records
  exact package/member/manifest/control/save comparisons.
- Existing distinct/decorative sprite, movement-input, full-route and rendered
  permanent-fog reports pass (`cutout_decorations_shared` and
  `cutout_decorations_fog` in the established generated-full-match artifact root).
  `python3 tests/validate_repo.py` and `git diff --check` pass. Repository
  validation reconstructs all 185 rasters and rejects provenance/identity drift.
- Official Linux (`decorations_linux_final/report.json`) and Windows
  (`decorations_windows_final/report.json`) export/startup/generated-flow reports
  pass without fatal matches. The first two Windows terminals returned 143 after
  their passing reports; `decorations_windows_exit_confirm/report.json` completes
  the same official export/startup/generated flow with terminal exit 0 and a
  byte-identical PCK. Terminal confirmations used PTYs; no game or assertion
  changes were made to obtain them.
- Each final PCK contains **286,218,020 bytes / 5,482 entries**. Member sets match;
  only `project.binary` differs by platform. Against the prior 159-map-sprite
  Linux release, exactly 185 selected textures, the Overworld manifest and UID
  cache change; the other 5,295 payloads are identical. No members added/removed;
  source/before/generation/preparation files are excluded. No fixed size ceiling.
- Production changes are exactly 185 runtime PNGs, their 185 trimmed derivatives
  and the same 185 manifest rows. All non-provenance metadata, content records,
  runtime/native scripts, source sheets, prior repairs and 15 clean controls are
  unchanged. Pre-existing unrelated untracked retention files remain untouched.

Linux PCK SHA-256:
`d55ff9ebb05dac7f2e1dd849fb3fd5c9b40b94e8183a17860126493815cf085d`.
Windows PCK SHA-256:
`74bf3a3f360dd7498f3cbd9a22f8333ba6efb58a3f15a8ec2047be6d1689bad4`.

Reproduce preparation with `python3 -B tools/prepare_overworld_decoration_cutouts.py
--output <fresh-preview-dir> [--install]`; focused tests with `python3 -B -m
unittest discover -s tests -p 'test_overworld_decoration_cutouts.py'`. Existing
source/packaged probes select `--batch decorations`; resolutions, platform
arguments and fresh artifact-directory requirements remain as above.

## Accepted mixed legacy/hero/tree/state cohort (2026-09-09)

35 further authoritative rows are corrected in 20 runtime PNG files. The packet
is `art/overworld/source/generated/cutout_recovery_20260909/legacy_families/`:
`recipe.json` locks exact identities, original bytes and geometry;
`generation.json` records the four built-in original image-edit prompts and tool
outputs; `manifest.json` locks preparation, source, trim and runtime hashes.
`before_runtime/` retains all 20 originals. Prepared trim copies are under
`art/overworld/source/trimmed/cutout_recovery_20260909/legacy_families/`.

| Family | Source-backed defect and correction |
| --- | --- |
| Six faction heroes | Bad matte extraction retained pink edge colors and neighboring sheet fragments. Original opaque RGB matches the six original 512-square cells exactly. Recover original paint, including cross-row banner tips; preserve boots' baseline. Embercourt/Mireclaw/Sunvault remain 1:1; complete Thornwake/Brasshollow/Veilmourn paintings are proportionally contained at 0.94358/0.97379/0.92776, never stretched. Explicit prism/flower regions preserve intentional color. |
| Sixteen older generated trees | The recorded source already had clipped crowns, missing alpha and neon edge patches; fully transparent pixels contain only black, not recoverable foliage. An original built-in atlas edit repairs the same sixteen ordered subjects. Extract complete groups into the unchanged sixteen 128-square regions. Current native `cohesive_*` blocker paintings are not replaced. |
| Sawmill and quarry | Existing processed sources clip the roof/woodpile and rear crane/rim. Recorded intact old sheet files were not found. Two precise original image edits restore those edges, preserving architecture, camera and proportions; fit on unchanged 512-square canvases with original floor baselines. |
| Ten other legacy props | Remove recorded neighboring sheet fragments without repainting or moving the original main subject. Every pixel of each original main connected painting is independently checked unchanged; retain the watchtower's separate foreground rock. Original processed source files remain byte-identical. |
| Controlled Miremoon Crownmere | A painted checkerboard survived the historical extraction. A backing-only original image edit preserves the landmark. Independent old-source pixel comparison recovers the original full-source 44-square bilinear resize and 2-pixel pad inside its unchanged 48-square region. Eleven neighboring atlas regions remain byte-identical. The historical source manifest points to the corrected derivative while retaining original provenance. |

Preparation refuses incomplete cohorts, clipped source paint, changed input
hashes/identities, unrecognized runtime edits and unrelated trim destinations.
Manifest row replacements are preflighted before installation. Assembly checks
caught a tree branch crossing the proposed grid boundary and a shrine cleanup
rectangle touching real foliage; the branch and foliage are preserved in the
accepted result. Two generated corner-pixel artifacts are explicitly excluded
from the tree source and two from Crownmere; no global color threshold is an
acceptance shortcut. Eighteen clean controls are unchanged.

Validation evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `legacy_unit_acceptance.log`: **15 new Python tests pass**; prior pool and
  decoration logs pass **28 + 14** tests. Exact source reconstruction, complete
  main-subject preservation, source colors, original alignment, clean neighbors
  and fail-closed corruption/clipping cases are covered. All 35 before rasters
  fail independent visible-pixel acceptance of the corrected result.
- `legacy_after_1280/`, `legacy_after_1920/`, `legacy_packaged_linux/` and
  `legacy_packaged_windows/`: **7,364 checks pass per run**, zero runtime errors
  or leaked-resource reports, terminal exit 0. Import expectations are derived
  independently from source PNGs; alpha-edge processing occurs on each complete
  atlas before extracting its authoritative region. Windows retains every
  assertion and omits only screenshot operations.
- All **12 final source/Linux screenshots** were directly inspected: three
  explicitly labeled detached art-gallery pages and one actual earned native
  map control at each source resolution and in Linux's 1280 package. Clear
  margins, intact silhouettes and no sheet dividers/checker backing were
  checked. The old 48-square Crownmere remains low-resolution when enlarged;
  this is a backing repair, not an atlas-resolution or gameplay-layout change.
- **Evidence boundary:** none of these 35 selected legacy assets occurs in the
  unchanged earned Medium Day97 save. Do not call that map a corrected-object
  gameplay capture. It proves 2,380 current native blocker presentations remain
  art-backed and use their existing cohesive palette, and the real saved hero
  retains identity-art priority. Detached inputs verify the exact Crownmere
  controlled/unclaimed resolver and registered fallback/direct art paths;
  no hero mappings, world objects, coordinates or fog are injected.
- `legacy_delivery_preservation.json`: all five before/source/package native
  saved outputs are equal except the save-envelope `saved_at_unix`; within-run
  full-session/save/load checks exclude nothing. All 1,214 manifest identities
  and all top-level content mappings remain; only the selected 35 source/art
  metadata rows change.
- Shared distinct/decorative sprite, movement-input, route and fog checks pass:
  `.artifacts/full_play_runtime_20260905/legacy_cutout_shared_final/report.json`.
  `legacy_repo_acceptance.log` passes the full repository validator. The older
  sovereign-atlas gate now verifies its exact retained original plus the
  source-locked repaired derivative, not the defective historical runtime hash.
  `git diff --check` passes.
- Official `legacy_linux_final/report.json` and
  `legacy_windows_final/report.json` pass, terminal exit 0. Linux startup and
  the packaged earned-map probe pass; Windows fresh-prefix startup and the
  existing generated Overworld/Town ten-building flow pass. Windows evidence
  remains headless Wine, not hardware/GPU certification.

Both PCKs are **285,850,292 bytes / 5,482 members**, 367,728 bytes smaller than
the prior decoration checkpoint. Only `project.binary` differs by platform.
Against that checkpoint, exactly 20 texture members, the Overworld manifest and
UID cache change; **5,460 members are byte-identical**, with no additions or
removals. Compiled runtime/gameplay/native/save owners therefore remain exact.
Linux SHA-256: `ece698b87080c3bfa3b7d4168274b0488345a6f7b82ad0b2a6fefc156c261838`.
Windows SHA-256: `632f4b1c344a11a0247e416a343dfb202c03ab105bdaed2c683e457d19ec00d3`.
Commands and honest detached-versus-gameplay coverage requirements are in
`docs/overworld-cutout-quality-requirements.md`; both existing cutout drivers
select this cohort with `--batch legacy_families`.

## Enclosed resource-state backing recovery (2026-09-09)

Seven more original paintings are corrected in three existing atlas PNGs:
opened Thorn Seal Gate, Frost Toll Bar, Reef Chain Boom, Ash Sluice Lock and
Toll Ruin, plus active Root Pass Arch and Ridge Wind Chute. No new generated
painting was needed. The original `route_control_opened_wave1/manifest.json`
and `land_transit_active_wave1/manifest.json` explicitly document border-only
background removal. Enclosed checker/white regions therefore survived inside
arches, chain links and braces. Original source inspection and the actual
earned Root Pass screenshot reproduce the defect; it was baked raster backing,
not a missing import, runtime overlay, identity fallback or RMG placement issue.

`tools/prepare_overworld_passage_cutouts.py` removes only explicitly inspected,
source-connected near-neutral backing components, with exact seed/area/bounds
and original-source hash checks. It retains every other source pixel, including
snow/crystal glints and the wind/canvas current. Independent original RGB
comparison proves the unchanged source crops and bilinear 44-pixel fits:
274–977 opaque material samples per asset average 0.87–1.22 channel error against
the historical atlas. Toll Ruin retains its unusual `(2,4)` canvas offset.
Only the projected repair support changes in the runtime: all other original
RGBA pixels, all seven 48-square regions, all 16 neighboring atlas regions and
every content/placement/state mapping stay unchanged.

The `passages/recipe.json`, `manifest.json` and three retained `before_runtime/`
atlases under `source/generated/cutout_recovery_20260909/` record the recovery.
Seven complete recovered sources and seven prepared runtime-size trims are
under `source/trimmed/cutout_recovery_20260909/passages/`. Historical source
manifests retain original hashes and point to the repair proof; repository
validation reconstructs the actual corrected pixels rather than accepting a
replacement hash alone.

Accepted evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `passages_acceptance_1280`, `passages_acceptance_1920`,
  `passages_packaged_linux_acceptance` and fresh-prefix
  `passages_packaged_windows_acceptance` each pass **2,458 checks**, terminal
  exit 0 and zero runtime errors. The final nine source/Linux screenshots
  were individually inspected. Windows remains headless Wine, not rendered
  Windows or physical-GPU certification.
- `passages_before_1280` reproduces all seven independent art-oracle failures;
  ordinary movement, full saved state and unrelated controls still pass.
  `passages_unit_acceptance.log` passes 11 new Python tests;
  `passages_prior_legacy_tests.log` passes 15 prior tests. The full repository
  validator passes (`passages_repo_acceptance.log`), as do `git diff --check`
  and shared distinct/decorative sprite, movement-input, route and fog reports
  (`.artifacts/full_play_runtime_20260905/passages_cutout_shared/report.json`).
- Both official `passages_linux_final/report.json` and
  `passages_windows_final/report.json` pass, including Linux startup and
  Windows fresh-prefix startup/generated Overworld/Town ten-building flow.
- `passages_delivery_preservation.json` proves all five native saved outputs
  equal except `saved_at_unix`. Five independently started authored outputs
  additionally differ only in `session_id`, whose existing constructor uses
  `Time.get_ticks_msec()` (`SessionStateStore.gd:48`). Each run's complete
  session/save/load comparisons exclude **nothing**, including session identity.

The first Windows probe passed its 2,456 assertions but failed acceptance on
an abrupt-exit ObjectDB warning. Retained verbose diagnostics identify four
`AudioStreamPlaybackOggVorbis` references after the multi-scene test. The final
probe leaves audio enabled during gameplay, then uses the existing music and
ambient stop methods and briefly drains the mixer **after** all captures and
save checks. Two additional checks prove the owners stop and full session
state is unchanged. The verbose teardown diagnostic and a fresh-prefix final
run are clean. This is test-lifecycle correction, not a production audio fix
or a claim that arbitrary game-exit paths were repaired. The original failure
remains in `passages_packaged_windows` and `passages_exit_diagnostic`.

Both exact PCKs are **285,855,668 bytes / 5,482 members**, 5,376 bytes larger
than the mixed-family checkpoint. Only `project.binary` differs by platform;
exactly three texture members, the Overworld manifest and UID cache changed.
All **5,477 other members are byte-identical**, with no additions/removals and
no runtime/gameplay/native/save-owner changes. Linux SHA-256:
`0c49b7026b31aee3a77bec6081c53d749df8efe0fe387d90b692553cf6a865e3`.
Windows SHA-256:
`dd53b9f298fa810beb6ebfb942c0a956aedb149e5cc057111191f15646010187`.
Both cutout drivers select this cohort with `--batch passages`.

Gameplay evidence is explicit: a fresh `seedseer-drowned-orchard` start reaches
and claims Root Pass Arch at its original `(5,1)` through seven ordinary moves,
with no position, fog, movement, collection, resource or encounter grants.
The opening is visibly clear in both source resolutions and the Linux package.
Detached galleries show all seven variants and are labeled **not gameplay**.
The unchanged earned native Medium Day97 case still has 2,380 original cohesive
blocker bodies; none of its current resource states uses these seven variants,
so that capture is a regression control, not a corrected-state native capture.

## Recurring encounter source recovery (2026-09-09)

Twenty-four recurring encounters now use high-resolution derivatives of their
original generated RGBA paintings. The recovery recipe and exact historical
atlas are retained in `art/overworld/source/generated/cutout_recovery_20260909/recurring_encounters/`;
prepared cutouts are in the corresponding `source/trimmed` folder. This is
original-source reprocessing under the owner's approval, not new generation,
procedural approximation or color-key removal.

The concrete fault is historical palette/alpha loss. Atlas revisions `180c83bf`
and `823b8fc7` used indexed palettes with multilevel transparency. `f18349e6`
(high-difficulty encounter landmarks) reduced the first 24 regions to binary
alpha. `01251fed` later copied those damaged pixels unchanged into an RGBA atlas
while adding seven smooth-alpha neighbors. Current imports faithfully loaded
those already-damaged PNGs; missing `.ctex`, fallback routing and native map
generation were not the cause. Thin pikes, flags and chains were particularly
damaged. Original source RGB also recovers detail lost to palette quantization.

The first recovery retained 48x48 cells. Its functional tests passed, but actual
1280/1920 gameplay inspection rejected it as blurry. Those rejected outputs
remain under `recurring_install`, `recurring_after_1280` and
`recurring_after_1920`, not as the accepted package boundary. The installed
`recurring_encounter_recovered_atlas.png` is 4608x192: 24 cells at 192 pixels,
resampled directly from original paintings, not enlarged 48-pixel thumbnails.
The recipe preserves original crop/aspect and multiplies fit/offset coordinates
by exactly four. First-six bottom alignment and subsequent centered alignment
remain distinct. This does not claim recovery of the undocumented historical
resampler command; source registration and palette-loss evidence are explicit.

Only the 24 manifest rows change raster paths/regions and processing provenance.
Their content IDs, faction/role ownership and source paintings remain exact.
`OverworldMapView._hostile_actor_layout` owns the world draw rectangle independently
of raster dimensions. The actual Beacon Wardens marker/draw rectangle is equal
before/after at both source resolutions and in the packages. The entire old
1488x48 atlas remains byte-identical (`a43eeb70…`), including its seven unaffected
alpha controls. **Those seven are not blanket visual acceptance**: the later
Lantern Patrol source comparison still shows resolution loss, so their detailed
quality follow-up remains in the parent work.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `recurring_before_1280` records all 24 failing independent pixel oracles and
  the actual original Beacon Wardens. One additional assertion was a stale
  generic tile-report expectation; the final probe checks the actual encounter
  draw owner's identity route instead. No runtime fallback fix is claimed.
- `recurring_hd_preview/comparison_00..05.png` shows all 24 before/recovered/source
  comparisons. `recurring_hd_1280`, `recurring_hd_1920`,
  `recurring_hd_packaged_linux` and `recurring_hd_packaged_windows` each pass
  2,550 checks without runtime errors. Eleven focused Python tests cover full
  reconstruction, normalized geometry, smooth alpha, exact neighbors and
  negative source/identity/resolution cases.
- All twelve final source/Linux images were inspected: two labeled detached
  24-identity galleries, ordinary authored scouting and the unchanged native-map
  control at each rendered boundary. The larger detached gallery intentionally
  enlarges its cells; actual game-size inspection is separate. Windows is
  headless Wine, not a claim of Windows GPU/hardware visual validation.
- `recurring_linux_hd` and `recurring_windows_hd` official exports pass startup,
  generated gameplay/Town entry and native-library checks. Both 286,696,296-byte
  PCKs have 5,484 members and all 21 encounter atlas import/texture pairs; source
  art stays excluded. Only `project.binary` differs between platforms. New large
  platform artifacts live in a fresh root-disk temporary directory through
  recorded `.artifacts` links; no old artifacts or caches were deleted.
- `recurring_delivery_preservation.json` proves only the new texture/import pair
  is added, with no removed members. Of existing members, only the Overworld
  manifest and UID cache change; 5,480 remain byte-identical to the passage
  checkpoint, including all gameplay/native code and the original atlas.
  Exactly 24 of 1,214 manifest rows change; all gameplay mappings stay exact.
  Five native saves match outside `saved_at_unix`; five fresh authored saves
  additionally differ only in the existing clock-generated `session_id`.
  Within each run, save/load/reentry excludes no state fields.
- The existing 31-identity/two-resolution encounter report passes after its atlas
  expectations are updated. Its Roadward Lodge fixture also now expects that
  already-authored exact Waywatch identity, not its obsolete unit fallback.
  Production fallback order and rendering code are unchanged.

Actual gameplay coverage is precise: two ordinary moves from Charter Pyre's
starting hero expose original Beacon Wardens at (4,1), with Bridgeward Levies
also visible. No placement, visibility or resource injection is used. The earned
native Medium Day97 save has two Tidepool Skiffyard guard records at (46,3) and
(50,17), **both already resolved**. They remain resolved, not revived for a
picture. That run verifies all 2,380 original manifest-backed blockers and full
native state unchanged; the detached gallery proves the 24 repaired identities
separately. Probe-only audio teardown uses existing stop methods after gameplay,
without changing game audio behavior.

Final consolidated acceptance passes: `recurring_hd_repo_acceptance_final.log`
records repository validation; `recurring_hd_shared_final` in the existing
full-play validation artifact root passes all five distinct/decorative sprite,
movement-input, route and fog reports. `recurring_hd_unit.log` records all eleven
Python tests; `recurring_hd_legacy_report_final.log` records the 31-identity
two-resolution report. Earlier rejected/failed diagnostics remain distinguished
from these final results. Diff checks pass. This accepts the 24 repaired rows,
not the whole parent or the seven unchanged resolution-quality follow-ups.

## Remaining seven recurring paintings — accepted 2026-09-09

The seven later recurring sources have intact smooth alpha; their defect was
excessive detail loss in 48-pixel runtime cells, not the earlier binary-alpha
damage. Original Barrow Pickets, Bramble Hedge Watch, Lantern Patrol, Reedward
Camp, Sluice Raiders, Willow Mill Pack and Ghoul Grove now join the same recovered
atlas at 192 pixels per cell (5952x192 total). No new painting was necessary.
The original 1488x48 atlas remains byte-exact; the first 24 accepted recovered
cells and trim/proof hashes are also exact, retained in `prior_24_checkpoint`
and `before_runtime` within the recurring recovery source packet.

The v3 recipe records each immutable source, crop and measured registration:
42-pixel logical aspect fit, bottom alignment and BILINEAR resampling. Projecting
those sources at the old size matches alpha and opaque RGB to less than one
average channel level on the 0–255 scale. This is measured registration, not a
claim that the historical processing command was recovered. Alpha-support
thresholds of 4 or 8 select crop bounds only; all original RGBA pixels inside
remain intact. Geometry, placement, identity, gameplay and save code are unchanged.

Consolidated evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `recurring_wave4_before` completes 2,607 checks with 28 expected failures,
  four per new identity (path, region, canvas, RGBA), and no runtime errors.
  `recurring_wave4_preview/comparison_06.png` and `comparison_07.png` show all
  seven before/recovered/source comparisons; both were inspected.
- `recurring_wave4_1280`, `recurring_wave4_1920`,
  `recurring_wave4_packaged_linux` and `recurring_wave4_packaged_windows` each
  pass all 2,607 checks without runtime errors. All eighteen final source/Linux
  images were inspected: three explicitly detached 31-identity gallery pages
  and three actual gameplay/control views per rendered run. Windows is
  headless Wine, not Windows GPU visual certification.
- The first packaged Linux wrapper returned 143 after writing its successful
  complete reports (engine exit 0). The clean
  `recurring_wave4_packaged_linux_final` repeat exits 0 and passes all 2,607
  checks; its three complete saves match that earlier run under the same
  timestamp/session-ID rules. Its three gameplay images were re-inspected;
  the three gallery PNGs are byte-identical to those already inspected.
  No test failure or incomplete wrapper is waived.
- `recurring_wave4_unit.log`: thirteen focused Python tests pass, including
  original-paint registration, retained weak alpha and exact first-24 controls.
  `recurring_wave4_existing_report.log`: existing 31-identity/two-resolution
  report passes. `recurring_wave4_repo.log`: repository validation passes.
  Existing full-play output `recurring_wave4_shared/report.json` passes all five
  distinct/decorative sprite, movement-input, route and fog reports.
- Official `recurring_wave4_linux` / `recurring_wave4_windows` exports pass
  startup, generated Overworld/Town, native-library and source-exclusion checks.
  Both PCKs are 286,972,440 bytes with the same 5,484 members; only
  `project.binary` differs between platforms. Relative to the previous 24-row
  checkpoint, there are no new or removed members: only the existing recovered
  texture, Overworld manifest and UID cache change; 5,481 members remain exact.
  No package-size limit was introduced, and no artifacts or caches were removed.
- `recurring_wave4_delivery_preservation.json` proves all fifteen full saves
  match across before/source/platform runs outside the existing save timestamp
  and fresh-authored session ID. Within-run save/load/reentry excludes no state.
  Actual Linux world/marker rectangles are JSON-exact before and after; Windows
  geometry has identical float32 bits (one JSON decimal endpoint differs by
  1e-12). This numeric serialization distinction does not exclude any save state.

Actual new gameplay coverage is original Bogbound Oath Lantern Patrol at (3,1),
visible after two ordinary moves from (0,2) to (2,2), with no injected placement
or fog. Original Charter Pyre Beacon Wardens remains the prior-art control.
The unchanged earned native Medium Day97 save contains three Bramble Hedge and
two Tidepool guards, **all already resolved**; none was revived for a screenshot.
Its 2,380 original blockers and complete native state remain unchanged. Detached
31-identity art coverage is not presented as 31 live native encounters.

## Thirty recurring resource-site originals — accepted 2026-09-09

This cohort restores detail from all thirty immutable original RGBA paintings
under `resource_sites/recurring_wave1` and `recurring_wave2`. Unlike the earlier
binary-alpha encounter damage, these old cells retained smooth transparency but
lost substantial detail through 48-pixel packaging. No new generation, color key,
alpha removal, replacement geometry or gameplay change was needed. Purple crystals,
mushrooms and banners are original paint, not removable matte.

`tools/prepare_overworld_recurring_site_cutouts.py` reconstructs the original crop
and 44-pixel logical aspect fit directly at four times the raster density. The
first five retain bilinear resampling and the south anchor. The later 25 retain
Lanczos and their measured two-pixel south inset, which the historical manifest's
generic south-anchor description omitted. Those later registrations reproduce
every old alpha and nontransparent painted pixel exactly; tiny RGB differences
under zero alpha are not visible paint. The first five registrations have alpha
MAE below 1 and opaque RGB MAE below 1.4 on the 0–255 scale. The installed atlas
uses the same path at 5760x192, with no change to logical/world-space size.

The `recurring_sites` recovery packet retains the exact original 1440x48 atlas,
source hashes, complete per-identity registration recipe and reconstructible
trim/runtime proof. Source manifests retain their historical hashes and point to
that derivative proof. All 30 ids and all resource-site/state mappings are exact.
In particular, the 24 separately authored claimed variants are **not** rerouted
to these recovered legacy originals. Greenbranch Copse still uses its original
claimed artwork and its separate unclaimed map-object identity.

Evidence below is under `.artifacts/overworld_cutout_quality_20260909/` unless
noted otherwise:

- All eight `recurring_sites_preview/comparison_00..07.png` pages were inspected.
  `recurring_sites_before_final` records exactly 90 expected old-art failures
  across 2,673 checks and no runtime errors. An earlier diagnostic included two
  probe mistakes—an obsolete Greenbranch unclaimed expectation and an attempted
  move onto water—which were corrected before the accepted before/after pair.
- `recurring_sites_1280`, `recurring_sites_1920`, `recurring_sites_packaged_linux`
  and `recurring_sites_packaged_windows` each pass all 2,673 checks with no runtime
  errors. All fifteen final source/Linux screenshots were inspected: three
  detached galleries, actual Prismhearth Watch gameplay and an earned native-map
  control at each rendered boundary. Windows is headless Wine, not GPU evidence.
  The relay remains at (2,3), visible after an ordinary move from (0,3) to (0,2);
  no placement, collection or fog was granted. The retained Day-97 native sample
  has 2,380 manifest-backed blockers but zero currently selected cohort assets;
  its image is explicitly an unchanged control, not a repaired-object example.
- `recurring_sites_unit_final.log`: twelve Python tests pass. The existing
  `neutral_dwelling_claimed_landmark_report` passes all 38 claim/reward/repeat/save
  cases in `recurring_sites_claimed_final.log`. Its sole stale expectation was
  corrected from `kennel` to `mapobj_fenhound_kennels`; the previous accepted PCK
  already contains that exact mapping. Current art/state routing was not changed.
  The old combined visual-smoke fixture's density/bounds expectations were aligned;
  its script loads through normal autoload startup (`recurring_sites_legacy_load`),
  but its obsolete combined claimed-state fixture is not counted as acceptance.
  A standalone `--check-only --script` diagnostic lacked autoloads and is not a
  runtime failure. The Python-owned thirty-identity probe supplies exact coverage.
- Repository validation passes in `recurring_sites_repo.log` and the final
  `recurring_sites_repo_final.log`. All five
  existing sprite/decorative/input/route/fog reports pass with individual exit 0
  in `.artifacts/full_play_runtime_20260905/recurring_sites_shared_final/report.json`.
  The first runner stopped after three cases; the repeat's parent shell was also
  signaled, but its isolated child completed all five. These interruptions remain
  recorded and are not presented as successful outer-shell exits.
- Official `recurring_sites_linux` and `recurring_sites_windows` reports pass
  package integrity, startup and generated Overworld/Town/native flows. Windows
  startup and generated gameplay each return 0 with no fatal matches; its outer
  shell reported SIGTERM despite the completed success marker/report. The separate
  exact-art Windows package probe exits 0. Both PCKs contain 5,484 members and are
  288,003,784 bytes; only `project.binary` differs between platforms. No fixed
  package ceiling applies. No source-art metadata or payload is shipped.
- `recurring_sites_delivery_preservation.json` compares baseline `7e05c5af`,
  source and both exact packages. Only the existing resource-site texture,
  Overworld art manifest and UID cache differ: 5,481 members, including all game
  code/native/content/save owners, remain byte-identical. Only 30 of 1,214 art
  rows change. All ten complete saves match across five runs except save time and
  the fresh authored session's clock-generated id; within each run nothing is
  excluded. Original relay placement and 1280-pixel world draw rectangles remain
  exact (Windows float32 exact); wide gameplay uses the same unchanged geometry
  owner. All original paintings and the historical atlas remain hash-exact.

## Thirty-one separately authored claimed dwellings — accepted 2026-09-09

The original claimed paintings were a different family from the thirty preceding
legacy resource-site originals. Twenty-five source files had binary-keyed alpha:
white salt-pan interiors, snow roofs, canvas and pale stone were erased, while
enclosed checkerboard behind ropes, frames and banners remained. Six sources had
genuine smooth alpha. All 31 also lost detail in their old 48-pixel atlas cells.
The repository source files retain the original painted RGB beneath zero alpha;
the absolute external `generated_original` paths no longer exist and are not
claimed as available recovery inputs.

`tools/prepare_overworld_claimed_cutouts.py` restores that retained paint and removes
only individually inspected, seed/area/bounds-locked connected backing. The two
scoped lower-body policies remove neutral backing beneath Reedbarge and Cinder
Kiln without applying those thresholds to their roofs, cloth or smoke. True-alpha
sources remain byte-identical as RGBA. Original edited source PNGs are immutable.
Salt trays, Icehook's snowy roof and its separate snow cap touching the canvas
edge are explicit positive preservation tests, not a global white-removal class.

The `claimed_dwellings` recipe/provenance packet preserves all three old atlases
and records source hashes, inspected components, recovered masters and trimmed
cells. Original alpha bounds, bilinear fit and canvas anchors are measured against
the old cells: alpha MAE below 1 and opaque RGB MAE below 1.6 on the 0–255 scale.
The first eight retain the south anchor; the later 23 retain their centered fit.
Reprojection at 192 pixels per cell gives 1536x192, 3072x192 and 1344x192 atlases
at the same paths. No new generation, upscaled old cells, world-size change,
gameplay/native/content/save change or claimed-to-unclaimed substitution occurs.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `claimed_prepared_01/comparison_00..07.png`: every repaired original and runtime
  cell visually inspected against its old painting. Final 1280/1920 source and
  Linux package galleries distinguish detached coverage from actual gameplay.
  All eighteen final source/Linux images were opened and visually inspected:
  three galleries and three gameplay/control captures at each rendered boundary.
- `claimed_final_scout_1280`, `claimed_final_1920`, `claimed_packaged_linux` and
  `claimed_packaged_windows`: 2,693 checks each, exit 0 and no runtime errors.
  All 31 texture identities and claimed/unclaimed routes match the independent
  full-atlas import oracle. Bramble Hedge remains enemy-owned at (16,18) in
  Ninefold Confluence; normal UI route selection moves Mira to (18,19), revealing
  it through ordinary vision. No position, ownership, guard, placement or fog
  injection was used. The Day-97 generated sample retains all 2,380 original
  manifest-backed blockers but has zero selected claimed-cohort assets; it is an
  unchanged control. The Prismhearth relay is also an unchanged gameplay control.
- Early scouting diagnostics are retained: a noncontiguous direct movement call
  was rejected, then the normal route to (20,21) stopped outside Bramble's vision
  range. The accepted route uses the existing UI planner to (18,19), with normal
  movement cost and no end-turn, combat or visibility shortcut.
- `claimed-unit-final.log`: twelve Python tests pass, exit 0. All 38 existing
  claim/reward/repeat/save cases pass (`claimed-claim-save.log`). This fixture
  initializes states and is not presented as earned gameplay. The older combined
  visual/muster fixture remains outside acceptance; the Python-owned 31-identity
  probe supplies current atlas/registration coverage. No legacy fixture failure
  is relabeled as a gameplay pass.
- `claimed-validate-repo.log` and `claimed-validate-repo-final.log` pass. The five existing sprite/decorative/input/
  route/fog reports pass individually and as a complete suite in
  `.artifacts/full_play_runtime_20260905/claimed_dwellings_shared/report.json`.
  Initial completed unit/source runners had outer-shell SIGTERM observations;
  the final direct-process unit and all four final source/package runners exit 0.
- Official `claimed_linux` and `claimed_windows` exports pass startup and their
  required package/gameplay checks. Windows startup and generated Overworld/Town
  flows exit 0 with no fatal matches. Exact-art Windows validation is headless
  Wine, not real Windows GPU evidence. Both PCKs contain 5,484 members and are
  289,137,800 bytes; only `project.binary` differs between platforms. Source-art
  metadata/payloads remain excluded. No fixed package ceiling applies.
- `claimed_delivery_preservation.json` compares baseline `24354c6c`, source and
  both packages. Exactly the three textures, Overworld manifest and UID cache
  change; 5,479 members, including all compiled game/native/content/save owners,
  remain exact. Exactly 31/1,214 art rows change; all state mappings are unchanged.
  All twelve full saves match across four runs except cross-run save timestamps
  and fresh authored session ids; within-run comparisons exclude nothing.
  Native and Prismhearth saves also match the prior accepted batch. Actual
  Bramble placement and 1280 source/Linux draw geometry are exact; Windows values
  match at float32 precision. Original registration and geometry owners remain
  unchanged at both resolutions.

## Thirty-four early post-interaction paintings — accepted 2026-09-09

The six major-vault, creature-bank, guarded-route, repeatable-service,
progression-shrine and scouting atlases used separate original state paintings,
not the already accepted unclaimed map objects. Seventeen repository originals
had binary-keyed alpha with retained painted RGB; seventeen had genuine smooth
RGBA. The old 48-pixel derivatives obscured detail and retained backing inside
gates, braces and ropes. This was a source/cutout defect, not a state-key mismatch.

`tools/prepare_overworld_state_cutouts.py` recovers retained paint and removes
96 individually inspected, seed/area/bounds-locked backing components
(20,971,852 source pixels). Genuine RGBA stays exact. Crystal, snow, canvas,
smoke and painted water are preserved. Original-sample matte decontamination
is restricted to the two-source-pixel backing boundary, or twelve pixels at
Ashbarb's inspected diffuse ground rim; inconsistent composite fits are rejected.
The first preview's white Ashbarb outline was rejected before this correction.
No new painting generation or procedural replacement was needed.

The `early_states` recipe/provenance packet retains all six historical atlases
and the immutable original inputs, recovered masters and 192-pixel derivatives.
Independently measured 42/44-pixel centered and 46-pixel south-aligned source
transforms match the historical cells (alpha MAE below 1, opaque RGB MAE below
1.6 on the 0–255 scale). Fourfold source projection changes density, not original
world draw rectangles. Every path, identity and ready/used mapping stays intact.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- All nine final `early_states_preview_02/comparison_*.png` pages and all three
  source-1920 and packaged-Linux detached galleries were opened and inspected.
  Actual 1280/1920 gameplay captures collectively cover all eleven visible
  affected native identities; the packaged Wayfarer capture was also inspected.
  Detached galleries are explicitly labeled, not represented as earned gameplay.
- `early-states-unit-final.log`: eleven tests pass. `early_states_source_1280`,
  `early_states_source_1920`, `early_states_packaged_linux` and
  `early_states_packaged_windows`: 2,763 checks each, exit 0, no runtime errors.
  The independent full-atlas import oracle verifies all 34 assets and state
  routes. The earned Day-97 native save contains 31 affected records, not 31
  visible objects; eleven distinct affected identities are actually visible.
  Consumed records remain absent through the existing presence/cache owners
  (`OverworldMapView._resource_node_at`, `OverworldRules.resource_node_is_present`).
  All 2,380 original native blockers and the authored relay remain controls.
- Before-run raw evidence retains 102 intended new-size/pixel failures plus five
  erroneous probe attempts to capture consumed records. The probe was corrected
  to respect existing visibility/presence; gameplay was not changed. Its initial
  outer shell exited 143, so this is diagnostic evidence, not a passing process.
  All four final direct-process runs exit 0. The first repository run rejected
  34 stale size expectations; exact six-atlas expectations were updated alongside
  independent reconstruction. `early-states-repo-final.log` passes.
- All five existing sprite/decorative/input/route/fog reports pass in
  `.artifacts/full_play_runtime_20260905/early_states_shared/report.json`.
  Older combined domain fixtures are not claimed as rerun in this batch.
- Official `early_states_linux` and `early_states_windows` exports pass their
  startup/package/gameplay checks; Windows generated Overworld/Town flows exit
  0 without fatal matches. Windows art validation is headless Wine, not a real
  Windows GPU capture. Both PCKs are 290,229,064 bytes with 5,484 members; only
  `project.binary` differs by platform. Source art is excluded; no ceiling applies.
- `early_states_delivery_preservation.json` compares baseline `28a82998`, source
  and both packages: exactly six textures, the manifest and UID cache change;
  5,476 members including every compiled game/native/content/save owner remain
  exact. Exactly 34 art rows change, 1,180 do not, and all state mappings match.
  All eight complete saves match within runs without exclusions, and across
  runs except save time and fresh authored session ids. Native/authored saves
  also match the before capture and prior accepted checkpoint. All 31 matching
  native placement records, thirteen actual/control capture records, original
  source/atlas hashes and 1280 world rectangles remain exact (Windows float32).
  The wide view retains the same unchanged geometry owner.

## Forty landmark and objective-state paintings — accepted 2026-09-09

The five faction-landmark, road/objective, fourteen-mark, eightfold-reliquary
and border-standard atlases still used 48-pixel derivatives of intact originals.
Those derivatives visibly blurred rope, branch, crystal, masonry and instrument
detail in actual native gameplay. Thirty-nine originals have genuine smooth
RGBA and remain exact. Witness Stone has binary-keyed alpha: its pale eye and
candles were already opaque, contrary to the initial visual hypothesis. They
are preserved, not claimed as restored. Its correction is a narrow edge repair.

`tools/prepare_overworld_landmark_cutouts.py` projects the originals at 192 pixels
per cell through measured 44-pixel logical fits and the original centered/south
anchors. It removes Witness Stone's single inspected exterior backing component
(1,437,420 mostly already-transparent source pixels), decontaminating only its
two-source-pixel boundary. Compared with original alpha, 43 formerly visible
backing pixels disappear, 3,422 hard edge pixels soften and 28 faint edge pixels
are recovered. Pale foreground is exact. No global color deletion or new image
generation occurs. The `landmark_states` source/trim/provenance packet retains
all five historical atlas hashes, all forty original input hashes and exact
reconstruction of every new runtime cell. Existing source files are immutable.

Historical-source registration alpha MAE is below 1 for 39 rows and 1.07856 for
the live Graft Arch; opaque RGB MAE is below 1.34 for all forty. The arch's exact
measured discrepancy is recorded separately (maximum alpha difference 10/255),
not hidden by weakening earlier batches. A one-logical-pixel shift fails every
registration test. Texture density changes; original world rectangles do not.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- All ten original-review and ten candidate-comparison pages were inspected,
  plus all four source-1920 and packaged-Linux detached galleries. Actual source
  1280/1920 captures collectively cover all eight visible affected identities;
  packaged Graft Arch and before/after Graft Arch and Granary captures were
  inspected in context. Galleries are explicitly detached, not earned gameplay.
- `landmark-unit-final.log`: eleven tests pass. The initial test incorrectly
  expected erased eye/candle pixels; exact input inspection corrected it to a
  positive preservation assertion, without changing art to satisfy the test.
- Source 1280, source 1920 and packaged Linux/Windows each pass 2,804 checks, exit 0 and
  no runtime errors. The independent full-atlas oracle covers forty exact
  textures and state resolvers. There are 21 matching earned native records,
  eight visible affected identities and two unchanged gameplay controls. All
  2,380 native blocker bodies remain manifest-backed. Consumed records stay
  consumed; no position, ownership, guard or fog grants manufacture captures.
- The before diagnostic records 120 intended new-size/pixel failures and three
  incorrect fixture assumptions: Granary Lock, Blackwater Shrine and Prism Yard
  are faction landmarks, so existing `_resource_asset_id` precedence always
  selects their live image. The final probe explicitly preserves that rule.
  The before outer runner exited 143; its complete raw report/screenshots are
  diagnostic evidence, not a passing run.
- `landmark-repo.log` and final `landmark-repo-final.log` pass. Both existing sprite reports passed before the
  initial shared runner exited 143; `landmark_states_shared_final/report.json`
  under `.artifacts/full_play_runtime_20260905/` passes the remaining three
  movement/route/fog tests with exit 0. No interrupted suite is called complete.
- Official Linux and Windows exports/startup/generated-map flows pass, as do
  their exact packaged art probes. The first Windows runner exited 143 without
  a final report; `landmark_states_windows_final/report.json` is the completed
  fresh isolated run, not acceptance of that interruption. Windows/Wine is
  headless and does not establish hardware/GPU visual certification.
- `landmark_states_delivery_preservation.json` passes: both PCKs are
  291,354,392 bytes with the same 5,484 members; only `project.binary` differs
  by platform. Against commit `742a3a89`, exactly five imported atlases, the
  Overworld art manifest and UID cache change; 5,477 other members are exact,
  including compiled game/native/content/save owners. Only forty manifest rows
  change; all state mappings, forty original paintings and five archived atlas
  hashes remain exact. All eight complete saves agree with both prior art
  checkpoints, excluding only cross-run timestamps and fresh authored session
  ids (no within-run exclusions). All 21 earned records and original world
  draw rectangles remain exact, including Windows float32 equivalence.
  Forty new, non-overlapping dispositions bring acceptance to 620; 594 remain.

## Route, arcane and dwelling-state recovery — 2026-09-10

Fifty-four paintings on eight existing resource-site atlases now render from
192px cells instead of their coarse 48px derivatives. This covers coastal
operational sites, frontier markers, elite/elder dwellings, Pactwright/Mireglass,
High Arcanum and Horizon company musters. Runtime paths, normalized framing,
footprints and all 35 site/state mappings remain unchanged. Fifty-two genuine
RGBA masters are retained exactly. The old controlled Cinderwake/Tideglass
sources were only 384x192 composites whose neutral backing had contaminated
fine edges; these two received approved original generated controlled edits.

The built-in imagegen workflow used each original 1774x887 unclaimed painting
and its historical controlled design reference. Both first edits returned opaque
checkerboards and were rejected for runtime. Two explicit isolation-matte edits,
recorded with full prompts/output hashes in the `route_arcane/generation.json`
packet, supplied extraction masters. The scoped recovery tool removes their
matte, preserves Tideglass's inspected purple coral and restores Cinderwake's
two smoke windows from its genuine original RGBA. It clears 370 explicitly
reviewed rear-rail backing pixels and two detached background corner pixels per
replacement. Both recovered masters have zero magenta-review pixels; smoke,
coral, membranes, supplies and physical claim pennants were inspected visually.
No painted source was overwritten and no procedural replacement was drawn.
Historical `source_generated` references remain intact; the new
`source_processing_manifest` and recipe identify the exact replacement inputs,
source restoration and derived master/runtime outputs.

All original crops/fits/anchors are recorded. The replacement pair retains the
original wide canvas and 46x23 logical fit, not an expanded tight-bounds fit.
Pactwright's original fit is 43px; the other families retain 40/42/44/46px fits.
Historical alpha MAE is below 1.3 and opaque RGB MAE below 7. Coast discrepancies
are recorded honestly: the old undocumented resampling/color pipeline was not
fully recovered. The preserved source manifest specifies trim/44px fit/center;
no claim of palette, double-alpha or thumbnail-processing parity is made.
Pactwright restores original master colors without its coarse old full-cell
grade. Its six original raster wax marks and Mireglass's six counterseals remain
exact state indicators, not newly drawn geometry.

Those seven **state-indicator paintings are not visually accepted**. Inspection
shows their retained low-resolution badges need original painted integration.
They received sharper foregrounds and keep existing behavior in this checkpoint,
but remain pending for generated state-art replacement. Therefore this batch
adds **47**, not 54, accepted dispositions: **667 accepted; 547 remaining**.

Evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- Fourteen original-review and fourteen candidate-comparison pages were
  inspected. All five rendered gallery pages were reviewed across source
  resolutions, plus packaged-Linux controlled-state imagery. Galleries are
  explicitly detached art coverage, not claimed gameplay.
- `route-arcane-unit.log`: eight focused tests pass, including original RGBA,
  smoke/coral/backing, raster state marks, original registrations, real detail
  rather than 48px upscales, and rejected source/mapping/region/anchor drift.
- Source 1280/1920 and isolated Linux/Windows cohort probes each pass 2,919
  checks without runtime errors. They check all 54 exact atlas textures against
  an independent full-atlas PNG import oracle and preserve complete saves.
  The fixed earned Medium Day97 map has no matching affected states: its 2,380
  native blocker bodies are an unchanged control, not manufactured affected
  coverage. Actual Horizon start/ordinary wharf claim captures show the new
  unclaimed and controlled paintings at original coordinates (0,10), with
  ordinary vision and player-controller authority. The Prismhearth relay is a
  second unchanged gameplay control. Both resolutions were visually inspected.
- Before diagnostics recorded 162 intended size/region/pixel failures, plus
  incorrect harness assumptions subsequently corrected: these seven frontier
  shrines use the existing final mapping fallback, the wharf controller is
  `player`, and this native checkpoint contains none of these exact states.
  No game rules, ownership, fog or placement were changed to satisfy the probe.
- `route_arcane_shared` under `.artifacts/full_play_runtime_20260905/` passes
  the five existing distinct/decorative sprite, movement/input, route and fog
  reports. Six additional domain reports pass their individual complete runs:
  elite dwellings, elder sanctuaries, Horizon musters, Briarwheel, Unbound Road
  Ledger and Mireglass. Their eight-case outer runner exited 143 and is not
  called a clean suite. Two additional failures remain outside this art scope:
  Sevenfold's obsolete 17-node scenario assertion and Veil-Coast's blocked
  fixed route at (1,6), (1,5), (1,4). `route_arcane_unchanged_domain_failures.json`
  reproduces both exact failures with the previous `bbb6435c` release and
  unmodified historical test scripts. Two original physical PNGs were supplied
  only for those source-only image checks; this is a domain diagnostic, not
  package certification. The first attempt omitted those PNGs and crashed after
  the same domain failures; its logs are retained, not counted as a passing run.
- Both official export/startup/generated-map smokes pass, with artifacts in
  `/tmp/heroes-route-arcane-{linux,windows}-20260910` to avoid project-volume
  duplication. Exact packaged probes pass with no loose art/game overrides.
  Windows is headless Wine, not physical GPU/controller certification.
- `route_arcane_delivery_preservation.json` passes: both PCKs are 292,839,144
  bytes and retain the same 5,484 members. Only `project.binary` differs between
  platforms. Against `bbb6435c`, eight imported atlases, the art manifest and UID
  cache change; all 5,474 other members, including compiled gameplay/native/save
  owners, remain exact. Only 54 of 1,214 manifest rows change. All twelve complete
  source/package saves match the before checkpoint, excluding only cross-run
  timestamps/fresh authored session ids; within-run comparisons exclude nothing.
  Actual draw rectangles match before/source/Linux/Windows (float32 equivalent).

Repository validation's first run exposed only stale coastal art dimensions/hash
checks; those now verify the archived original and source-reconstructible current
atlas separately. `route-arcane-repo-final.log` passes repository validation;
`git diff --check` passes. All 66 baseline hashes for the unrelated untracked
retention/report/cache artifacts were verified unchanged before staging.
No fixed package ceiling, cache clearing, gameplay correction, RMG placement
change or Town-screen redesign is part of this checkpoint.

## Integrated physical state details — 2026-09-10

The seven previously unfinished Pactwright/Mireglass variants are now accepted.
Their low-resolution floating wax string/blue diamond came from the historical
state-atlas raster derivation, not a missing renderer mapping. Seven built-in
original image edits provide six wax seals on the Waydesk's ledger and distinct
counterseals physically attached to the Siltglass binding, Greenline plaque,
Reedflame trunk, Ossuary sash, Glowcap support and Kite-Signal shaft.

The generated files again contain opaque backing. Only reviewed foreground
patches were composited into the original transparent masters; the backing and
unrelated model repaint were rejected. Every pixel outside the recorded supports
is exact, and each support covers less than 2.5% of its master. Five variants
retain the original alpha byte-for-byte; the two small Glowcap/Kite clasp
extensions are recorded explicitly. This uses the owner's approved raster
processing, not runtime geometry or a shared drawn replacement.

Sources and full prompts: `art/overworld/source/generated/cutout_recovery_20260909/integrated_seals/`.
Its `previous/` freezes the `3a8084c5` recipe, proof and two affected atlases.
The updated route/arcane tool reconstructs the seven cells and proves the other
47 paintings plus seven unmarked neighbors unchanged. Both atlas paths, regions,
logical fit/anchor, content ids and every state resolver remain unchanged.
Only seven paintings and their descriptions/provenance change; seven base rows
receive only the shared atlas checksum update.

Consolidated evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `integrated_seals_source_1280_v3`, `integrated_seals_source_1920_v3`,
  `integrated_seals_packaged_linux_v3` and `integrated_seals_packaged_windows`
  pass all **3,012 checks each**, with no runtime errors. All fourteen final
  source site screenshots, source comparison sheets and representative packaged
  views were visually inspected. No detached markers or generated backing remain
  on these seven variants. Other visible unrepaired families are not accepted
  by association. Windows is headless Wine, not hardware visual certification.
- The sites are the existing seven campaign placements: (8,5) in Tollglass,
  Mudkeel, Lenscaptain, Votivejaw and Glassmarshal; (10,4) in Rotlamp and Daynote.
  Ordinary scouting reveals them; the last two include their real (9,6) artifact
  pickup. Their guarded site records remain exact. The earned native Medium
  checkpoint contains none of these seven; its 2,380 blocker bodies remain an
  unchanged control, not invented affected-native coverage.
- `integrated_seals_before_linux_v3` uses the SHA-locked preceding package and
  fails exactly the seven expected new-pixel assertions, no other assertion.
  `integrated_seals_delivery_preservation.json` proves all **50 full saves** equal
  across before/source/both packages, excluding only cross-run timestamps and
  fresh authored session ids. Within-run save checks exclude nothing. Actual
  draw rectangles match before/Linux/Windows, with float32 comparison on Windows.
- Both official export/startup/generated-map smokes pass in
  `/tmp/heroes-integrated-seals-{linux,windows}-20260910`. Both PCKs contain
  5,484 members and are **292,865,768 bytes**. Only `project.binary` differs by
  platform. Against `3a8084c5`, two imported atlases, the art manifest and UID cache
  change; the other 5,480 members, including gameplay/native/save owners, are exact.
- All 11 focused Python tests and the five shared sprite/movement/route/fog
  reports pass. Both affected six-chapter campaign reports pass rendered runs
  (`integrated_seals_domain_final`); only their two expected atlas hashes changed.
  Earlier insufficient-vision probes, a stopped headless campaign run and stale
  hash failures are retained diagnostics, not acceptance. The prior Sevenfold and
  Veil-Coast gameplay-test failures remain documented above and out of scope.

Repository and diff validation pass. All 66 hashes of pre-existing unrelated
untracked retention/report/cache artifacts remain unchanged. No gameplay, Town,
native/RMG, save-schema, package-budget or cleanup changes are included.

## Marchland command-site detail recovery — 2026-09-10

34 originals across `marchland_warband_musters`,
`marchland_grand_route_operations` and `commander_dominion_sieges` are now
accepted. Their genuine-alpha source paintings were clean, but the shipped
48px atlas cells discarded fine detail. This cohort is a resolution-quality
correction, not 34 newly confirmed magenta-key defects. Purple cloth, crystal,
smoke and magic are preserved. No new generation was necessary.

`tools/prepare_overworld_command_cutouts.py` projects the original paintings
directly into 192px cells. Every original 42px centered logical fit reproduces
the historical alpha and all visible RGB exactly; a shifted, cropped, re-keyed
or mismatched source now fails focused validation. The same three runtime
paths, all 34 site/state mappings, object identities and gameplay owners remain.
Original masters/prompts remain in their existing generated-source folders;
the `command_sites/recipe.json`, proof, retained before atlases and 34 trimmed
PNGs record the new source-to-runtime pipeline. No duplicate source masters,
procedural paint, generic replacements or palette-based removal were needed.

Actual affected gameplay captures use ordinary scouting to Tollbrand's original
site at (12,5), Cinderquill's at (20,7), and Quench's at (19,7). The latter two
include a normal end turn and the existing AI response. Guards and complete
site records are unchanged. The earned Medium Day97 map contains zero sites
from this cohort: its 2380 native blocker bodies remain an explicit unchanged
control. All-34 detached galleries are labeled art coverage, not gameplay.
Three actual site views at both 1280x720 and 1920x1080, all six original/source
comparison pages, all three small-resolution renderer galleries and a packaged
Linux site view were inspected visually: recovered detail, no matte backing or
new fringe, unchanged scene size and placement.

Acceptance evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `command_sites_before_1280`: exactly 102 deliberate failures (old region,
  48px cell and independent RGBA for each of 34 rows), zero runtime errors;
  all original scouting, state, native-body and save checks still pass.
- `command_sites_source_1280`, `command_sites_source_1920`,
  `command_sites_packaged_linux`, `command_sites_packaged_windows`: each passes
  2750 checks, five actual captures/observations, three detached galleries and
  zero runtime errors. Windows is headless Wine, not GPU visual certification.
- `command_sites_delivery_preservation.json`: 25 complete save files across
  before/source/Linux/Windows agree, excluding only save timestamps and fresh
  authored session IDs between runs; no fields excluded within each save test.
  Original placements and draw rectangles are identical (Windows float32
  representation accounted for). All 1180 other manifest rows and every state
  mapping are unchanged; all 34 original source hashes match.
- Six focused Python tests pass. Five shared sprite/input/route/fog reports
  pass in `../full_play_runtime_20260905/command_sites_shared/report.json`.
  The three existing domain smokes pass with all 34 required captures, 70
  representative battle fixtures, 34 claims and 34 save round trips in
  `../full_play_runtime_20260905/command_sites_domain_captured/report.json`.
  These controlled domain fixtures are not additional full playthroughs.
- The first domain adapter omitted capture-directory variables: all behavior
  checks passed but the three historical report gates correctly failed for
  zero captures. That initial adapter process returned 143 after its reports;
  it is not the accepted run. The corrected captured run exits 0. No gameplay
  assertion was relaxed. Final `python3 -B tests/validate_repo.py` and
  `git diff --check` pass.

Both official exports/startup/generated-entry flows pass, including packaged
Windows generated Overworld and Town/build entry. Fresh exports are in
`/tmp/heroes-command-sites-linux-20260910` and
`/tmp/heroes-command-sites-windows-20260910`; both PCKs are 293911032 bytes,
5484 members. Only `project.binary` differs by platform. Compared with
`95d1e047`, only three ctex payloads, the Overworld manifest and UID cache
changed: 5479 other members, including compiled game/native/save owners, are
byte-exact. Linux SHA: `da3cae5a831756dc98b3a53e6c22bc535d455d9b7e11cfbc65dfec7697990f46`;
Windows SHA: `57eaa3ae6dd07c2abeece732396f6061dbaf1d4135f60c18152453d3916b0b60`.
Source art is excluded from both packages. Tightening the historical-pixel
validator refreshed proof metadata only; all prepared/runtime rasters stayed
identical. Logs are `/tmp/heroes-command-*-20260910.log`, including
`unit-final`, `repo-final`, both exports, packaged probes and captured domains.

This is a 34-asset checkpoint, not full-pool or release completion. All known
pre-existing unrelated untracked retention/report/cache files are preserved;
the 66-file hash baseline still passes. No cleanup, gameplay, native/RMG,
Town-screen, save-schema or package-budget changes are included.

## Recruitment and habitat recovery checkpoint — 2026-09-10

36 runtime rows in three same-path atlases now use direct 192px source
projection. **34 quality dispositions are accepted; two clipped-mast source
repairs remain pending.** This is not closure of the full recruitment cohort.
Original Unbound Wild Concords paint is unchanged. Veteran musters retain
their original paint except reviewed low-alpha clipped-colour noise and three
disconnected fragments from adjacent sheet cells. The original identity sheet
confirms those fragments belong to the next row's mast tops, not map objects.
The Prismwake and Gaugecoil habitats also receive low-alpha RGB repair;
intentional nacre, purple crystal, fabric and valve colours remain.

Frontier Mythic Habitats previously stamped a procedural flag and ellipse onto
each controlled state (`tools/author_six_frontier_mythic_habitats.py:180`). Six
approved built-in image edits replace those marks with physically attached
cloth or active gauge lighting. The tool returned opaque backing; only reviewed
foreground paint is composited into genuine-alpha originals, with two bounded
cloth extensions. Nothing outside the recorded repair masks changes. Prompts,
six generated originals, recipe and proof are retained under
`art/overworld/source/generated/cutout_recovery_20260909/recruitment_sites/`;
36 trimmed cells and 20 recovered masters are in the matching trimmed folder.
`tools/prepare_overworld_recruitment_cutouts.py` reconstructs them fail-closed.
The 44px south/42px centered/43px bottom-46 logical registrations remain.
Frontier's historical base pixels reconstruct exactly; older family filter/
quantization differences are recorded, not claimed as exact reconstruction.

Accepted evidence under `.artifacts/overworld_cutout_quality_20260909/`:

- `recruitment_sites_source_1280_imported`, `recruitment_sites_source_1920`,
  `recruitment_sites_packaged_linux`, `recruitment_sites_packaged_windows`:
  2830 checks each, zero runtime errors, ten actual views/observations and three
  labelled all-36 detached galleries. Eight affected original sites are reached
  through ordinary scouting, with normal end turns where needed. No placements,
  guards, ownership or fog are granted. The earned Day97 native checkpoint has
  zero affected sites; its 2380 blockers remain unchanged controls.
- `recruitment_sites_before_packaged_linux_routed`: the exact `ee73e59f`
  predecessor PCK produces only the 108 expected region/size/RGBA failures.
  The opt-in ancestor-manifest selector retains strict manifest and texture
  validation; default current-release validation remains unchanged.
- `recruitment_sites_delivery_preservation.json`: all 50 complete save files
  across predecessor, two source resolutions and both packages agree, excluding
  only timestamps/fresh authored session IDs between runs and no fields within
  save tests. Placements, state routes and draw rectangles agree; all 1178 other
  manifest rows and all compiled gameplay/native/save owners are unchanged.
- Seven focused Python tests, the five shared sprite/input/route/fog reports,
  and all three domain smokes pass (`recruitment_sites_shared` and
  `recruitment_sites_domain_current` in the full-play validation folder).
  Domain fixtures exercise guarded claims, recruitment, weekly delivery and
  saves, plus the six-chapter Unbound campaign; they are not new full playthroughs.
  The veteran smoke's old skirmish-only/five-hook assertions were updated to
  the already-shipped Six Sealed Companies campaign availability/six hooks;
  content and gameplay rules are unchanged.

All six comparison sheets, three small renderer galleries, eight small gameplay
views, a wide gameplay view and a packaged Linux view were inspected. Original
and generated sources were inspected too. Earlier blocked scouting coordinates,
stale Godot imports, stale veteran-test expectations and initial predecessor
argument-forwarding failure are diagnostics, not accepted evidence. Windows
checks run headless under Wine, not real Windows GPU certification.

Official Linux and Windows export/startup checks pass; packaged probes enter
earned generated maps, and Windows also exercises generated Overworld/Town
building entry. Exports: `/tmp/heroes-recruitment-{linux,windows}-20260910`.
Both PCKs: 294968040 bytes, 5484 members; only `project.binary` differs between
platforms. Versus the predecessor, only three ctex files, art manifest and UID
cache differ; 5479 members are identical. Linux SHA:
`0a0c9f30e9552ab5910c3ac4a66cf4b4c29c5f42252cd6b406c339ec39421905`;
Windows SHA: `0b560a60884fd39031e4be8d0692969e3bf841778a7e4d5554c903d5bd4ce75b`.
Repository and diff checks pass. Logs: `/tmp/heroes-recruitment-*-20260910.log`.
All 66 pre-existing unrelated file hashes still match; no cleanup occurred.

At that checkpoint, remaining source repairs were controlled `three_gauge_chapter_foundry`
and `fog_keel_lastwatch_mooring`. Their 362px historical sources clip mast tops
which remain visible in the original 1448x1086 veteran identity sheet (connected
foreground bounds [362,689,696,1056] and [1104,700,1419,1078]). Their current
edge/detail improvements pass regression, but do not restore those missing tips.
Exclude these two IDs from accepted-disposition unions until reconstruction and
visual acceptance are real. The following completion closes these two repairs.

## Veteran mast-top completion — 2026-09-10

The two deferred recruitment dispositions above are now accepted. Both 362px
masters are **byte-exact grid crops** of the retained 1448x1086 original sheet.
The northern crop boundary at y=724 cut through their painted masts. The
Foundry's connected foreground starts at y=689 (74,998 pixels, bounds
[362,689,696,1056]); Mooring starts at y=700 (73,413 pixels, bounds
[1104,700,1419,1078]). The original sheet SHA is
`ffd967019382bf44876f04187c23dbedd15f68bab3c97b104d9b0d7ff6c139b1`.

The recruitment preparation tool recovers only those connected northern pieces,
including their two-source-pixel low-alpha fringe, through the original logical
scale and anchor. It does not shrink, shift or repaint either building. Only
194 Foundry and 186 Mooring runtime pixels change, within the extension and
one bilinear seam row; every body pixel below that seam remains exact. Cell-edge
alpha maxima are 26/12: the complete opaque finials fit, with only antialias
support at the boundary. The other **34 states remain byte-identical**, including
the earlier removed stray fragments and six generated physical details.
No new generation was needed. Original-sheet hash, exact crop/component proof,
two complete recovered masters and frozen predecessor recipe/proof/runtime cells
are retained in the existing recruitment source/trim packet (`before_mast_completion`
and the two `sources/*_controlled_complete.png` derivatives).

Consolidated evidence in `.artifacts/overworld_cutout_quality_20260909/`:

- `mast_source_1280_final`, `mast_source_1920_final`, `mast_packaged_linux`
  and `mast_packaged_windows`: **2856 checks each**, zero runtime errors, 36
  exact state routes, three labelled detached galleries and 11 actual map
  observations. Fog-Keel wins its original guard battle through shipped Quick
  Resolve, acknowledges casualties, claims normally and walks away to expose
  the mast while retaining ordinary vision. No army, guard, ownership, position
  or fog grants. The direct Foundry starter assault genuinely loses on Day 2;
  its terminal save is retained, not represented as an earned controlled-art
  capture or a claim that the scenario cannot be won. Foundry visual acceptance
  uses original paint and the unobscured, explicitly detached renderer gallery.
- `mast_before_packaged_linux`: the exact `e75cde7f` predecessor PCK fails only
  the two expected RGBA checks. Its battle outcomes and complete saves match.
- `mast_completion_preservation.json` / `verify_mast_completion.py`: all **60
  full save files** agree across five deliveries, excluding only save timestamps
  and fresh authored session IDs between runs; no fields are excluded within
  round trips. All placements, draw rectangles, native masks and state mappings
  are unchanged. The Day97 native map still has zero affected sites and 2380
  unchanged blocker bodies; it is a control, not corrected-site evidence.

Nine focused Python tests, all five shared reports (`mast_shared`), all three
recruitment domain reports (`mast_domain_final`), repository validation and diff
checks pass. The domain reports verify controlled claim/state/recruitment/save
fixtures; their artificial battle resolution is not a normal-play victory.
Their Foundry capture has hero overlap, so it is not the unobscured visual proof.
Both resolutions, source masters/comparison, before/after controlled galleries,
actual Mooring gameplay and the Linux-package view were inspected directly.
Initial probe diagnostics exposed a null scene during battle handoff and an
incorrect assumption that the direct Foundry assault would win; final probes
wait for the actual handoff and retain the genuine loss. The first domain
wrapper exited 143 after all three child reports exited 0; the standard file-
launched rerun completes exit 0. Those initial runs are not the acceptance runs.

Official exports/startup and packaged generated-map entry pass on both platforms;
Windows also passes its generated Overworld/Town building flow. Windows uses
headless Wine, not physical GPU certification. PCKs in
`/tmp/heroes-mast-{linux,windows}-20260910/export/` are **294969576 bytes / 5484
members**. Only `project.binary` differs by platform. Against the predecessor,
only the veteran atlas ctex, art manifest and UID cache change; **5481 other
members**, including compiled gameplay/native/save owners, are byte-identical.
The manifest changes only the shared atlas hash on its 12 rows. Linux SHA:
`7e58fa11ecb5b31be67484d42cba5caa17eae647ecfac361f1ea1b8ddd244fd2`;
Windows SHA: `5d26066ad701e80e9509b015f5ea77da3d03baca08db4cfbf3e2f4add6065084`.
Logs: `/tmp/heroes-mast-*-20260910.log`; no source paintings enter the packages.
All 66 known unrelated file hashes are preserved. No cleanup, gameplay/native/
RMG/save, Town-screen or package-budget changes. This completes the recruitment
cohort, not the full art goal or release readiness.

## Command/training originals — 2026-09-10

Forty paintings are now recovered across Doctrine Expeditions (8), Proving
Roads (8), Field Mastery (6), Garrison Warrants (6), Twin Councils (6) and Named
Rival Banners (6). These are original authored resource-site identities, not
missing manifest assignments or procedural fallbacks. Their old 48px atlases
discarded substantial source detail. Twenty-nine masters also contain 150,404
saturated RGB outliers at alpha 1..4; these are near-transparent quantization
noise, not a justification for removing painted purple material.

`tools/prepare_overworld_training_cutouts.py` reprojects the retained genuine-
alpha originals directly into 192px cells, never upscaling the old 48px sprites.
Only those scoped noisy RGB samples borrow nearest original foreground RGB
(alpha at least 128); alpha,
opaque paint and all other original pixels stay exact. Preserve the historical
42px centered fits, six 44px Twin Council fits and six bottom-aligned Named
Rival fits. Sixteen historical projections match exactly. The other twenty-four
older filtered PNGs have alpha MAE below 4/255 and opaque RGB MAE below 8/255;
that is cross-filter registration evidence, not byte equality. Every installed
pixel reconstructs exactly from the new recipe and unchanged source hashes.

The source review does **not** establish missing Bellfounder or furnace caps:
Bellfounder's cap has transparent top padding; only three faint furnace edge
pixels exceed alpha 128, with maximum 179. The close-up and rendered results
retain the complete visible structures. No new generation was needed for this
cohort. Intentional Rotlamp smoke, violet cloth, magical mirrors and crystals
remain intact. The six original source manifests are immutable. Original PNGs,
recipe, before atlases and preparation proof are retained under
`art/overworld/source/generated/cutout_recovery_20260909/training_sites/`;
derived cutouts are in the corresponding `source/trimmed/` directory.

### Consolidated evidence

Eight tests in `tests/test_overworld_training_cutouts.py` pass, including exact
reconstruction, alpha/opaque preservation, saturated-purple protection and
fail-closed mapping/source/crop/anchor/noise mutations. Existing source/package
drivers use `--batch training_sites`; the independent oracle applies Godot's
unchanged full-atlas alpha-edge processing, never loose art overrides.

Under `.artifacts/overworld_cutout_quality_20260909/`:

- `training_source_1280`, `training_source_1920`,
  `training_packaged_linux_final`, `training_packaged_windows`: **2,836 checks
  each**, 40 state-resolved original textures, no runtime errors. Four labeled
  detached galleries cover all forty paintings; six actual authored sites are
  exposed by ordinary Day-1 scouting, without moving objects, granting fog or
  claims. Native Day-97 retains 2,380 blockers and contains no affected sites;
  it is explicitly an unchanged control, not invented cohort-placement proof.
- `training_before_packaged_linux`: exact `57f22488` predecessor PCK rejects
  all forty cells on region, resolution and independent RGBA checks (120
  expected failures), with no runtime errors or other failing assertions.
- `training_sites_delivery_preservation.json` and
  `verify_training_sites_delivery.py`: **40 full-save comparisons** across the
  four deliveries and predecessor; only save timestamp and fresh authored
  session IDs are excluded between runs, nothing within save/load roundtrips.
  Original placements and world-space draw rectangles remain unchanged.

All five source contact pages, seven source/prepared comparison pages and four rendered gallery pages,
small/wide actual scouting views and final packaged Linux views were visually
inspected. They retain fine connected details without pink fringes, detached
sheet residue or invented geometry. Windows texture/state/save validation is
headless Wine, not hardware-GPU screenshot acceptance.

All six existing domain smokes (`training_domain_final`) and five shared
sprite/decorative/movement/fog reports (`training_shared`) pass. Domain smokes
retain their existing controlled battle/claim fixtures; they are not six new
end-to-end playthroughs. The initial domain and Linux-probe outer launchers
ended 143 after successful inner reports; final direct-exec repeats finish 0.
Both original runs remain diagnostic evidence, not the final launcher result.
`python3 -B tests/validate_repo.py` and `git diff --check` pass. Logs are
`/tmp/heroes-training-*-20260910.log`; no per-image export cycles were used.

Both official export/startup checks pass, including Windows Town runtime and
generated-map entry. PCKs at `/tmp/heroes-training-{linux,windows}-20260910/export/`
are **296,267,688 bytes / 5,484 members**. Linux SHA-256:
`d57848fc22ee8726a25dd6704e985a0dbff233852224ebe516f784fbc609e2af`;
Windows SHA-256:
`5455ecd81b264fbde109a32013743478ef1ff764a34c2fdda87ec68e31d88f91`.
Platforms differ only in `project.binary`. Relative to `57f22488`, only six
texture payloads, the art manifest and UID cache differ; **5,476 members**,
including every compiled gameplay/native/save owner, remain identical.
Source paintings stay excluded. Exactly forty art rows change; all routing
tables and the other 1,174 rows remain exact. No cleanup or unrelated changes.

## Contract and expedition encounter originals — 2026-09-10

All 52 paintings are accepted after source, visual, runtime and Linux/Windows
delivery checks. This is a checkpoint, not full runtime-pool or release
acceptance; the parent and selected child remain in progress.

The nine same-path atlases cover Dissident Fronts, Standalone/Outer Reach/
Mire-Sun Contracts, Ascendant Companies, Waywatch Trials, Spellwright
Expeditions, Ritual Relay Circuits and Grand Convergence Marches. All 52
retained RGBA originals were visually inspected. Their rich painting was
being reduced to 48px cells; 30 sources also contain 105,994 saturated RGB
outliers at alpha 1..4. The approved original-source workflow recovers that
detail directly at 192px and replaces only those reviewed near-transparent
RGB values with nearest original alpha-128+ foreground color. No alpha,
opaque paint, legitimate purple material or other source pixel is changed.
No new generation, color key, invented geometry or runtime filtering is used.
The Drum Cordon's topmost faint edge reaches alpha 175; its connected painted
hook was inspected at source and runtime size, not erased as an edge count.

`tools/prepare_overworld_contract_cutouts.py` and
`cutout_recovery_20260909/contract_encounters/{recipe,manifest}.json` preserve
all 52 original hashes, nine original provenance manifests and archived 48px
atlases. Documented 42/44px fits and centered/bottom registrations are retained.
Historical raster filters differ: maximum alpha MAE 4.6671 and opaque RGB MAE
8.14983 are bounded registration evidence, not byte equality. Every installed
pixel reconstructs exactly from the retained source and recipe. Atlas paths,
identity routes and the commander's priority over a non-preferred landmark
remain unchanged. All 1,162 other art rows and every routing table are exact.

Eight focused Python tests pass, including complete reconstruction, purple/
alpha preservation and fail-closed mapping/crop/anchor/provenance mutations.
`tests/overworld_contract_cutout_probe.py` uses the existing shared drivers with
`--batch contract_encounters`. Evidence is under
`.artifacts/contract_delivery_20260910/`, a new symlink to
`/tmp/heroes-contract-delivery-20260910`; the file-launched adapter
`/tmp/heroes-contract-delivery-20260910.py` changes only evidence placement.

- `source_1280`, `source_1920`, `packaged_linux`, `packaged_windows`: 2,899 checks each, zero game
  runtime errors. Five explicitly detached galleries cover all 52 textures.
  Nine real authored fronts are exposed by ordinary Day-1 scouting; no direct
  fog, coordinate, encounter-resolution or commander-priority mutations.
- The unchanged earned native Medium Day-97 save retains 2,380 blockers and
  eleven affected but already-resolved encounters. The actual draw index must
  keep all eleven absent. These are cleared-state controls, not fabricated
  unresolved-encounter screenshots. Every rendered capture preserves a full
  actual save/load roundtrip.
- `before_packaged_linux_terminal`: exact `94138278` predecessor rejects the
  52 old regions, canvas sizes and independent full-atlas RGBA hashes (156
  expected failures), with no unrelated failures or runtime errors; exit 1.
- `contract_encounters_delivery_preservation.json` and its adjacent
  `verify_contract_encounters_delivery.py`: 60 complete-save comparisons
  across the four current deliveries and predecessor, exact original
  placements and matching draw geometry. Only timestamps and fresh authored
  session IDs are excluded between runs; nothing is excluded within actual
  save/load roundtrips. All 52 source hashes and all routing tables are exact.

All seven source contact pages, nine original/recovered comparisons, five
rendered galleries, small/wide authored views and final Linux package views
were inspected. The selected paintings have clean connected detail; unrelated
blurred medallions/other pending families in those maps are not accepted here.
The full-atlas PNG oracle retains Godot's existing alpha-edge processing;
packages receive hashes and probe code, never loose replacement textures.

All five shared sprite/decorative/movement/fog reports pass at
`/tmp/heroes-contract-shared-suite-20260910/contract_shared/report.json`.
`python3 -B tests/validate_repo.py` and `git diff --check` pass. Nine existing
domain reports were run, not silently relaxed: Dissident passes, while the
other eight retain **74 failures** concerning old skirmish/objective and
placement/battle expectations. Running their exact original scripts from
`94138278` inside its unchanged predecessor PCK reproduces every error and
exit code, with zero new failures. Evidence:
`/tmp/heroes-contract-domain-suite-20260910/contract_domain/report.json` and
`/tmp/heroes-contract-domain-before-20260910/report.json`. These are baseline
limitations, not nine passing reports or new end-to-end playthroughs.

Official Linux and Windows export/startup checks pass, including Windows Town
and its 23-step generated-map/build flow. Final exports are
`/tmp/heroes-contract-linux-20260910/export/` and
`/tmp/heroes-contract-windows-final-20260910/export/`. Both PCKs contain
297,968,472 bytes / 5,484 members. Platforms differ only in `project.binary`;
versus `94138278`, nine texture payloads, the art manifest and UID cache change.
All 5,473 other members, including compiled gameplay/native/save owners, match.
Linux SHA-256: `66d9f97d72d315aa1c8e5810e8f75af7e4b5a4af5cc3e019051139c796e30318`.
Windows SHA-256: `0447501e9e208d9d1d1b328a2c55d7e0c23d2e2276367723c64d623390e1654d`.
Windows remains headless Wine, not hardware-GPU visual certification.

Initial scout captures correctly failed three earned-vision assertions; the
final scouts take an additional legal step. Interrupted outer launchers and
the first incomplete Windows run remain diagnostics. Linux's final game and
package reports pass, although its outer launcher returned 143 after writing
them. Full child-process tracing made Wine initialization exceed 180 seconds;
that failed report is retained as `windows-child-trace-timeout-report.json`.
The final Windows export without child tracing and Windows cohort probe both
exit 0; the latter uses a fresh `/dev/shm/heroes-contract-wine-20260910` prefix
to avoid filling the root disk. Only that batch's
disposable failed Wine workspace was reset by the official smoke; prior
evidence, project caches and unrelated untracked retention files are untouched.

## Remaining encounter paintings — 2026-09-10, accepted

The next coherent group is implemented and accepted after consolidated validation:
79 original-paint recoveries across eleven atlases (73 cells) and six signature
PNGs, with six clean faction landmarks preserved byte-for-byte. All 85 source
paintings, the eight-page 1280x720 renderer gallery, all twelve ordinary-scouting
screenshots and the unchanged native-map control were visually inspected. No
magenta mats or sheet borders are visible on those repaired encounter subjects;
this is not acceptance of the unrelated Town/terrain/remaining-art surfaces.
Atlas cells are now 192px and signatures 256px, reprojected from the large
originals with their existing logical registrations. Frontier Watch's nominal
source PNGs were only 48px derivatives; the genuine 1536x1024 original sheet
supplies those six recovered cells. Horizon Compact keeps its original full-cell
fit; other family-specific centered fits remain unchanged. Across 53 sources,
315126 reviewed alpha-1..4 saturated RGB samples borrow original foreground RGB;
alpha and every other source pixel remain untouched. No generation was needed.
Recipe/proof: `art/overworld/source/generated/cutout_recovery_20260909/remaining_encounters/`.
Owner: `tools/prepare_overworld_remaining_encounter_cutouts.py`.

Real evidence retained:

- Final focused Python suite: 8/8, `/tmp/heroes-remaining-encounter-python-final-20260910.log`.
- Source 1280x720: 3178 checks, zero runtime errors, 85 exact raster/routes,
  15 complete save round-trips and 12 unchanged original encounter fronts
  reached on Day 1 through ordinary scouting. The 2380-body native control and
  57 affected native records remain their earned state; all 57 are already
  resolved, not visible corrected encounters. Evidence:
  `/tmp/heroes-remaining-encounter-delivery-20260910/source_1280_clear_scout/`.
- Repository validation passes again after the external artifact removal and
  separate cleanup commit in
  `/tmp/heroes-remaining-encounter-repo-current-20260910.log`. The earlier
  `/tmp/heroes-remaining-encounter-repo-20260910.log` remains retained. The final
  preparation-tool file-handle closure fix preserves exactly the same runtime
  bytes and passes the focused suite.
- Official Linux export/startup and Windows export/startup/generated-map/Town
  flow pass. PCKs are 300776216 bytes, 5484 members; only `project.binary` differs
  between platforms. Against `23d20edf`, only 17 imported textures, the art
  manifest and UID cache change; all 5465 other payloads, including compiled
  gameplay/save/native owners, are exact. Exactly 79 art entries change; all
  other 1135 entries and every routing table are identical. These are package
  inventory proofs, supplemented by the completed cohort-specific packaged
  gameplay probes below.
  Reports: `/tmp/heroes-remaining-encounter-linux-20260910/report.json`,
  `/tmp/heroes-contract-windows-final-20260910/report.json` and
  `/tmp/heroes-remaining-encounter-delivery-20260910/payload-preservation.json`.
- Twelve existing domain reports ran: seven pass; the five failing reports'
  fourteen complete error strings and exit codes exactly reproduce against
  the retained `23d20edf` Linux PCK using that commit's unedited test scripts.
  These concern the old Roadward unit-fallback expectation, catalog breadth
  and previously recovered standard-atlas geometry; no new failures in this
  twelve-report comparison. Reports and fail-closed comparison:
  `/tmp/heroes-remaining-encounter-domain-suite-20260910/remaining_domains_final/report.json`
  and `/tmp/heroes-remaining-domain-before-complete-20260910/comparison.json`.
  Three original reports read raw PNGs directly; the baseline runner supplies
  exactly nine Git-original reference rasters excluded from the release pack,
  with individual hashes recorded. The PCK and test assertions are unchanged.
  The earlier attempt without those reference inputs crashed in three reports;
  `/tmp/heroes-remaining-domain-before-20260910/` is retained, not acceptance.
  Seven passing geometry assertions subsequently had only their stale error
  wording corrected to describe the recovered dimensions; no predicate changed.
- Both distinct/decorative sprite reports and the movement-input report pass
  in `/tmp/heroes-remaining-encounter-shared-suite-20260910/remaining_shared/report.json`.
  That outer launcher exited 143 after the three completed reports, so it is
  not recorded as a five-test pass. The remaining route and fog reports both
  pass in the separately resumed `remaining_shared_tail/report.json` beside it.
  All five individual reports pass; the interrupted wrapper is retained.

Earlier candidate probes exposed test-route mistakes: distant stops caused
unnecessary normal AI turns, and an interactable destination started a battle.
The final probe excludes interaction destinations and stops within ordinary
vision. Production movement/combat rules and all encounter records are unchanged.
Those failed probes are retained and not acceptance evidence.

**Resolved fixture blocker:** at approximately 05:12 UTC, concurrent activity outside this run
removed `.artifacts/generated_full_match_quality_20260906` and its secondary-volume
target. Free space rose from roughly 1 GB to 54 GB. The exact required fixture
`medium_match_11_continuation_01/data/godot/app_userdata/heroes-like/saves/autosave.json`
(SHA256 `1734cf2274e00eb763b94db4f814f4ffc73e30bb9377a9225b36bcc3780e0fcc`)
is gone. The first 1920x1080 probe failed before launch with FileNotFoundError;
cohort-specific packaged probes had not run then. No byte-identical copy was found among
the surviving candidate temporary save/checkpoint files. The successful run's
complete manual save survives at
`/tmp/heroes-remaining-encounter-delivery-20260910/source_1280_clear_scout/native_saved_session.json`
(SHA256 `d4b6cac54c25fc42456bdb7fdd3d4a9d0ed37fda8115dd63afe29d05b18bb1c1`).
The owner subsequently approved this exact replacement ("yes go ahead use it").
The bytes are now pinned under
`tests/fixtures/overworld_cutout/native_day97_roundtrip.json`, with their complete
lineage in adjacent `provenance.json`; no save fields were edited. Three focused
tests pass, including rejection of altered or missing input. Both source and
package drivers retain every original runtime/save assertion. The completed
checks below use this separately identified control. This does not rewrite
historical evidence or claim native generation changed.

Consolidated acceptance with the approved pinned control lives under
`.artifacts/remaining_encounter_delivery_20260910/` (the retained symlink to
`/tmp/heroes-remaining-encounter-delivery-20260910/`):

- `source_1280_repin`, `source_1920_repin`, `linux_1280_repin_complete` and
  `windows_1280_repin`: **3,178 checks each**, exit 0 and zero runtime errors.
  Each resolves all 85 exact textures/routes, preserves 15 complete actual
  save/load round-trips and reaches twelve real authored fronts through
  ordinary Day-1 scouting. The unchanged native control retains 2,380 blockers;
  all 57 affected native encounters remain resolved, not fabricated visible
  encounters. Both package reports prove unchanged PCKs and retained assertions.
- `linux_before_repin_final`: the exact `23d20edf` predecessor completes all
  3,178 checks and fails exactly **231 art assertions** (79 canvas sizes,
  79 independent full-atlas raster oracles and 73 atlas regions), expected exit 1.
  No other assertion or runtime failure occurs; six clean controls still pass.
- `acceptance-repin.json` and adjacent `verify_repin_acceptance.py` prove the
  exact expected predecessor failures and **60 complete saved-state comparisons**
  across the four current deliveries and predecessor. Cross-run comparisons
  exclude only `saved_at_unix` and fresh authored-session IDs; native session
  identity remains compared. Actual within-run round-trips exclude no fields.
- `payload-preservation-repin.json` and adjacent `verify_payloads_repin.py`
  prove all 5,465 unrelated predecessor payloads, original source hashes,
  1,135 unaffected art entries and every routing table remain exact. Linux and
  Windows differ only in `project.binary`; neither test-fixture file is shipped.
- All twelve final 1920x1080 authored views, all eight wide rendered gallery
  pages and the native control were inspected. Final Linux 1280x720 gameplay
  captures and a direct before/after Frontier Watch comparison were also
  inspected: original sharp detail replaces the old 48px derivative without
  magenta mats or sheet borders on the selected subjects. Detached galleries
  are coverage evidence, not earned gameplay. Windows remains headless Wine,
  not hardware-GPU visual certification.
- The eight art tests and three fail-closed fixture tests pass. Final
  `python3 -B tests/validate_repo.py` passes in
  `/tmp/heroes-remaining-encounter-repo-repin-20260910.log`; shared/domain
  results and their explicitly reproduced legacy failures remain as above.

Two initial outer launchers returned 143 after their Godot reports were written;
they are retained as diagnostics, not package acceptance. Standalone Linux and
predecessor reruns completed normally. The package-isolation guard correctly
rejected an interrupted probe directory; that directory was moved intact into
its diagnostic evidence before the final rerun. The completed Windows run used
the existing owned-prefix cleanup helper: recreatable system files were removed,
while prefix user data, reports and receipts were retained. No project cache
was deleted. These 79 repairs and six unchanged dispositions bring acceptance
to **921/1214**, leaving **293 pending**; neither parent nor child is completed.

For the official Windows rerun, this run moved the preceding accepted export,
reports and generated-flow evidence intact into
`/tmp/heroes-contract-windows-final-20260910-baseline/`; the official smoke reset
only its own disposable Wine prefixes. The prior contract Windows paths above
now refer to that baseline directory. This run did not remove the native save
or the full-match artifacts, and did not delete project caches. The four
pre-existing unrelated untracked retention paths remain hash-preserved;
`tools/wine_prefix_cleanup.py`, `tests/test_packaging_wine_cleanup.py` and edits to
`tests/packaging_windows_export_smoke.py` and
`docs/packaging-windows-export-smoke-report.md` appeared from concurrent work.
They were subsequently committed separately as `2dd6d74f` and are not part of
this art batch. Local HEAD, origin/main and the live remote were verified at
that cleanup commit before finalizing this cohort. The unrelated retention
paths remain hash-preserved and excluded from the art commit.

## Artifact original-source field recovery — 2026-09-10, accepted

All 69 artifact field identities were inspected against their original art.
Three compact atlases held 36 paintings at only 48px per cell: 18 Three Relic
Pilgrimages, six Marchland Retinue Heirlooms and 12 Command Relic Marches.
Their retained original RGBA masters have usable detail; no regeneration was
needed. Twenty-four originals also contain saturated RGB noise at alpha 1–4
(161656 pixels). Scoped original-foreground RGB recovery preserves every alpha
sample and every unselected RGB sample, including opaque purple crystals and ink.
The 33 clean standalone 512px paintings and all 69 inventory icons are unchanged.

`tools/prepare_overworld_artifact_cutouts.py` reconstructs the original paintings
at fourfold density on 192px cells in the same three runtime files. The explicit
42px-in-48px centered logical fit, world profile, identity routes and footprints
remain authoritative. Historical two-stage icon filtering is not claimed
pixel-identical: the frozen recipe records alpha/opaque-RGB differences, and
all 36 before/after source registrations were visually reviewed. This is direct
original paint, not enlargement of the old 48px or inventory images. The packet
under `art/overworld/source/generated/cutout_recovery_20260909/artifacts/`
retains all three old atlases, original-source/icon/provenance hashes, exact
registrations and reproducible processing; its 36 derived cutouts are under the
matching trimmed directory. Source history remains immutable; validation checks
the historical atlas against its old provenance and reconstructs the live pixels
separately rather than replacing old source hashes with new output hashes.

Accepted evidence: eight Python art tests, three fixture tests, all six existing
artifact/domain reports, five shared sprite/input/route/fog reports and 3164
assertions at each source resolution and in each official platform package pass.
The exact `6e2d6c29` predecessor fails only the 108 expected canvas/region/raster
assertions, with zero unrelated/runtime failures. All 48 complete-save comparisons
pass, excluding only cross-run timestamps and fresh authored session ids; native
session identity and all actual round-trip fields remain checked. All 1178 other
art rows and 5479 unrelated packaged payloads are exact, including compiled
gameplay/save/native owners and all inventory icons. Only three textures, the
art manifest and UID cache changed. Linux/Windows PCKs each contain 5484 members
and measure 301907848 bytes; only platform `project.binary` differs. Both official
exports pass; Windows also exercises fresh generated-map/Town entry. This is
headless Wine evidence, not real Windows GPU/controller certification.
`python3 -B tests/validate_repo.py` and `git diff --check` pass. The full-pool
baseline advances to **990/1214**, leaving **224 pending**; neither slice completes.

Evidence roots: `.artifacts/overworld_cutout_quality_20260909/` labels
`artifact_source_1280_current`, `artifact_source_1920_current`,
`artifact_linux_current`, `artifact_windows_current`, `artifact_linux_before`,
`artifact_domains_current` and `artifact-acceptance.json`.
All six detached galleries and actual 1280/1920 gameplay were visually inspected.
Seven original authored artifacts are revealed by ordinary scouting; four are
collected through ordinary movement and disappear normally. Three guarded cases
retain their actual guards; the separate unchanged domain reports exercise their
existing reward flows. Native control: 2380 unchanged blockers and all 22 original
artifact placements (21 collected, one still available), not invented placements
or forced fog. Detached identity coverage is not presented as earned gameplay.

Reproduce with `python3 -B -m unittest discover -s tests -p
test_overworld_artifact_cutouts.py`, then
`python3 -B tests/overworld_cutout_batch_regression.py --batch artifacts --label
<fresh> --resolution <1280x720|1920x1080>`. Use the unchanged packaged driver with
`--binary`, `--pack`, `--platform`, `--batch artifacts` and a fresh label/prefix.
The same exact assertions remain active in predecessor runs selected explicitly
with `--baseline-manifest-commit 6e2d6c29`. Consolidate with
`.artifacts/overworld_cutout_quality_20260909/verify_artifact_acceptance.py`.
Domain evidence uses `/tmp/heroes-artifact-suite-20260910.py`, which redirects
only output destinations and runs the six existing source reports unchanged
apart from their maintained high-resolution atlas assertions. No game, Town,
native/RMG, inventory-icon, save-schema or balance code changes.

Official exports: `/tmp/heroes-artifact-{linux,windows}-20260910/report.json`.
Repository log: `/tmp/heroes-artifact-repo-final-20260910.log`; Python log:
`/tmp/heroes-artifact-cutout-python-20260910.log`. Two earlier pipe-launched
validation processes exited 143 without a completed result; those are not passes.
The full repository rerun passes. The first shared suite retains two passing
sprite reports; its three unfinished input/route/fog reports pass separately in
`.artifacts/full_play_runtime_20260905/artifact_shared_remaining_20260910/`.
Fresh temporary Wine prefixes are retired by the established helper, preserving
users and reports. Pre-existing unrelated retention files remain hash-exact.

## Remaining parent work

The full 1,214-row runtime pool is **not accepted**. The then-remaining 783 rows
received a first-pass visual contact review across all six remaining family
groups; those contacts and 32 color candidates are not final per-row acceptance.
The accepted cohorts now cover 990 repaired/preserved dispositions, leaving
224 for complete detailed review/recovery. The two veteran mast repairs are now
included only after the separate source/visual/platform closure above.
All 31 recurring encounters, 30
recurring resource-site originals, 31 separate claimed dwellings and 34 early
post-interaction and 40 landmark/objective-state paintings are accepted.
The 34 command-site originals, all 36 recruitment/habitat dispositions and the
40 command/training paintings and 52 contract/expedition encounter paintings
are accepted, along with the remaining 79 encounter recoveries and six faction
controls above. All 69 artifact dispositions are accepted above. Next: the 54
remaining resource-site atlas rows, then hero/Town/other runtime families.
The seven
Pactwright/Mireglass states are accepted only by the explicit integrated-edit
follow-up above; recovery of these originals does not accept different paintings.
Individual source and native-resolution
checks of other remaining families and intentional purple materials remain. Existing
unit medallions and state indicators are not mislabeled as magenta matte.
Do not hide remaining defects or claim release readiness from this checkpoint.
