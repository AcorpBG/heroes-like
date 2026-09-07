# Approved full-match art repairs

Parent: `quality-generated-full-match-20260906`; selected child:
`ux-generated-full-match-presentation-20260906`. Status: in progress.

## Approval and boundaries

On 2026-09-07 the owner approved resuming with scene-matched per-faction Town
building layers and Overworld cutout repairs. Requirements:
`docs/generated-full-match-quality-requirements.md` (approved-art continuation)
and `docs/town-integrated-building-progression-requirements.md` (visual/interaction
invariants). Original game assets only; no rules, masks, placement, save schema,
native generation or unrelated cleanup changes. Runtime exports stay below
250000000 bytes on both platforms. Reverting the coherent art/code commit restores
prior rendering without save migration.

## First production briefs

- Wreck Quay: exact `object_wreck_quay` -> `mapobj_wreck_quay` mapping in
  `art/overworld/map_object_sprites.json` and `art/overworld/manifest.json`.
  The standalone runtime PNG contains a white/magenta sheet frame and edge matte.
  Repair transparency while preserving painted salvage-quay identity and framing.
  Keep original source master; record edited master, trimmed/runtime derivatives,
  exact prompt, processing and hashes before adoption. No sampler workaround.
- Bellwake: `faction_veilmourn` Bell Harbor and Wayfarers Hall currently use
  square isometric catalog icons against a low-angle moonlit harbor. Generate
  dedicated scene layers with matching camera/materials/illumination and grounded
  plots. Keep catalog/info icons separate and exact built-id/upgrade authority.
  First two structures are a bounded checkpoint, not all-faction completion.

Art direction sources: `docs/worldbuilding-foundation.md` World Premise, Tone,
and Veil Coast; `docs/factions-content-bible.md` Veilmourn Home Region and Town
Feel, Visual Language, Object Hooks and Town Building Identity. Preserve black
lacquered timber, tarnished metal, salt stone, rope, bell/mast silhouettes and
small amber lamps. No pirate/undead stereotypes or copied game imagery.

## Validated Wreck Quay checkpoint

The corrected runtime remains the same manifest-backed asset at (39,30,level 0)
in the actual Medium11 Day43 native-map save. Placement
`native_h3maped_93c0f05a_object_0961` retains source `object_wreck_quay`, adopted
as resource site `site_wreck_quay` with a native two-way-portal record and its
one-cell native block mask. The renderer resolves the exact object sprite through
that adopted identity, not a generic resource-site icon. Its 3x2 **visual**
footprint is separate from the native pathing mask. Both, its interaction and
all saved state remain unchanged. This is an art-processing
correction, not native generation or placement work.

The built-in imagegen workflow was attempted first: candidate one retained
colored edge contamination; candidates two and three baked a checkerboard into
RGB output. All were visually inspected and rejected, never imported. Exact
prompts and rejection records are retained beside the processing manifest.
The accepted production repair instead uses the approved original-raster
processing scope: preserve the exact 512x512 source canvas; remove 1238 known
sheet-divider pixels outside the complete painted structure; analytically
unmatte the magenta contamination and recover partial alpha. No replacement
shapes or new building pixels were drawn. More than 40000 uncontaminated painted
pixels remain byte-identical. Original input and original generated atlas are
retained; runtime/trimmed outputs are byte-identical, SHA256
`30683c62a83d442fcdf999f39a6d49a3b7d97221e3131e8779bc99e1b8b7c377`.

`tests/overworld_wreck_quay_repair_regression.py` fails on the original live
renderer texture with 1238 divider pixels and 6122 contaminated pixels, without
runtime errors. After processing **and a fresh editor import**, the same test
passes 11 checks at each of 1280x720 and 1920x1080: zero divider/magenta pixels,
47995 painted pixels, exact asset resolution, no procedural fallback, unchanged
complete session and input save. All three before/after gameplay screenshots
were inspected. An intermediate post-edit run still loaded the old imported
texture and failed correctly; that attempt is excluded from acceptance.

The final extended runs (`wreck_quay_final_720` / `wreck_quay_final_1080`) add
three explicit native-placement/resource-site/transit and visual-footprint checks:
14 checks pass per resolution. The native one-cell mask must not be confused with
the 3x2 art footprint. The final repository log is `wreck_quay_final_repo.log`.

