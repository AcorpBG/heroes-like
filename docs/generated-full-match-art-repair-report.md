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

## Late-harbor continuation — validated, 2026-09-08

Bellwake's five remaining catalog-scene mappings were Drowned Map Room, Memory
Anchor, Leviathan Sounding, Drowned Admiralty and the Sounding upgrade,
Memory-Rite Court. Exact original catalog paintings existed; the missing
faction/building scene-manifest rows selected those catalog dioramas at the old
plots. This is a scene-art gap, not changed construction rules or save identity.
The seventeen accepted scene paintings and the village remain the baseline.

`tests/town_scene_layer_regression.py --late-harbor-growth` starts only from the
actual nonterminal Day-14 earned save, SHA256
`69f4c289bb0bd273f175e24a0b2704391302c0cf2dcc0be76c4d487f91886537`.
It orders Map Room, Mistgate Slip, Memory Anchor, Sounding, Admiralty, Court and
Saltwake Factor through ordinary End Turns, the ledger and paid one-ore Trade.
The source market permits six ore purchases weekly, so the driver must wait
through real daily simulation for caps or income; it never injects reserves,
resets market usage or resumes a terminal match. Each paid Trade is compared to
the complete authoritative rule result and recap. The Court must replace the
Sounding's visible plot/hotspot while retaining the earned prerequisite in the
built-id array. Other visible paintings retain their complete input coverage.

Initial strict coverage fails on exactly the five missing Bellwake mappings.
The three driver-preflight tests pass (dependency order, altered-save rejection
and mutually exclusive sequences). The original renderer's complete
`late_harbor_before_720` control finished 44185 checks with the expected missing
scene-mapping, overlap/input and Court replacement failures. The outer launcher
ended with code 143 while its isolated Godot child continued; observation of that
same child, its terminal report and final earned save recovered the evidence
without replaying it. `late_harbor_before_harvest.py` records that the child's exit
code is unavailable, not zero. Intermediate saved-frame markers alone were not
accepted. The real seven orders completed on Days 15, 16, 17, 22, 23, 29 and 30;
weekly ore caps account for the intervening ordinary End Turns.

Five original source-curated RGBA masters and exact prompts are prepared via
the built-in image tool. The chart-house initial RGB candidate required a
built-in alpha extraction. Court image-to-image/extraction variants repeatedly
returned opaque checkerboards and were rejected. Its selected master is a
fresh transparent painting specified from the inspected Sounding composition,
with the same source-space site and ground anchor, not a pixel-identical edit.
API fallback approval was requested as an alternative, but no API was used.
The earned-Day-30 composition passes 9615 checks at each of 1280x720,
1920x1080 and 2048x1079, including all visible building information/input
controls and 16 authored upgrade relationships in both variant and saved-id
orders. All three scenic captures and the Court information dialog have been
visually inspected: the header, command controls and footer remain clear, the
chart house joins the inner-left shore, the anchor occupies the counting-house
quay and the Admiralty sits behind the inn. Complete input saves and runtime
owners remain unchanged. Reports: `late_harbor_candidate_view_720`,
`late_harbor_final_view_1080` and `late_harbor_final_view_2048` under the goal
artifact directory. These read-only composition checks are not paid construction
or base-to-upgrade transition proof. The separate source and official-package
normal replays below prove those behaviors. This packet is accepted; other
faction art and the full presentation goal remain unfinished.

The combined Python run passes 88 tests (`late_harbor_unit.log`): strict original
scene layers, late-sequence preflight, packaged-probe/bootstrap contract,
lossless imports, PCK compaction, release artifact verification and candidate
pipeline. Every selected master was additionally compared byte-for-byte to its
actual original built-in generation output; all five have genuine RGBA. Exact
output identities and rejected RGB attempts are now recorded in the scene-layer
source README.

`late_harbor_growth_720/report.json` now passes **51490 checks**, with exit code
zero, no runtime errors and unchanged input save/runtime owners. All seven paid
orders complete on the same Days 15, 16, 17, 22, 23, 29 and 30 as the before-art
control, including normal weekly ore-cap waits. Every purchase preserves exact
costs, daily limits, all visible painted/input/information ownership and complete
save/re-entry. The Court correctly replaces the Sounding and its live hotspot
without deleting the earned base id. The actual Map Room, Anchor, Sounding,
Admiralty, Court and final saved Town captures were inspected; the Sounding/Court
pair visibly develops the same jetty site, rather than relocating the structure.

`late_harbor_save_comparison.json` compares all 17625693 saved bytes against the
old-renderer Day-30 control. The only difference is the single top-level
`/saved_at_unix` clock value; no other fields, whitespace or array ordering are
normalized away. Both remain nonterminal Day-30 sessions with all 23 earned
building ids, including base and upgrade. New save SHA256:
`79c4eca066dd4b7ca5c954b56c2d49f0a79ace4eb99b7f98b67c0de53f05b8cb`.

The existing rendered Town layout/dialog and all-town skyline/progression reports
pass (`late_harbor_town_existing_driver.log`). The full lossless preparation
verifies five new textures and reuses 2262 verified cache entries; all decoded
pixels/mipmaps and imported bytes are unchanged. These initial caches already
used the approved stronger setting, so this run claims zero additional savings.
`late_harbor_lossless.json` retains the full five-resource proof.

The paid Court continuation also exposes a real visual-selection defect:
`TownStageView._town_building_scene_entries` loops the authored plot's variants
and keeps the last built member. The Bellwake plot lists Court before Sounding,
so preserving both earned ids selects the predecessor instead. The selected
renderer correction now excludes built ancestors of built upgrades using
`content/buildings.json`'s `upgrade_from`, keeping plot ownership and saved
progression intact; array order is not upgrade authority. The old renderer and
manifest stayed frozen through the completed before-art control. The new
source-run supervisor retains each real child exit result independently of the
interactive launcher's lifetime; it stops on a failure rather than retrying.

