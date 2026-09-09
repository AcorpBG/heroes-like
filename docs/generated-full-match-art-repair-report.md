# Approved full-match art repairs

Parent: `quality-generated-full-match-20260906`; selected child:
`ux-generated-full-match-presentation-20260906`. Status: in progress; the owner
removed the package-size budget and requested continuing. The parent quality
goal remains unfinished.

## Mireclaw opening integration — 2026-09-09, validated without a size budget

The real deterministic Medium seed `10`, two-player land setup with
`faction_mireclaw` / `hero_vaska` produces owned Duskfen at native placement
`native_h3maped_ce8e40cc_object_0950`, with the hero at entrance `(43,40,0)`.
`tests/mireclaw_town_opening.py` uses the normal setup/retry, Town-entry and
save/resume APIs. Its unchanged Day-1 input has SHA256
`57f48cd7fcb650777a7923f5aec273f8bd73e61d65acaf9306a048323549ba89` and is retained
at `mireclaw_opening_01/opening_save.json` beneath the evidence base below.
The original Town capture exposes the miniature Den and warm blue-roofed Hall
catalog icons. There was no missing scale transform: this faction had no exact
scene layers, so `TownStageView` correctly selected its older catalog artwork.

Three original built-in, text-only generated paintings now have exact-faction
scene mappings: Blackbranch Den, Wayfarers Hall and Market. Their reed roofs,
wet dark timber, short pilings and causeway approaches were described from the
inspected original Duskfen village. The Den joins the middle-left boardwalk,
the Hall sits behind the right communal fire, and the Market continues the left
working landing toward the ferry. The original panorama and all earlier art
remain separate, unchanged assets. No runtime renderer, construction, native
generation, content rules or save schema was changed.

Masters and exact prompts are in
`art/towns/source/generated/scene_layers/faction_mireclaw/`; derivatives are in
the matching `source/trimmed/scene_layers/` and `runtime/scene_layers/` folders.
`tools/prepare_town_scene_layers.py --faction faction_mireclaw` hash-locks all
three originals, crops only fully transparent outer margins and preserves alpha
and aspect through the existing 512-pixel maximum pipeline. Runtime imports
retain mipmaps. The manifest records source/prompt/trim/runtime hashes, generation
date/output, no image-reference inputs, grounded bounds and shared alpha-aware
input ownership. Full original SHA256 values are recorded in that manifest.

`tests/town_scene_layer_regression.py --faction mireclaw` requires that exact
opening input. It buys the ordinary 1000-gold Market, confirms a normal End Turn,
then pays for Mire Pens using the existing ledger. Both live orders are compared
against complete authoritative rule results, including recaps, resources and
built ids. Save/re-entry, painted/transparent pointer ownership, keyboard and
controller information routes, main-building construction and shared-faction
cache/missing-layer boundaries are retained. Mire Pens remains its own older
catalog painting: the mixed composition/input control is not acceptance of its
art or a complete Mireclaw town. Detached Hall visibility remains explicitly a
view fixture, not evidence of an earned construction order.

Evidence base: `.artifacts/generated_full_match_quality_20260906/`.
`mireclaw_before_720` and `mireclaw_before_2048` each retain the 14 expected missing
scene-art failures, with no engine errors and unchanged complete purchase/save
behavior. The inspected first integrated `mireclaw_draft_720` passes 4068 checks.
All 16 source jobs pass in `mireclaw_source_batch.json`: the final
`mireclaw_accepted_1280x720`, `mireclaw_accepted_1920x1080` and
`mireclaw_accepted_2048x1079` each pass 4068 checks with no engine errors; the six
Python suites pass 71 tests; prior Embercourt/Veilmourn, shared Town layout and
all-town progression, Overworld distinct/decorative, repository and diff checks
also pass. Opening, paid Market and mixed Mire Pens captures were visually
inspected at all three resolutions: the three new paintings retain their
proportions, ground against the boardwalks and leave navigation/HUD controls
clear. The old Mire Pens catalog composition is not accepted as scene-matched art.

`mireclaw_source_acceptance.json` compares all ten before/after Market and Mire
Pens saves as complete exact Decimal JSON and raw bytes, excluding only
`/saved_at_unix`; all match. `mireclaw_preservation.json` proves 5868 of 5869
earlier tracked art/content/runtime/native files unchanged; only the scene
manifest differs, retaining every old row. All 46 earlier layers, panoramas,
catalog paintings, rules and maps remain unchanged. `mireclaw_idempotence.json`
proves all 197 source/prompt/trim/runtime/manifest files byte-identical after
repeating the selected preparation.

Before the owner's no-limit decision, both official export/package smokes built a
**250525428-byte** PCK, **525428 bytes above** the then-enforced 250000000-byte
limit. Export itself returned zero with no fatal export messages, but the old
size gate rejected startup. These retained failures do not claim new-package
gameplay or Windows runtime acceptance.
`mireclaw_budget_linux/report.json`, `mireclaw_budget_windows/report.json` and
`mireclaw_package_budget_blocker.json` retain the evidence. All 5234 package members
were compared: six new texture/import entries, only scene manifest and UID-cache
changes, and 5226 old payloads byte-identical to accepted Marsh packages. Platforms
differ only in `project.binary`; no source masters leaked into the packages.
The three new lossless textures total 846716 bytes. Existing factor-100 preparation
preserved every decoded image/mipmap but yielded no additional saving for them.

The owner subsequently directed removing the imposed budget entirely, not
replacing it with 350 MB. Both official export gates, the packaged Town probe,
lossless-transfer regression and repository validator now omit the obsolete
ceiling while retaining actual sizes and all independent asset/runtime checks.
`tests/test_release_package_size_policy.py` passes 11 focused tests: the real
export decision expressions accept synthetic sizes above 250 MB/350 MB, every
existing asset-integrity condition independently rejects bad content, and
lossless proofs still reject missing/changed/unproven/platform-drifting payloads
or absent savings. Synthetic sizes are not actual large-package runtime proof.

All six jobs in `mireclaw_packages_no_cap_02_batch.json` now pass: official
Linux and Windows export/startup/generated Town flows, then the identical paid
Mireclaw probe at 1280x720 and 2048x1079 on each platform. Every exact Town replay
passes 4068 checks with zero runtime errors, unchanged input and immutable export
files. Both platforms pass all five inert/path/hash/base-type/valid-Node bootstrap
controls. Linux's generated flow passes 19 steps/eight daily builds; Windows's
passes 23 steps/ten builds. Four final Linux Market/Mire Pens captures were
visually inspected at both resolutions. Windows is headless Wine, not physical
Windows GPU/audio/controller certification.

`mireclaw_packages_no_cap_02_acceptance.json` proves all 18 complete before/source/
Linux/Windows purchase saves equal as exact Decimal JSON and raw bytes outside
only `/saved_at_unix`. The actual 250525428-byte packages are byte-identical to
the previously budget-rejected exports, confirming no art was reduced or content
removed to pass. All 5234 members remain, 5226 earlier payloads are unchanged,
and Linux/Windows differ only in `project.binary`. Accepted exports and official
reports are in `mireclaw_release_linux_no_cap_02/` and
`mireclaw_release_windows_no_cap_02/`, with matching `isolated-export/` bundles.
Linux PCK SHA256: `e5512c9453b937bf33146322227cb2fe5219bd833ce1801824a7df801c2cb8e8`.
Windows PCK SHA256: `1eb3cc8269eb5aa9876d3bf873ebe28b4ef785bcaa41d632172b049e59a2dd93`.

The no-budget continuation also passes 87 Python tests across the size-policy,
packaged Town/Overworld, lossless imports, JSON compaction, release-candidate
pipeline, release-artifact verification and Mireclaw-sequence suites, plus
repository validation and `git diff --check`. The initial no-cap batch failed
before launching Godot because the transient service lacked `/root/.local/bin`
in PATH; `mireclaw_packages_batch.json` and its driver traceback remain retained.
The fresh `_no_cap_02` run supplies the executable path and completed normally;
no game or validation assertion was relaxed to address that launcher failure.

This accepts the three-layer opening and package-policy checkpoint, not all
Mireclaw buildings or the parent quality goal. No art quality, gameplay, save,
native/RMG, source-exclusion or untrusted-archive parser safety changes accompany
the removed content budget. The visibly unconverted Mire Pens painting is the
next Duskfen art target; remaining faction/variant art stays unfinished.

## Marsh Listener Post extraction repair — 2026-09-09

