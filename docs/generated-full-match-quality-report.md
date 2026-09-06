# Generated full-match quality: gameplay corrections

2026-09-06. Active Phase 6 parent `quality-generated-full-match-20260906`,
playthrough child `quality-generated-full-match-playthrough-20260906` remains
in progress and is the current implementation child. Measured responsiveness
improvements remain a validated checkpoint, not a completed full-match child.
Requirements:
`docs/generated-full-match-quality-requirements.md`. This is an implementation
checkpoint, **not completion of the child, full matches, or release readiness**.

## Gameplay corrections

Four failures were reproduced before their production fixes:

| Failure | Runtime owner and correction | Live proof |
| --- | --- | --- |
| Visit Town disappeared after selecting the current town in the roster; arriving at a guard left a disabled Select Site button | `OverworldShell._refresh_selected_route_action_surface` now uses authoritative current-tile actions when there is an interaction, retaining the compact destination path elsewhere | Roster selection keeps Visit Town; walking to the guard offers Enter Battle; repeated refresh preserves it; actual Town/Battle scenes open |
| A defeated cache guard did not unlock its reward | `OverworldRules._resource_site_guard_targets_node` now treats an explicit placement ID as authoritative, without falling through to the shared site-type ID | The actual guard loses through shipped Quick Resolve, the casualty report continues, and the cache can be claimed while other caches' guards remain unresolved; legacy type-only links still work |
| Owned hero/town navigation disappeared after leaving Town | The compact generated Town-return refresh now initializes the hero/town action phase on the newly instantiated shell | The return immediately contains one owned hero and one owned town with focusable controls |
| A collected, invisible cache trapped the hero at a waypost | `OverworldRules.resource_node_is_present` now owns consumed-site presence for collision, context, route interactions and map/selection indexes | A normal two-day visit collects the cache once, visits the waypost, backtracks and restores the exact save; permanent, repeatable, transit and overlapping scenery bodies remain |

Exact generated reproduction: Medium, seed `10`, two players, normal difficulty,
Embercourt/default Lyra. Town `native_h3maped_93c0f05a_object_0950` has its native
art anchor at (45,40), its legal entrance/hero start at (43,40), and the required
source cache/guard at (41,41). The guard is
`h3maped_small_rare_source_guard_h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources`.
Before the guard-link fix, unresolved guards for towns 0951–0956 also matched
that cache because they share `site_generated_town_required_source_cache`.

The fourth defect explains the actual Day-21 Medium stall at (50,48): Waystone
Cache `native_h3maped_93c0f05a_object_1055` at (49,49), collected on Day 6, was no
longer rendered/actionable but its original `package_block_tiles` still entered
the occupancy index. This was the only exit from Reed-Knot Waypost 1054. The fix
leaves source masks immutable and lets the existing before/after topology facts
invalidate occupancy when a pickup is consumed; it does not erase other bodies.

No generator, masks, placement, balance, battle RNG, resources, art or save-schema
changes were used to correct these defects. The focused run uses ordinary
starting forces and real scene actions, not forced combat outcomes.

### Exact targets versus scenic footprints

A fifth production defect caused the later Medium Day-54 loop. In the unchanged
recorded save, artifact `native_h3maped_93c0f05a_object_1285`
(`artifact_waymark_compass`, 18,55,0) overlaps the scenic rectangle of resource
1289 (actual entrance 18,56,0). Artifact 1305 (`artifact_trailsinger_boots`,
12,49,0) similarly overlaps resource 1306 (entrance 11,50,0). Both resources
are persistent, already controlled sites. Neither owns the artifact's actual
interaction tile. The view projected the pointer correctly, but
`OverworldShell._selection_route_tile` and `_resource_node_at` resolved scenery
before the exact target, redirecting movement and descriptors to the resource.

Selection now queries exact targets in the existing level-aware domain index and
the active hero tile before scenic shortcuts. The opt-in exact query excludes
guard control zones and town art anchors; default movement queries are unchanged.
Resource entrances use the domain interaction index, including generated support
sites without an authored scenic descriptor. Resource visual fallback cannot
claim another live target. Owned-town
body-click opening additionally requires that selection really resolved to that
town's entrance. No placement, source mask, pathing rule or asset changed.

Evidence below is under `.artifacts/generated_full_match_quality_20260906/`:

- `exact_targets_before_02`: unchanged production code fails exactly three
  pointer/route/descriptor checks, with zero engine errors. Input save SHA-256:
  `f571ab1a10696e0411f417c666d1a91bf6ba9363ad757cfc54491d8efd3c10d7`.