`late_harbor_preservation.json` proves all seventeen accepted rows, their 51
rasters and seventeen prompts are unchanged against `e97d7e66`; all 160 tracked
catalog files, the village and the selected building/town/rule owners are also
byte-identical. The first managed source-batch launch failed before Godot because
its service PATH omitted the local engine directory (exit 127), not because of
a game failure. That report remains retained. `late_harbor_source_batch2.json`
ran with the explicit engine PATH under the finite
`heroes-late-harbor-source2-20260908` user service. All five jobs completed with
zero exits and the service is now terminal/successful. Intermediate live state
and saved-frame markers were never treated as acceptance.

After those source checks ended, the existing preparation pipeline recorded the
curation decision. `late_harbor_curation_metadata.json` proves that only the five
new `curation` strings and `migration_scope` changed in the manifest, with all 110
asset/prompt/import files and all scenic geometry unchanged. Source checks used
manifest SHA256 `e782c36ffbe8b4be7dc6bf1ced53d863e8dc3a80cd861f898def0881aa8bfb10`;
both official packages use the resulting
`61f495580a0e6f562c1998bcf72aded411b92669c6519b4e3239b7c2072454f9` manifest.
`late_harbor_package_batch.py` runs the unchanged normal platform smokes and
the same complete seven-order probe in each isolated official release pack,
with five bootstrap controls and no game-script/art overrides.

The normal Linux and Windows smokes have both completed successfully, including
startup and generated-map/Town construction. The isolated Linux release replay
also passes all **51490 checks**, with zero exit/runtime errors, unchanged input
and runtime owners, all five bootstrap controls, and the exact current manifest.
Its Sounding, Court and final saved Town captures have been visually inspected;
the same-site upgrade and readable header/commands/footer remain present in the
actual release build. The Linux PCK is 243281500 bytes, SHA256
`c5cda746d309314e3ce854b111594aff2dba2af7bd165fa8448097148cb9d71c`,
with 5180 members and 6718500 bytes below the unchanged ceiling. Normal Windows
startup and generated-entry logs have no fatal runtime matches in this run;
this does not establish a fix for the earlier intermittent quick-exit warning.
The exact Windows/Wine seven-order replay also passes **51490 checks**, exit
zero, no runtime errors, unchanged input/source owners and all five bootstrap
controls. Both release probes retain every gameplay/input/save assertion; only
paired frame/screenshot operations are omitted in headless Windows. The six-job
`late_harbor_package_batch.json` is terminal/successful, including the final
repository and diff checks. The managed service is inactive with result success.
Headless Wine is not physical Windows/GPU certification.

`late_harbor_package_parity.json` verifies all 5180 members: exactly five texture
caches and five import descriptors were added; no old member was removed.
Of the prior members, 5167 are unchanged; only the scene manifest, compiled
`TownStageView` and generated UID cache differ. All new texture bytes match the
lossless-import proof. Linux and Windows have 5179 identical members, with only
`project.binary` platform-specific; no source master is packaged. Both PCKs are
243281500 bytes. Windows SHA256:
`428f05f5805da0336fb7e510612e6ed79530ca997434b1c1db53184874d9d8bd`.

`late_harbor_packaged_save_comparison.json` passes a four-way raw-byte comparison
of the original renderer, new source, Linux release and Windows release earned
Day-30 saves. Only the one top-level `/saved_at_unix` numeric span is excluded;
no whitespace, field or array normalization is permitted. All remain nonterminal
with 23 earned building ids. Linux save SHA256:
`9d20f5cefc788faa88686fc1cabc46cc410997dda83be0c99066db3a5452e9e2`;
Windows: `e86e0b29b70350dfb6b08436b945e3d41bc018dbf80fc8df6c9620779dfe94bd`.

After every process finished, `late_harbor_wine_retirement.json` records removal
of only the test prefix's three rebuildable Windows/Program Files directories:
1309548544 allocated bytes. All user data and registry hashes remain identical;
reports, saves, source art, caches, RMG evidence and both official exports remain.

Reproduction: run `tests/town_scene_layer_regression.py --late-harbor-growth`
with the recorded Day-14 `--save`, a fresh `--label` and `--resolution 1280x720`;
use `--presentation-only --developed-save <earned-Day-30-save>` for the inspected
three-resolution composition controls. The packaged counterpart additionally
takes `--binary`, `--pack`, `--platform`, `--bootstrap-controls` and a fresh
Windows `--wine-prefix`. The artifact supervisor records the exact standard
Linux/Windows export/startup/generated-entry commands and retained logs. Strict
scene/sequence/bootstrap/lossless/compaction/release tests, both existing Town
reports, `python3 tests/validate_repo.py` and `git diff --check` pass. This is
complete Bellwake scene coverage, not all-faction or release-ready acceptance.

## Next Embercourt opening packet — preparation only

The real Medium11 Day-1 Riverwatch control reproduces detached catalog art for
Muster Yard, Wayfarers Hall and the normally purchased Market Square. Its exact
save SHA256 is `c0d67e4b2a8403ac82ae599391ae0a946ea16110beb4dd378a599af9a9ab7a59`.
`embercourt_opening_before_720` runs 72 checks with five expected scene-mapping
failures and no engine errors; exact 1000-gold purchase, daily/build-id and
complete save/resume controls are retained. The before capture was inspected.

Three original text-only RGBA candidates and exact prompts are preserved under
`embercourt_opening_candidates_20260908/`; its README owns output identities,
hashes and the rejected RGB/checkerboard extraction. Direct alpha sampling and
an actual-engine detached preview resolve the misleading brown RGB visible in
raw previews: those surrounding pixels are transparent in the game. The preview
passes 35 overlay/state/save controls, not production art/input acceptance.
Muster Yard still needs its base raised onto the quay court, and raw full-size
textures need the established trimmed/mipmapped runtime pipeline before judging
sampling. No Embercourt candidate has entered the production manifest/export.
After the validated Bellwake commit, extend exact-faction preparation while
preserving all 22 Veilmourn layers, then validate placement, actual construction,
input/save, developed compositions and both-platform packages. The presentation
child and full-match parent remain in progress.

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