The same earned Medium Day-46 map used in the accepted Cinder/Moss packet exposes
another contaminated original cutout. Inspection of the runtime PNG and generated
batch-06 atlas shows a detached upper white divider, isolated sheet debris and
magenta around the wooden listening hut, stilts and reeds. This is extraction
contamination, not a missing identity or procedural fallback. The actual
`OverworldMapView._resource_asset_id` selects `mapobj_marsh_listener_post` from
`object_marsh_listener_post` for resource site `site_marsh_listener_post`.
Native placement `native_h3maped_93c0f05a_object_1053` remains at `(39,41,0)` with
the original one-cell body/block/visit masks, unclaimed controller and earned
exploration. No generator, map records, renderer, gameplay or save code changed.

`tools/repair_map_object_cutouts.py --write --asset mapobj_marsh_listener_post`
reuses approved analytical magenta unmatting within independently inspected
`[124,176,382,420)` bounds. The full 512x512 canvas remains; only detached debris
is excluded. All 30,385 uncontaminated painted body pixels are unchanged, with
34,618 visible pixels retained. Stray pixels fall from 356 to zero and magenta
contamination from 4,580 to zero. Original inputs/atlas are hash-locked. A separate
`art/overworld/source/generated/full_match_art_repairs/marsh_listener_cutout/`
packet retains the exact before PNG, processing description and runtime hashes.
Selected preparation leaves accepted Cinder/Moss packets untouched; focused
tests cover per-packet preservation, idempotence, corrupt masters, invalid
selection and manifest identity/provenance mismatch rejection.

Source input SHA256: `d73f51678c1ca4b756fe15a236e5eaacad5e2141ab01aa235d3e53b0000f7a7f`.
Original atlas SHA256: `111b62a8da56c966ccc2d93cf1a4bfb25919de663aa012de667b98bd75b32798`.
Repaired runtime/trim SHA256: `b1a9c1e6d86fade72300649791e05628f3b651e6168b33c437630ea465379e0b`.

Evidence base: `.artifacts/generated_full_match_quality_20260906/`.
`marsh_listener_before_1280x720` and `marsh_listener_before_1920x1080`
fail only the two intended decoded-image checks, with zero engine errors.
Both `marsh_listener_accepted_<resolution>` source cases pass all 31 checks;
before and after gameplay images at both resolutions were visually inspected.
The unchanged earned input is `embercourt_late_court_packaged_linux/earned_growth_save.json`,
SHA256 `a3c565cc299de08f2970be3456b07d97a8fba628c288162f12c5360e7c89d6fe`.
Reproduce with `python3 -B tests/overworld_map_object_cutout_regression.py --case
medium_marsh_listener --save <exact-earned-save> --resolution <1280x720|1920x1080>
--label <fresh>`; official packages use the existing `packaged_overworld_map_object_cutout_regression.py`
adapter and restricted SHA-checked Node bootstrap, without runtime changes.

All 16 source jobs pass in `marsh_listener_source_batch.json`: the two exact
Marsh views, all three prior Cinder/Moss cases, both Wreck Quay resolutions,
six existing distinct/decorative/fog/movement/Town reports, 44 Python tests,
preservation and repository/diff checks. `marsh_listener_source_acceptance.json`
proves all four complete saves equal both as exact Decimal JSON and raw bytes
outside only `/saved_at_unix`; entire placement and tile/art-footprint authority
also match. `marsh_listener_preservation.json` proves 5,864 of 5,867 earlier
tracked art/content/runtime/native files unchanged, with only the two selected
PNGs and the one Overworld manifest row different. Normal Godot import and the
existing stronger-lossless helper preserve the complete decoded raster while
reducing that fresh imported texture by 700 bytes (`marsh_listener_lossless.json`).
All six jobs in `marsh_listener_packages_batch.json` pass: official Linux/Windows
export and startup/generated-map/Town construction, then the identical earned
Marsh probe at both resolutions on each platform. Both platforms also pass the
five existing inert/path/hash/base-type/valid-Node bootstrap controls. All six
repaired source/platform views pass 31 checks with zero engine errors. The four
corrected source/Linux screenshots were inspected; Windows is headless Wine,
not physical GPU certification. New Wine installations use disposable temporary
directories, leaving persistent caches, existing evidence and saves intact.

`marsh_listener_packages_acceptance.json` proves all eight before/source/Linux/
Windows saves equal outside only their timestamps, including raw bytes and
entire placement/tile/art-footprint records. Each PCK is 249671040 bytes, leaving
328960 bytes under the unchanged 250000000-byte limit. All 5228 members remain;
5225 prior payloads are byte-identical. Only the selected imported Marsh texture,
Overworld manifest and generated UID cache differ from the accepted Cinder/Moss
export. Linux/Windows differ only in `project.binary`; no source masters or
editor resources leak into either package. Official reports remain directly in
`marsh_listener_release_linux/report.json` and
`marsh_listener_release_windows/report.json` beside the retained isolated exports.
Linux PCK SHA256: `bcd67ac63f446be413423e671dccddbcb9f2bd9f94646381992a838d22c771d6`.
Windows PCK SHA256: `0b5d770225cb528627f2bb605b70f8b7d391ccc2a05fa38b624150522e4ce086`.

This cutout checkpoint is accepted. There were no failed acceptance attempts;
the two intentionally failing original-image controls remain retained. A
read-only duplicate-payload check found only 2612 repeated bytes, insufficient
to provide meaningful headroom for remaining Town art; no deduplication or
package-limit change was implemented.
The wider Town variant/faction art requirement and full goal remain open.

## Cinder Ore Face / Moss Oath Cache extraction repair — 2026-09-08

This continues the owner-approved cutout processing, not new painting or changes
to map adoption. The defects were already recorded in the full-match quality
report: white/magenta sheet debris in Cinder Ore Face and a magenta fringe on Moss
Oath Cache. Inspection of the original generated batch04/batch09 atlases and the
exact runtime PNGs confirms contaminated extraction, not absent sprite mappings.
The earlier distinct-sprite count did not prove clean alpha edges.

`OverworldMapView._resource_asset_id` resolves the actual Large Day-8 placement
`native_h3maped_c2520619_object_2306` at `(40,73,0)` through
`object_cinder_ore_face`, despite its adopted `site_aetherglass_lens_house` id.
The Medium earned Day-19/Day-46 supply placement
`h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources`
at `(41,41,0)` resolves Moss through `site_generated_town_required_source_cache`.
The same cache painting is authoritative before and after the ordinary earned
capture; unrelated `site_moss_oath_cache` opened-state art is not changed.

`tools/repair_map_object_cutouts.py` retains hash-locked extracted inputs and
generated masters in the established source/generated/trimmed/runtime pipeline.
It removes only inspected out-of-body debris and applies the previously approved
analytical magenta unmatting. Both canvases remain 512x512; every uncontaminated
painted pixel is preserved. Provenance lives at
`art/overworld/source/generated/full_match_art_repairs/cinder_moss_cutouts/manifest.json`.
The runtime manifest changes only the two processing-manifest/hash registrations.

| Original painting | Stray pixels before → after | Magenta pixels before → after | Painted pixels retained |
| --- | ---: | ---: | ---: |
| Cinder Ore Face | 282 → 0 | 2941 → 0 | 47194 |
| Moss Oath Cache | 5 → 0 | 2056 → 0 | 42795 |

All six pre-repair rendered controls (three earned cases at 1280x720/1920x1080)
fail only the two pixel checks, with no engine errors, identity/mask/controller
failures, fog injection or full-state/save drift. The new regression uses normal
saved Overworld entry or normal Leave Town, not synthetic ownership or progress.
`tests/test_map_object_cutouts.py` passes its six strict original/master,
idempotence, malformed-input, preservation and fail-closed provenance tests after
the repair. The package adapter's two focused tests retain every assertion while
translating Windows paths and omitting only paired headless captures.

Evidence root: `.artifacts/generated_full_match_quality_20260906/`.
`cinder_moss_lossless.json` verifies both engine imports without decoded-pixel
changes; `cinder_moss_preservation.json` checks 5825 earlier tracked files, with
only the four selected PNGs and Overworld manifest changed. All 5820 others,
including earlier Town/Wreck/opened-cache art, native/maps/content and runtime
owners, are unchanged; tracked `src/gdextension`/`bin` also match HEAD. Both
repaired PNGs and all six repaired gameplay screenshots were visually inspected.
Source acceptance is complete: `cinder_moss_source_acceptance_batch.json` records
17 passing jobs, including 43 Python tests, six exact earned views, both Wreck
Quay resolutions, six existing sprite/decorative/fog/movement/Town reports,
preservation, `python3 tests/validate_repo.py` and `git diff --check`.
`cinder_moss_source_acceptance.json` compares all twelve before/after saves:
complete exact-Decimal JSON and raw bytes match outside only `/saved_at_unix`;
entire placement records and tile/footprint/mapping authority also match.
Package acceptance is also complete (2026-09-09):
`cinder_moss_packages_final_batch.json` records 14 passing jobs: both established
export/startup/generated-Town flows and all twelve exact Linux/Windows saved-map
cases. Both platforms pass the five existing bootstrap rejection/activation
controls. Windows uses headless Wine; this is not physical Windows GPU evidence.
All six Linux packaged screenshots were inspected in addition to the six source
views. `cinder_moss_packages_acceptance.json` verifies all 24 complete saves
(before, source, Linux, Windows) as exact-Decimal JSON and raw non-clock bytes,
with identical entire placements and tile/footprint/mapping authority.