Five Python tests cover failing-before defects, deterministic/idempotent repair,
format rejection, exact preserved pixels and manifest/hash/identity provenance.
Repository validation now also fails specifically if the Wreck Quay border,
matte, approved runtime hash or processing-manifest ownership regresses.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:
`wreck_quay_before/report.json`, `wreck_quay_imported_720/report.json`,
`wreck_quay_imported_1080/report.json`, corresponding `wreck_quay_gameplay.png`
captures, `wreck_quay_import.log` and `wreck_quay_repo.log`.

Both original distinct-map-object and decorative-sprite reports pass, alongside
existing movement ownership, full-route and permanent-fog regressions. Fresh
Linux and Windows package/export/startup/generated-map-to-Town checks pass via
the established RAM-backed packaging wrapper; reports are `wreck_quay_linux_release`
and `wreck_quay_windows_release`, both with 248468784-byte PCKs (1531216 bytes
below the limit). Windows execution is Wine, not physical Windows certification.
Source masters are excluded from both packages. This checkpoint
does not certify other sprites' edge quality or complete Town integration.

Reproduction commands:

```sh
python3 -B tools/repair_wreck_quay_cutout.py --check art/overworld/source/generated/full_match_art_repairs/mapobj_wreck_quay_before.png # expected failure
python3 -B tools/repair_wreck_quay_cutout.py --write
godot4 --headless --editor --path . --quit
python3 -B -m unittest discover -s tests -p test_wreck_quay_cutout.py
python3 -B tests/overworld_wreck_quay_repair_regression.py --label <fresh> --save <Medium11-slot2.json> --resolution 1280x720
python3 -B tests/overworld_wreck_quay_repair_regression.py --label <fresh> --save <Medium11-slot2.json> --resolution 1920x1080
python3 -B tests/validate_repo.py
git diff --check
```

## Validated Bellwake starting-building checkpoint

Bell Harbor and faction-specific Wayfarers Hall now have dedicated scene layers
in `art/towns/runtime/scene_layers/faction_veilmourn/`, separate from the unchanged
catalog/info icons. `content/town_building_scene_art_manifest.json` owns exact
faction/building paths, non-square scenic bounds, ground-depth anchors and all
source/trimmed/runtime hashes. Original generated masters and exact prompts live
under `art/towns/source/generated/scene_layers/`; the README records curation,
originality, processing and rollback. The package helper uses disposable outputs,
not retained duplicate Wine installations.

Root cause: the renderer previously always asked for the 256x256 catalog icon
and inferred a square scenic rectangle. Bellwake's two initial icons therefore
clashed with the panorama's camera and light and occupied detached water plots.
The baseline `town_layers_before` report fails the two exact scene-path assertions
while ordinary construction, state and save controls pass without engine errors.

The approved generated paintings are cropped only at fully transparent margins,
aspect-preserving downsampled to maximum 512px and imported with mipmaps. Bell
Harbor's gangway joins the existing left quay; the Hall lies on the right shore,
behind the foreground gate. `context_03` / `context_04` are inspected composition
previews, not shipped-runtime acceptance. Two earlier preview harness failures
(type inference and invalid scene parenting) are excluded. An initial Hall
placement that covered the foreground gate was rejected.

`TownStageView` applies the same cover-source projection to art and input. The
texture cache is keyed by resolved path, preventing shared building ids from
leaking a Veilmourn scenic layer into another faction. Declared broken layers
return no texture instead of reverting to a catalog icon. The new building
button tests pointer hits against an alpha mask of the actual cropped raster;
keyboard focus still covers the full accessible button. Pointer ordering follows
the same ground-depth order as drawing. The main building still opens the
authoritative Construction Ledger, and individual buildings open their existing
read-only information surface.

Final frozen-source runs `town_layers_controls_720`, `town_layers_controls_1080`
and `town_layers_controls_2048` each pass **824 checks** at actual 1280x720,
1920x1080 and 2048x1079. Coverage includes exact asset resolution, 722 alpha/crop
sample points, transparent and painted pointer activation, keyboard accept/cancel,
raw controller A/B, preserved catalog info icons, cross-faction/negative-cache
boundaries, normal affordable construction costs, and complete save/resume.
Input save and runtime/test owners remain unchanged during each run; no engine
errors or leaked resources occur. The Large08 opening save SHA256 is
`d2b4a0ef45521f768a6e0b8f23878c5f7e16a92838250068df05fff1f3cd31a9`.

