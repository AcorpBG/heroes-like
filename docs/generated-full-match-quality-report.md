# Generated full-match quality: gameplay corrections

2026-09-06. Active Phase 6 parent `quality-generated-full-match-20260906`,
playthrough child `quality-generated-full-match-playthrough-20260906` remains
in progress. The Town overlay checkpoint below is validated; fresh terminal
matches are next. Measured responsiveness improvements remain a validated
checkpoint, not a completed full-match child.
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
