# Generated Overworld Quality Closure

Owner direction, 2026-09-18: fix the comparison's visual problems **and** the
perceived lack of artifacts, useful interactable destinations, guards and neutral
monsters. Phase 6 parent `rmg-overworld-quality-closure-20260918`, derived from
`project.md`, `PLAN.md`, `docs/lessons-learned.md`,
`docs/rmg-exploration-and-guarded-routes.md`, and the owner-reviewed Medium/10
H3MapEd/current-game screenshots sent to Discord. Previous adoption completion
does not mean these remaining product-quality requirements are satisfied.

## Acceptance and implementation order

1. **Playable objects** (`rmg-playable-object-presence-20260918`): trace native
   artifact/site/monster identities into runtime inventories, actual visible
   sprites and legal interaction/battle/reward flows. Fix missing, misclassified,
   unusable or visually suppressed objects, including unreachable approach
   handling where source masks permit entry. Measure initial and reachable
   opportunities separately from whole-map counts; do not call a catalog pool
   playable just because its IDs exist. Preserve source placement/masks and old
   saves; use deterministic original-content translation for fresh sessions.
2. **World readability** (`art-overworld-comparison-readability-20260918`): make
   rewards, destinations and neutral armies recognizable against scenery at
   normal gameplay and supported wider views. Respect the owner's earlier
   rejection of oversized chests; use a deliberate visual hierarchy, not blanket
   enlargement. Reduce repeated scenery bands and noisy ground; preserve distinct
   cliff/wood/wetland identities and exact blocked-cell coverage. Correct angular
   road presentation without changing road topology. Use original manifest-backed
   raster art, maintain fog and click targets, and do not add debug markers or
   procedural object stand-ins.
3. **Guarded exploration** (`rmg-guarded-exploration-closure-20260918`): exercise
   real routes toward artifacts/sites/enemy starts, including portals and cleared
   objects. Fix concrete missing guard/neutral interaction and translation defects;
   keep compositions varied and source quantities authoritative. Trace genuinely
   sparse native placement back to recovered source phases before changing it.
   No guessed density scalars, arbitrary filler, brute-force seed retries, removed
   supply-cache reinjection, blanket guard multipliers or day-based movement locks.
4. **Integrated acceptance** (`rmg-overworld-quality-acceptance-20260918`): fresh
   Medium/Large games, representative Small and water/layer regression, real
   artifact collection/site use/neutral battles/guarded progress/save-resume,
   normal-fog and explicitly labeled inspection screenshots, Linux/Windows parity
   and responsiveness. A missing named recovery function/private-state proof is
   an explicit blocker, not permission to approximate or claim completion.

## Targets

`NativeRandomMapPackageSessionBridge.gd`, `GeneratedNeutralEncounterRules.gd`,
`OverworldRules.gd` and its domain helpers, native post-generation proxy selection,
original content eligibility/proxy manifests, `OverworldMapView.gd`,
`OverworldGroundSurface.gd`/shader and relevant art presentation manifests.
Python-owned focused regression and existing generated-map/interaction/art tests.
Native generation changes require a separately named recovered owner, phase and
private-state fixture within this parent before implementation.

## Consolidated validation

- Focused source and exact packaged Linux/Windows regression for changed behavior;
  real pickup/site/battle and save-resume, not just inventory totals.
- Existing exploration, generated-neutral, distinct/decorative sprite, object
  scale, ground and road tests; deterministic Medium/10, Large/11 and Large/1.
- Retained native final payload comparisons for unchanged configurations, with
  no whole-generator parity claim; investigate any source-state differences.
- Visual inspection at 1280x720 and 1920x1080, including normal gameplay zoom/fog;
  wider comparison views alone do not establish normal-play readability.
- `python3 -B tests/validate_repo.py`, official
  `tests/packaging_linux_export_smoke.py` and
  `tests/packaging_windows_export_smoke.py`, package parity, `git diff --check`.
- Report actual results and remaining limits, push only coherent validated work,
  remove task-owned disposable evidence/exports after reporting, preserve caches,
  saves, original art/provenance, all native RMG recovery and unrelated files.

Non-goals: Town/combat presentation redesign, copied H3 pixels/content, arbitrary
map-count targets, changed source topology hidden in rendering, save-schema
migration, unrelated cleanup or a broad release-ready claim. The parent remains
in progress; focused results do not establish integrated or whole-match acceptance.

## Initial concrete findings (not completion)

- Matched Medium/10 inventories retain 22 loose artifacts, 306 resource/site
  nodes and 57 encounters in Weak; Normal has 21/296/77. Large/11 Normal has
  17/869/95. These are inventories, not sufficient interaction density, reachable
  starting rewards or visible-screen counts. No records were overwritten in the
  sampled resource/artifact/encounter tile indexes.
- Native types 6 and 84 resolve guarded original object IDs to the unrelated
  unguarded `site_waystone_cache`. Medium/10 Weak contains nine and one of these
  respectively. This loses real defenders, site silhouettes and reward contracts.