A separate detached built-id fixture exercises absent/present Hall art and input.
These two structures are starting buildings, not purchasable Bellwake orders;
the fixture does not pretend to construct them legally or change the catalog.
Actual paid construction uses the offered Market Square. At that checkpoint its
post-build capture still showed an unsuitable floating catalog icon: the next art
target, not an accepted seamless construction result. Opening, information,
absent/present and post-build captures were visually inspected for the repaired
layers and preserved controls; the remaining icon is explicitly not accepted.

Six Python tests reject missing/wrong assets, missing mappings and distorted or
out-of-bounds geometry. Repository validation passes in
`town_scene_layers_repo_final.log`; `git diff --check` passes. Original source
masters are retained. Two successive processing runs produce byte-identical
derivatives after stripping timestamp metadata. Final runtime hashes:

- Bell Harbor (512x477): `e0d2431746b0c7c779da805cef48e62f0ac37ad62bf377a3cd66811b470944d5`.
- Wayfarers Hall (512x353): `10dd806963528a714c81693337177b996f1ded9e329d4ac16d695355527210b5`.
- Scene manifest: `b7c3c0a9f7094473e7bca689de26a75d67442324e31ca915b82246f008eecf1a`.

The final reports record renderer, hotspot, manifest, test and executed-probe
hashes at launch and require them unchanged at exit. Earlier probes are not
substitutes: test inference/type and pointer-coordinate failures were corrected;
an impossible Hall purchase fixture was replaced by explicitly detached built-id
visibility plus real offered construction; alpha tests now sample source pixel
centers rather than numerically ambiguous boundaries. Pre-final reports whose
test hashes were sampled after launch are excluded from frozen-source proof.

Existing Town validation under `.artifacts/full_play_runtime_20260905/`:

- `town_scene_layers_existing_v2`: the rendered layout/dialog report passes all
  five actions and six-faction/three-stage hotspot metadata. The integrated
  progression report passes all 32 towns and 179 catalog mappings, construction,
  upgrades, information and saves. This is behavior coverage, not visual
  acceptance of every faction's older catalog art.
- The older keyboard smoke fails in unchanged Overworld named-file saving before
  reaching Town: it expects numbered-slot overwrite confirmation instead of the
  current filename dialog. This same mismatch is documented in the gameplay
  report's earlier exact-target validation. It is not reported as passing; the
  new Town-focused pointer/keyboard/controller checks pass independently.
- The first rendered save/development report timed out at 240 seconds.
  `town_scene_save_headless` completes in 407.237 seconds without engine errors:
  32/32 save/resume, rare-resource, same-day guard and Town resume-target cases
  pass; 31/32 towns finish development within its 30-turn target. The sole error
  is `town_moonbite_reedshrine` missing that deadline. Its unchanged domain-only
  test never uses TownStageView; no balance, rules or assertions were altered.
  The aggregate report remains failed, not waived or represented as a full pass.

Final `town_layers_linux_final` and `town_layers_windows_final` pass the
established export/startup checks and actual generated-map-to-Bellwake entry.
Both PCKs are **249083376 bytes**, 916624 below the unchanged ceiling, with zero
source-master/metadata package entries. Runtime import settings are versioned
so clean imports retain mipmaps. The rendered Linux packaged Town capture was
inspected; Windows startup/native DLL/generated gameplay execution is Wine,
not physical Windows/GPU certification. Export binaries and Wine prefixes are
disposable RAM-backed outputs; reports and gameplay captures remain retained.

Reproduction commands (fresh labels, retained input save above):

```sh
python3 -B tools/prepare_town_scene_layers.py
godot4 --headless --editor --path . --quit
python3 -B -m unittest discover -s tests -p test_town_scene_layers.py
python3 -B tests/town_scene_layer_regression.py --label <fresh> --save <Large08-slot1.json> --resolution <1280x720|1920x1080|2048x1079>
python3 -B tests/full_play_validation_suite.py --label <fresh> --rendered --accessibility disabled --timeout 240 --only town_screen_layout_and_dialog_controls_report town_building_skyline_progression_report active_play_keyboard_focus_smoke
python3 -B tests/full_play_validation_suite.py --label <fresh> --accessibility disabled --timeout 600 --only town_development_save_resume_report
python3 -B tests/validate_repo.py
python3 -B .artifacts/generated_full_match_quality_20260906/scenery_package_validation.py linux <fresh>
python3 -B .artifacts/generated_full_match_quality_20260906/scenery_package_validation.py windows <fresh>
git diff --check
```