Both packs contain 5228 entries and are **249668544 bytes**, leaving **331456
bytes** under the unchanged ceiling. Relative to the accepted Riverwatch pack,
5224 entries are unchanged: only the two cutout `.ctex` files, Overworld manifest
and UID cache differ. Linux/Windows differ only in `project.binary`. No source
masters or accidental editor resources are shipped. Earlier Town, Wreck Quay,
opened-cache and all other members remain identical. Pack SHA256:

- Linux: `56a95c24b0706b6fb29237dd0a2a58724417b7fc0c7bc26ed5d7dc829516ad2a`
- Windows: `66fa8158fc35f893738530fecf86761507d4467134ad132ae8e792430f70582b`

Exports are under `cinder_moss_final_release_<platform>/isolated-export/`;
per-case reports/views use `cinder_moss_packaged_final_<platform>_<case>_<resolution>/`.
The standard checker initially wrote to its default report directory because
the guard wrapper set the output override after importing it. Those successful
reports/logs were copied unchanged into the packet after verifying their ordered
full-member inventory against the tested PCKs; hashes and originals are recorded
in `cinder_moss_standard_report_retention.json`. The repeatable wrapper now sets
the override before import. No replacement pass result was synthesized.

This accepts only the two cutout corrections, not full presentation or the full
goal. The inspected earned Medium view still exposes sheet/magenta contamination
in Marsh Listener Post, native placement `native_h3maped_93c0f05a_object_1053` at
`(39,41,0)`, mapped to `mapobj_marsh_listener_post` from original batch06. Its
runtime PNG was inspected and remains unchanged; it is a next bounded follow-up.
Other Town variants/factions and the unapproved data-budget request remain open.

The first background source launch failed before the engine ran because its
service PATH omitted Godot. Its terminal report is retained; the corrected
isolated service explicitly inherits the execution PATH and uses fresh evidence
labels. No failed run is counted as an acceptance pass.

The first export service also lacked a login home, so Godot searched
`./godot/export_templates` instead of the installed templates. Its accidental
44 KiB editor-settings directory is retained outside export scope at
`cinder_moss_failed_service_godot_data/`. An already-scanned subsequent package
contained two editor-settings resources; the all-member check rejected it and
the batch was explicitly stopped. Final package checks use `User=root` with
`SetLoginEnvironment=yes`, fresh labels and an early exact-member check before
runtime testing. These are validation-environment corrections, not game changes
or accepted package evidence; the failed/stopped reports remain retained.

## Approval and boundaries

On 2026-09-07 the owner approved resuming with scene-matched per-faction Town
building layers and Overworld cutout repairs. Requirements:
`docs/generated-full-match-quality-requirements.md` (approved-art continuation)
and `docs/town-integrated-building-progression-requirements.md` (visual/interaction
invariants). Original game assets only; no rules, masks, placement, save schema,
native generation or unrelated cleanup changes. Runtime exports stay below
250000000 bytes on both platforms. Reverting the coherent art/code commit restores
prior rendering without save migration.

## Embercourt late court — validated, 2026-09-08

The four remaining Riverwatch buildings (Beacon Court, Drake Sluice, Charter
Colossus Bastion and Charter Flame) lacked exact scene-manifest rows and therefore
displayed their separate catalog paintings. Original RGBA scene layers now exist
in source/prompt/trim/runtime paths, through the unchanged preparation pipeline.
All 42 previously accepted layers, the village, catalog art and gameplay remain
intact. The four new paintings now pass source and official-platform acceptance,
completing the 24 non-embedded starting/constructible Riverwatch mappings. Other
town variants, factions and the full goal remain unfinished.

The legitimate input is `embercourt_civic_accepted_earned_720/earned_growth_save.json`,
Day 19, SHA256 `82da9e8507a069a56b4ee114a38b017780f0a60d474400b2e249f4b19696b57f`.
Its existing resource placement
`h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources`
at (41,41,0) references `site_generated_town_required_source_cache` in
`content/resource_sites.json`: normal claim rewards and controlled daily income
provide the missing rare resources. The existing rare-source guard blocks its
approach. No native generation, source placement, market or income rule changed.

The Python-owned `--embercourt-late-court-growth` continuation pays for three
normal field recruit orders, retains the existing garrison, walks the visible
map through its ordinary controller, wins the guard through confirmed Quick
Resolve, continues the casualty report, claims the cache and walks back to the
same town. Construction uses normal ledger orders, paid Ore trades and confirmed
End Turns. No resources, days, armies, ownership or built ids are injected.

The original-renderer `embercourt_late_court_control_720` completes **35855 checks**
with exactly **13 expected missing-art failures**, no runtime errors and unchanged
source/input hashes. The four purchases occur on Days **22, 30, 40 and 46**;
all save/re-entry checks pass. Its earned Day-46 nonterminal save SHA256 is
`bc67b368c3be8b5afe096661ff2b6540784eb82b476ba552b2b3502a174c1a93`.
The earlier `embercourt_late_court_before_720` driver incorrectly checked raw
`owner` instead of `OverworldRules._resource_node_matches_controller()` (the
imported mine uses collected/controller state), and confirmed Quick Resolve
before its deferred focus settled. That failed evidence is retained. The clean
repeat uses the canonical predicate and existing settle convention; no production
ownership or focus behavior was altered. Result logging now keeps compact facts,
not copies of the nested full autosave payload.

Four built-in text-only generated masters have genuine alpha; exact prompts and
source hashes are adjacent to the PNGs under
`art/towns/source/generated/scene_layers/faction_embercourt/`. Two attempted Flame
edits produced opaque checkerboard backgrounds and were rejected, retained only
as ignored failure evidence. The final Flame is a fresh original painting using
the Bastion architectural brief, not a claimed pixel-identical edit. Bastion and
Flame share source bounds/ground anchor; the Court joins the right terrace and
the Drake pens meet the existing waterfront. Their four imported textures total
1106794 bytes; complete package-size and member proofs are recorded below.

The first developed draft records four test errors, not engine errors: the old
catalog Flame/Market overlap assumption counts a now-exposed Market click twice,
and the caller requests the correctly superseded Bastion as a visible layer.
The driver now verifies actual painted ownership, resets the independent body
click counter, explicitly proves Flame replacement and tests only the expected
visible successor. The strict visible-layer assertion remains unchanged;
Bastion's own input is covered before upgrade in paid growth. Twenty sequence
unit tests pass. The fresh `embercourt_late_court_developed_review_720` passes
**8499 checks**, without runtime errors or source/input/developed-save changes;
its final 1280x720 composition was inspected. The strict art suite passes 26
tests. An added manifest-mutation control then demonstrates two undetected
Charter upgrade relocations; adding the Bastion/Flame pair to the existing
reconstructed-site/ground-anchor validator makes that negative control pass.
This changes validation only, not the frozen gameplay, manifest or paintings.

`embercourt_late_court_preservation.json` proves all **42 prior rows**, **126 prior
scene rasters**, 42 prompts and **416 existing files** unchanged from `f9a9befb`;
selected preparation is byte-idempotent. `embercourt_late_court_lossless.json`
verifies all four new imports through the existing engine-decoded image/mipmap
comparison (2287 prior cache hits, four reimports, no byte-size change).
The finite `embercourt_late_court_source_validation.py` batch has completed all
**18 jobs**, all successful. At **1280x720, 1920x1080 and 2048x1079**, each frozen
earned replay passes **35963 checks**, and each developed-input fixture passes
**8499 checks**, with no engine errors and unchanged source/input hashes. All
four construction stages, final saved/re-entered views and developed compositions
were visually inspected at each resolution; the guard casualty report and normal
map capture were also inspected at 720p. The scenic cover crop keeps the HUD,
command controls and footer unobstructed. Developed fixtures remain composition
and input evidence only, not legitimate progression.