## Validated salt-trade / pilot scene-layer continuation

The actual Large08 terminal Bellwake has Salt Counting House, Mourner Pilot Guild
and Saltwake Factor built. All three resolved exact catalog images through
`TownStageView`, but their steep miniature perspective and isolated bases did
not match the village waterfront. No missing purchase, rule or cover transform
was found. The normal source regression now has an opt-in `--salt-growth` sequence:
Market Day 1, Counting House Day 2, Fog Buoys Day 3, Salvage Ledger Day 4, Pilot
Guild Day 5 and Saltwake Factor Day 6. Previous Harbor/Exchange sequences remain
available; the same real End Turn, construction and save routes are reused.

Failing-before evidence is `town_salt_before_720/report.json`: 2230 assertions,
exactly nine scene-path/save-re-entry/developed-view failures for the three new
identities, no engine errors, unchanged input and terminal saves/runtime owners.
All six days of normal costs, prerequisites, daily limits and full save/resume
pass. Final baseline treasury is 4060 gold, 15 wood, 7 ore and zero rare resources;
no resources, buildings or terminal outcomes were injected into this live path.
The separate developed-16 composition remains explicitly a detached view fixture.

Three original 1536x1024 RGBA masters now have exact-faction mappings, original
prompts/hashes and alpha-margin/512px/mipmap derivatives. Counting House and
Saltwake Factor extend the left working quay; the Guild lookout and skiff join
the right waterfront behind the later Drydock. The initial Guild height and
Factor/Mistgate conflict were rejected; the next Guild/Oratory conflict was also
rejected. Sparse 720p and actual developed-16 wide previews were inspected before
registration. Original outputs, prompts and all composition attempts remain in
`town_salt_candidates_20260907/`; accepted source identities, curation and rollback
are in `art/towns/source/generated/scene_layers/README.md`.

The village, seven prior complete scene-art records/rasters, catalog/info icons,
building rules/layout catalog and Town controllers/hotspots are unchanged. The
166-file asset/runtime-owner comparison against the previous commit has no drift.
Only the existing exact-faction art pipeline/manifest and focused tests change.

Validation (all paths relative to the goal artifact directory):

- Eleven strict art, 20 export compaction, 17 release-artifact and nine release
  pipeline Python tests pass (57 total); the strict mapping test failed before
  registration. Repository and diff checks pass.
- Existing rendered Town layout and progression reports pass in
  `.artifacts/full_play_runtime_20260905/town_salt_existing/`, retaining all five
  dialogs, 18 main-building cases, two layouts, 32 towns and 179 plot mappings.
  These functional counts are not all-faction visual acceptance.
- `town_salt_linux/report.json` and `town_salt_windows/report.json` pass both
  exports, binary/native checks, startup, source exclusion and package limits.
  Both PCKs are 248145628 bytes, leaving 1854372 below the unchanged ceiling.
  Export-only compaction removes 3130848 bytes from 251276476-byte raw packs;
  all 5156 members are verified, with all 5105 non-JSON payloads byte-preserved.
- The Linux `generated-entry` and Windows `generated-flow` live reports pass
  19 steps each: setup/Overworld/Town and eight real daily builds with information.
  Earlier Market/Fog/Ledger/Exchange/Drydock coverage remains; the three new
  buildings extend the same opt-in harness on Days 6-8. No new runtime entry point.
  New gameplay payloads match across platforms; the only new UI difference is
  a 0.0001px formatted Factor button height, with alignment passing on both.
  Linux's exported Day-8 1920x1080 Town capture has been visually inspected.
  Windows is headless Wine, not physical Windows/GPU certification; package
  entry fixtures are not additional legitimate full-match outcomes.
- `town_salt_final2_720`, `town_salt_final_2048` and `town_salt_final_1080` each
  pass 4476/4476 source checks with zero engine errors and unchanged input/terminal
  saves/runtime owners. Normal paid construction, both overlap owners,
  painted/transparent clicks, keyboard/controller, full save/re-entry and
  developed-16 visibility pass. All five growth gameplay records in each run
  exactly match the failing-before run. Normal and developed captures at all
  three resolutions were visually inspected, together with Counting House,
  Ledger, Guild and Factor information captures. The 1080p Factor information
  retains its exact 1750 gold/1 wood/1 ore cost, two prerequisites and 170-gold
  daily contribution. No clipped navigation or new dialog overlap was observed.
  The detached developed view still exposes five old catalog-based buildings;
  this is not full-town visual acceptance.

The first source pass `town_salt_final_720` completed 4474 checks with three
related test-point failures: its old Salvage Ledger facade point was now covered
by the visibly foreground Counting House, correctly opening Counting House
information and restoring its focus. All new-building and cost/save checks passed;
there were no engine errors. The probe now explicitly proves that foreground
treasury owns the overlap, then clicks the Ledger's still-exposed roof. No runtime
input priority, prior art/placement or gameplay changes conceal this test failure.

Reproduce with `python3 -B tests/town_scene_layer_regression.py --salt-growth
--save <Large08-slot1.json> --developed-save <Large08-slot3.json> --label <fresh>
--resolution <1280x720|1920x1080|2048x1079>` and the existing Town/platform commands
above. Fresh package binaries/Wine installations are disposed by the retained
launcher; all saves, reports, screenshots, original art, caches and RMG evidence
are preserved. This is three further layers, not full presentation acceptance.

## Defense / memory integration — validated checkpoint