All-faction, per-building integration and other reproduced prop-edge defects
remain part of the full goal. This two-starting-building checkpoint is not a
complete seamless construction-art solution for every Town or a release claim.

## Validated Bellwake paid-construction Market checkpoint

The actual Large08 opening save offers `building_market_square` for 1000 gold.
Its old scene presentation was the shared square catalog icon at a detached
water plot. It now resolves a dedicated original Veilmourn trading-quay layer,
grounded on the foreground-left waterfront. The existing catalog/info icon,
250-gold daily income, build prerequisites, one-build-per-day rule, saves,
village backdrop and both earlier accepted scene rasters are unchanged.

The original RGBA master and verbatim prompt are retained beside the earlier
scene sources; the README records generation identities and curation. Three
opaque checkerboard outputs were inspected and rejected. A fresh render from
the original village and accepted original Hall master produced real alpha.
Only transparent-margin crop, aspect-preserving Lanczos downsampling and metadata
stripping produce the imported 512x338 mipmapped raster. The disconnected central
water placement was rejected; accepted framing is `[200,560,375,250]` before trim.
The small ramp is a boat-loading ramp, not a claimed connection to a land street.

- Generated master SHA256: `9afc680fe3311278da44f54c069854764ef3f17d2f9020e32925a1b4b27aafe1`.
- Verbatim prompt SHA256: `91f3c68f06972033f5771d8cb83e9e72f90856fff44195e39b680961d60404cd`.
- Runtime SHA256: `78f91a231c276218d8ab3db96ff01f5a92b60edadda47aaeaee2e255498ea2de`.
- Three-layer manifest SHA256: `e975fc8a05023975649de31e8755df09c2bc252e9798c4b8122cc13341ac96a0`.

`town_market_before_02` fails exactly the two Market scene-resolution/re-entry
assertions out of 840 checks, with no engine errors or changed input save.
`town_market_final_720`, `town_market_final_1080` and `town_market_final_2048`
each pass **1213 checks**: actual paid construction, normal costs/daily limit,
three exact layers, painted/transparent pointer ownership, keyboard/controller
information, complete save equality and actual Town re-entry. Source and input
hashes remain unchanged during each run. The 1080/2048 Python launchers included
the subsequently removed optional export mode, but their executed source-mode
GDScript is identical to the final test at those resolutions; reports preserve
both hashes. The final 720 launcher SHA256 is
`51eb4db25589cb4fe01b339cf7591d1b28a1e29bc0b21d792a1ce9e98eaf9aa1`.
Opening/build/information and saved re-entry captures were visually inspected;
the Market joins the quay and does not cover the main tower door or controls.

Release templates forbid external scene/path overrides. `town_market_linux_layers`
and `town_market_linux_02_layers` retain those two failed probe launches, not
asset failures. The unsupported mode was removed. The existing opt-in
`LiveValidationHarness` generated-Town flow now accepts
`--live-validation-town-building=building_market_square`. The Python Windows
package check requires both new constructed/information steps. The flow uses
the existing ledger select/confirm controls, checks normal resource deductions
and daily state, loads the exact manifest-backed non-square texture, and opens
the aligned read-only information hotspot. It is inert in normal gameplay.

`town_market_linux_03` and `town_market_windows_final` pass export/startup/native
library checks and generated-map/Town entry plus the new construction and info
steps. Both PCKs are **249356964 bytes**, **643036 bytes below** the ceiling;
source masters remain excluded. Linux's actual 1920x1080 packaged construction
and information captures were visually inspected. Windows is headless Wine:
it verifies the exported resource and gameplay paths, not rendered Windows/GPU
quality. The generated package flow's existing hero-positioning visit fixture
is smoke coverage, never additional legitimate full-match evidence.
Temporary exports/Wine installations are removed after the checks, retaining
reports and screenshots; no caches or project evidence are removed.