`embercourt_late_court_source_save_comparison.json` proves all four complete
**7469715-byte Day-46 saves** (original renderer plus three source resolutions)
equal as exact-decimal JSON and raw bytes outside only `/saved_at_unix`. The
receipt retains every input hash; no other field is excluded. The two opening
compatibility cases pass **2519 Embercourt / 1382 Veilmourn checks**. Existing
`town_screen_layout_and_dialog_controls_report` and
`town_building_skyline_progression_report` both pass without runtime errors.
All **76 Python tests** pass (27 strict-art, 20 Embercourt sequence, 4 preparation,
3 late-harbor sequence, 3 packaged-probe and 19 lossless-import tests), as do
the lossless/preservation rechecks, repository validator and diff checks.

Both finite services are terminal-successful: **18 source jobs and 8 package
jobs**, all return codes zero. Official Linux/Windows export, startup and normal
generated-Town construction pass. Each release also passes the same **35963
earned / 8499 developed checks** without engine errors, altered source/input or
changed exported bytes. All five restricted-probe bootstrap controls pass on
each platform. All four Linux release saved construction views and its final
developed composition were inspected at 1280x720; its independent generated-town
construction capture was inspected too. Windows uses headless Wine, retaining
every gameplay/input/save assertion and omitting only paired capture operations;
this is not physical Windows/GPU certification or a shutdown-lifetime fix.

`embercourt_late_court_packaged_save_comparison.json` proves **all six complete
Day-46 saves** equal as exact-decimal JSON and raw bytes outside only the clock.
`embercourt_late_court_package_parity.json` compares **all 5228 members**: exactly
four new texture payloads and four import descriptors, **5218 prior members
unchanged**, and only the scene manifest / generated UID cache updated. Platform
payloads differ only in `project.binary`; all four new texture payloads match
the lossless import proofs and source masters remain excluded. Both PCKs are
**249662752 bytes**, leaving **337248 bytes** below the unchanged 250000000-byte
ceiling. SHA256: Linux
`25fb3569ff985b5613d58ed0c2a4f4b9bb1d7ddb78c17a46f00d25de2de9e9a0`;
Windows `c07e929db8b9aea849ee95b283a99d94f65fba576c5f1bdfb885f7b823004756`.

After terminal platform/parity acceptance and a live-process-reference audit,
`embercourt_late_court_wine_retirement.json` records **2619101184 bytes** reclaimed
from only the two finished probes' disposable Wine system/program directories.
User/save/registry hashes are preserved, as are caches, source, captures, reports,
RMG evidence and both retained exports. Deleted Wine system files are rebuildable.

The source and package batch JSON files retain the exact executed commands.
The tracked probe entry points are `tests/town_scene_layer_regression.py` and
`tests/packaged_town_scene_layer_regression.py`, using `--faction embercourt
--embercourt-late-court-growth` and the hash-locked Day-19 input above; use fresh
labels, the three stated source resolutions, and official release binaries/PCKs
with `--bootstrap-controls` for the package replay. Complete comparisons are
reproduced by `embercourt_late_court_save_comparison.py packaged` and
`embercourt_late_court_package_parity.py`. Evidence/helper names are relative to
`.artifacts/generated_full_match_quality_20260906/`.

## Embercourt civic quays — validated, 2026-09-08

Lantern Court and Relief Quay previously selected their separate catalog paintings
in Riverwatch because their exact faction/building scene-manifest rows were absent.
The selected correction adds original grounded court/quay layers, preserving all
40 accepted paintings, the village, catalog information art and gameplay.
The exact earned Day-17 input from `424edffe` is
`embercourt_riverworks_accepted_earned_720/earned_growth_save.json`, SHA256
`9f7dcbf9f69d49e21d9404d042e63e388c5ce959411af738dcf9b7422ff1884e`.
The Python-owned `--embercourt-civic-growth` sequence uses the existing paid
ledger, paid Ore Trade and confirmed End Turns; no new market goods or resources
are injected. Beacon Court, Drake Sluice, Charter Colossus Bastion and Charter
Flame remain open: they require rare resources absent from this save, whereas
the normal market only buys/sells wood and ore. Their legitimate acquisition and
art acceptance are not implied by this two-building checkpoint.

The terminal original-renderer control completes 18348 checks and both purchases
on Days 18/19, but has five expected missing-layer failures plus one unexpected
Trade recap mismatch. The detailed repeat
`embercourt_civic_control_details_720` proves the latter is the reference clone:
`normalized()` uses `JSON.stringify()` with sorted dictionary keys, then
`control.from_dict(before)` reproduces that reordered state. The existing
`get_town_recruit_options()` preserves recruit dictionary order and
`TownRules._next_town_action_line()` chooses its first ready recruit. The sorted
control recommends “Citadel Pikeward fields 4 now.”; the actual UI recommends
“River Guard fields 12 now.” Only the four recap next/text fields differ.
The corrected driver clones `session.to_dict()` directly, asserts identical
recruit-option order, and still compares complete normalized state/recaps.
Production rules and saved state remain unchanged. The fresh
`embercourt_civic_control_ordered_720` finishes **18351 checks**, with exactly five
expected missing-layer failures, no recap mismatch or engine errors and unchanged
input/source hashes. Its complete earned Day-19 save SHA256 is
`6a606584222a44e59d07e80b8fc5455c4501a17b237bf38636ab49da2ac46923`.
That run is the missing-art-only control; the two earlier runs retain their
explicit clone defect and are not presented as clean acceptance evidence.

The initial 14 sequence/preflight tests pass. The strict 24-test art suite fails exactly
on `Missing Embercourt civic-quay scene mapping` before integration. The initial
`embercourt_civic_before_720` launcher stopped with code 127 before Godot ran:
the systemd service lacked `/root/.local/bin` in PATH. This is retained launcher
evidence, not a game/render failure. Corrected launcher and clone-control results
are recorded separately above.

The built-in image tool generated two text-only transparent 1536x1024 original
masters, inspected and copied unchanged into
`art/towns/source/generated/scene_layers/faction_embercourt/`, with exact adjacent
`.prompt.txt` files. Lantern Court output `exec-008e04ee-92e3-47b4-bddf-7820ce9d37d4.png`
has SHA256 `f34d056a814a65e2cb46967bf040128680118d6a9ae721d7062e0296add76738`;
Relief Quay output `exec-07981847-b39d-4354-b993-1aa3a0f885e4.png` has SHA256
`4cffe2a4a5b569b1c17fa4a0d27436688f1214cc6436542d6f02101dceb1d7ca`.
Original outputs remain under the same thread's generated-image directory.
Actual alpha is present; no manual recoloring, silhouette drawing or background
approximation was used. The two exact-faction rows and aspect-preserving runtime
derivatives are now registered with normal lossless imports/mipmaps. Preservation
checks prove all 40 old rows, 120 scene rasters and 40 prompts unchanged, with
byte-identical selected preparation. The 24 strict art tests and 16 sequence tests
pass. The Oath/Lantern pointer probe now follows the actual foreground alpha:
the old catalog silhouette covers its sampled roof while the lower scenic arcade
may expose it; either route is checked before the separate Oath body and Slip
overlap controls. No runtime input owner changed.

The terminal developed 720p draft passes **8457 checks** and the ordinary paid
growth draft passes **18387 checks**, both without runtime errors and with the
source/input unchanged. Their actual frames and both information surfaces were
visually inspected: the low Court follows the foreground-right stone bank;
Relief's store and timber hoist meet the left quay, with an attached pontoon and
plain barge extending into the channel. Neither needs an independent landscape
tile or a moved command control. The earned header reaches Tier 4 then Tier 5.
The detached developed fixture still retains its previously documented stale
opening-header context; it is not legitimate progression evidence.

`embercourt_civic_draft_save_comparison.json` proves complete exact-number JSON
and raw save-byte equality against the clean pre-art control, excluding only
`/saved_at_unix`. The live sequence reaches Day 19 with 21 built ids, 3368 gold,
12 wood and zero ore/rare resources after three paid one-Ore trades and two
normal daily purchases. Its final save SHA256 is
`8b82c1fd0e3e42ebabbb61fd0e24ad42c8d5321456cc43aa08d00ede41c5ffc7`.
The frozen placement/curation passed the finite 18-job source acceptance
(`embercourt_civic_source_validation.py`, receipt `embercourt_civic_source_batch.json`,
followed by `embercourt_civic_source_resume.py` / `embercourt_civic_source_resume.json`).
All three earned cases pass **18387 checks** each; all three mixed-developed cases
pass **8457** each at 1280x720, 1920x1080 and 2048x1079. Their final frames were
visually inspected for grounding, depth, crop and clear controls. Embercourt and
Veilmourn opening controls pass 2519/1382 checks; the shared Town layout/dialog
and skyline reports pass without runtime errors. Six Python suites pass **69
tests**, the repository validator/diff pass, and preservation proves 406 prior
files plus byte-identical selected preparation.