Five remaining catalog dioramas in the actual Large08 developed Bellwake view
now resolve through exact-faction original scene layers: Harpoon Gantry,
Bell-Chain Watch, Obituary Vault, Wake Oratory and Mistgate Slip. The prior ten
manifest rows and their source/prompt/runtime files are unchanged. The village,
catalog/info icons, built ids, costs, prerequisites and save schema are unchanged.
Original built-in imagegen outputs, exact prompts, rejected checkerboard outputs,
accepted second placements and alpha-margin/512px/mipmap provenance are recorded
in `art/towns/source/generated/scene_layers/README.md` and the scene manifest.
No new generated geometry or procedural/background-extraction approximation is
used. This is fifteen accepted source paintings, not all-faction acceptance.

The source probe adds ordinary opening defense purchases (Market then Fog Buoys,
Watch, Ransom Exchange, Drydock and Gantry over Days 1–6), and memory purchases
from the exact retained nonterminal Day-8 save (Vault, Oratory and Slip on
Days 9–11). Rare resources and prerequisite buildings in the latter come from
actual prior play, not injected funds. The terminal Day-14 built-id composition
is only a detached UI model; it is not resumed as a match or presented as paid
construction. Its shell and stage agree on built ids, initialize through the
ordinary ledger read and retain complete model/live-state comparisons.

Input inspection exposed a real accessibility defect: automatic node-name
metadata could overwrite authored building names during a later focus scan.
`TownStageView` now uses the existing `UiAccessibility.describe_control` API,
which clears that automatic metadata. Exact names are checked after an explicit
accessibility scan and after focus restoration. Painted/transparent clicks,
keyboard/controller activation, separate catalog icons and prior-layer
foreground ownership remain covered. The old Market counter click is correctly
owned by the foreground Vault; the probe proves that overlap, then clicks the
still-exposed Market canopy. No input-priority bypass is introduced.

Official release templates reject CLI scene/path overrides. The existing
opt-in `LiveValidationHarness` now permits a restricted export-local Python
probe only with the explicit flow and matching SHA256, after ordinary Main Menu
startup. Normal startup is inert. `tests/packaged_town_scene_layer_regression.py`
uses the real isolated release binary and unchanged adjacent PCK; no editor
substitution, resource overlay pack or loose game scripts. All assertions remain
Python-owned. Windows removes only paired rendering/capture operations and
retains gameplay, real input, exact identity and complete save checks. Wrong
paths, hashes and script base types have explicit negative controls.

Evidence so far (relative to the goal artifact directory):

- `town_defense_before2_720` and `town_memory_before_720` reproduce the missing
  exact scene mappings while retaining normal purchase/save behavior. Earlier
  attempts with omitted prerequisites, unpainted/occluded click coordinates,
  mismatched detached shell/stage models and unsupported release overrides
  remain rejected evidence, not gameplay regressions or accepted test passes.
- `town_memory_final_720/report.json` passes all 8474 checks with no runtime
  errors, unchanged input/terminal saves and runtime owners. All three complete
  paid-growth records equal the failing-before control. Normal saved Town and
  developed composition captures were visually inspected at 1280x720; the five
  new waterfront structures remain grounded and the edge controls usable.
- `town_defense_final_1280x720/report.json` passes all 9003 checks with no
  runtime errors and unchanged input/terminal saves/runtime owners. All five
  complete successive-day defense-growth records equal the failing-before
  control; Market's separate normal purchase, exact costs, daily limit and
  complete save/re-entry also pass. Its developed-view capture was inspected.
- `town_memory_final2_1920x1080/report.json` passes all 8474 checks, with three
  complete paid-growth records equal to the same failing-before control and
  unchanged source/input/terminal saves. The normal saved Town, developed view
  and Vault information captures were inspected at original resolution: all
  five new structures are grounded, and the building dialog's costs, prerequisites
  and effects remain readable. This inspection also exposes the separate
  pre-existing wide Town stockpile-caption clipping described below; it must not
  be mistaken for full-screen visual acceptance.
- `town_defense_final_1920x1080/report.json` passes all 9003 checks, preserving
  exact sources/input/terminal saves and all five complete paid-growth records
  from the failing-before control. Its developed composition was inspected at
  original resolution; the existing three-resource caption happens to fit this
  opening-defense stockpile, unlike the rare-resource memory case.
- `town_memory_final_2048x1079/report.json` and
  `town_defense_final_2048x1079/report.json` pass 8474 and 9003 checks respectively,
  with zero runtime errors and unchanged source/input/terminal saves. Complete
  paid-growth rows equal the same failing-before controls. Both developed-view
  captures and the normally saved Slip capture were inspected at original
  resolution: waterfront layers, information targets and edge navigation remain
  coherent; the separate wide resource-caption defect is still visible.
- Thirteen strict art, three packaged-probe, twenty PCK compaction, seventeen
  release-artifact and nine release-pipeline Python tests pass (62 total).
  `town_defense_repo02.log` records a passing repository check. Existing Town
  layout/progression reports are retained under
  `.artifacts/full_play_runtime_20260905/town_defense_existing/`.
- `town_memory_final_pack_linux/report.json` and `packaged-report.json` pass
  all 8474 exact-save checks and all five bootstrap controls, with zero runtime
  errors, unchanged input/terminal saves and unchanged export bytes. Its three
  complete paid-growth rows equal the failing-before source control. The saved
  Slip and developed-view captures were visually inspected at 1280x720. The
  isolated official Linux PCK SHA256 is
  `8e9089dd501694fec489aedc2f88da4219b48d76b7a2af13cdff0a5f87458a5c`.
- `town_memory_final_pack_windows/report.json` and `packaged-report.json` pass
  the same 8474 exact-save assertions and five bootstrap controls. Complete paid
  rows equal the failing-before control, and all saved inputs and export bytes
  remain unchanged with no engine errors. The official Windows PCK SHA256 is
  `308a2b2c7b6f0618c33351e9af49304f0755b75dedaaea23a29c2711e8065db0`.
  This is headless Wine, with only paired frame/capture operations omitted;
  inspected visual evidence comes from the source and Linux rendered runs.
