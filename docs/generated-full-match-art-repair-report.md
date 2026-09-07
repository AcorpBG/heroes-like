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

## Remaining acceptance

Extend scene-matched art beyond the two starting structures and constructed
Bellwake Market Square to the remaining faction/building plots and upgrades.
Require inspected sparse, mid-development and developed scenes, exact
built-id/input/save ownership and
both-platform packages within the ceiling for each accepted packet. Other
reproduced Overworld prop-edge/terrain defects and all-faction visual acceptance
remain open. Preserve the two explicit legacy validation limits above. The
Wreck Quay and Bellwake evidence accepts only these repaired assets, not the
remaining art scope or the overall goal.