The first batch stopped only at lossless import: a fresh transient systemd service
had neither HOME nor XDG data/config/cache paths. Godot returned zero but reported
relative editor-cache/feature-profile directory failures; the strict importer
correctly rejected that run before cache publication. The failed receipt and
`embercourt_civic_lossless.json` / `.import.log` remain intact. The resumed nine
jobs explicitly set `XDG_DATA_HOME=/root/.local/share`,
`XDG_CONFIG_HOME=/root/.config` and `XDG_CACHE_HOME=/root/.cache`; retained successful
reports are bound to unchanged source hashes and the prior batch hash. No game,
import-tool or error-filter change was made, and no passed rendered case was
discarded or counted twice.

`embercourt_civic_lossless_verified.json` proves exact decoded/header equality for
both new caches, including all nine mip levels. Their 288420/247866-byte encodings
were already at factor 100; verification saves zero additional bytes. The other
2285 eligible entries remain cache hits. `embercourt_civic_source_save_comparison.json`
proves complete exact-number JSON and raw-byte equality for the old control and
all three final earned saves, excluding only the timestamp.

The subsequent eight-job official Linux/Windows export and packaged-probe batch
passes (`embercourt_civic_package_validation.py` / `embercourt_civic_package_batch.json`),
with the same explicit XDG paths and normal tool PATH. Both exports pass normal
startup/generated-Town construction. Each isolated release passes **18387 earned
checks** and **8457 developed checks**, with unchanged packages, source and inputs.
All five restricted bootstrap controls pass on both platforms. Linux final earned
and developed captures were visually inspected; Windows runs headlessly under
Wine, omitting only paired capture operations while retaining all gameplay/input/
identity/save assertions. This is not physical Windows GPU certification. No
error/leak warning appears in this packet's normal Windows startup/generated-entry
logs; the earlier intermittent Ogg shutdown warning has not received a lifecycle
fix and is not claimed resolved.

`embercourt_civic_packaged_save_comparison.json` proves all six complete earned
saves (old control, three source resolutions and both platforms) equal outside
only `/saved_at_unix`. `embercourt_civic_package_parity.json` checks every one of
**5220 PCK members**: four new exact texture/import members, 5214 unchanged prior
members, and only the scene manifest/UID cache changed among existing members.
The platforms differ only in `project.binary`. Each PCK is **248543948 bytes**,
leaving **1456052 bytes** below the unchanged ceiling. Linux SHA256:
`4b205a8ecbcba42e84e6b2d0281d1bafd839da7771e8b869d63d43fc74774c83`;
Windows SHA256:
`e5c71b277d5bb3fa5bcec176e3f2fcee32791a721c568d3b0c28b7a590be543c`.

After terminal platform/save/member acceptance, `embercourt_civic_wine_retirement.json`
records **2619101184 bytes** reclaimed from the two new test prefixes' disposable
Windows/Program Files trees. Live-process checks and retained user/registry hashes
pass; caches, saves, sources, evidence, RMG work and exported packages are retained.
These installations are permanently deleted but recreated by fresh Wine setup.

This accepts only Lantern Court and Relief Quay: **22 Bellwake and 20 Embercourt
scene layers** now have accepted paintings. Four rare-cost Riverwatch buildings,
other factions and remaining Overworld presentation keep the child and full goal
in progress. Gameplay, native generation, save schema and the village/catalog art
are unchanged.
Evidence names above are relative to `.artifacts/generated_full_match_quality_20260906/`.

## Embercourt riverworks — validated, 2026-09-08

The next six exact-faction scene gaps are Granary Lock Exchange, Lockhouse Tally,
Tollstone Weir, Bargebow Slip, Oath Pikehall and Beacon Writs. Their original
catalog images remain separate. Six new text-only RGBA paintings, exact prompts,
trimmed/runtime derivatives and hash-locked preparation briefs are registered.
Their three-resolution placement/input and full post-art replays pass, including
both official platform packages. The 34 previously accepted rows, 102 scene rasters, 34 prompts, village
backdrops, catalog art and runtime/gameplay owners remain byte-identical to
`1a3fc9895da1d6ac0121569378db3a257cb7d902`. The completed source batch verifies
376 prior files and byte-identical selected preparation, including the frozen
composition and curation: `embercourt_riverworks_preservation.json`.

The exact Day-10 input is `embercourt_supply_accepted_earned_720/earned_growth_save.json`,
SHA256 `6c24033ca1d35971c9ca5b50fee30bed47cb0992fdfe737d07767839ca445d66`.
The first replay stopped after two orders: ordinary enemy conquest changed
Riverwatch placement `native_h3maped_93c0f05a_object_0950` to enemy ownership on
Day 13. `OverworldRules.set_active_town_visit` correctly rejected remote management
with “Only owned towns can be managed remotely.” The complete interrupted state,
Overworld capture and exact error are retained in
`embercourt_riverworks_before_interruption_720`; this is not a Town-entry bug.

The revised Python replay uses normal enabled Recruit/Transfer controls on Days
10–12, pays actual discounted costs, respects stock and keeps a field guard
company. Each action matches its complete authoritative rule/recap state. It
does not change enemy actions, ownership, armies, resources, daily simulation or
construction rules. The same policy must run before and after art changes.
`embercourt_riverworks_defended_before_720` completes all six orders on Days 12–17:
31921 checks, exactly 27 expected missing-scene-art errors, no other assertion or
engine errors, unchanged input/source hashes and complete save/re-entry. Its
earned Day-17 save SHA256 is
`5dcb5990c719bf649f018b0f68ea46999e2bd16c5faa9ddd2847b2af7b9f9198`.
This is the pre-art control, not a passing presentation report or complete match.

Source files/prompts are under
`art/towns/source/generated/scene_layers/faction_embercourt/`, with corresponding
trimmed and runtime directories. Each new manifest row records its actual built-in
`generation_output` filename and source/prompt/derivative SHA256. Original tool
outputs remain in `/root/.codex/generated_images/01a05d96-1b3a-7930-839c-fd2fe5a9eccc/`.
No CLI/API fallback, copyrighted reference, pixel recoloring or procedural stand-in
was used. The initial strict manifest check reproduces the missing riverworks
mapping before adoption. Full visual, three-resolution, unchanged-state and
official Linux/Windows package checks pass as recorded below.

The first developed draft (8420 checks) exposed Oath Pikehall overlapping the
command dock. Only its new placement moved, to the foreground-right bank; no
existing building or control moved. The revised/input drafts retain the real
Lantern Court and Bargebow Slip foreground hits on overlapping roof pixels.
Those are correct depth ownership, not renderer failures. The probe now tests
both foreground routes explicitly and uses the visually exposed right gable for
the Oath information route. `embercourt_riverworks_developed_gable_720` passes
8431 checks, with no runtime errors and both complete input states unchanged.
The scene and exact Oath information capture have been visually inspected.
Failed frames and reports remain in `embercourt_riverworks_developed_*`.
The separate catalog icons shown in information dialogs remain unchanged.

The focused six-suite Python run passes 64 tests; repository validation and
`git diff --check` pass. The frozen source acceptance is selected by
`embercourt_riverworks_source_validation.py`: normal earned and developed views
at three resolutions, both earlier faction openings, existing Town layout/skyline
reports, lossless-import proof, complete prior-file/idempotence controls, the
six Python suites and repository checks. `embercourt_riverworks_package_validation.py`
requires that completed source batch before official Linux/Windows export,
startup/generated entry and the identical paid-growth/input/save probe. Complete
non-clock save and all-member package comparisons are separate required
checks; their completed results are recorded below.

The frozen normal replays at **1280x720, 1920x1080 and 2048x1079 each pass 32177
checks**, exit zero, no assertion/runtime errors and unchanged input/source hashes.
Their six paid orders complete on Days 12–17. All four full Day-17 states (control
plus three resolutions) match as exact Decimal JSON and raw bytes after excluding
only `/saved_at_unix`; `embercourt_riverworks_source_save_comparison.json` records
every exact file and SHA256. The three developed-view counterparts each pass
**8431 checks**, with clean exits and both complete input saves unchanged.

Evidence: `report.json`, `earned_growth_save.json` and
`building_embercourt_beacon_writs_saved.png` under
`embercourt_riverworks_accepted_earned_{720,1080,2048}`, with the corresponding
`accepted_developed` directories and `developed_built_id_fixture.png` frames.
All six final/developed scenes and the 720p Oath information capture have been
visually inspected: the new paintings occupy their riverbank sites, with the
header, command buttons and footer clear. Developed frames retain the later,
unaccepted catalog-art buildings; these are read-only built-id fixtures, not
earned match continuations. All six source PNGs were also compared byte-for-byte
with their recorded original generation outputs.

