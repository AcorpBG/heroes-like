# Generated full-match quality: gameplay corrections

2026-09-06. Active Phase 6 parent `quality-generated-full-match-20260906`,
playthrough child `quality-generated-full-match-playthrough-20260906` remains
in progress. Town overlay and command/footer checkpoints below are validated.
Large08 reached a legitimate Day-14 defeat after enemy-town conquest; Medium10
stopped on Day 35 without an outcome and remains diagnostic. Measured
responsiveness improvements are a checkpoint, not a completed full-match child.
Requirements:
`docs/generated-full-match-quality-requirements.md`. This is an implementation
checkpoint, **not completion of the child, both match sizes, or release readiness**.

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

The Day-54 army defect now has a validated player-side correction below. The older
Medium/Large continuations remain diagnostic: their saved armies already exceed
the seven-slot rule, including AI holders. Latest observed progress was Medium
Day 84 and Large Day 52, not terminal success or uncontaminated timing evidence.
The inspected Veilmourn Town still has detached-looking building sprites and
stray footer resource text; the presentation child remains pending.

### Player army admission and non-destructive overflow recovery

The unchanged Day-54 save contains **18 stacks / 970 troops**. Paid recruitment,
per-unit transfers and site claims appended new unit types without the existing
seven-slot check. The snapshot rejected the oversized army with no slots/count;
the bar displayed seven empty slots and zero troops. Separately,
`OverworldRules._add_army_stack` added each incoming grant to every matching split
stack and stripped formation metadata. A grant of four to stacks of two and three
became thirteen instead of nine.

`HeroCommandRules.army_addition_plan` now plans a complete manifest without
mutating its input. Paid recruitment, Town/field transfers and site claims reject
before costs, reserves, source troops or claim state change. New stacks get a free
formation index; matching units reinforce one existing stack, not every split.
Town offers report capacity and refresh after transfers. Hero/Town convoys retain
their existing saved manifest and receipt while a destination is full, then arrive
once when room exists; no new reserve inventory or save-schema field is introduced.

Legacy overflow keeps all troops. The bar shows the actual total, seven occupied
slots, excess counts and a focused tooltip listing the excess. Positional editing
remains disabled for oversized holders. The existing **Town Log & Logistics →
Transfers** controls can reduce excess legally; valid formations then regain
positional splits/merges. Icons now sit above readable counts rather than behind
them. No troop truncation, content, price, map, RNG, balance or save-version change.

Evidence root: `.artifacts/generated_full_match_quality_20260906/`.

- `army_capacity_reference_01`: **10 expected failed checks**, zero engine
  errors, replaying unchanged `HeroCommandRules`/`OverworldRules` from `c8d05faf`
  on the same isolated fixtures. This is an old-owner control with current shared
  dependencies, not a complete old build. Save SHA-256 is the recorded
  `f571ab1a10696e0411f417c666d1a91bf6ba9363ad757cfc54491d8efd3c10d7`.
- `army_capacity_complete_720` and `army_capacity_complete_1080`: **63 checks
  pass each**, zero runtime errors; source hashes are recorded. Exact save/restore,
  atomic rejected actions, slot-index recovery, matching/split grants, successful
  site claims, hero/Town convoy waiting/one-time arrival and actual keyboard Town
  transfer/split all pass. Synthetic controls are isolated from the unchanged
  saved match; they are not full-match gameplay evidence.
- The final Overworld, overflow Town and recovered Town captures at 1280x720 and
  1920x1080 were opened and inspected. Army counts/icons and recovery instructions
  are legible; the dialog scrolls to transfers without losing input. Existing
  Town footer/background composition defects remain visible and unresolved.
- `tests/generated_full_match_quality.py` now observes hero, garrison, encounter
  and commander-roster capacity. Every action/continuation must have observations;
  transient excess or missing old observations fail acceptance. Eleven Python
  acceptance/resume tests pass (`army_capacity_acceptance_tests.log`). This
  validation supports the correction; it is not itself a gameplay fix.
- `army_capacity_domains_02` under `.artifacts/full_play_runtime_20260905/`
  passes Town transfer feedback, recruitment playback, elder-wild site claims and
  transactional saves. `army_capacity_town_dialogs` passes current five-dialog
  Town routing and field rendezvous transfers. The historical army-bar report
  still opens retired `ManagementTabs`; the historical recruitment-surface report
  expects inline tier buttons before opening Muster. Their failures are retained,
  not suppressed or called passing; current dialog/keyboard coverage above passes.
- `army_capacity_scope_final` reruns read-scope equivalence/freshness across six
  factions and 29 catalog samples with no errors.
- `army_capacity_validate_repo_final.log`: repository validation passes.
  `army_capacity_linux_final`, `army_capacity_windows_final` and
  `army_capacity_linux_generated`: exports/startup and generated Overworld/Town
  entry pass, with **248442920-byte** PCKs on both platforms (1557080 bytes spare).
  Actual processes exit zero. Windows evidence uses Wine, not native hardware.

The defect is **not fully closed**. The same saved Medium observer reports Town
0950 with 14 stacks, Town 0951 with nine, and two enemy raids/roster armies with
eleven. The retained Large Day-37 save also has nine in enemy Town 2170.
At that player-only checkpoint, `EnemyTurnRules` recruitment and
`EnemyAdventureRules` roster/site/Town/raid handoffs still appended without
capacity protection. The following AI checkpoint corrects those owners without
rewriting older oversized saves. At that checkpoint, `ScenarioScriptRules` still
marked one-shot hooks fired before unbounded army/garrison grants; 106 authored
reinforcement hooks needed reward-preserving behavior, not silent rejection.

### AI army admissions and feasible orders

The unchanged `e8f4db7d` AI reproduced **16 failures in 17 checks**:
an eighth paid stack spent treasury/reserves, direct and opportunistic site claims
consumed rewards, and whole-host transfers could retire a donor while overflowing
the recipient. The first matching-unit control passed. Evidence:
`ai_army_capacity_before_01` under the same generated-full-match evidence root.

`EnemyTurnRules._recruit_town_forces` and `_apply_reinforcement_to_raid` now
preflight the shared `HeroCommandRules.army_addition_plan` before purchase/commit.
`EnemyAdventureRules.reinforce_commander_roster_army` and both site claim owners
do the same before claim/spoils/roster mutation. Consolidation, town defense and
empty-neutral-town capture plan whole-host transfers before ownership/commander
changes. Resupply transfers fitting stacks only, retaining rejected source troops
and their slot metadata. No price, target score, map, art, balance or save-version
change; old excess is not truncated or converted into a new carrying reserve.
The admission army resolver retains saved commander continuity when an explicit
raid army has not yet been populated, matching restoration precedence instead of
substituting the encounter's starter troops. Claims, handoffs and selection use
that same resolution.

Current target validation, current-tile claims, ordinary/explicit selection,
saved/live tasks and threatened/post-capture town defense use the same admission
feasibility. Grouping skips incompatible donors and can select another fitting
one. Held-site defense, which grants no new claim recruits, remains available.

Evidence:

- `ai_army_capacity_expanded_02`: **46 focused checks pass**, zero engine errors.
  Tests cover complete-state rejection, real commander retention, matching paid
  and roster recruitment, exact site grants, atomic handoff rejection after a
  fitting prefix, fitting town defense/capture, partial resupply and target
  selection. `ai_army_capacity_after_01` first passed the original 17 checks.
  Initial selection/probe iterations with parse errors are retained as failed
  attempts, not counted as behavior passes.
- `ai_army_capacity_continuity_before`: four added checks reproduce starter-army
  substitution, incompatible consolidation and lost saved troops on the first AI
  correction, without engine errors. The final 55 focused checks include these
  controls plus continuity-only resupply, town defense/capture and target choices.
- `ai_army_capacity_verified_medium` and `ai_army_capacity_verified_large`:
  **95 checks pass each**, including those 55 focused checks and two ordinary
  seven-turn replays from the same freshly
  generated opening, all serialized state equal after every turn. The production
  match capacity observer checks heroes, garrisons, encounters and commander
  rosters, with zero violations. Seeds/configurations match the representative
  Medium/Large cases above. No injected armies, removed opponents or forced
  outcomes. These are rule-level early turns, explicitly **not terminal matches**.
  Large rule-call timings reached 7.42 seconds under concurrent test load; no
  timing comparison or full-action improvement is claimed from this correctness
  test. Earlier 86/90/93-check iterations remain historical evidence only.
- `ai_army_capacity_domains_verified` in `.artifacts/full_play_runtime_20260905/`:
  all five existing town-defense, recruitment-preparation, assault-grouping,
  live-task execution and known-world-memory reports pass without engine errors.
  The Python suite now accepts the two newly selected defense/preparation reports
  directly; no historical assertions were removed or weakened.
- `ai_army_capacity_validate_repo_verified.log`: repository validation passes.
  `ai_army_capacity_acceptance_verified.log` records eleven passing Python
  full-match acceptance/resume tests; `git diff --check` passes.
- `ai_army_capacity_linux_verified` and `ai_army_capacity_windows_verified`:
  export and startup checks pass, including Windows generated Overworld/Town
  entry under Wine. `ai_army_capacity_linux_entry_verified` passes that generated
  entry flow from the Linux export too. All processes exit zero. Both PCKs are
  **248446360 bytes**, 1553640 below the decimal 250 MB ceiling.
  Windows-native hardware testing remains unproven. No visual layout was changed
  by this AI checkpoint; the previously inspected presentation gaps remain open.

The older `medium_match_08` and `large_match_06` subsequently exhausted their
7200-second observation windows without terminal reports. Their oversized-army
prefixes cannot become accepted full matches by resuming them or truncating their
troops. Fresh legal matches remain required.

### Scripted earned-reinforcement retention

The `8aa89d20` script owner reproduced **13 failures in 28 checks** without
engine errors (`scripted_reward_before_02`). Authored Stonewake survivors and
Causeway's veteran garrison could create an eighth stack. Simply rejecting the
addition would lose an earned grant because `process_hooks` records the once-only
hook before applying its effects. All 106 current authored reinforcement hooks
are one-shot (104 field-army, two garrison effects).

`ScenarioScriptRules._add_army_units` and `_town_add_garrison` now preflight the
whole validated manifest through `HeroCommandRules.army_addition_plan`, before
changing troops. A blocked hook effect stores optional `pending_reinforcements`
inside existing script state, keyed by hook/effect index and fixed to its earned
hero/town and controller (plus town owner). Normal hook evaluation retries
existing pending grants once. It does not recheck transient earning conditions,
refire narrative/flags/resources/recruit-reserves/spawns, select a replacement
recipient, create actors, or let a captor receive the original grant. Successful
delivery consumes that pending record exactly once; the empty optional key is
removed. Non-active heroes retain their own grant without changing active mirrors.

Unknown saved unit content suspends the complete grant instead of materializing
an invalid stack or discarding a partial manifest. Existing fired hooks without a
pending record remain fired; old armies are never truncated. The generic
repeatable-hook facility allows at most one outstanding invocation per hook and
cannot refire during its delivery pass. These are saved source-owned entitlements,
not extra army inventory. Existing event messages/recent-event tooltips explain
waiting and delivery. Save version **9**, authored rewards, capture rules, maps,
balance and art are unchanged. The exact mechanism was specified in the parent
requirements and tracked before implementation.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `scripted_reward_verified_01`: **40 checks pass**, zero engine errors. Includes
  the real authored hooks, complete-state save/resume, unchanged blocked retries,
  changed transient conditions, non-active/missing/foreign heroes, missing towns,
  controller and owner changes independently, matching split stacks, atomic
  multi-unit grants, once-only flags/resources/spawns/chains, unknown saved units,
  bounded repeatable hooks and no retroactive rewards. Production script SHA-256:
  `f3aafd02234ae36d3297ef510cf9dcf1f8527123220b124af350d40cc827fa7c`.
- `scripted_rewards_player_capacity_verified`: **63 checks pass**, preserving the
  actual legacy save and explicitly rejecting its overflow history for match
  acceptance. `scripted_rewards_ai_capacity_verified`: **55 checks pass**.
- `scripted_rewards_generated_medium_verified` and
  `scripted_rewards_generated_large_verified`: **95 checks each**, including two
  normal seven-turn replays from each representative generated opening with
  complete-state equality and zero capacity violations. These are early-turn
  rule controls, **not complete matches or matched performance measurements**.
- `scripted_rewards_acceptance_verified.log`: eleven Python acceptance/resume
  tests pass. `scripted_rewards_validate_verified.log`: repository validation
  passes; `git diff --check` passes.
- `scripted_rewards_linux_verified_serial`, `scripted_rewards_windows_verified`
  and `scripted_rewards_linux_entry_verified`: exports, startup and generated
  Overworld/Town entry pass, including Wine's Windows execution. Both PCKs are
  **248450520 bytes**, **1549480** below the decimal 250 MB ceiling. This does
  not certify Windows-native hardware.

The nine affected Stonewake/Reedbarrow/Causeway and campaign reports pass on the
final production owner (headless controls plus the final-nine report's required
rendered run). They are now invocable through
`python3 tests/full_play_validation_suite.py --scripted-rewards --accessibility disabled --label <fresh>`.
The consolidated nine-report rerun passes in
`.artifacts/full_play_runtime_20260905/scripted_rewards_campaigns_verified/report.json`.
No historical gameplay assertions were
weakened. Rendering uses the already-documented validation-only AT-SPI isolation;
production accessibility defaults are unchanged.

Failed attempts remain explicit: the first disposable test had an incorrect
draft-registration call; a later repeatable fixture lacked required registry
metadata. Those harness failures were corrected, not counted as behavior passes.
The original final-nine headless invocation was terminated at its unconditional
`frame_post_draw` wait, then passed with rendering. Parallel Linux/Windows export
hit their shared Godot `/tmp/tmpproject.binary`; the failed Linux package is not
accepted. The serialized Linux rerun and Windows package both pass and match in
size. Export errors were not suppressed or ignored.