Eight Python asset/provenance tests pass. `town_market_existing` under
`.artifacts/full_play_runtime_20260905/` passes existing Town layout/dialog and
all-32-town/179-catalog progression reports. Repository validation passes in
`town_market_harness_repo.log`; final documentation/tracker validation is retained
as `town_market_repo_final.log`. The two previously documented legacy keyboard
and Moonbite development limits remain unmodified and are not claimed green.
Reproduce with the commands above and the three `town_scene_layer_regression`
resolutions; the established package wrapper now also requests Market construction.

## Validated Bellwake Fog Buoys / Salvage Ledger and modal lifetime checkpoint

The same Large08 Bellwake (`native_h3maped_c2520619_object_2167`) had two more
catalog dioramas in its scenic scene: `building_veilmourn_fog_signal_buoys` and
`building_veilmourn_salvage_ledger`. They now resolve exact original scene layers:
separate bell/lantern hulls in the foreground channel and a timber claims office
on the left working quay. The village, three earlier runtime layers, catalog/info
icons, building IDs, prerequisites, costs, daily limits and save schema are
unchanged. Their ordinary sequence is Market on Day 1, Fog Buoys on Day 2
(900 gold / 1 wood), then Salvage Ledger on Day 3 (1300 gold / 1 wood / 1 ore).
The regression uses real confirmed End Turns, not resource grants or forced days.

Original 1536x1024 RGBA masters and verbatim prompts are retained in
`art/towns/source/generated/scene_layers/faction_veilmourn/`; the adjacent README
records built-in imagegen identities and references. The first opaque RGB
checkerboard buoy output was rejected. Preview positions obscured by Bell Harbor,
crowding the footer or conflicting with developed structures were also rejected.
Final full-source framing is `[860,650,180,120]` for buoys and
`[480,450,260,173.3333333333]` for the office; the manifest owns trimmed normalized
bounds and depth anchors. Only alpha-margin crop, aspect-preserving Lanczos
downsampling and metadata stripping produce the mipmapped runtime derivatives.

- Fog Buoys runtime (512x338): `17a085dbf94fe908e6dce825ce4dad8093b17651fb0fb82204a292c3f2ff4e7a`.
- Salvage Ledger runtime (512x339): `a4ae8644c58b30079aebeb4e00450a501861010bd2419b4c9bafc3c11741585b`.
- Five-layer manifest: `fddef117cde38bf7507623dd3d8af56835ca58476af6855a64f2a05c19073783`.

Evidence is under `.artifacts/generated_full_match_quality_20260906/`:

- `town_harbor_before_02`: 1313 checks, four genuine missing-layer/re-entry
  failures and two test-only dictionary numeric-type comparison failures; zero
  engine errors. Integer deductions compared with float-decoded JSON must both
  be normalized. The retained `dictionary_numeric_probe.gd` confirms that
  distinction. The earlier `town_harbor_before` timed out at the old 300-second
  whole-probe limit after both purchases; it is not completed proof. The extended
  growth probe has a 600-second cap, leaving other probes' 300-second cap intact.
- `town_harbor_runtime_720`: the initial pointer fixture selected the transparent
  gap in the buoy bell frame, then incorrectly sent Escape to Town and continued
  on freed scene references, ending in an engine abort. This failed harness run
  is retained, not evidence of a normal construction crash. The probe now uses
  the painted central hull and stops that inspection after failed modal opening.
- `town_harbor_linux`: the exported three-day flow exposed a real production
  defect: two `Parameter "data.tree" is null` errors after immediate modal close
  and Town departure. `TownShell._restore_town_catalog_focus` now checks scene
  membership before and after its await. Normal focus return is preserved;
  departure is not delayed or rerouted to hide the error.
- `town_harbor_final_720`, `town_harbor_final_1080` and `town_harbor_final_2048`:
  **2824 checks pass each** at 1280x720, 1920x1080 and 2048x1079, including normal
  successive-day purchases, exact costs/daily limits, five exact assets, painted
  and transparent pointer ownership, keyboard/controller info, ordinary focus
  return, immediate close/departure and complete save/re-entry equality. Zero
  runtime errors; executed source and both input saves remain unchanged. The two
  larger-resolution checks ran concurrently; their durations are not performance
  measurements. Final test SHA256 is
  `a8bea079cc1bc9f89cb512faccf0188c0f85ffb71afb3914b1fc01ab7b7c16e0`;
  TownShell is `eae6a6d2b538efd0ca236ba4cc660f9d6cd0233d1c3d67934ad3bbb3965efb4e`.