- `exact_targets_boundary_02` and `exact_targets_boundary_1080`: **39 checks
  pass each** at rendered 1280x720 and 1920x1080, zero engine errors. Both settled
  final collection captures were opened and visually inspected. Fog, scenery
  and command controls remain present; the army overflow display remains wrong.
  The earlier dual-resolution `exact_targets_controls` reports
  passed 32 checks before the additional boundary cases. Actual projected
  mouse press/release events collect both artifacts, then save/resume every
  serialized gameplay field through production services. All terrain and source
  placement geometry remain equal. Detached controls cover consumed targets,
  cache invalidation, underground selection, encounters and reserve/active heroes
  without changing the live match. Seven added checks retain guard-zone movement,
  town-anchor/entrance distinctions and support-site ownership.
- `exact_target_arrival_02`: all **23 original guarded-opening checks pass**,
  including arrival's enabled Enter Battle, real victory/report and cache reward.
  The first refinement dropped the resource descriptor for a generated cache
  lacking authored scenery and consequently auto-entered battle. Its failed
  `exact_target_arrival` report and `exact_target_arrival_diagnosis` identified
  that regression; using authoritative resource visit tiles corrected it without
  changing the original test's gameplay assertions. An intermediate Dictionary/
  Vector3i comparison also failed parsing and was corrected before this rerun.
- `exact_target_arrival_body_final`: **26 checks pass**, adding an actual generated
  town body click, exact entrance routing and preserved movement. The initial
  extra check used the native source image anchor, outside the runtime clickable
  body; it was corrected to the view's actual body tile, not a production change.
  `exact_target_town_body_final` also passes the unchanged six-cell authored town
  footprint report, including all five body cells and entrance/arrival behavior.
- `.artifacts/full_play_runtime_20260905/exact_target_domains`: movement-input
  ownership, complete-route movement and fog reports pass. The keyboard smoke
  fails its retired fixed-slot Save expectation, also reproduced rendered in
  `exact_target_focus_rendered`. Controller A opens the actual named-file browser
  with filename focus; the test expects an immediate slot overwrite dialog.
  `_on_save_pressed` and the shared save dialog are unchanged from `a8c4a81f`.
  Named-file behavior is specified in `docs/visual-performance-file-saves-report.md`.
  This old test is not suppressed or represented as passing.
- `exact_target_final_domains` in that same full-play evidence root reruns all
  three movement/input/fog reports successfully after the final boundary fixes.
- `exact_target_named_saves_final`: the existing current named-file regression
  passes all four shipping Save routes, nine independent files, physical Enter,
  Escape/controller Back, transactional and overwrite-consent checks. Only the
  temporary script's screenshot output path was redirected to this fresh evidence
  directory. Initial attempts failed in the host's missing desktop bus and then
  the removed historical screenshot directory; both failures are retained.
  Its intentional same-size corrupt-file probe emits the expected invalid-JSON
  error; no script error occurs.
- `exact_target_linux_final`, `exact_target_windows_final` and
  `exact_target_linux_generated_final`: exports, startup and actual generated-map/Town
  entry pass; Windows runtime checks use Wine, not native hardware. Both PCKs
  contain **248438424 bytes**, leaving 1561576 bytes below the unchanged ceiling.
  Actual export/boot/generated-flow commands return zero with successful reports;
  two outer execution handles subsequently reported 143 after their completion
  output, not an engine/package failure. The completed logs/reports are retained.
- `exact_target_validate_repo_final.log`: repository validation passes. Nine
  Python full-match acceptance/checkpoint tests pass; `git diff --check` passes.

The runner now records revision and runtime source hashes at **launch**, not at
the end of an hours-long run; dirty runtime changes are separately fingerprinted.
This improves evidence provenance only and does not alter its gameplay policy.

## Fresh validation

Evidence root: `.artifacts/generated_full_match_quality_20260906/`.

Latest consumed-site checkpoint (after the first three fixes in `74492703`):

- `stall_diagnosis_01` restores the real stalled Day-21 save; `consumed_before`
  reproduces invisible collision and failed backtracking through normal play.
- `consumed_overlap_final`: **25/25 checks pass**, zero engine errors, actual
  generated opening and collection/save/backtrack flow. Explicit isolated unit
  controls preserve overlapping scenery, repeatable services and native transit;
  they are not mutations of the live match. Terrain/source masks remain equal.