Next: establish competent
legal Medium/Large exploration/conquest through real
terminal outcomes and terminal save/resume, continue measured full-action
optimization and address the recorded Town/Overworld presentation gaps.
Keep all three children and the parent honest; individual fixes and package
success do not establish complete-match or product readiness.

### Battle-transition driver repair and Town overlay ownership

Medium09 stopped on Day 4; Large07 stopped on Day 6. Both supervisors exited and
neither run reached a terminal outcome. The six-frame driver settle returned
while `BattleShell._battle_exit_handoff_in_progress` was still true after a real
battle resolution. Medium reissued Quick Resolve against an already resolved
battle; Large attempted confirmation on a subsequently freed scene. This is a
driver timing defect, not evidence that production battle resolution failed.
The driver now waits for the authoritative handoff flag, bounded by its existing
30-second failure timeout. Production animation, autosave, casualty report,
Quick Resolve and battle rules are unchanged. Their opening saves remain valid
focused fixtures, but no matching later full-match checkpoint supports resuming
those diagnostic prefixes. Fresh Medium10/Large08 runs are required.

The generated Town captures also reproduced a real production composition bug:
`TownStageView._draw` painted its standalone district strip behind TownShell's
footer. At 1280x720 its local rectangle was `(16,614,620,36)`, exposing detached
district numbers between navigation buttons. Its standalone heading duplicated
the compact Town header across the scenic center. These are drawn UI, not baked
art or resource balances. Both now obey the existing external-overlay ownership
flag. Standalone previews keep their original summaries; TownShell's existing
Log & Logistics modal displays the same production district/garrison/action
counts. Status plaques, stores, five dialogs, build hotspots and navigation stay.
No art, placement manifest, gameplay rule or save-schema change was made.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `match_route_before_01` reproduces the premature route; `match_route_after_02`
  and `match_route_town_final` pass real animated exit/report, ordinary Quick
  Resolve/report and genuinely unavailable-action controls, with zero engine
  errors. The latter control must still fail the driver. Early fixture/type
  comparison mistakes remain failed harness attempts, not gameplay results.
- `town_overlay_before_720_02` fails 16 of 58 original ownership/Log checks on
  unchanged production, with zero engine errors. The earlier first attempt used
  the wrong unique node name and is not the production reproduction.
- `town_overlay_final_720` and `town_overlay_final_1080`: **64 checks each pass**,
  zero engine errors, using the real Medium09/Large07 opening saves. Cover actual
  footer containment/non-overlap, hidden standalone overlays, all five district
  values retained in a read-only Log, standalone geometry/data, one ordinary
  affordable build and complete production save/resume. Final `after_build.png`
  and `after_build_log.png` at both resolutions were opened and inspected: no
  stray district numbers, duplicate middle heading or clipped Log summary.
  These are opening/one-build captures, not mature-town acceptance.
- `town_overlay_validate_02.log` passes repository validation after its exact
  geometry contract was updated to require conditional ownership; the earlier
  unconditional-geometry assertion failure was retained. `town_overlay_acceptance.log`
  passes all eleven Python full-match acceptance/checkpoint tests.
- `town_overlay_linux_verified`, `town_overlay_windows_verified` and
  `town_overlay_linux_entry_verified` pass serial exports, startup and actual
  generated Overworld/Town entry. PCKs both **248450632 bytes**, **1549368 bytes**
  below the unchanged ceiling. Windows execution is Wine, not native hardware.

In `.artifacts/full_play_runtime_20260905/town_overlay_domains_final`, the existing
dialog/hotspot and field-transfer reports pass. The historical recruitment test
previously read synthetic labels from a closed lazy modal: all 42 tier checks
failed despite the real buttons already containing tiers. The Python runner now
opens Muster before the original assertions and explicitly checks modal state.
`town_overlay_muster_verified` passes all six factions/42 tier controls with zero
engine errors; no original tier, affordability, portrait or tooltip assertion was
removed. An intermediate adapter used the wrong snapshot key (`visible` instead
of `open`), failed only its six added modal checks, and is not accepted evidence.

Final runtime source-tree SHA-256:
`b5491122615a0b0491028a9c4c462713da126a210ca96746015a8fd016249eae`.
Driver SHA-256:
`3ccdad0ba3feb986c5de2d02529886379bd390fdd99aa1184c83cc3a81a21229`.

Still visibly unfinished: individual Town sprites read as separate icons, most
obviously Veilmourn's warm buildings/market floating over water; command-sidebar
text is truncated; the Overworld save-status footer clips. Removing duplicate
overlays does **not** solve those defects or certify Town art integration. The
presentation child, full matches and overall goal remain in progress. No new
matched responsiveness claim is made from these concurrent validation runs.

### Compact commands/footer and first-entry choices

`TownShell` now displays name plus level/XP in two lines, keeping the complete
authoritative hero description in its tooltip. Empty command labels wrap or
ellipsize instead of cutting words without an indication. The Overworld system
frame's decorative chevrons extended beyond its old content inset: horizontal
padding is now 20 pixels, and save status has a 76-pixel minimum. Failure copy is
the concise **Save failed**, retaining the complete explanation and retry action
in the existing tooltips. Save storage, feedback publication and rules are unchanged.

Large08's developed Town also exposed earned choices missing on initial entry.
`TownShell._refresh(true)` already obtains the full cached entity view, but
`_rebuild_current_action_surfaces` skipped both command rows when presentation
was minimal. It now creates commander/specialty controls from those existing
rows on every refresh. Hidden Build/Muster dialogs stay lazy; no new progression,
cache lifetime, rule, art or save-schema change was needed.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `command_layout_before_02`: seven reproduced text/frame failures; the first
  attempt did not exercise hydrated empty-state labels and is not the complete
  reproduction. `command_layout_verified_720` and `_1080`: **58 checks each pass**
  on actual Medium10/Large08 opening saves restored through the production save
  loader. Cover real named-save dialog opening, failure feedback, ordinary paid
  construction, complete-state read-only observations and responsive bounds.
- `command_entry_reference_verified`: the exact `19ebe521` Town script/scene in
  a disposable control reproduces ten missing-command failures, with zero engine
  errors. Current `command_entry_verified_720`/`_1080` pass **124 checks each**:
  actual first-entry controls, two stationed commanders, three offered choices,
  Enter-key selection, exactly one consumed choice/rank gain, switching away and
  back, closed-dialog laziness and complete save/resume. Fixtures explicitly award
  XP through progression and pay the normal hire through the real Town handler;
  they are UI tests, not full-match evidence. Source saves are unchanged.
- `command_entry_art_preserved_720`/`_1080`: the final expanded test passes
  **148 checks each**, retaining the same keyboard/save controls and verifying
  all built IDs survive in the scenic payload and their visible plot mappings
  across entry, choice, commander changes and resume. Final images were inspected;
  this guards building presence, not the quality of scene integration.
