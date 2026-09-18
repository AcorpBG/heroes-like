# Generated Exploration and Guarded Routes

Owner direction, 2026-09-18: generated maps need worthwhile interactions,
artifacts and guarded enemy approaches that cannot simply be rushed around.
Phase 6 implementation slice `rmg-exploration-and-guarded-routes-20260918`,
derived from `project.md`, `PLAN.md`, `docs/lessons-learned.md` and the preceding
`docs/rmg-guards-and-empty-space-audit.md`.

## Implementation scope and acceptance

1. Restore all supported native scenery at classification/adoption, retaining
   source identity, coordinates, levels and exact masks. Render original raster
   art appropriate to the original-game biome/scenery translation. No invisible
   blockers and no silent unknown-body fallbacks. The three confirmed guard
   bypass fixtures must fail through normal movement after correction.
2. Trace all reward destinations, artifact pickup/site rewards and generated
   guard quantities/compositions into live interactions. Correct concrete
   adoption/rule defects; document measured availability and remaining design
   limits rather than inflate object counts or claim unplayed match pacing.
3. Preserve deterministic generation and final native bytes. New-map adoption
   changes must not silently rewrite old saved topology or reward state.
   Existing site defenders must not be deleted merely for overlapping artwork.
4. Keep Linux/Windows runtime, native libraries and packages in sync. Inspect
   representative Medium/Large renders and verify real pickup/movement/battle
   boundaries, not metadata alone.

## Targets and validation

Owners: native package/CLI classification, original-art scenery manifest,
`NativeSceneryRules.gd`, `NativeRandomMapPackageSessionBridge.gd`,
`ScenarioSelectRules.gd`, `OverworldRules.gd`, `OverworldMapView.gd`, reward eligibility where a
concrete translation gap is proved, Python-owned focused regression.

Consolidated validation: focused source and packaged Linux/Windows regression;
existing generated-neutral, distinct/decorative coverage and town-supply-removal
checks; deterministic Medium/10, Large/11 and Large/1 cases; native payload
comparison to retained original authority without feeding captures into native
generation; `python3 tests/validate_repo.py`; official Linux/Windows export
smokes and package parity; `git diff --check`, tracker validation and final
`git status --short`. Record exact limits and cleanup disposable task outputs
while preserving native RMG recovery evidence, caches, saves and unrelated files.

Non-goals: source-phase generation/placement/RNG changes, arbitrary density or
guard multipliers, synthetic reward/route filler, post-payload mask carving,
day-based movement locks, native parity claims without private-state proof,
unrelated UI/Town/art families or balance changes unrelated to measured gaps.

## Results

Correction implemented and validated; the separate opening-density and full-match
balance limits below remain explicitly unfinished.

### Corrections and design choices

- A shared C++ runtime classifier now covers all 38 scenery families present in
  the recovered group-zero object-template inventory. The native generation
  core is unchanged. Unknown nonvisitable types fail adoption instead of being
  mislabeled renderer-managed. The bridge also recognizes these families in
  existing, not-yet-started packages. Every original mask remains untouched.
- New sessions opt into `art/overworld/native_scenery.json`: existing original
  biome raster masses cover landscape bodies; explicit water, frozen shelf,
  lava, basalt and deadwood assets cover the corresponding special families.
  There is no new generation, copied source art or procedural replacement.
  Source-inventory-based visual validation now detects records absent from
  live state, not just missing pixels on the records already adopted.
- Source random-artifact classes 66–69 previously selected four exact catalog
  proxies: one fixed item per class. Their original-game translation now draws
  deterministically from common/uncommon/rare/epic bands (2/24/37/6 candidates),
  using the existing stable map/ordinal selector and no native RNG. Fixed
  compatible catalog identities remain unchanged. Rarity is our content policy,
  not a claim that original-game item balance equals H3MapEd item balance.
- The type-16 bank proxy crossed domains: a generated guarded reward site
  became a free artifact pickup. It now uses the existing original guarded-site
  pool and its real defender/reward contract. This intentionally reduces free
  pickups while restoring guarded destinations; it does not delete the reward
  or replace it with a decorative prop.
- Catalog-auto setup already declared a normal guard profile but omitted the
  actual native `monster_strength` field. That omission used `random`, which
  aliases weak raw setup `-1`. New catalog-auto games explicitly use supported
  normal raw setup `0`. Historical size profiles explicitly retain weak; saved
  sessions and explicit replay configs are not rewritten. This chooses an
  existing recovered setup mode, not a new multiplier or guard-placement rule.