The developed composition is explicitly a detached scenic view of the actual
Day-14 terminal town's **16 built IDs**, not a resumed terminal match. Its input
SHA256 is `f628774c1beb18b2cd6d127e683572f9fa1a38505de77e36b42763745df1e8d2`;
the opening save remains `d2b4a0ef45521f768a6e0b8f23878c5f7e16a92838250068df05fff1f3cd31a9`.
The live Day-3 session is unchanged by this view fixture. All three source
resolutions and the 1920x1080 Linux package captures were opened and inspected:
the new office
connects to the quay, the buoys remain clear of the footer, and both remain
readable among the developed structures. Other detached catalog buildings in
that developed view remain visibly unfinished and are not accepted by this work.

`town_harbor_linux_final` and `town_harbor_windows_final` pass the established
exports, native-library startup and generated-map/Town flow. The opt-in existing
`LiveValidationHarness` accepts a building sequence and the Windows checker
requires all nine setup/entry/build/info steps, including normal Days 1, 2 and 3.
All three constructed assets load from their exact manifest paths without
runtime errors. Both PCKs are **249872672 bytes**, only **127328 bytes below** the
unchanged ceiling; further art needs measured packing efficiency, not a raised
limit. Source art stays excluded. Windows execution is headless Wine, not Windows
GPU certification; the packaged Town visit fixture is smoke coverage, not another
legitimate full match. Only newly created disposable exports/Wine trees are
removed after checks; reports, screenshots, source, saves and caches are retained.

Nine Python provenance/geometry tests pass. Existing rendered Town layout/dialog
and all-32-town/179-catalog progression reports pass in
`.artifacts/full_play_runtime_20260905/town_harbor_focus_existing/` with zero
runtime errors. Repository validation passes in `town_harbor_focus_repo.log`;
final documentation/tracker validation is retained in `town_harbor_repo_final.log`.
The previously documented legacy named-slot keyboard mismatch and Moonbite
30-turn development deadline failure remain explicit, not reclassified as green.

Reproduce the source checks with the earlier command list, adding
`--harbor-growth --developed-save <Large08-slot3.json>` to
`tests/town_scene_layer_regression.py` at each of the three resolutions. The
established package wrapper now requests Market, Fog Buoys and Salvage Ledger
in sequence. This accepts two more constructed layers and the demonstrated
modal lifetime fix, not the remaining faction/upgrade art or full quality goal.

## Validated export-only art headroom prerequisite

The five Bellwake layers left only 127328 bytes below the package ceiling.
Inspection of the actual export found only 2674 duplicate payload bytes, but
about 3.1 MB of unnecessary JSON formatting. No images were regenerated,
recompressed, downscaled, removed or substituted to recover this space.

`tools/compact_export_pck.py` now compacts newly exported JSON through the existing
Python release builder and both platform smokes, before manifest/size/startup
checks. It removes only space, tab, CR and LF outside JSON strings, preserving
all other token bytes, key/array order, escapes and number spellings. Readable
repository JSON is untouched. All 5095 non-JSON pack members, including every
imported raster, script and resource remap, remain byte-identical.