`embercourt_riverworks_source_batch.json` is terminal/pass for all 18 serial jobs.
Embercourt/Veilmourn opening compatibility passes 2519/1382 checks; both existing
Town layout/dialog and skyline reports pass under
`.artifacts/full_play_runtime_20260905/embercourt_riverworks_existing_town/`.
The six lossless-import proofs preserve all decoded pixels/mips and cache bytes;
376-file/idempotence preservation, 64 Python tests and repository validation pass.

`embercourt_riverworks_package_batch.json` is terminal/pass for all eight serial
jobs. Official Linux and Windows exports, startup and generated-map Town
construction pass. Both platforms' exact Riverwatch probes pass **32177 earned /
8431 developed checks**, with unchanged inputs, current manifest equality and
unchanged exports. Reports are under `embercourt_riverworks_release_{linux,windows}`,
`embercourt_riverworks_packaged_{linux,windows}` and
`embercourt_riverworks_packaged_developed_{linux,windows}`. The Linux generated
construction frame and both final Riverwatch frames are visually inspected.
Windows uses fresh isolated headless Wine, not physical Windows GPU certification.
Its startup/generated logs contain no warning/error-like or fatal matches in this
run; the earlier quick-exit audio warning is not claimed fixed by these art changes.

`embercourt_riverworks_packaged_save_comparison.json` proves **six-way complete
Decimal JSON and raw-byte equality outside only `/saved_at_unix`**: the pre-art
control, three source resolutions and both platform packages. Each ends on Day 17,
still in progress, with the same 19 built ids, resources, troops, ownership,
simulation and saved state. Reproduce the final comparison with
`python3 -B .artifacts/generated_full_match_quality_20260906/embercourt_riverworks_save_comparison.py packaged`.

`embercourt_riverworks_package_parity.json` verifies all **5216 members**: exactly
twelve new texture/import entries, 5202 unchanged prior entries, and only the
scene manifest and generated UID cache changed among prior members. The platforms
differ only in `project.binary`; all six new cache payloads match the lossless
proof. Each PCK is **248001816 bytes**, leaving **1998184 bytes** under the unchanged
250000000-byte ceiling. Linux SHA256:
`c01a92d329ba083387cacd94e27364f9e42d56a4b236f827bb2bdf353fd55cff`;
Windows SHA256:
`bdf77dd6f6c43b46e878c041406b08e5e0dbf6c451dcc21c237582fbb7403eb4`.
Reproduce with
`python3 -B .artifacts/generated_full_match_quality_20260906/embercourt_riverworks_package_parity.py`.
All riverworks evidence paths above are relative to
`.artifacts/generated_full_match_quality_20260906/` unless explicitly stated.

After terminal platform/save/parity success and live-process checks, only the two
riverworks Wine prefixes' `drive_c/windows`, `Program Files` and
`Program Files (x86)` directories were permanently removed: **2619101184 allocated
bytes reclaimed**, matching the measured free-space increase. Fresh Wine prefixes
rebuild those disposable installations. User/save data and registry hashes remain
identical; caches, source/generated art, RMG evidence, reports, captures and current
exports are retained. Receipt: `embercourt_riverworks_wine_retirement.json`.
The unrelated pre-existing artifact-retention files remain untouched.

This accepts six paintings, not the whole presentation goal. Later Riverwatch
buildings, other factions and remaining Overworld repairs stay in progress.

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

## Embercourt opening packet — validated 2026-09-08

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
The selected paintings now have production source/trim/runtime rows, preserved
generated alpha, 512px aspect-preserving Lanczos derivatives and mipmaps. Muster
was raised onto the left-bank court; Wayfarers joins the right shore and the
Market extends the foreground-left quay. The exact prompts, original output
identities and source hashes are in `art/towns/source/generated/scene_layers/README.md`.
`prepare_town_scene_layers.py --faction faction_embercourt` merges selected rows
without resetting other factions or earlier buildings. The retained preservation
control against `ed62f12a` proves all 22 Veilmourn rows, 66 scene rasters, 22 prompts,
imports, village backgrounds, catalog art and gameplay/save owners unchanged;
selected preparation is byte-identical on replay.

The actual Day-43 Riverwatch built-id fixture (SHA256
`553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59`)
exposed a separate real input defect. `TownStageView._sync_building_hotspots`
assigned alpha masks only to new scene layers: transparent margins of older
catalog art remained rectangular hit areas. The visible Market facade therefore
opened Charter Flame or Lockhouse Tally information. The retained draft2/draft3
captures show those wrong modals. The renderer now applies the existing cached
alpha/crop mask to every visible non-embedded building texture, preserving depth,
placement, focus bounds and the authoritative information route. It does not
move/hide other buildings or change their art. The developed probe independently
compares catalog hit ownership with image alpha, checks actual foreground Charter
pixels and clicks the exposed Market facade. Watch Barracks correctly supersedes
Muster Yard; both earned ids remain in the untouched fixture.

`embercourt_developed_720_inputfix` passes 8255 checks without engine errors or
source/input mutation. This is a read-only composition/input checkpoint, not
paid-growth or platform acceptance. The first source draft's gold-only dictionary
assumption was corrected to require 1000 gold and zero other normalized resource
costs; no game cost changed. Earlier drafts remain failures, including the
superseded-Muster probe indexing error and draft3's source-hash change during
curation. The first detached source batch failed before engine launch because
its PATH omitted `/root/.local/bin`; the corrected serial batch has fresh labels
and preserved reports. That second batch passes all six ordinary/developed
resolution runs, Bellwake compatibility and both existing Town reports, but its
lossless preparation fails because the isolated runner lacked absolute editor
data/config/cache directories. It published no texture replacements. Its larger
capture also rejects the over-raised Muster placement: the final reviewed
pre-trim rect is `[215,355,340,226.6666666667]`, ground anchor `[390,565]`, meeting
the actual quay instead of leaving a tent under the entrance. The original
masters and all derived raster bytes remain unchanged by this placement review.
The third serial batch uses explicit isolated XDG directories and fresh
`embercourt_accepted_*` labels. This third source batch is complete and passes:
each normal purchase/input/save run has 2519 checks, each developed composition
has 8255 checks (including all 18 retained visible catalog paintings), and the
unchanged Bellwake opening compatibility run has 1382 checks. The opening,
post-build and developed captures at 1280x720, 1920x1080 and 2048x1079 were
personally inspected for shoreline grounding, cover crop, information routing
and readable, unclipped controls. Both existing Town reports and repository
validation pass. Three lossless imports preserve decoded pixels/mips and import
options; 2267 earlier imports are cache hits. There is no newly claimed compression
saving: these fresh textures already used the required lossless settings.

The complete source saves compare equal to the original paid-Market control with
exact Decimal-valued JSON numbers, excluding only `/saved_at_unix`. The original
overlay saves before normal JSON restoration while the fuller input probe saves
after it, so raw number spelling differs (`4000` versus `4000.0`); do not claim
raw before/after byte equality. The three matched new-probe saves do match
byte-for-byte outside that clock. Arrays, all other fields and exact numeric
values remain included. Evidence: `embercourt_accepted_save_comparison.json`.
The immutable source manifest SHA256 is
`b5bd44bdd7fde9867de464443b8f6f8a318308075da883209a8ae39f5b0e4173`.
Official Linux and Windows releases each pass the same 2519 ordinary-purchase
and 8255 developed-input assertions, with unchanged exports, inputs and source
owners, no runtime errors and all five opt-in bootstrap boundary controls. Linux
release captures were personally inspected; Windows uses headless Wine with only
paired frame/capture operations omitted, not physical Windows/GPU certification.
Both normal export/startup/native-generated Town construction smokes also pass.
The first export attempt used the isolated data directory as its template search
root and failed before making a package; the corrected batch uses the existing
official 4.6.2 templates and fresh release/report labels, with no game-file change.

`embercourt_package_parity.json` verifies all 5186 members: six new texture/import
members, no removals and 5177 prior members byte-identical. Only the manifest,
compiled TownStageView and UID cache change among existing members. Linux and
Windows differ only in `project.binary`; the new textures match all three
lossless proofs and no source masters ship. Each PCK is **244111660 bytes**, with
**5888340 bytes** headroom below the unchanged ceiling. Linux PCK SHA256:
`d8c66a2c59bf65c6b61495d1b063a89b0a8a3493737f316f155dae5da45637aa`;
Windows: `c8ca89145990fd99a69ae7c422cc2a2043cc65436c8dd307ba4d441d5781190f`.
`embercourt_packaged_save_comparison.json` includes the original control, all
three source resolutions and both releases: complete exact-number states agree
apart from the clock, and all five matched new-probe saves agree in raw bytes
outside it. The two-byte Windows length difference is only clock precision.