- `town_defense_linux3/report.json` and `town_defense_windows2/report.json`
  pass official export/startup and package checks. Both PCKs are 249673796 bytes,
  leaving 326204 bytes below the unchanged ceiling. Compaction verifies all
  5166 members, preserving all 5115 non-JSON payloads. The Linux generated-entry
  and Windows generated-flow reports each pass 23 steps and ten daily builds,
  including Watch and Gantry construction/information. Windows is headless Wine,
  not physical Windows/GPU certification. Its first checker still expected
  eight buildings although the launcher built ten; the expectation was corrected
  and the entire official smoke rerun successfully, not retroactively relabeled.
  Independent payload comparison finds all 5166 member names identical between
  retained Linux/Windows packs; only `project.binary` differs. All 204 protected
  content/script/Town-layer members are byte-identical between platforms.

The first batch supervisor terminated with status 143 after the accepted 720p
defense run, leaving the following 1080p engine without its report collector.
That orphan was explicitly stopped after verifying the collector was gone;
`town_memory_final_1920x1080` is interrupted evidence, not an accepted pass.
The replacement batch has its own detached process session and uses the fresh
`town_memory_final2_1920x1080` label, preserving the original logs and captures.

All six source-resolution runs and both exact Day-8 packaged flows now pass.
The detached serial batch is terminal, with six successful results in
`town_defense_detached_final_batch.json`; its temporary Wine installation was
disposed after validation. This accepts this five-layer checkpoint, not full
Town/art scope or the parent goal. The separate caption correction follows.
Reproduce with `tests/town_scene_layer_regression.py --defense-growth` using
Large08 slot1, or `--memory-growth` using its slot2; both use slot3 only as
`--developed-save`, a fresh `--label` and the supported `--resolution`.
The packaged wrapper additionally requires isolated matching `--binary/--pack`,
`--platform`, `--bootstrap-controls`, and a fresh `--wine-prefix` for Windows.

## Remaining acceptance

All 22 Bellwake starting/constructible scene layers, including the same-site
Sounding/Court upgrade, now have source and package acceptance recorded above.
Extend that scene-matched coverage to the other faction/building plots and
upgrades, starting with the reproduced Embercourt opening packet. Candidate
generation or mapping counts alone do not establish that acceptance.
Require inspected sparse, mid-development and developed scenes, exact
built-id/input/save ownership and
both-platform packages within the ceiling for each accepted packet. Other
reproduced Overworld prop-edge/terrain defects and all-faction visual acceptance
remain open. Preserve the two explicit legacy validation limits above. The
Wreck Quay and Bellwake evidence accepts only these repaired assets, not the
remaining art scope or the overall goal.

The 1080p memory-growth captures show a clipped resource-caption fragment in
Town's top-right menu (`Gold 8490 | Wood 11 | Ore 2 | Aeth...`, clipped rather than
intentional ellipsis). `TownShell._apply_responsive_layout` selects summary mode
on wide viewports while this menu retains the shared default
`fit_summary_to_width = false`. The earlier Overworld-only correction deliberately
did not change that Town default. The full ledger remains available; this is a
caption/layout defect, not missing resources. After the immutable art validation
batch, select a narrow Town opt-in/real-font-width and popup-input correction,
preserving every ledger amount, input route, layout bound and saved field. Do not
claim that the current wide captures have no remaining HUD clipping.

`town_stockpile_before3_authored/report.json` is the clean failing-before UI
control: 856 checks, exactly eight expected caption/read-only-text failures,
zero engine errors and unchanged sources/input save. It projects only the real
Day-8 resource amounts into the existing small River Pass Town fixture, not a
generated-match continuation or paid-growth proof. The wide caption measures
756px in a 222px button; all nine resource rows, original icons/tooltips, popup
containment, pointer/keyboard/focus, compact scene bounds and full live-state and
save/re-entry comparisons pass. The popup screenshot also confirms dark disabled
text; the selected fix includes a Town-local opaque text theme matching the
existing Overworld ledger, without enabling its read-only entries.

The two earlier caption probes compared a detached setup object after
`SessionState.set_active_session` had copied it. Resolving the actual active Town
model removed their spurious `/game_state` comparison failure; no gameplay code
changed. These earlier reports are retained, not accepted as clean controls.
## Town stockpile caption and ledger contrast — validated checkpoint

After the immutable art batch completed, the Town-local scene now enables the
shared menu's existing `fit_summary_to_width` option and assigns the same opaque
read-only popup text color as Overworld. Only `TownShell.tscn` changes at runtime;
the shared default, nine-resource ledger, frame dimensions, art and all gameplay
owners remain unchanged. This is not a wider header or a new resource display.

`town_stockpile_after_authored/report.json` passes all 856 checks with the same
executed probe SHA256 as the clean eight-failure control, unchanged source/input
save and no engine errors. Actual visible text is now 53px (`Stores`) within
92px/222px allocations at all three sizes. The full tooltip and all nine ordered
disabled popup entries remain intact; pointer/keyboard/focus, larger font,
full-state and complete save/re-entry checks pass. The 720p and 2048x1079 popup
captures were inspected: all amounts are legible and the menu stays inside the
viewport. These are explicitly authored UI projections, not generated matches.

The older Town stockpile report independently fails only `menu_width_exact` in
`town_stockpile_legacy_before`: it expects the 80px minimum to equal the actual
92px allocation. The Python-only `--legacy-town` adapter sets the real logical
viewport and compares the menu allocation to the exact framed content width,
preserving original 96/226px frame and 80/210px minimum checks, icons, resources,
input and full state. `town_stockpile_legacy_aligned_before` passes both sizes
before the runtime caption/theme edit. The original GDScript report is unchanged;
this fixture correction is not a game-layout fix.