The container remains a plain standalone Godot 4.6 v3 PCK. Offset, length and MD5
handling follows the official [PCK writer](https://github.com/godotengine/godot/blob/4.6-stable/core/io/pck_packer.cpp)
and [reader](https://github.com/godotengine/godot/blob/4.6-stable/core/io/file_access_pack.cpp).
Unknown engine/format/flags, encryption, sparse/embedded packs, deltas/removals,
unsafe/duplicate names, overlaps, corrupt digests and invalid JSON fail closed.
Every temporary output member is verified against the original before atomic
same-directory replacement. Direct Godot exports remain raw; the shared Python
release/export workflows perform this additional validated step. No engine,
native map format, gameplay, save or source-art change is involved.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `town_pack_compaction_first.json`: all **5146 members** verified. PCK size
  decreases from **249872672 to 246744064 bytes**, saving **3128608 bytes** and
  restoring **3255936 bytes** below the unchanged 250000000-byte ceiling.
- `town_pack_godot_equivalence/report.json`: both actual PCKs load in Godot and
  all **51 JSON members** parse identically, with zero runtime errors. Original
  and compacted pack hashes are retained, and both files remain unchanged during
  the check. Repeating compaction leaves the complete result byte-identical;
  compacted SHA256 is `bba0471c150ba7b1cce28abd0adb398f47b121b9f035dec51725d0c76bc8972f`.
- `town_pack_unit_tests.log`: **20 tests pass**, including independent byte-scan
  and parsed-value comparisons, malformed inputs, deterministic/idempotent output,
  atomic failure preservation, concurrent changes and both release-builder paths.
  Existing artifact-verification **17 tests** and release-pipeline **9 tests**
  pass in `town_pack_artifact_tests.log` and `town_pack_pipeline_tests.log`.
- `town_pack_linux` and `town_pack_windows`: both compacted exports pass native
  library startup and the nine-step generated-map/Town flow, including normal
  Market/Buoys/Ledger builds on Days 1-3 and exact loaded art. Both final PCKs are
  **246744064 bytes**; no runtime errors. Windows remains headless Wine, not
  physical Windows graphics/input certification.
- Linux's final 1920x1080 constructed Town was visually inspected and is
  pixel-identical to the retained `town_harbor_linux_final` Day-3 capture. All
  three construction payloads match that pre-compaction run exactly. The opening
  capture differs by 53 channel bytes and is not claimed bit-identical.
- Repository validation passes in `town_pack_repo.log`; final docs/tracker
  validation is retained in `town_pack_repo_final.log`. `git diff --check` passes.

Reproduce: run `tests/test_compact_export_pck.py`, the two existing release test
scripts above, and the established platform package wrapper with fresh labels.
For independent parser proof, retain a raw `godot4 --headless --path .
--export-pack 'Linux Release' <temporary>/before.pck`, copy it to `after.pck`,
run `tools/compact_export_pck.py <temporary>/after.pck`, then
`tests/export_pck_json_regression.py <before.pck> <after.pck> --output <fresh>`.
Only this turn's disposable exports and temporary Wine installations are removed;
all reports/captures, caches, saves, source art and RMG evidence stay retained.

This is production tooling required to ship further scene layers, not additional
art acceptance or a new speed claim. Continue the remaining developed Bellwake
plots, upgrades and other factions with the restored but still finite headroom.

## Validated Bellwake Exchange / Drydock scene-layer checkpoint

The actual Large08 terminal Bellwake contains both Ransom Exchange and Mirror
Drydock. Their prior exact catalog icons were present, but used steep diorama
perspective and isolated bases rather than the village's working waterfront.
There was no missing building, failed purchase or missing crop transform.

`tests/town_scene_layer_regression.py --exchange-growth` reuses the normal
construction, confirmed End Turn, read-only information and full-save checks.
The failing-before engine log `town_exchange_before_720/runtime.log` completed
1328 assertions with exactly six failures: both identities still resolved the
catalog art after construction/save/re-entry and in the developed view. The
1290-gold Exchange was bought on Day 2; the 1610-gold/1-wood Drydock on Day 3,
after the normal Day-1 Market. Costs and complete saved states matched. The
supervising process ended with signal 15 while its isolated engine continued;
the retained final engine marker is failure evidence, not a clean harness pass.

Two original 1536x1024 RGBA masters now own exact Veilmourn scene mappings.
The Exchange's covered counters and ramp extend the right shore below the lodge;
the mirror-lined training/repair slip follows the foreground quay. The first
Drydock placement clipped its lower edge at 2048x1079 and was rejected. Revised
sparse/developed previews preserve the open central channel and all controls.
Three opaque RGB Exchange candidates were rejected before the fourth generated
real alpha; no checkerboard removal or drawn stand-in processing was used.
Exact prompts, original generation identities/hashes, source sections, curation
and rollback live in `art/towns/source/generated/scene_layers/README.md` and the
adjacent prompts. Candidate evidence: `town_exchange_candidates_20260907/`.

The unchanged packaging pipeline crops only alpha margins and downsamples with
preserved aspect/alpha and mipmaps. Runtime Exchange is 512x344; Drydock 512x333.
The original village, catalog/info icons and all five prior scene-layer records
and rasters remain byte-identical. No runtime controller, core rule, authored
building cost/effect/prerequisite, native map, built-id or save-schema change.

The source test adds an opt-in Exchange sequence without replacing the existing
Fog/Ledger sequence. The Windows package smoke retains those earlier purchases
and extends the same existing generated-Town harness to Exchange and Drydock on
Days 4/5. Linux's retained disposable-export launcher exercises that same complete
five-build sequence. No additional runtime validation entry point was added.

Validation and evidence, relative to the goal artifact directory unless noted:

- `town_exchange_final_720`, `town_exchange_final_2048` and
  `town_exchange_final_1080_serial`: 2824/2824 checks each, zero engine errors,
  unchanged input/terminal saves and runtime owners. Each proves actual paid
  Market/Exchange/Drydock construction across Days 1-3, exact loaded layer/aspect,
  transparent/painted pointer ownership, keyboard/controller information and
  focus restoration, authoritative main-building Build route, cost/daily limit,
  full save/resume and re-entry. The terminal 16-built-id view is explicitly a
  detached composition fixture, not a new terminal match or injected purchase.
- Visually inspected normal saved Towns at all three resolutions, developed
  composition at the target resolution and 720p candidate, and both exact
  information dialogs at 720p. The new layers are grounded and do not clip the
  footer or command controls. Other legacy diorama layers remain visible and
  unfinished. The earlier `town_exchange_final_1080` attempt was deliberately
  interrupted for host RAM pressure; it is not accepted validation evidence.
- Ten scene-layer Python tests pass, including fail-closed missing new mappings,
  exact hashes/paths, alpha, mipmaps, aspect and separate catalog identity. The
  initial focused run failed the required mapping check before registration.
- Existing rendered Town reports pass: five direct actions/18 main-building
  cases/two layouts, and all 32 town catalogs/179 plot mappings with existing
  build/save controls. Evidence is under
  `.artifacts/full_play_runtime_20260905/town_exchange_existing/`. Those functional
  mapping counts do not certify the remaining catalog art's visual quality.
- `town_exchange_linux/report.json` and `town_exchange_windows/report.json` pass
  established exports, binary/native checks, startup, source-art exclusion and
  unchanged size ceiling. Both final PCKs are **247312024 bytes**, leaving
  **2687976 bytes**. The shared compactor removes 3129504 bytes of JSON whitespace
  from the raw 250441528-byte exports; no pixels or resource paths are removed.
- Both `town_exchange_linux/generated-entry/live_validation_report.json` and
  `town_exchange_windows/generated-flow/live_validation_report.json` pass all
  **13 steps**: normal generated setup/Overworld/Town plus five successive-day
  builds and information dialogs. Both newly repaired construction payloads are
  exactly equal across platforms. An optional all-five literal comparison finds
  only a 0.0001px formatted old-buoy button-width difference; both remain aligned.
  The inspected Linux exported Day-5 capture is 1920x1080. Windows is headless
  Wine, not physical Windows/GPU certification; the existing entry fixture is
  packaging proof, not an additional legitimately completed match.
- Repository validation and `git diff --check` pass, as do 20 PCK compaction,
  17 release-artifact and nine release-pipeline Python tests. Together with the
  ten scene-layer tests, 56 focused Python tests pass.

Reproduce the source cases using `tests/town_scene_layer_regression.py
--exchange-growth --save <Large08-slot1.json> --developed-save <Large08-slot3.json>
--label <fresh> --resolution <1280x720|1920x1080|2048x1079>`. Run the two existing
Town reports with `tests/full_play_validation_suite.py --label <fresh> --rendered
--accessibility disabled --only town_screen_layout_and_dialog_controls_report
town_building_skyline_progression_report`. Platform launches use the retained
`scenery_package_validation.py linux|windows <fresh>` wrapper around the committed
platform smokes, with disposable RAM-backed exports/fresh Wine installations.
All commands use `python3 -B`; source masters, caches, saves, reports and RMG
evidence are retained. No new gameplay/performance claim is made. This accepts
two more layers, not the full presentation child or parent goal.

## Remaining acceptance

Extend scene-matched art beyond the two starting structures and constructed
Bellwake Market Square, Fog Buoys, Salvage Ledger, Ransom Exchange and Mirror
Drydock to the remaining
faction/building plots and upgrades.
Require inspected sparse, mid-development and developed scenes, exact
built-id/input/save ownership and
both-platform packages within the ceiling for each accepted packet. Other
reproduced Overworld prop-edge/terrain defects and all-faction visual acceptance
remain open. Preserve the two explicit legacy validation limits above. The
Wreck Quay and Bellwake evidence accepts only these repaired assets, not the
remaining art scope or the overall goal.