52 focused Python tests pass (23 scene/preparation, seven sequence preflight,
three packaged-bootstrap, 19 lossless-import), together with existing Town,
repository and diff checks. Reproduction commands and complete job exits are in
`embercourt_source_batch3.json` and `embercourt_package_batch2.json`; drivers are
`tests/town_scene_layer_regression.py --faction embercourt` (ordinary purchase or
`--presentation-only --developed-save`), `tests/packaged_town_scene_layer_regression.py`
against each retained `embercourt_release_*/isolated-export`, the established
Linux/Windows packaging smokes, `tests/full_play_validation_suite.py` selecting
both Town reports, `python3 tests/validate_repo.py` and `git diff --check`.
All paths in this paragraph are under the goal artifact root unless repo-relative.
The completed tests' two disposable Wine installations were retired only after
verified process exit; their user/save/registry hashes remain exact. The receipt
`embercourt_wine_retirement.json` records 2619097088 bytes reclaimed, with caches,
RMG evidence, current exports and source art retained.
The presentation child and full-match parent remain in progress; later Embercourt
catalog art is still visibly unaccepted, not covered by this opening packet.

## Embercourt early growth — validated checkpoint, 2026-09-08

The next bounded packet adds original Stone Store, Watch Barracks, Bowyer Lodge
and Beacon Range scene layers. The actual earned Medium11 Market save is
`embercourt_accepted_opening_720/earned_growth_save.json`, SHA256
`838606e03fc1dffd5cf5c2b79ca5d20cc59c77ecfb42b831005577d449652d18`.
`tests/town_scene_layer_regression.py --faction embercourt --embercourt-growth`
continues that nonterminal Day-1 save through four confirmed End Turns and normal
paid ledger orders. Stone costs 900 gold/2 ore, Watch 1400 gold/2 ore, Bowyer
1200 gold/2 wood, and Beacon 1700 gold/2 wood/1 ore. No resources, days, built ids,
prerequisites or outcomes are injected. The Day-43 save remains a detached
composition fixture, never a resumed match.

The unchanged old presentation reproduces 13 scene-resolution failures across
8198 checks in `embercourt_growth_before_720`, with no engine errors and all
four orders completed. Inspected captures show the tiny detached catalog
paintings, including the replacement Watch and Beacon. Four new text-only
built-in generations now resolve through the exact faction manifest and existing
alpha/crop-aware renderer. Their original masters, exact prompts, output ids
and source/trim/runtime hashes are retained in the scene-art README/manifest.
The initial RGB checkerboard Barracks edit is rejected and retained separately
in `embercourt_growth_candidates/`; no matte removal or procedural replacement
was used. The existing transparent-margin/Lanczos/mipmap pipeline is unchanged.

Pre-trim bounds in the 1600x900 panorama: Stone `[1270,358,280,186.6666666667]`,
ground `[1410,537]`; Watch `[215,355,340,226.6666666667]`, ground `[390,565]`;
Bowyer and Beacon both `[790,378,270,180]`, ground `[925,552]`. Watch retains
Muster's exact site. Both upgrade pairs preserve saved predecessors and show
only the advanced painting/hotspot. Stone stands behind Wayfarers on the right
bank; the archer yard is west of the civic hall above the lock quay. This packet
does not change the village, separate catalog icons, Town renderer, gameplay,
save schema, native/RMG behavior or unrelated art.

The first source draft passes 8306 earned-growth and 8294 developed-fixture
checks with no engine errors; all four paid-stage screenshots and the developed
720p view were personally inspected. `embercourt_growth_draft_save_comparison.json`
proves complete Day-5 raw saves equal to the before-art replay outside only
`/saved_at_unix`; exact Decimal-valued JSON agrees too, with no other exclusions.
The focused Python suites pass 57 tests. `embercourt_growth_preservation.json`
checks every prior row, 75 rasters, 25 prompts and village/catalog/gameplay/UI
owners against `b96e3eab`, including real selected preparation idempotence.

Final frozen manifest SHA256:
`d0a2d0cc9b55871fa7868b703a5e05b7eb682cd81efd307955529f1eaa4bed89`.
The finite serial `embercourt_growth_source_validation.py` batch uses fresh
`embercourt_growth_accepted_*` labels for earned/developed 1280x720, 1920x1080
and 2048x1079 runs, both faction opening compatibility controls, both existing
Town reports, four lossless-import proofs, preservation, all 57 Python tests
and repository validation. Its receipt is `embercourt_growth_source_batch.json`.
The source batch is now terminal with all 18 jobs successful. Each earned run
passes 8306 checks and each developed fixture 8294, with no engine errors or
source/input mutation. All six final compositions and the paid upgrade stages
were personally inspected for grounded placement, crop, input and readable
controls. Opening compatibility retains 2519 Riverwatch / 1382 Bellwake checks;
both shared Town reports, all 57 Python tests and repository/diff checks pass.
The four lossless imports preserve all pixels/mips/options; 2270 previous
resources are cache hits and no new compression saving is claimed. The
331-file preservation/idempotence replay against `b96e3eab` passes after imports.
`embercourt_growth_source_save_comparison.json` proves complete Day-5 raw-byte
equality across all three new saves and the original renderer, outside only the
single save clock. Every field, array order and exact numeric value is included.

`embercourt_growth_package_validation.py` is now terminal with all eight jobs
successful: normal official Linux and Windows export/startup/generated-Town
smokes, the same earned/developed probes, repository and diff checks. Each
official release passes 8306/8294 checks with unchanged source, inputs and PCK;
all five bootstrap controls pass per platform. Final Linux release growth and
developed screenshots were personally inspected. Windows is headless Wine,
retaining every gameplay/input/save assertion but not physical GPU certification.
The earlier intermittent Main Menu Ogg shutdown warning is absent from both
normal Windows logs this time; this art-only packet does not claim a lifetime fix.

`embercourt_growth_package_parity.json` compares every member with the prior
244111660-byte package. Each new PCK is **245305344 bytes**, with **4694656 bytes**
headroom. There are 5194 members: eight new texture/import members, no removals,
5184 prior members byte-identical, and only the scene manifest/UID cache changed.
The four texture payloads match their lossless proofs; no masters ship.
5193 members are identical across platforms, with only `project.binary`
platform-specific. Linux PCK SHA256:
`7f921485f2c8f86508175b698d39995fd46a1257a1255530ae6e18bd33582ad4`;
Windows: `da1dcc1a142f7e95ac9bc8b61862965ee4d1b2a8510941278a8f85f083fbf239`.
`embercourt_growth_packaged_save_comparison.json` proves all six complete Day-5
states and raw save bytes equal outside only `/saved_at_unix`: original
presentation, three source resolutions, Linux and Windows.

The completed batch's two Wine installations were retired only after verifying
terminal success, no live prefix processes, and preserved user/save/registry
hashes. `embercourt_growth_wine_retirement.json` records **2619105280 bytes**
removed and the same measured free-space increase. Only each prefix's
`drive_c/windows`, `Program Files` and `Program Files (x86)` were permanently
removed; fresh disposable prefixes recreate them. All caches, saves, reports,
source, exports, RMG evidence and unrelated untracked retention files remain.
This accepts only the four early-growth paintings. Later Embercourt catalog
paintings, other factions and remaining Overworld presentation stay unfinished;
the full presentation child and parent goal remain in progress.

Reproduce the packet with `--faction embercourt --embercourt-growth`, the exact
earned Market save above, supported `--resolution` and fresh `--label` on
`tests/town_scene_layer_regression.py`. The developed check instead uses
`--presentation-only --developed-save` with the original Medium11 opening save
and exact Day-43 fixture from the preceding section. The official-package wrapper
adds `--binary`, `--pack`, `--platform`, `--bootstrap-controls` and a fresh
`--wine-prefix` for Windows. Retired prefixes cannot be reused. The retained
source/package drivers record every exact command and path. Full receipts use
`embercourt_growth_save_comparison.py packaged`,
`embercourt_growth_package_parity.py` and `embercourt_growth_preservation.py`.

## Embercourt supply/magic — validated checkpoint, 2026-09-08

Selected after pushed `fe7ce89b`: River Granary Exchange, Quartermaster Depot,
Lantern Archive, Starseer Annex and Citadel Pikehall. These existing authored
buildings still resolve to detached catalog miniatures in the actual earned
Medium11 progression and developed Riverwatch capture. No gameplay identity,
build cost, prerequisite, daily limit, saved predecessor or schema changes are
selected. The original villages, catalog art and 29 accepted scene layers stay
unchanged; Archive/Annex retain one scene site.