`town_stockpile_after_generated/report.json` passes 855 checks on the real
Large08 Day-8 save, without the authored projection or moved hero. All three
resolutions retain the complete nine-resource ledger, pointer/keyboard/focus,
original input bytes and full state/save/re-entry equality. Its 720p Town,
1080p ledger and 2048x1079 Town captures were inspected; the caption fits and the
popup amounts remain legible. The Town scene SHA256 is
`d7ba31df4d70b7c1312c7b7b610b84aa398cbcd39adb9cdf9dc5d27e4aad4529`;
the shared component remains byte-identical to the earlier Overworld checkpoint.

`town_stockpile_legacy_after` and `town_stockpile_overworld_after` pass both
existing authored viewport cases. Both Town layout/progression reports pass in
`.artifacts/full_play_runtime_20260905/town_stockpile_existing/`, covering the
five actions, main-building routes and existing all-town progression surface.
The first serial batch stopped at the repository checker because its two old
assertions required Town *not* to use the earlier Overworld fix. The now-selected
Town contract requires both explicit scene opt-ins and local opaque themes;
the shared false default and all original ledger/ownership checks remain.
`town_stockpile_repo_after.log` records the passing rerun. The earlier failed
batch and exact error log remain retained, not relabeled successful.

Fresh `town_stockpile_linux/report.json` and `town_stockpile_windows/report.json`
pass established official export/startup checks. Both PCKs are 249674052 bytes,
leaving 325948 bytes below the unchanged ceiling; all 5166 entries are verified
by the existing JSON-only compactor. Linux's generated-entry report passes 19
steps/eight daily builds; Windows's generated-flow report passes 23 steps/ten
daily builds. Both generated Town flows have zero engine errors. The final
Linux construction capture was inspected at 1920x1080, requested through the
existing presentation-resolution option: a short fitting summary stays visible
and controls retain their bounds. `town_caption_package_batch.json` records
both successful terminal processes and unchanged source hashes. Temporary
exports/Wine installations were disposed by their owning launcher; evidence,
saves, source art, caches and RMG data remain retained.

Windows remains headless Wine, not physical Windows/GPU certification. Its
separate Main Menu quick-exit log includes an `ObjectDB instances leaked` warning
listing Ogg music streams/playback/packet sequences. The established checker does
not treat that warning as fatal. The generated Town flow and focused source
regressions have no such warning. No audio owner changed in this caption fix;
the quick-exit lifetime cause is not established here and needs a separate
reproduction/correction, not a blanket clean-shutdown claim. This checkpoint
does not close all-faction art, remaining Overworld repairs or the parent goal.

## Verified lossless-import headroom prerequisite