- Actual guarded-site collection/save checks exposed a pre-existing omission:
  resource normalization discarded `state_id` and `route_state_id` after a site
  opened. Both existing optional fields now survive normalization and restore;
  absent legacy fields remain absent. Native replay metadata now retains the
  exact original input config, including strength, instead of an empty config.

The final five-case rendered source run passed 81,237 checks with no runtime
errors. The historical weak cases now have zero dropped source records and zero
source-blocked cells newly opened by adoption. All three exact bypass routes
are rejected by production movement. Artifact anchors equal native visit tiles
in these samples: no artifact-coordinate migration was justified.

| Case | Scenery records | Artifact pickups / distinct identities | Guarded banks | Native guards / total creatures |
| --- | ---: | ---: | ---: | ---: |
| Medium 10, weak | 950 | 22 / 18 | 11 | 41 / 1,461 |
| Large 11, weak | 1,852 | 14 / 10 | 23 | 58 / 2,270 |
| Large 1, weak | 2,019 | 34 / 27 | 39 | 129 / 5,013 |
| Medium 10, normal | 956 | 21 / 20 | 10 | 65 / 2,487 |
| Large 11, normal | 1,855 | 17 / 12 | 22 | 73 / 3,010 |

These are complete map inventories, not all initially revealed or immediately
accessible loot. Normal mode changes native placement/army distribution, so
not every individual guard is stronger: Medium median heuristic army strength
is 838 versus weak's 988, while there are more guards and total creatures.
No blanket army multiplier was added. The heuristic is not a battle win estimate.

Ground-only analysis with all unresolved bodies intact finds 42/58/86-step
routes between starting-town entrances for Medium weak, Large 11 weak/normal;
none survives removal of every guard-control tile. Large 1 weak and Medium
normal have no such direct ground route even before closing controls; this
analysis excludes clearing pickups/bodies and portal travel. It is not proof
that all possible played routes are guarded or a universal day-three lockout.

### Compatibility and remaining limits

Old saved topology is intentionally retained, even if it contains the previous
missing-body defect. Start a new generated game for the corrected scenery and
new default strength. Source quantities, native masks, original save schema,
authored scenarios and existing battle rules are unchanged. Added site guards
are the existing authored internal-defender policy, not invented native guards.
Their visual overlap with external native guards remains a separate presentation
issue; defenders are not silently removed or moved.

Full-match pacing across templates/factions, portal routes, and the subjective
distribution of major destinations remain broader play-balance work. No native
phase/private-state parity advance, arbitrary-seed proof or release-ready claim
is made by this adoption correction.

The existing four-size density report passes Medium, Large and Extra Large but
still fails two Small opening-ring thresholds: two early interactions (minimum
four), seven mid-ring interactions (minimum eight). All four sizes now pass the
zero-dropped-source-object check. The failing seed is
`generated-density-distribution-10184-homm3_small`, explicit historical size
profile/weak setup. This is a remaining design/quality limit, not
a reason to remove restored collision, weaken thresholds, reinject the deleted
Town Supply Cache, or invent post-generation rewards. Artifact variety improved;
the native number of artifact placements was not increased.

### Validation commands and observed results

- `python3 -B -m unittest discover -s tests -p 'test_rmg_exploration_contract.py'`
  and `test_rmg_guard_space_audit.py`: nine Python checks passed.
- `python3 -B tests/rmg_exploration_regression.py --label final-source --render
  --resolution 1280x720 --timeout-seconds 900`: 81,237 checks passed. Real disk
  package startup, source masks, exact old bypass routes, repeat adoption,
  artifact inventory/pickup, guarded-site entry/rewards, saved cleared-site
  state and legacy topology preservation. Bank victory in this focused probe
  is an explicit resolved-battle fixture; it is not a played whole match.
- Existing authored-pool proxy, object weighting, distinct sprite and decorative
  sprite reports passed. Neutral-unit report passed 7,471 checks; generated
  Medium/Large neutral-map tests passed 451/1,348 checks including battle cases.
- `tools/rmg_start_placement_audit.py --label exploration_water_levels_20260918
  --case matrix_36_2_land,matrix_72_1_normal_water,matrix_36_2_islands,matrix_72_2_normal_water
  --require-entrance-starts`: four generation/adoption/entrance cases passed.
  Direct source/live inventory comparison found zero dropped records in each,
  with 271/898/88/950 scenery records respectively, including both levels.