- `consumed_exact_720` and `consumed_exact_1080`: **20/20 checks pass** in each
  rendered run. Both final screenshots were visually inspected. They replay the
  unmodified recorded Day-1 opening (SHA256
  `f0112262145c2494fdd2031103e3ea8f89fc4490629bdf044ad753a4badd3251`). The later
  headless test adds the pure lifecycle/overlap controls. No art was replaced.
- `presence_arrival_recheck`: all previous **23 gameplay checks pass** again.
  Nine Python acceptance/checkpoint tests pass. Resuming requires a recorded
  matching normal setup/checkpoint, error-free action prefix and exact full
  serialized gameplay restoration; no future actions count toward coverage.
- `presence_domain_regressions`: interaction-confirmation optimization passes.
  Three unchanged older reports fail: object occupancy expects a 10-cell/15-cell
  sawmill while current uncollected authored content has a 6-cell/6-cell mask;
  six-repeatable-services has old Ninefold counts and recovery assertions; the
  profile-log test expects a skipped recap while the current path builds one.
  These failures are retained, not suppressed or presented as passing. The
  focused new live and lifecycle checks pass; the whole legacy suite is not green.
- `presence_validate_repo_verified.log`: repository validation passes. Its
  presence contracts now check the shared helper and each caller, preserving
  persistent/repeatable/transit checks instead of requiring duplicated source.
- `presence_linux_export`, `presence_windows_export`, and
  `presence_linux_generated`: exports/startup/generated-map/Town flows pass.
  Both PCKs are **248439144 bytes**, below 250000000; Windows uses Wine.
  `git diff --check` passes.

Earlier three-fix checkpoint evidence (not a claim these entire batches were
regenerated for the fourth fix):

- `arrival_before`: reproducible missing town/guard primary actions.
- `guard_identity_before`: real victory followed by a wrongly locked reward.
- `return_roster_before`: zero hero/town roster buttons after returning.
- `arrival_final_720` and `arrival_final_1080`: all **23 checks pass** at actual
  1280×720 and 1920×1080, zero engine errors. Visually inspected roster, guard,
  combat and reward captures; command controls are available. Broader scenery
  polish and abbreviated/crowded footer copy remain unfinished.
- Five existing route/context-cache, destination-only action, incremental
  refresh, full-route movement and movement-input-ownership regressions pass in
  `route_regressions`.
- Six Python complete-match acceptance tests pass; timeouts, driver stalls,
  early incomplete defeats and missing outcome/save/report coverage fail closed.
- All 26 repository-required consolidated content smokes were regenerated.
  Four stale tests were aligned with the existing 160-unit/299-scenario catalog
  and Charterless Compact campaign/witness contracts already asserted by
  `tests/validate_repo.py`; all their gameplay checks remain. Fresh successes
  are in `required_content_smokes_dbus` and `required_content_smokes_corrected`.
  Initial launches without a desktop bus failed in host accessibility setup;
  old wrappers also emitted unavailable-ALSA-device errors before Dummy fallback.
  Corrected reruns explicitly used Dummy audio/disabled accessibility and had
  no engine errors. These are content smokes, not full-match certification.
- `python3 tests/validate_repo.py` and `git diff --check` pass; final repository
  output is retained in `final_validate_repo.log`.
- Linux/Windows export smokes pass, including native sidecars and startup;
  `linux_generated` and Windows `generated-flow` both enter a generated map and
  player Town. Both PCKs are **248438632 bytes**, below 250000000. Windows evidence
  is Wine, not native Windows/GPU certification.

Additional unresolved validation: the legacy
`native_rmg_small_h3maped_guard_engagement_report` fails with
`no_reachable_hostile_town` for Small seed 1, three players. Its private
`_build_direct_path` cannot produce the requested hostile-town route; a disposable
entrance-target correction alone did not solve it and was reverted. The test and
native generation remain unchanged. The new exact Medium runtime guard/reward
proof passes, but this older Small path-report failure is not claimed fixed.

## Full matches and remaining work

The new Python-owned runner drives production scene handlers, shipped Quick
Resolve/casualty-report continuation, normal town orders and enemy turns. Saves
are compared across every JSON-serialized gameplay field and resumed through the
production router. Raw Godot Variant equality proved too strict for typed/packed
containers; serialized comparison drops no gameplay fields. Evidence is compact
action/profile JSONL, sparse screenshots and selected saves, not per-action world
dumps. Test save storage is isolated from the owner's saves.