- Earlier command-test attempts bypassed scenario restoration, observed a copied
  session instead of the live one, or bypassed the UI cache-invalidation handler.
  They remain failed fixture attempts. The final test requires the production
  restore path and object identity with the actual Town session; it does not hide
  assertion failures or alter production data to accommodate them.
- Final command/Overworld/Town captures at both resolutions were opened and
  inspected. The command rows, five dialogs and navigation fit; the scenic
  building sprites still visibly float over Veilmourn water. This is **not**
  seamless-building-art acceptance.
- `command_entry_named_saves/named_save_files_report.json`: existing real named-
  file tests pass storage, overwrite consent, rollback, external-edit detection,
  keyboard input and all four Save routes. Only fresh artifact paths and the
  recorded validation-only accessibility/backend wrapper differ.
- `command_entry_linux_verified`, `command_entry_windows_verified` and
  `command_entry_linux_entry_verified`: serial exports, startup and generated
  Overworld/Town entry pass. Both PCKs are **248450328 bytes**, **1549672 bytes**
  below the unchanged 250000000-byte ceiling. Windows runtime is Wine, not native
  hardware certification. Runtime source SHA256:
  `a54cc1ef6d49efb4797cea408b9ec5d5e77dd566a140842b0982a558a9c625cd`.
- `command_entry_acceptance.log`: all eleven Python acceptance/checkpoint tests
  pass. `command_entry_validate_final.log` and `git diff --check` pass.

The six existing reports in
`.artifacts/full_play_runtime_20260905/command_layout_domains_final/report.json`
all pass: Town dialog/hotspot matrix, field transfers, 42 live Muster tiers,
generated-opening save failure/retry, save-written and load-resumed feedback.
The Python runner retains the original assertions. Its old save-retry fixture
needed generated identity normalized before the baseline snapshot; the same
failure was reproduced on `19ebe521` in `command_save_failure_baseline`. The load
cue report now observes the actual scene-change/first-drawn-frame boundary instead
of assuming a 260-ms reduced-motion cue survives three arbitrarily slow frames.
Original cue activity, copy/layout, once-only publication, input, bytes/state and
expiry checks remain; no production duration was extended. Earlier concurrent
and serial failures are retained, not reported as passing.

### Current terminal-match audit

Both runs below launched on clean `19ebe521`, runtime SHA256
`b5491122615a0b0491028a9c4c462713da126a210ca96746015a8fd016249eae`,
driver SHA256 `3ccdad0ba3feb986c5de2d02529886379bd390fdd99aa1184c83cc3a81a21229`.
AppRouter preloads the relevant PackedScenes, so later UI-only working-tree edits
did not replace their launch owners. Both are now stopped, not live monitors.

- **Large08: legitimate defeat, accepted bounded Large terminal coverage.**
  Seed `large-runtime-profile-10225`, Large 108x108, four players, normal,
  Veilmourn/Orso, rendered 1920x1080. Day 14, 201 actions, 15 shipped Quick Resolve
  battles and 15 casualty reports, 13 builds, 24 recruitments, eight studies and
  13 End Turns. All 201 capacity observations pass. Opening, Day-8 mid-match and
  terminal save/resume preserve every serialized field. At action 189 the real
  battle captured enemy Mireclaw town `native_h3maped_c2520619_object_2169`;
  this is an enemy-to-player ownership transition, not a screenshot counter or
  merely a neutral claim. The driver then reclaimed a hostile site, defeated
  raid `player_3_raid_5`, and lost to `player_3_raid_6` through real battle/report
  routing. Terminal slot3 and the inspected `final.png` show
  `ScenarioOutcomeShell`, defeat, no primary army and “The primary commander is
  defeated.” No force-outcome, surrender or turn-limit defeat was injected. The
  policy filters visible targets by the existing coarse army-strength estimate
  before attacking; that estimate does not guarantee a combat win. This is not
  tactical/manual coverage, balance approval or exhaustive Large endgame coverage.
- **Medium10: failed diagnostic, not terminal coverage.** Seed `10`, Medium,
  two players, normal Embercourt/Lyra, rendered 1280x720. Day 35, 608 actions,
  three owned towns, 61 builds, 113 recruitments, 47 studies and 11 battles/reports.
  All 608 capacity observations pass; no engine error was logged. It stopped on
  the fourteen-day no-exploration/interaction-progress guard, still in Overworld
  with army strength 13347. The final history repeatedly revisits troop-reward
  site `native_h3maped_93c0f05a_object_1324` despite seven occupied slots, then
  follows a moving raid with the remaining movement. Costs/capacity rejection are
  working; the driver does not yet avoid this known-infeasible reward and keep a
  coherent long route. Diagnose its policy with the exact saved state before any
  gameplay change. A legal matching-checkpoint continuation or fresh complete run
  is still required; do not weaken the no-progress acceptance guard.

Large08 `town_day_014.png` was inspected: 16 built buildings, Spell Tier 4 and
three pending specialties on the old UI. The new command fix addresses that
availability defect. The outcome title still leaks/clips the raw generated
scenario id, and Town scene-matched building layers remain unfinished. The driver
also did not spend earned specialties; that is a legal-policy coverage limitation,
not justification to rewrite the accepted action history.

The two engines were individually identity/ancestry-verified and paused for
119 seconds during a cue-timing isolation attempt, then resumed in a guaranteed
cleanup path. `command_layout_feedback_pause.json` records the exact interval and
PIDs. The older group-pause helper correctly rejected their nonleader wrappers.
Concurrent tests and this pause contaminate their wall timings; retain profile
data as hotspot observations, **not** a matched performance improvement claim.

### Medium guard approach and legal driver policy

The exact unchanged Medium10 Day-35 autosave (SHA-256
`196604fa63145f683f36af4d00f9828a028ef5d63550fabc9ae46f321df5bcbf`)
exposes two separate causes, not an immobile hero or a generation defect:

- Resource `native_h3maped_93c0f05a_object_1324`, Glassbound Eyrie at
  (16,50), entrance (15,50), grants **two different unit types**. The seven-slot
  army correctly rejects it. The test driver repeatedly preferred this nearby
  unclaimable reward, then abandoned partial longer journeys each day.
- Guard `generated_guarded_reward_native_h3maped_93c0f05a_object_1261`
  has a legal approach at (33,57). `OverworldShell._selection_route_tile`
  redirected that tile through the resource's scenic rectangle to (34,58).
  The ordinary route cannot cross surrounding guard interactions to reach that
  interior destination. `_resource_node_at` also gave the approach an unrelated
  resource descriptor. An ordinary northward move off the Eyrie worked: the
  capacity rejection did not trap the hero.

`OverworldShell` now preserves active same-level guard approaches before scenic
shortcuts and uses the existing encounter descriptor. This is separate from
exact-anchor ownership; exact resource entrances and Town-anchor shortcuts remain
intact. Resolved guards and other levels release selection priority. No native
code, terrain, placement, masks, movement/combat rules, troops or save schema
changed. This corrects the earlier overly broad assumption in the exact-target
section that surrounding guard squares never need their own selection priority.