- Fresh release CLI output still equals the retained original Medium/10 and
  Large/11 payloads byte for byte (79,333 and 147,775 bytes). Comparison material
  is retained under `rmg_start_audit_20260905/exploration_retained_20260918`.
  Standalone adoption's existing same-run metadata authority gate is unchanged.
- The legacy boundary report's fixed-artifact assumptions were updated to
  rarity/pool provenance. Its dwelling fixtures now put the hero at the native
  visit tile and test each reward with available army capacity, rather than
  remotely recruiting or accumulating twenty unit types in a seven-slot army.
  Production locality and capacity rules are unchanged.
- The full native runtime-boundary report now passes, including its actual
  guarded-bank combat/reward path. The Town Supply Cache removal regression
  passes 9,421 checks with the corrected default; the removed injection stays
  removed.
- The official Windows growth smoke encountered a genuine day-ten town assault.
  Its existing battle driver now requests/accepts shipped Quick Resolve, checks
  the report/Overworld return and unchanged day, then resumes the exact ten-build
  sequence. The observed result was victory, with all 26 setup/construction/
  battle/report steps complete. No enemy is deleted, victory forced, army
  inflated, day skipped or gameplay rule changed. The Python verifier permits
  those battle steps while still requiring the full ordered build/info list.
- Rendered source evidence at 1280x720 and packaged Linux evidence at
  1920x1080 were inspected: restored biome masses and reeds cover source bodies,
  with original assets, legible routes and intact edge controls. Starting-town
  captures retain fog; guard-area inspection captures explicitly reveal the
  map for diagnosis, not a shipped fog change. An initial lake-art choice that
  read as repeated wells was replaced with the existing reed/water masses
  before final source/package visual inspection.

- Linux/Windows Debug and Release native libraries and both release CLIs were
  rebuilt successfully. Both official export/package smokes pass. Each final
  PCK is 648,455,080 bytes with 8,918 entries; only platform `project.binary`
  differs. Current project policy has no fixed package-size cap.
- Exact-probe packaged exploration: Linux 81,237, Windows 81,227 checks passed;
  Windows headless omits only ten screenshot writes. All five map inventories,
  native hashes and gameplay metrics match across platforms. Probe SHA-256 is
  `1e419df81bb3e84571fb0967bf7498623e85b19012b935347c836a7d0f11b05b` on both,
  and each runner verifies an unchanged export and compiled runtime owners.
  Final Windows PCK exactly equals its exercised package. The final Linux PCK
  differs from its exercised package only in the subsequently corrected opt-in
  `LiveValidationHarness.gdc`; every exploration owner and native library is
  identical, and final Linux boot plus Windows's real assault flow validate the
  harness correction. This does not substitute a source run for package testing.
- Final package SHA-256: Linux
  `e302216d3b56bfc9d7f22897f235428f67cca9b376185ae532ae2f7c56c9fc1a`;
  Windows `971eeb62d65df9efdf621de3e479cbeece67ec79ef8dd2c70ed9b3c7d53df6d5`.

- `python3 -B tests/validate_repo.py`: passed after updating its stale fixed-item
  and unlimited-army fixture assertions to match the verified behavior. It
  reports 26 absent historical smoke artifacts as unexecuted, not passed.
  The complete repository validator is distinct from the density runtime report:
  its pass does not erase the two Small-map density failures above.
- `git diff --check` and focused tracker validation passed. The
  heroes-progress workflow tracked the implementation under Phase 6; no native
  generation/private-state parity checkpoint or whole-product completion was
  inferred from it.

### Completion cleanup

Removed 4,512,436,224 allocated bytes (4.51 GB; 4,509,948,303 apparent bytes)
from 14 verified task-owned targets: disposable exports, temporary Wine test
data, runtime reports/captures, generated-case snapshots and the interrupted
probe/profile. These are rebuildable; commands, results, limits and package
hashes are recorded here. Exact paths were checked for symlinks, tracked files
and active file users before removal. No blanket `.artifacts` or `/tmp` sweep.

Preserved native reverse-engineering/reference material, including the new
254,621-byte retained-payload comparison; all build/import caches, source,
original art/provenance, real user saves/backups, and the pre-existing unrelated
untracked artifact-retention files and `tools/__pycache__/`. Disposable engine
profiles were task-created test data, not user saves. Required shipped native
binaries remain in `bin/`; temporary package copies were not release delivery.