Medium attempts reached Days 21, 18 and 21. All failed the
driver's progress gate with no terminal outcome. They exercised development,
recruitment, battles, casualty reports, enemy capture of the home town, and
opening/mid-match save/resume. The first rendered Large attempt reached Day 10
before being stopped for a driver portal-backtracking loop. Its Day-8 checkpoint,
opening town, combat, casualty and map captures remain. A second Large attempt
reached a real Day-5 defeat and terminal save/resume but failed acceptance because
it had neither a mid-match checkpoint nor recruitment coverage. **None is an
accepted complete match.** Follow-up driver work recognizes owned-site waypoints,
avoids re-reading signs/portal shuttling, and retains the same legal movement
rules. The original Day-21 route defect is now diagnosed and fixed as described
above.

Subsequent legal continuations moved beyond that area. `medium_match_07` reached
Day 54, after owning three towns and then losing two, but failed its fourteen-day
no-progress gate. It repeatedly targeted artifacts while arriving at controlled
resource-site actions, spending movement before reaching hostile towns. The
production scenic-footprint routing cause is now corrected above; the failed
report is retained, not called a completed match. `medium_match_08` restored its
exact recorded Day-54 autosave and reached Day 69 beyond the loop.
`large_match_05`, after capturing enemy Mireclaw town 2169 and neutral town 2178,
was deliberately superseded to load the validated routing correction, not stopped
for an observation timeout. `large_match_06` restored its exact recorded Day-37
autosave (SHA-256 `82448ac96ee05b7d26cf1ff7f04ebe9424e207fd1b0c6303af1a2a9877cd88b9`)
and reached Day 43. Neither continuation is an accepted terminal match. They
loaded the initial selection fix, before the final guard/support-site/anchor
refinements; their launch source hashes identify that difference exactly.
Their prefixes include actual development, battles and save checkpoints.
The driver now invests in available recruitment buildings, checks visible portal
guards, targets legal guard-zone edges and backtracks through visited entrances.
These are test-policy improvements, not production AI/balance fixes.

Long-run orchestration can resume exact recorded End Turn autosaves and run under
a detached Python supervisor with its own timeout. An execution-tool wrapper
previously terminated while leaving its engine running; that exact task-owned
engine was identified and stopped. Superseded partial runs remain failed/partial,
not successful matches. The live supervisor PIDs and action logs are operational
evidence only; terminal reports are still required.

One concurrent fresh seed-10 setup failed package JSON loading and normal retry
selected a different seed (`consumed_after_720`). The provenance records the
failure and retry, not exact-seed success. Simultaneous same-name package writing
is a suspected race, not a proven native-generation defect; no native tuning or
retry change was made. Exact visual controls restore the recorded opening and
serial fresh-generation controls independently pass. Package-write concurrency
needs separate focused reproduction before any correction or determinism claim.

Large observations include multi-second builds and roughly ten-second turns;
some runs overlapped validation processes, so these are responsiveness warnings,
not controlled before/after benchmark results. Subsequent controlled actual Town
orders and complete End Turns now show behavior-preserving improvements in
`docs/generated-full-match-performance-report.md`; those limited measurements do
not establish whole-match responsiveness.

The Day-54 screenshots expose another real correctness defect: the formation bar
shows seven empty slots and zero troops while the saved army contains **18 stacks
and 970 troops**. `OverworldRules.recruit_in_active_town` appends a new unit type
without enforcing the existing seven-stack limit. `HeroCommandRules.army_slot_snapshot`
rejects oversized armies with `capacity_valid=false` and no slots; `ArmyStackBar`
renders that response as empty instead of showing the error. Additional reward
append paths must also be checked. This is not troop loss in the save, and no
army or recruitment fix is claimed here. These long runs remain diagnostic until
the capacity/rule/display inconsistency is resolved; oversized armies must not
silently certify legitimate full-match acceptance. The next correction must
preserve existing saved troops, costs, recruitment reserves and rewards rather
than truncating armies or changing the seven-slot rule.
The inspected Veilmourn Town still has detached-looking building sprites and
stray footer resource text; the presentation child remains pending.

Next: establish competent legal Medium/Large exploration/conquest through real
terminal outcomes and terminal save/resume, continue measured full-action
optimization and address the recorded Town/Overworld presentation gaps.
Keep all three children and the parent honest; individual fixes and package
success do not establish complete-match or product readiness.
