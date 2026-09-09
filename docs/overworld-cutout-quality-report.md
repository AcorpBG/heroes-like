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

## Remaining parent work

The full 1,214-row runtime pool is **not accepted**. The remaining 783 rows have
now received a first-pass visual contact review across all six remaining family
groups; those contacts and 32 color candidates are not final per-row acceptance.
The five cohort recipes cover 454 repaired/preserved dispositions, leaving 760
for complete detailed review and any necessary recovery. Next are 24 recurring
encounter regions whose historical atlas has only binary alpha despite sources
retaining full alpha; source/runtime comparisons show broken thin silhouettes.
The other seven recurring regions retain smooth coverage. Individual source/
native-resolution checks of intentional purple materials also remain. Existing
unit medallions and state indicators are not mislabeled as magenta matte.
Do not hide remaining defects or claim release readiness from this checkpoint.