The Python-owned match driver now checks the existing current army admission and
visit-cost authority before choosing recruit rewards, retains a target id across
partial travel only after fresh knowledge/risk/availability/path checks, and
spends earned specialties through normal Town actions. It never claims or hides
the rejected reward, adds capacity or injects experience. Moving target positions
come from today's known record, not retained coordinates. Checkpoint records now
include an exact saved-file hash and driver no-progress/cooldown/intent state;
continuation uses production saved-generated registration. Older incomplete
checkpoint histories are rejected rather than resetting the fourteen-day guard.
These driver changes support playthrough coverage; they are not gameplay fixes
or a completed match.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `medium_policy_guard_before`: unchanged runtime/driver fails precisely the
  infeasible-target, guard-click redirect and descriptor checks; no engine error.
- `medium_guard_route_release`: **40 checks pass**, zero engine errors, source
  save unchanged. Actual projected pointer selects (33,57), ordinary travel
  pauses at (24,49), and the next normal End Turn plus retained target reaches
  battle. Real Quick Resolve and casualty Continue clear that exact guard, retain
  all 661 player troops, and award normal rewards. Town actions then spend four
  earned choices (three saved plus one earned from this battle), perform seven
  normal paid matching-stack recruitments, and save/resume every gameplay field.
  Terrain/source placement/mask geometry stays equal and all armies remain legal.
  Detached controls cover two required free slots, full matching-stack admission,
  changed-army freshness, hidden-target rejection and refreshed moving-target
  coordinates; they do not modify the live saved game.
  `medium_guard_route_complete_driver` repeats all 40 checks while also compiling
  the entire unused full-match entry with project autoloads present. A standalone
  `--check-only` attempt could not resolve autoload `SaveService`; that invocation
  is not a valid project-runtime compile check and is not counted as passing.
- `guard_priority_exact_controls`: **44 checks pass**, including two real artifact
  collections/save-resume, guard resolution/cache invalidation, level boundaries,
  exact resource/support entrances, Town anchors and source geometry.
- `guard_priority_arrival`: all **26** existing generated opening/guard/reward,
  Town-body, roster and primary-action checks pass.
- `guard_priority_battle_handoff`: animated exit, normal Quick Resolve/report and
  genuine-unavailable failure controls pass. The three movement-input/full-route/
  fog reports in `.artifacts/full_play_runtime_20260905/guard_approach_domains`
  pass without suppressed runtime errors.
- **12 Python acceptance tests pass**, including exact-file mutation and missing
  driver-history rejection; repository validation and `git diff --check` pass.
- `guard_route_linux_final`, `guard_route_windows_final` and
  `guard_route_linux_entry` pass exports/startup and actual packaged generated
  Overworld/Town entry. Both PCKs are **248450296 bytes**, 1549704 below the ceiling.
  Windows evidence uses Wine, not physical Windows hardware. The unchanged
  Windows smoke assertions ran with two separate fresh disposable `/dev/shm`
  prefixes, releasing the completed startup prefix before creating the generated
  prefix. Only those test-owned temporary prefixes were removed; packages and
  reports are retained. This avoids retaining another multi-gigabyte Wine copy.

The final approach-selected, guard-resolved and developed-Town screenshots were
opened and inspected at 1280x720. The approach order, route, hero arrival, fog,
roster and controls are visible without clipping/overlap. Existing floating Town
building art remains visibly unfinished; this correction does not claim to fix it.
An initial probe incorrectly expected an empty disabled primary action to contain
a `disabled` key; later admission controls incorrectly treated the two-unit Eyrie
reward as one type, including one probe parse error. Those failed diagnostic
attempts remain retained and are not product defects or passing evidence.

Validated runtime source-tree SHA-256:
`7de32bf57bcd8b0cda4dd4d4fd77f436e6ef6130b3b31e4fe48842159294bfd6`.
Final driver SHA-256:
`a235d8abf65f97001d75a32247e6c10510708475f60d52a11ed85f03055a5abc`.
Medium10 remains failed/nonterminal; Large08 remains its previously audited legal
defeat. Next is a fresh Medium11, not promotion of this isolated Day-35 replay.
Overall goal, full-match acceptance and broader presentation stay in progress.

### Generated outcome identity, same-map retry and bounded feedback

Selected under `ux-generated-full-match-presentation-20260906`, with requirements
recorded before implementation. The unmodified Large08 terminal/opening saves
reproduce four failures: the heading exposes the internal native scenario id,
has no full-name tooltip or intentional ellipsis, and confirmed Retry Skirmish
fails to start. `outcome_flow_before_02/report.json` records those failures with
zero engine errors. This is the actual previously audited defeat, not a newly
fabricated outcome.

Root cause: `ScenarioRules.perform_outcome_action` passed
`native_h3maped_c2520619_skirmish` to the authored-skirmish selector. That runtime
record has no authored availability entry. Generated retry now loads the original
`.amap`/`.ascenario` pair from the saved package boundary, validates both package
hashes, document identities and scenario-to-map reference, then passes those same
already-checked documents through `NativeRandomMapPackageSessionBridge` and the
shared generated-startup finalizer. It verifies the original starting hero and
faction before activating the fresh session. No regeneration, replacement seed,
default-faction fallback, generator/native edits or save/package schema change.
Missing, changed and legacy-without-boundary cases stay on the complete outcome
with a visible explanation and unchanged session/save/progression authority.

The heading uses a legitimate custom scenario name or the existing map-browser
package-stem display rule: this case is **Defeat | Fallow Lantern Fen**, not its
internal id. Stored records/ids stay unchanged. A single-line native ellipsis and
full tooltip keep long names bounded. Failed-action feedback is shown only when
needed. Banner and sidebar minimum-size changes now refit their edge layout after
wrapped text receives its real width; otherwise failed retry or expanded Details
could push the emblem/commands or Save/Menu/Close/Guide below the viewport.

Focused evidence lives in `.artifacts/generated_full_match_quality_20260906/`:

- `outcome_flow_720_final_03`: **128 checks pass**, zero runtime errors. It loads
  the complete saved defeat through production restore/router, checks collapsed
  focus, title/Details/navigation bounds, confirms/cancels the actual retry, enters
  the real fresh Overworld and compares map, hero position/army, towns, resources,
  artifacts, players, original hero and difficulty with the recorded Day-1 save.
  Four separate unavailable/mismatched/legacy fixtures preserve complete state;
  authored-name and custom long-name controls are isolated from match evidence.
  Original terminal/manual saves and campaign progression are unchanged.
- `outcome_flow_1080_final_03`: the same **128 checks pass**, source files
  unchanged, zero runtime errors and process exit 0. Final 720/1080 outcome,
  Details, long-title and unavailable-package views were opened and inspected;
  navigation stays visible and the scenic background remains dominant.
  Earlier 93-check reports lacked expanded-Details/navigation assertions and
  are not final acceptance. One intervening 1080 run printed passing assertions
  but its supervisor ended with signal 143 before writing a final report; it is
  not accepted. A fresh detached supervisor ran the unchanged test and its
  existing 300-second timeout to a complete successful report.