- Sixteen implemented guarded sites still carry an old `metadata_only` summary
  on their map-object definitions. Eligibility must use the executable resource
  site's matching guard/reward contract. All 32 authored guarded sites have live
  contracts; their art and rewards already exist. Restoring these candidates is
  post-generation content adoption, not native placement or density tuning.

## Implemented correction batch

- Guarded eligibility follows the live resource-site contract, not stale
  map-object summary flags. With the pickup correction below, the registry now
  exposes **356 eligible / 66 excluded** objects, including all 32 guarded sites.
  Fixed type-6/type-84 original identities now resolve their own sites instead
  of the free Waystone Cache. Native placement, quantity, masks and RNG owners
  are unchanged; four Linux/Windows Debug/Release native libraries were rebuilt.
- New internal site defenders control the authoritative site entrances only.
  They no longer project an invented eight-neighbor roaming control ring.
  External native guard control, armies, defenders and reward-clearance checks
  remain intact. Existing saved defenders are not reconstructed or rewritten.
- New sessions opt into scenery presentation version 2. Explicit rock, woods,
  conifer, scrub, deadwood, wetland and fungi palettes cover all nine biomes.
  Eighteen previously unregistered cells of existing original generated atlases
  are registered with their exact crop/provenance; no new pixels or copied art.
  Cell-local deterministic visual selection replaces repeated rectangular
  motifs. Version-1 saves retain the previous semantic/biome selection policy.
- Landscape sprites draw before visitable/hostile identities, so neighboring
  canopy does not cover small rewards or armies. Neutral paintings use cached
  painted-alpha bounds and preserve aspect rather than shrinking inside their
  transparent canvas. Existing handheld/chest scale limits remain unchanged.
- Ground consumes its manifest sampling span (four tiles) and bounded original
  raster mip detail with atlas-safe insets. A clean-import path creates missing
  mip levels once per view; no static GPU texture lifetime or per-frame uploads.
  Road corners curve inside their existing cells with exactly the same edge
  endpoints; wheel ruts follow the curve. No road graph or movement changes.
- Type-79 portable resources now use real one-time Wood Pile, Ore Hod, Purse,
  Aetherglass Splinter Lot, Embergrain Sample Sack, Peatwax Votive Bundle and
  Memory-Salt Jar contracts. The four rare pickups retain their authored planned
  amount of one and original distinct rasters. This advances the final authored
  pool to **356 eligible / 66 excluded**. Production mines and saved site IDs are
  unchanged; no source placement/quantity or final native bytes changed.

The final three-case source render passed **19,166 checks**. This includes all
529 generated portable-resource nodes, actual one-time collection of all seven
resource kinds in each map (21 collections), rejection of repeat claims, no
pickup income, artifact grants, deterministic adoption and save/restore. Six
legal adjacent-step battles use the unchanged starting army and shipped Quick
Resolve: three external-guard defeats and three internal-site victories. The
fixture starts beside the target; it is not a full journey or whole-match pacing
proof. Separate post-victory fixtures check guarded artifact reward/save behavior.

| Case | Loose artifacts | Guarded sites / artifact-bearing sites | All encounters |
| --- | ---: | ---: | ---: |
| Medium/10 Weak | 22 | 26 / 11 | 67 |
| Medium/10 Normal | 21 | 16 / 8 | 81 |
| Large/11 Normal | 17 | 39 / 28 | 112 |

These are whole-map opportunities, not all revealed or reachable on day one.
No new native object placements were inserted. An internal defender is not
counted as a new independent exploration destination.

### Consolidated evidence

- `tests/validate_repo.py`: passed. Its 26 absent historical smoke reports are
  explicitly not counted as new runtime passes.
- Python exploration contracts: six tests passed. Ground/material fixture: 75
  checks passed, including clean-import mip creation, atlas boundaries, stable
  panning, unchanged collision, fog, and a 6.882 ms Large CPU surface lookup
  (not a frame-rate measurement).
- Current authored-pool and end-to-end native runtime-boundary reports passed.
  The latter exercises entrance-only defenders and all corrected pickup/mining
  distinctions. Existing distinct/decorative sprite reports passed.
- Official Linux and Windows export smokes passed. Windows' generated flow
  completed all 26 steps through Town construction, day-nine battle/report and
  resume. Wine is not certification on a physical Windows machine.
- Final packages each contain 650,606,648 PCK bytes and 8,918 members. Parity
  passed with only expected `project.binary` platform features differing. There
  is no fixed package-size ceiling in the current `project.md`.
- Small two-level, Medium normal-water, Small islands and Medium two-level
  normal-water cases passed town entrance/exit and save checks (four cases).
- Two retained original H3MapEd payload cases (Medium/10 Weak and Large/11 Weak)
  remain byte-exact. These are retained final-writeout controls, not new private-
  state captures or proof of all generator phases; missing same-run profile
  authority remains an explicit refusal where applicable.