The 249674052-byte caption package left only 325948 bytes for the remaining
approved art. Godot 4.6.2 defaults its lossless WebP effort to 25 and its shared
compression method to 2. Its texture-import fingerprint includes VRAM formats,
not this WebP effort. Simply changing a setting would leave existing imports at
the old encoding. Sources: [setting defaults](https://github.com/godotengine/godot/blob/4.6.2-stable/servers/rendering/rendering_server.cpp#L3695),
[lossless encoder and exact transparent RGB](https://github.com/godotengine/godot/blob/4.6.2-stable/modules/webp/webp_common.cpp#L45),
and [import settings fingerprint](https://github.com/godotengine/godot/blob/4.6.2-stable/editor/import/resource_importer_texture.cpp#L1014).

`project.godot` now selects lossless factor 100; the shared method remains 2 so
lossy imports are not changed. `tools/prepare_lossless_texture_imports.py` stages
ordinary editor imports of the actual exported lossless PNG set at identical
resource paths in a disposable project. It preserves source/option hashes and
compares the complete original/candidate texture header plus real Godot-decoded
format, dimensions, every mipmap and all pixel bytes, including transparent RGB.
Only verified CTEX/MD5 cache outputs are atomically published, with rollback on a
failed write. Source rasters/options, provenance and unrelated caches stay intact.
The production release builder and both platform smokes call the same helper.

An exact source/options/output/metadata/engine/settings stamp plus retained decode
proof skips unchanged imports. Missing input metadata uses the normal editor
bootstrap; because that scan may also rebuild other caches, all pending outputs
then get fresh default-factor-25 baselines. Fresh or intentionally changed inputs
are compared against that default import, not an unrelated old asset. Unknown
engine/remap/options, mismatched pixels, concurrent changes and failed imports
stop preparation. The `.godot/lossless-import.lock` is never stolen; after an
interrupted helper, verify no owning process remains before removing that one
empty lock directory. No broad cache purge is required.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `lossless_sample2/report.json`: two actual assets pass complete engine decode
  comparisons, saving 36618 imported bytes. Gantry retains nine mip levels.
- `lossless_all/report.json`: all 2260 selected assets covered, with 2258 additional
  reimports saving 8328140 bytes in 103.35 seconds. `lossless_texture_proofs.json`
  retains the full combined exact-source/import/output/pixel proof.
- Unchanged full-workspace preparation takes 9.58–19.50 seconds in the platform
  runs, with 2260 cache hits and no reimport. This hashes the selected inputs and
  outputs; it is a build-time prerequisite, not a gameplay speed claim.
- `lossless_first_import2/report.json`: real empty-cache and missing-metadata
  imports, two cache hits, and a deliberate mip-option change on a disposable
  copy all pass against fresh default imports. Both original rasters stay intact.
- `lossless_package_proof.json`: all 5166 PCK members checked. All 2260 verified
  texture encodings are present; 2255 members differ from the baseline exported
  after the initial sample, while 2911 remain byte-identical. Every non-texture
  member is unchanged, including scripts, native/package metadata and content.
  Linux/Windows match for all 5165 members other than platform `project.binary`.
  Both PCKs are **241309204 bytes**, with **8690796 bytes of headroom**. The full
  comparison saves 8328304 bytes; versus the previous caption checkpoint the
  reduction is 8364848 bytes. These are PCK sizes, not archive/install totals.
- `lossless_town/report.json`: 855 real Large Day-8 save/input/resource/re-entry
  checks pass at 1280x720, 1920x1080 and 2048x1079. `lossless_overworld720` and
  `lossless_overworld1080` pass 643 checks each with complete save equality.
  Town and Overworld captures were inspected at both supported sizes. Independent
  Town captures differ slightly around animated scenic lighting; they are not
  claimed pixel-identical. The asset/mipmap comparison is exact, without masks.
- `lossless_linux/report.json` and its `generated-entry` report pass startup and
  19 steps/eight normal daily builds. The final 1080p constructed-Town capture was
  inspected. `lossless_windows/report.json` and `generated-flow` pass startup and
  23 steps/ten normal daily builds, using headless Wine, not physical Windows/GPU.
  This pair has no engine/leak errors; the earlier quick-exit Ogg warning remains
  a separate unresolved observation, not a claimed audio fix.
- Nineteen helper/package unit tests, twenty compactor tests, seventeen release
  artifact checks and nine release-pipeline tests pass. Existing Town layout and
  all-town building-progression reports pass at
  `.artifacts/full_play_runtime_20260905/lossless_town_existing/report.json`.
  Map-object sprites, decorative sprites, permanent fog and movement-input reports
  pass at `.artifacts/full_play_runtime_20260905/lossless_overworld_existing2/report.json`.
  `lossless_repo_final.log` records repository validation; diff checks pass.

Reproduce with `python3 -B tools/prepare_lossless_texture_imports.py --report
<fresh.json>`, `python3 -B tests/lossless_texture_clean_import_regression.py
--output <fresh-directory>`, `python3 -B -m unittest discover -s tests -p
test_lossless_texture_imports.py`, and `python3 -B
tests/lossless_texture_package_regression.py <before-linux.pck> <after-linux.pck>
<after-windows.pck> --proofs <retained-proof.json> --output <fresh.json>`.
Use the normal Town/Overworld commands above and both established packaging
smokes; no special runtime or custom export template is required.

Retained failed/support attempts are not passes: the editor-script API experiment
leaked editor-only objects, so production uses ordinary isolated `--import`
instead. The first decode probe used a nonexistent static hash helper and failed
before publication. The first clean-import control exposed the bootstrap-baseline
classification gap corrected above. An initial Linux wrapper loaded the smoke
module before setting its report directory; the genuine passing default-directory
report was retained verbatim under `lossless_linux`. Its supervisor exited 143
after the completed Linux flow and before recording the row/launching Windows;
the Linux terminal report/log was independently verified, and Windows ran as a
separate successful process. That partial batch is not called a six-job pass.
The first extra Overworld command requested an unregistered lava report and
stopped at argument parsing, before any scene ran.

This closes the measured package-headroom prerequisite, not the remaining Town
building/upgrade/faction paintings, Overworld cutout repairs or the overall goal.

## Bellwake rigging/magic continuation — 2026-09-08 (validated checkpoint)

The real earned Large08 Day-8 Town can construct Black-Sail Loft and Tideglass
Chapel, but neither had an exact scene-layer entry. Consequently
`TownStageView._town_building_texture_path` selected their separate 256px catalog
icons. This was an unpainted scene-art category, not a save/visibility or crop
transform defect. The corrected read-only before probe,
`town_rigging_magic_before_view_720/report.json` under the artifact root above,
runs 6446 checks and fails only those two exact identity-to-scene-art mappings;
runtime errors are empty and both source/input hashes remain unchanged.

Two original built-in image generations now supply exact faction/building
source, trimmed and runtime rasters. The prompts and source masters are paired
under `art/towns/source/generated/scene_layers/faction_veilmourn/` with stems
`building_veilmourn_black_sail_loft` and `building_veilmourn_tideglass_chapel`.
Neither generation used input images; each new manifest row explicitly records
that and its 2026-09-08 generation date. The fifteen accepted rows and their
rasters remain byte-identical, as do the village and separate catalog icons.
Processing retains generated alpha and aspect, trims transparent margins and
uses the established maximum-512px mipmapped runtime pipeline. No game rules,
native generation, save schema or live scene scripts change in this packet.

The first Loft preview appeared hazy, but pixel inspection found zero alpha at
the sampled background positions. An attempted background-only refinement
returned an RGB checkerboard and was rejected; a second text-only alternate
was unselected. No extraction/repainting was applied to the chosen master.
Exact attempted prompts and output locations are retained in
`rigging_magic_generation_attempts.json`. The first in-engine composition passes
7196 checks but puts the Loft too high. Its final authored source bounds lower
it onto the existing left quay behind Harpoon Gantry; the Chapel occupies the
inner quay behind the Ledger, with an exposed roof information target.

Ordinary growth requires six orders, not the initially assumed four: Salvage
Ledger, Loft, Obituary Vault, Wake Oratory, Mourner Pilot Guild and Chapel on
Days 9–14. The first normal run retained all six exact-cost/save rows and the
ordinary Day-14 Ore trade (720 gold for one Ore), with complete authoritative
market-result equality. However, its new test loop wrongly inspected all catalog
variants as visible, causing missing-hotspot driver errors; that report is a
failure, not acceptance. The corrected loop selects every currently visible
non-embedded scene entry and preserves all alpha/pointer/information/input/state
assertions after each order. The copied Day-14 save remains `in_progress`, SHA256
`d81339827f0a9a617109d685ed7daf434679e9e2876900c5fb11c8951025ab68`;
it is not a new terminal-match claim. Read-only composition fixtures now name
their recorded scenario status instead of labeling every fixture terminal.

The final lowered-placement `rigging_magic_final_view_720/report.json` passes
7196 checks with no engine errors and unchanged complete source/input snapshots.
Its Day-14 capture was visually inspected: the Loft joins the existing quay
behind the Gantry, the Chapel remains visible above the Ledger, controls do not
clip, and the clean capture retains the actual Spell Tier 5 header. This view
loads the earned Day-14 save itself; it does not mix the Day-8 header with a later
Town composition. Broader resolution and fresh paid-construction proof are
recorded below, not inferred from this read-only view.

The fresh ordinary replay, `rigging_magic_growth_720/report.json`, passes 35722
checks with no engine errors and unchanged source/input hashes. All six orders
preserve exact costs, daily limits and complete save/re-entry state; the paid Ore
exchange matches the complete authoritative market result. Its actual post-build
Day-14 screenshot was inspected. `rigging_magic_save_comparison.json` compares
the complete before/after save files: every byte outside the single
`saved_at_unix` value is identical. That field is normal wall-clock metadata
written by unchanged `SaveService.gd:1660`; the raw files are not byte-identical
and no other field or formatting is excluded. The new earned save SHA256 is
`69f4c289bb0bd273f175e24a0b2704391302c0cf2dcc0be76c4d487f91886537`.
The 1920x1080 and 2048x1079 views each pass 7196 checks and were visually
inspected, as were the original developed fixtures at both larger resolutions
(7196 checks each). All have empty engine-error lists and unchanged complete
source/input hashes. The original terminal built-id fixtures remain detached
composition tests, not live-match screenshots; the two larger standalone fixture
runs inherit the Day-8 shell, while the growth run inherits its earned Day-14
shell. Neither mixed fixture is evidence of live terminal gameplay. The actual earned-save views retain
the consistent Spell Tier 5 header and stage. Neither composition clips controls.

Strict art/provenance tests (14), packaged-probe tests (3), 65 existing packaging
unit tests, initial repository validation and verified lossless import preparation
pass. The latter checks
2262 textures, retaining 2260 unchanged proof hits and verifying the two new
imports in 26.366 seconds. Both existing rendered Town reports also pass:
`full_play_runtime_20260905/rigging_magic_town_existing/report.json` under
`.artifacts/` records layout/dialog routing and building skyline progression,
with no engine errors. The latter retains its existing test-only anchor-size
warning in `_validate_building_information`; this packet does not fix or hide it.
The official Linux export/startup and 19-step generated-Town flow pass. Its
isolated release-pack Large replay also passes all 35722 checks, including the
paid Ore exchange, six exact-cost/save-re-entry steps and all five bootstrap
controls. Source/input/package hashes stay unchanged; final Loft/Chapel and older
developed-fixture captures were inspected. The earned source and Linux saves
match every byte except the normal save timestamp.

Both platform packages are 241910736 bytes, leaving 8089264 bytes of headroom.
`rigging_magic_package_parity.json` verifies all 5170 members: four additions
are the exact two verified texture payloads and their import records; only the
scene manifest and UID cache change among previous members. All 5164 other old
members are unchanged, and all 5169 non-platform-specific Linux/Windows members
match. The Windows export/startup and 23-step generated-Town flow pass, but its
short Main Menu exit reproduces the previously retained ObjectDB warning for
three Ogg streams and their playback/packet objects. No engine errors occur in
that smoke, and the generated-Town flow exits without the warning. This is an
explicit unresolved audio-lifetime limit, not an art fix or clean-shutdown claim;
the unchanged established smoke does not classify that warning as fatal.

The official Windows earned-save replay also passes 35722 checks, with empty
engine-error lists, all five bootstrap controls and unchanged source/input/export
hashes. Its headless adaptation omits only eight paired frame/capture operations,
not gameplay or input assertions. The complete source/Linux/Windows earned saves
are compared in `rigging_magic_packaged_save_comparison.json`: every byte outside
the single normal `saved_at_unix` value matches, including all gameplay fields
and formatting. The retained Linux and Windows save SHA256 values are
`c5f3d553fe0a33ce27e0249e76f3fe7640e0459b09a0b138774493c98d20e524`
and `3a695f4e7bf1965c62139042430a5392ed9ea3ad79be9b07adff566d58394945`.
The packaged Large replay itself exits without the audio warning on both
platforms. Wine headless remains distinct from physical Windows/GPU evidence.

The normal smoke wrappers retire their temporary exports/Wine installations
automatically, preserving this packet's verified isolated release pair. After
the separate Windows probe completed and its prefix had no live processes,
`rigging_magic_retire_wine.py` permanently removed only that prefix's three
disposable Windows/Program Files directories, reclaiming 1309552640 bytes.
`rigging_magic_wine_retirement.json` verifies every retained user-data/registry
file; saves, logs, source assets, caches, RMG evidence and release packs remain.
Those runtime directories can be regenerated through a fresh Wine initialization.

All thirteen jobs in the serial `rigging_magic_validation_batch.py` complete
successfully, including final repository and diff checks. Exact commands and
results remain in `rigging_magic_batch.json`, with repository output in
`rigging_magic_repo_final_driver.log`. Reproduce the six-order source path with
`tests/town_scene_layer_regression.py --rigging-magic-growth --save <Large08-slot2>
--developed-save <Large08-slot3> --resolution 1280x720 --label <fresh>`; the existing
packaged wrapper forwards those arguments with isolated `--binary`, `--pack`,
`--platform`, `--bootstrap-controls` and a fresh Windows `--wine-prefix`.
The wider presentation goal remains in progress for other buildings, upgrades,
factions and Overworld repairs. Bellwake itself still lacks accepted scene layers
for Drowned Map Room, Memory Anchor, Leviathan Sounding, Drowned Admiralty and
the Memory-Rite Court upgrade; its Town Hall is embedded in the original base.
The audio warning and earlier physical-Windows/legacy-keyboard/Moonbite limits
also remain explicit. This two-painting packet is not full-goal completion.