- `.artifacts/full_play_runtime_20260905/outcome_input_release_final`: all three
  existing outcome confirmation, normal-entry/tab focus and autosave recovery
  reports pass. Twelve full-match Python acceptance tests pass.
- `.artifacts/full_play_runtime_20260905/outcome_campaign_release_final`: all
  four campaign completion atomicity, replay preservation, fail-closed storage
  and generated-opening autosave failure/retry reports pass.
- `outcome_linux_release_final` and `outcome_windows_release_final`: standard
  export/startup checks pass; Linux's real rendered packaged generated entry and
  Windows's fresh-prefix packaged generated entry both reach Overworld and Town
  without runtime errors. Both PCKs are **248453080 bytes**, **1546920** below the
  unchanged ceiling. Windows uses Wine, not physical Windows hardware. Native
  code/libraries and package content rules are unchanged. Repository validation
  passes after its obsolete status-tooltip token is updated to require the full
  error text and actual minimum-size refit owners; `git diff --check` passes.

The original source save hashes remain
`f628774c1beb18b2cd6d127e683572f9fa1a38505de77e36b42763745df1e8d2`
(terminal) and
`d2b4a0ef45521f768a6e0b8f23878c5f7e16a92838250068df05fff1f3cd31a9`
(opening). Package files remain
`145f8af5931ab879da58dfd3b1980fa718b997cc400a1e7ece8108b791031050`
(`large-fallow-lantern-fen-4587a983.amap`) and
`b2ac6048139e01c9974c65a28cae2480be94c97be625527c9cb9707949e2d419`
(`.ascenario`). Runtime source-tree SHA-256:
`863dbeb0855ab377f32d0792c93df5d80ca219bf3b4ae1c5caf948ba33a159de`.

Validation compatibility is explicit: the Python-owned existing-report runner
sets logical canvas size as well as OS-window size for old viewport fixtures;
opens actual Details for the legacy expanded-recap matrix; and invokes the
existing explicit fixed-slot compatibility API for its occupied-slot checks.
All original consent, physical cancel/confirm, focus, stale-source, route,
byte/state and progression assertions remain. Those fixed-slot checks are not
claimed as the current named-file Save UI: `outcome_named_saves_final` separately
passes real Save buttons and named-file storage/consent for Overworld, Town,
Battle and Outcome (nine files, zero failures). Only exact deliberately injected
outcome/return autosave domain errors are expected by the report runner.

Failed attempts are retained honestly: one probe parse fixture was corrected;
immediate same-frame test confirmation was changed to wait for the visible
dialog; a wrapped-title variant collapsed its measured height; first feedback
and Details variants exposed real layout overflow. The named-file test first hit
the known Linux AccessKit backend abort and then an obsolete screenshot path;
fresh isolated accessibility-disabled/current-path runs preserve its assertions.
The first disposable Linux export hid installed templates behind XDG isolation;
the next headless generated entry completed but emitted two engine Window signal
disconnect errors. Neither is accepted as a passing full-platform run.

Only disposable save copies created by this turn's four completed failed probes
were removed (about 120 MB); their source saves, reports and screenshots remain.
New package binaries/prefixes use fresh `/dev/shm` directories and are removed
after validation; existing retained packages, caches and unrelated artifacts
are untouched. This checkpoint does not finish Town building-art integration,
the complete Medium match, broader recap copy or full-game release acceptance.
Medium11 continues on its launch commit `983594db` and original driver hash;
its preloaded owners do not validate these subsequent outcome changes. At the
Day-32 checkpoint it has 655/655 legal army observations, 27 actual battles and
five owned towns; it remains nonterminal, not a newly accepted complete match.

### Claim progress observation in the full-match driver

Medium11's real action trace records Trailsinger Boots at serial 855 on Day 40,
Waystone Caches at 857–858 and three more at 875–877 on Day 41. Its Day-41 End
Turn record (860) nevertheless retains `last_progress_day: 38`. The matching
autosave SHA-256 was
`0514da917da4c800e0cb4c0549ad7b0d367b792c3626223d25281d80be2e0ce8`.
The read-only continuation validator accepted that exact saved-file/history
boundary and all 860 capacity observations. This identifies a driver observation
bug, not failed gameplay collection: `perform_target` previously counted only
new exploration, resolved encounters or scene routing. Successful claims on
already explored ground could falsely approach its no-progress deadline.

The Python-owned driver now snapshots category-scoped resource/artifact placement
ids with authoritative `collected` and player-collector state. A newly claimed
identity, including an enemy-held mine reclaimed through ordinary rules, updates
the progress day. Repeated visits, changed visit dates, income, movement, rejected
claims and enemy claims do not. This state is local observation around one order;
there is no new save field, policy score, reward, carrying capacity or cached
eligibility. The existing 14-day diagnostic horizon, terminal/capacity acceptance
and exact continuation history remain unchanged.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `claim_progress_before/report.json`: after extracting the original condition
  unchanged into the testable helper, four real-claim checks fail; zero engine
  errors. This is the reproduced missing observation, not an engine parse failure.
- `claim_progress_after/report.json` and final `claim_progress_final/report.json`:
  **47 checks pass** each, zero engine errors.
  The probe compiles the complete driver and calls actual resource/artifact claim
  rules in explicit isolated fixtures. It covers new/equal-count/category-scoped
  identities, duplicate artifact inventory, mine reclaim, rejected/repeated/enemy
  claims, read-only observations, existing exploration/battle/route criteria and
  a still-expired genuine stall. These fixtures are not accepted match actions.
- All **12** Python acceptance/continuation tests, `python3 tests/validate_repo.py`
  and `git diff --check` pass. New driver SHA-256:
  `fa1696b95b531a18a1ce7db341ac3468e93df0a43f4ccb5fef3a3959c608a632`.

Production source digest remains
`863dbeb0855ab377f32d0792c93df5d80ca219bf3b4ae1c5caf948ba33a159de`.
The existing `outcome_linux_release_final` and `outcome_windows_release_final`
export/startup/generated-entry reports still apply to that unchanged runtime;
both PCKs were 248453080 bytes. No duplicate exports were created for this
driver-only repair. Windows coverage remains Wine, not physical hardware.

Medium11 was not paused, restarted, reloaded or given the new driver. At the
Day-42 observation it has 905/905 legal capacity observations, 30 battles, no
engine errors and no terminal outcome. It keeps launch commit `983594db` and
driver `a235d8abf65f97001d75a32247e6c10510708475f60d52a11ed85f03055a5abc`.
It subsequently completes its real Day-43 mid-match save/resume (serial 908),
with unchanged complete serialized state and 908/908 legal capacity observations.
That exact slot-2 SHA-256 is
`553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59`;
the read-only continuation validator accepts it without resetting progress Day 42.
`medium_match_11/day_043.png` was opened and inspected at 1280x720: active hero,
owned roster, army slots and footer remain visible without control clipping.
This is current Overworld evidence, not new Town-art or full-match acceptance.
The gameplay/presentation/performance children and parent goal remain in progress.
Town scene-matched art scope and removal of superseded test exports/environments
still await owner approval; caches, source saves and unrelated artifacts remain.