- Exact SHA-locked focused probe: source and rendered Linux each **19,166**
  checks; headless Windows **19,160** (six screenshot checks omitted), all pass.
  Probe SHA-256 `6c2a08f4dcf6818c7e2183d5c04b4f1b41ae03d29fe416f64dbb3130ee9524b6`.
  Linux PCK SHA-256 `32409dd3ac6a8ea9623379a218bf428d4e9704ef7ed77133c7d42bae6d28dc7e`;
  Windows `6a5070468cd9cb4eb8c82bcf017add21945a93245ed1a76fe714018abc5f7ef4`.
- Existing exploration regression: **81,295** checks passed, including all
  source masks, the three reproduced guard bypasses, real artifact pickup,
  guarded-site rewards and legacy save topology. Object-scale regression:
  **6,836** checks; rendered living scenery/movement/fog: **459**, all passed.
  Stale scale/ground collision literals predating the previous scenery repair
  were replaced by before/after-render invariance; exact source-mask checks
  remain in exploration. Pickup selection now covers the new purse and jar.
- Existing generated neutral cases: Medium **459**, Large **1,368** checks,
  all passed. Native armies show 25/34 encounter identities and 65/197 distinct
  compositions respectively; these tests preserve native quantities and do not
  claim newly added independent monster placements.
- Visually inspected final 1280x720 source and 1920x1080 Linux scenes, including
  normal starting fog and explicitly revealed inspection regions: controls do
  not clip, rewards/armies remain visible against rock/wood scenery, roads bend
  without topology changes. The same ground probe passed **75** checks rendered
  in the Windows release under Wine/OpenGL, with its 1280x720 screenshots
  visually inspected. The existing runner previously forced Windows headless;
  the new explicit `--render-windows` option preserves the complete probe and
  records real visual capture. Four runner unit tests pass. Its initial
  headless attempt (39 checks) is not counted as rendered evidence. Wine's
  unsupported-MSAA warning and missing optional UI arrow glyph are not native
  Windows certification; no shader/runtime errors occurred.

Current reproducible receipts are under
`.artifacts/overworld-quality-20260918/{accepted-source,accepted-linux,accepted-windows,ground-accepted,followup}`;
official packages under `accepted-linux-export` and `accepted-windows-export`.
Native retained-reference and water/layer receipts are in
`.artifacts/rmg_start_audit_20260905/{quality_retained_20260918,quality_water_levels_20260918}`;
the unresolved density receipt is
`.artifacts/full_play_runtime_20260905/overworld-quality-density-20260918`.
All native recovery evidence is retained. Cleanup removed exactly
**1,535,693,895 bytes (1.54 GB)** of superseded task-created Linux/Windows exports,
after confirming no process used either directory. They are rebuildable; final
accepted packages, caches, saves and unrelated pre-existing files are retained.

Focused reproduction:

```sh
python3 -B tests/generated_overworld_quality_regression.py --label source-review --render --resolution 1280x720 --timeout-seconds 1800
python3 -B tests/rmg_exploration_regression.py --label exploration-review --timeout-seconds 1200
python3 -B tests/overworld_object_scale_regression.py --label scale-review --timeout-seconds 900
python3 -B tests/overworld_living_scenery_regression.py --label scenery-review --render --resolution 1280x720 --timeout-seconds 900
python3 -B tests/generated_neutral_map_regression.py --size medium --label neutral-medium-review
python3 -B tests/generated_neutral_map_regression.py --size large --label neutral-large-review
```

Use a fresh label/output directory for each run; packaged focused regression
adds `--platform`, `--binary`, `--pack`, and a fresh `--wine-prefix` on Windows.
Add `--render-windows` for actual Windows visual capture. Run the official export
smokes first. Final screenshots are runtime evidence,
not regenerated concept art. These accepted correction results do not complete
the remaining parent-level density/progression requirement below.

### Remaining questions, not silently declared fixed

The four-size density rerun passes Medium, Large and Extra Large. Small still
fails two existing thresholds: two early interactions (minimum four) and seven
in the next band (minimum eight). Its seed is
`generated-density-distribution-10184-homm3_small`, using the historical Weak,
three-player profile; native payload identity `bc036d7a`, runtime signature
`771dec4a`, starting entrance `(26,24)`. All 101 source interactables survive
adoption: four artifacts, 28 guards, 31 pickups, 34 sites and four towns.
Zero source objects are dropped. Fixed-body BFS calls 59 unreachable, which is
not proof that they remain unreachable after battles, portals or water travel.

Before any native density correction, obtain a same-configuration original
private-state fixture at `reward_guard_selected_create_dispatch_0x4a9f1c`,
`reward_guard_coordinate_scan_and_commit_0x4aa9b7_impl` / wrapper `0x4aa3e9`,
the selected-candidate vector `+0x10f4/+0x10f8`, and relation treasure bands
`+0xa0..+0xc0`. These native owners exist; the missing proof is this failing
case's original phase join, not an allegedly unimplemented function. The current
evidence cannot distinguish a port defect from an original sparse profile/seed.
Do not insert filler, remove source masks or lower thresholds to claim closure.
Whole-match day-three pacing, every portal shortcut and arbitrary seeds remain
outside the bounded battle/route proofs. The parent goal remains in progress.