The exact earned Day-5 input is
`embercourt_growth_accepted_earned_720/earned_growth_save.json`, SHA256
`48ed86fb4babfd21b5aab898baae06e7bc3f2d45ba91a182d29260c01551e963`.
The new `--embercourt-supply-growth` probe reuses ordinary End Turn, Trade and
construction-ledger routes, complete state/save assertions and the prior bounded
availability loop. It rejects wrong input hashes, factions or combined sequences.
The old-renderer replay in `embercourt_supply_before_720` completed all five
orders on Days 6–10 and retained the full earned save: 16490 checks, 18 expected
exact-scene failures, no runtime errors or source/input mutation. Four normal
one-Ore trades occurred (one Day 9, three Day 10); final resources are 560 gold,
four wood and zero ore. No resources, days, outcomes or built ids were injected.
The actual final before-art screenshot was inspected.

Five original text-only RGBA paintings now use the exact scene manifest and
unchanged alpha/crop-aware renderer. Source/output/prompt provenance and two
rejected Archive attempts are recorded in the scene-art README. One rejection
has an incompatible canvas, the other is opaque RGB with a baked checkerboard;
neither ships. All selected masters are 1536x1024. The fresh Archive resembles
the Annex's earlier records-lodge stage, not a pixel-identical generated edit.
Only transparent-margin cropping, aspect-preserving 512px Lanczos and mipmaps
are applied. Strict art checks now recognize the actual structured text-only
prompt form while retaining exact prompt hashes and explicit empty input lists.
The first art-unit invocation ran before mipmap setup and failed correctly;
after enabling mipmaps on exactly five new imports, all 22 art tests pass.
Nine sequence tests also pass, retaining paid trades, full-state comparisons,
daily limits, predecessor ownership, no-progress bounds and Windows assertions.

`embercourt_supply_preservation.json` verifies all 29 prior rows, 87 rasters,
29 prompts and original village/catalog/runtime/gameplay owners against
`fe7ce89b`, plus real selected preparation idempotence. The retained
source/package drivers use fresh `embercourt_supply_*` labels and the same
official-package bootstrap; no prior package evidence is relabeled as current
acceptance.
The first draft completed 16625 checks with 15 input failures, no runtime errors
and unchanged source/input. The depot's chosen click point is genuinely behind
the Watch court; the final probe proves that foreground ownership before
clicking the exposed supply roof instead. Archive/Annex's first right-bank
site hides the observatory behind the command rail. Both now share the rear
left-bank terrace `[0,205,300,200]`, ground `[180,385]`, with exposed upper
architecture above the granary. Earlier paintings, depth priority and controls
were not moved to conceal these failures. This is pre-acceptance composition
curation and stronger actual pointer testing, not a new renderer/gameplay rule.
The revised developed composition was inspected: the observatory now reads above
the left-bank granary, outside the command rail. The first revised probe's only
failure samples the open balcony rather than opaque architecture (8341 checks,
no engine errors). The final pointer control uses the inspected solid turret
roof, whose runtime alpha is independently confirmed, without filling the
opening or relaxing painted-pixel ownership.
The revised developed probe then passes all 8349 checks with no engine errors
or source/input mutation (`embercourt_supply_developed_draft2_720`). The Archive
control similarly uses an independently confirmed solid roof pixel, not the
transparent margin. `embercourt_supply_draft_save_comparison.json` proves the
complete old-renderer and first-draft Day-10 raw saves identical outside only
`/saved_at_unix`, including exact Decimal-valued JSON; no other fields are excluded.
Final frozen manifest SHA256:
`2473718258fb17657ee73d0f0a528865d33b2a20ccfe1a44a14b2532422c992e`;
Python probe SHA256:
`ff9aa598e85cb12480734d6df667535b55a4982ecba60585730a8174c8ea7309`.
`embercourt_supply_source_batch.json` is terminal with all 18 jobs successful.
Each earned replay passes 16654 checks and each developed fixture 8349 at
1280x720, 1920x1080 and 2048x1079, without runtime errors or source/input
mutation. All six final compositions and the Archive/Annex paid stages were
personally inspected, including the full-width crop and information dialog.
The existing header, command controls and footer remain readable; later
unaccepted catalog paintings are still visible in the developed fixture.
The detached fixture's header uses the opening session while its stage uses
the recorded developed built ids; it is not a resumed Day-43 match. Actual
earned captures show the ordinary tier-1 to tier-2 progression.

Earlier Riverwatch/Bellwake openings pass 2519/1382 checks; both existing Town
reports, all 60 Python tests and repository validation pass. Five lossless-import
proofs preserve pixels, mips and options, with 2274 prior cache hits and no new
compression saving claimed. The post-import preservation/idempotence replay
checks 351 files against `fe7ce89b`. `embercourt_supply_source_save_comparison.json`
proves all four complete Day-10 states and raw saves identical outside only
`/saved_at_unix`: original presentation and all three final source resolutions.
The final state retains all 13 built ids, including the saved predecessors.

`embercourt_supply_package_batch.json` is terminal with all eight jobs successful.
Each fresh official Linux/Windows release passes the same 16654 earned and
8349 developed checks, with unchanged source, input and PCK. All five bootstrap
controls pass per platform. Both normal export/startup/generated-Town smokes,
repository and diff checks pass. Final Linux release growth and developed
captures were personally inspected; Windows is headless Wine, retaining every
gameplay/input/save assertion, not physical GPU certification. Both normal
Windows logs have no script errors or leak messages this time; this art-only
packet does not claim a fix for the earlier intermittent Main Menu Ogg warning.
`embercourt_supply_packaged_save_comparison.json` proves all six complete Day-10
states and raw saves equal outside only the one clock field: original renderer,
three source resolutions, Linux and Windows. No other value or array is omitted.

`embercourt_supply_package_parity.json` checks all **5204 members** against the
previous 245305344-byte release. Each new PCK is **246609244 bytes**, leaving
**3390756 bytes** under the unchanged 250000000-byte ceiling. Exactly ten new
texture/import members are added, none removed, and 5192 existing members are
byte-identical. Only the scene manifest and generated UID cache change; no
source masters ship. The five new payloads match their lossless-import proofs.
Across platforms, 5203 members match and only `project.binary` differs.
Linux PCK SHA256:
`17c9c7b77a6a80756767c32628ed4dc4d7aea3423c0d2a935c139debaa67b910`;
Windows: `be63a64868255823fa6858ede31c3a123743be39e3d2b858a201a25251f78248`.

After terminal success and verified absence of live prefix processes,
`embercourt_supply_wine_retirement.json` records **2619097088 bytes** removed,
with the same measured free-space increase. Only `drive_c/windows`,
`Program Files` and `Program Files (x86)` in this packet's two disposable Wine
prefixes were permanently removed; fresh prefixes recreate them. Every retained
user/save/registry hash is unchanged. Caches, source, reports, captures, exports,
RMG evidence and unrelated untracked files remain. Retired prefixes cannot be
reused as complete Wine installations.

Reproduce the earned flow with `python3 -B tests/town_scene_layer_regression.py
--faction embercourt --embercourt-supply-growth --save <exact-Day5-save>
--resolution <1280x720|1920x1080|2048x1079> --label <fresh>`. Developed input
uses the original opening save with `--presentation-only --developed-save`
and the exact recorded Day-43 fixture instead. The official-package equivalent
is `tests/packaged_town_scene_layer_regression.py`, adding `--binary`, `--pack`,
`--platform`, `--bootstrap-controls` for earned growth and a fresh `--wine-prefix`
for Windows. The retained source/package drivers record every exact command.
Full receipts use `embercourt_supply_save_comparison.py packaged`,
`embercourt_supply_package_parity.py` and `embercourt_supply_preservation.py`.

This accepts five supply/magic layers, bringing accepted scene art to 22
Bellwake and 12 Embercourt paintings. Later Embercourt catalog paintings, other
factions and remaining Overworld repairs are unfinished. The presentation child
and parent quality goal remain in progress; this is not release readiness.

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
upgrades. Embercourt now has 24 accepted Riverwatch layers, including the four
late-court paintings above. Riverwatch/Bellwake coverage is not complete faction coverage:
the union of current authored towns includes six additional unmapped Embercourt
building identities and five additional Veilmourn identities. Mireclaw now has
three source-accepted opening layers, with platform acceptance tracked at the
top of this report; the other three factions have no scene-layer mappings yet.
These counts come from comparing
`content/towns.json` starting/buildable ids, excluding embedded Town Hall, with
the exact-faction scene manifest. Candidate generation or mapping counts alone
do not establish visual or gameplay acceptance.
The owner removed the imposed package-size budget on 2026-09-09. Earlier
headroom measurements remain historical evidence, not a continuing blocker.
Require inspected sparse, mid-development and developed scenes, exact
built-id/input/save ownership and
both-platform package integrity and gameplay for each accepted packet. Other
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