### Preserve Town priority without discarded driver path searches

The driver's existing `choose_target` returns the first eligible owned Town
before ranked field candidates, but previously computed every known encounter's
approach paths before reaching that return. On Medium11's unchanged Day-43
slot-2 save, these 15 unused approach computations took about 28 seconds.
`owned_town_management_target` now checks that same priority first, preserving
catalog order, visibility/level, day/failure cooldowns and the existing guard-risk
condition. Ordinary field candidate order, scoring, live intent and path/risk
rules are unchanged. This corrects test orchestration, not a gameplay delay;
Medium11 retains its preloaded launch driver and was not restarted or hotpatched.

Evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `town_priority_before_03/report.json`: the exact prior driver from `db66974e`
  selects Town `native_h3maped_93c0f05a_object_0950` at `(43,40)` in both copies;
  its only failed check is the 15 discarded encounter approaches. All target,
  complete serialized-state, bookkeeping and eligibility controls pass.
- `town_priority_after/report.json`: 57 checks pass with no engine errors.
  Final expanded `town_priority_final_02/report.json` passes **69 checks**, exit
  0, no runtime errors and unchanged source save. Ready-Town selection is 0.168
  ms with zero approach calls versus the reference's 28401.877 ms and 15 calls.
  When all owned Towns are marked managed in the isolated driver history, the
  unchanged real field catalog selects native portal placement `..._0961` at
  `(39,30)` with the same complete target: both methods still perform 15 approach
  calls and take about 28 seconds. That field-search cost has not been removed.
  These are method timings while the separate match runs, not uncontaminated
  game-action or renderer benchmarks.
- Explicit detached catalogs cover already-managed, failed, foreign, wrong-level,
  unseen and strongly guarded Towns, ordinary field fallback and retained intent.
  The guard fixture exercises the production risk predicate. These controlled
  inputs are not accepted match actions or edits to the original save.
- `claim_progress_town_priority/report.json`: **47** real claim/driver controls
  pass, zero engine errors. All **12** Python acceptance tests, repository
  validation and `git diff --check` pass.

The reference driver SHA-256 is
`fa1696b95b531a18a1ce7db341ac3468e93df0a43f4ccb5fef3a3959c608a632`;
the current driver is
`7ab98279b847e4b28f74eeecc577cbcc254e6a05ea086614213b769d89beda25`.
The source save retains SHA-256
`553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59`.
Production digest remains
`863dbeb0855ab377f32d0792c93df5d80ca219bf3b4ae1c5caf948ba33a159de`;
the already-passing `outcome_linux_release_final` and
`outcome_windows_release_final` export/startup/generated-entry reports apply to
that unchanged runtime, with both PCKs 248453080 bytes. No duplicate exports or
new physical-Windows claims accompany this driver-only checkpoint.

Failed fixture attempts remain explicit: the first probe attached its scene to
the wrong parent; the next omitted `kind: guard` from its isolated guard record.
Both were corrected before the accepted baseline. The first expanded final
engine printed 69 passing checks, but its launcher exited with signal 143 before
saving a final report; it is not accepted. The unchanged assertions subsequently
pass under a fresh detached supervisor. The new runner handles TERM through its
existing protected child cleanup. Only that failed test's unused temporary
scripts/save copy (about 7.3 MB) were removed after verifying no process references;
its runtime log, original source save and all unrelated retained files remain.

`medium_match_11/observed_day053.png` was captured from the actual running window
and opened at 1280x720: fog/minimap, owned roster, all seven army slots and the
command/system footer remain visible without control overlap. This is a late
Overworld observation, not Town-art acceptance. The Day-54 checkpoint has
1190/1190 legal army-capacity observations, 39 battles, progress Day 53, zero
runtime errors and no terminal outcome. The goal and all three children remain
in progress; Town-art scope and superseded export/environment cleanup approval
remain outstanding.

## Scenery refresh checkpoint — 2026-09-06

The selected responsiveness child now changes production `OverworldMapView`:
resource claims and other live interaction changes reuse unchanged decorative
and standalone scenery indexes. Complete construction inputs, manifest reload,
state-layer redraw and session/reset boundaries remain authoritative. No art,
placement, native map generation, gameplay rules or save fields change. Root
cause, exact source/save hashes, cold-load overhead and validation are in
`docs/generated-full-match-performance-report.md`, "Overworld scenery-index
reuse"; this is an actual renderer correction, not driver speed attributed to
the game.

The exact old/current owner comparison passes 95 checks on each real Medium and
Large save. Three matched ordinary rendered collection commands per size preserve
complete final states and indexes, with zero decorative rebuild calls instead of
753/1953. Summed command waiting is 12.4%/33.6% lower in these particular repeated
cases; the live match continues concurrently, so these are not whole-game or
isolated-machine results. Inspected before/collected captures are byte-identical
between owners. They also expose a pre-existing stale movement amount in the
owned-hero label, retained here as the next narrow UI refresh defect. This does
not satisfy Town-building integration or broader presentation acceptance.

Fresh Linux/Windows exports, startup and packaged generated-map/Town entry pass;
both PCKs are 248454200 bytes, 1545800 bytes below the unchanged ceiling. Temporary
exports and test environments used RAM and were disposed after validation, while
reports/screenshots and all older artifacts/caches remain. Windows is Wine-only.
The final seven-report sprite/movement/fog/generated-map suite, all 25 real
collection/collision/save checks, 12 Python acceptance tests, repository validation
and diff checks pass. The earlier suite-launcher argument mistakes are recorded
explicitly in the performance report, not counted as completed validation.
The heroes-progress workflow selected and scoped this renderer checkpoint; it
does not mark the parent or children complete.

At the independently observed Day-64 checkpoint, live `medium_match_11` has
1558/1558 valid army-capacity observations, 46 battles and zero runtime errors.
It is still nonterminal on its original preloaded runtime/driver, not silently
upgraded or restarted for this optimization. Large08's legitimate Day-14 defeat
remains the accepted bounded Large outcome. Complete Medium coverage, full-match
responsiveness and scene-matched Town buildings remain unfinished.

## Live commander and navigation refresh — 2026-09-06

The scenery checkpoint's real Medium/Large captures exposed a separate UI defect.
`OverworldShell._refresh_selected_route_preview` requests the map/context-route
phases without the full status phase. That route updated the map and readiness
but not the always-visible hero/status/stockpile or owned-roster tooltips. Against
the exact shell at `e17a4480`, the recorded Medium Day-43 Waystone Cache command
moves `(35,32)` to `(48,29)` and spends movement from 26 to 13, while the old hero
label still says `Move 26/26`. Large08's Day-8 Lens House at `(40,74)` exercises
the adjacent-click variant. These are ordinary feasible commands from unchanged
source saves, not injected coordinates or rewards.

The same physical keyboard/controller controls reproduce a second defect: full
refreshes queued every owned roster button for deletion, losing keyboard focus.
The correction keeps buttons by hero/placement identity, updates their current
art, text, ordering, ownership and pressed state, and removes only absent records.
Town callbacks look up their current owned entrance instead of retaining bound
coordinates. Army controls similarly retain an unchanged complete holder view;
actual stack, holder or active-hero changes still reconfigure it.

The route-only pass now updates the primary commander/status/stockpile, army and
existing hero tooltips without expanding to the full hidden-panel refresh. Full
and incremental refreshes share the same formatting helpers. Generated compact
play skips detailed forecasts; authored/open-drawer play shares one same-state
forecast between the live status and existing readiness/handoff tooltips.
No gameplay, generation, art, placement, save version or rules changed.

`tests/overworld_live_commander_refresh_regression.py` is Python-owned and compares
complete serialized old/current gameplay after actual pointer collection,
configured movement keys, physical controller axes, natural movement exhaustion
and a rejected zero-movement attempt. Complete save/restore compares parsed JSON
without excluding fields; original file hashes and the tested shell hash must
remain unchanged. Membership/order/ownership/entrance boundary mutations are
explicitly detached fixtures after the real commands/save checks; they are never
saved, captured as gameplay or counted as terminal-match progress.

Initial current-state checks passed but visual inspection found that a long hero
name could still ellipsize movement at 720p. The generated card now uses separate
name/movement lines and the existing footer uses three compact day/position/
movement lines. Real font widths/heights must fit; fresh strings alone do not
establish visible correctness. Full names remain in tooltips. Final Medium
720/1080 reports each pass 165 checks; both Large reports pass 161. Their new
captures were opened and inspected, including legible movement, bounded footer,
seven army slots, owned roster, fog/minimap and available controls. The ordinary
River Pass authored control passes 117 checks and its capture was inspected:
the existing mana-first visible card remains unchanged while its complete tooltip,
movement forecast and roster are current. All five final reports total **769
checks**, exit normally with no engine errors, and preserve their source files.
Artifacts are under `.artifacts/generated_full_match_quality_20260906/`:
`commander_medium_720_final`, `commander_medium_1080_final`,
`commander_large_720_final`, `commander_large_1080_final`,
`commander_authored_final`. The 12 Python full-match acceptance tests,
`python3 tests/validate_repo.py` and `git diff --check` also pass. Source-structure
checks retain their ordering/forbidden-full-refresh assertions while recognizing
the extracted shared formatter and same-state forecast argument.

Fresh `commander_linux_final` and `commander_windows_isolated_final` release
exports/startup/generated-map/Town entry pass, with both PCKs **248456120 bytes**,
**1543880 bytes** below the unchanged 250000000-byte ceiling. Windows is Wine,
not physical Windows/GPU evidence. Production digest is
`483403630f1ea7b1eecbb68059cd1ea0cd9f657974d7e6c5c7acd029769933cd`; tested shell
SHA-256 is `3d794c43dcc70578041cfcead1e96db9cce6cea601a95ffe91ce57b4aff30c96`.
Final Linux/Windows binaries and prefixes were disposable RAM-backed validation
outputs; original maps, saves, older artifacts and caches remain intact.

`commander_existing_02` passes the existing owned-roster/vision, physical movement
ownership, full-route movement, fog, field army transfer and End Turn confirmation
reports. Roster evidence is redirected to this fresh directory; assertions are
unchanged. It also retains two **failing** older Town fixtures: the resource-menu
test expects an 80-pixel menu where the current unchanged Town header gives it
92 pixels, and the army report clicks the now-hidden Town bar without opening
its actual dialog. Neither failure is suppressed or counted as a suite pass.
`commander_stockpile_viewport` still fails that Town width after correcting only
its old logical-viewport setup. `commander_stockpile_overworld` and
`commander_army_overworld` run the original affected Overworld cases at their
actual requested logical viewports, preserving all their assertions; both pass.
The latter retains direct rules, complete save and battle-order checks as well.
Town production code did not change in this checkpoint.

The first existing-roster launcher and initial Windows launcher ended with signal
15 after printing successful domain reports. Neither is accepted as completed
validation without a normal supervisor exit and aggregate report. Repeating with
isolated child process groups produces normal final results. The inactive fresh
failed Windows prefix/export directory alone was removed after a process-reference
check (1669091416 logical bytes); no old evidence or caches were deleted. Earlier
probe failures also retain their actual causes: inferred GDScript variable types,
using arrow navigation instead of configured hero keys, assuming adjacent clicks
only select, serializing independently created authored session identities,
JSON key ordering, and normalizing only part of a detached extra-hero fixture.
The corrected test restores one common payload, uses actual configured inputs,
fully normalizes fixtures before observation, and compares complete state.

### Medium11 supervision boundary and exact continuation

The previously live original `medium_match_11` actually ended at its 10800-second
supervision limit: return code 124, 10800.62 seconds, Day 67, final action 1635,
1635/1635 valid army observations, zero engine errors and **no terminal outcome**.
Its generic missing-final-marker acceptance failures are not evidence of illegal
armies or absent historical battles/builds. This remains a failed diagnostic
prefix, not an accepted Medium match.

Before launching `medium_match_11_continuation_01`, the unchanged continuation
checker verified the latest normal Day-67 autosave (7554019 bytes, SHA-256
`c0ac52b668425f01afc88d2ec1a19884704601294b477ed11f223978d81e7f98`) against
recorded successful End Turn action 1613 and complete driver history. All 1613
capacity observations and exact setup/faction/hero/difficulty checks pass. The
22 later original actions are not spliced into the continued history; continuation
replays from that real save. It preserves `last_progress_day=66`, active resource
target `native_h3maped_93c0f05a_object_0966`, failed targets, Town-day history,
waypoint visits and original limits. There is no regenerated map, injected state,
forced defeat or reset of no-progress history.

The new launch records commit `e17a448021be9728c08cd4b48079825d888797e9`, production
digest `548b7bfc61eb325e6de2837368414c27e27244ced9414c60bf57d207050af379` and driver
hash `7ab98279b847e4b28f74eeecc577cbcc254e6a05ea086614213b769d89beda25`.
It is not silently upgraded to this new commander UI while running. It has
independently progressed beyond Day 91, but a real outcome is still required.
Large08's bounded legal defeat remains valid; full-match quality and integrated
Town-building art remain open. The heroes-progress workflow keeps the selected
presentation child and parent in progress rather than closing them on this fix.

A subsequent read-only Day-93 audit identifies a concrete next runtime gap:
`src/gdextension/src/map_package_service.cpp:3107` writes objective kind
`defeat_generated_rivals`, preserved in the saved runtime scenario record.
`ScenarioRules.evaluate_session` only evaluates `victory`/`defeat` arrays and has
no handler for this kind. The unchanged Day-93 save owns all seven Towns and all
73 encounters are in `resolved_encounters`; its rival roster has no active field
placements, yet status remains `in_progress`. This is not evidence that taking
one arbitrary Town or changing a status field would be a valid correction. The
next correctness work must reproduce the exact missing objective evaluation,
preserve controller/team identity and actual surviving forces, and route a real
outcome/save through normal authority without altering generated-map semantics.
