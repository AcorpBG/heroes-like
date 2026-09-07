# Full-match responsiveness — 2026-09-06

Phase 6 child `performance-generated-full-match-actions-20260906`, under
`quality-generated-full-match-20260906`. Requirements:
`docs/generated-full-match-quality-requirements.md`. **In progress**; completed
match evidence is not game-wide performance approval or release readiness.

Earlier command/footer coverage boundary: Large08 reached a real Day-14 defeat after conquest;
Medium10 stopped nonterminal on Day 35. Their 201/608 action capacity traces pass,
but both ran alongside validation and were identity-checked/paused for 119 seconds
during cue isolation (`command_layout_feedback_pause.json`). These profiles are
hotspot observations, not clean comparison timings. The command/footer checkpoint
does not make a new performance claim or change the matched results below.
See `docs/generated-full-match-quality-report.md` for terminal evidence and limits.

2026-09-07 correctness checkpoint: Medium11 now reaches an earned Day-97 victory
through the original checkpoint-proven driver after interpreting the native
`defeat_generated_rivals` contract. The final-owner continuation `_03` takes
389.111 seconds and retains 2426 actions, including its historical prefix; that
wall time includes driver target selection, validation reads and scene settling.
It is **not** a matched player-response benchmark or an additional speedup claim.
All three changed runtime-owner files are identified in the gameplay report.
The 136-check dual-resolution objective/battle/save fixtures and platform smokes
support correctness, not performance acceptance. Existing matched Town/EndTurn/
scenery results below remain bounded to their actual owners and cases. Next:
refresh complete current-build player-action timings from retained Medium/Large
checkpoints, separate driver work from actual input-to-usable time, and fix any
demonstrated remaining dominant runtime owner without skipping work or saves.

## Town orders: implemented

Actual Large Day-20 recruitment clicks, not merely the validation wrapper, took
roughly 8.3 seconds each. `TownShell` repeatedly constructed the same consequence,
catalog and projected-state reads before the order, for its recap and for its
presentation. The pre-existing full-match driver added further validation reads;
that overhead is excluded from this focused player-handler measurement.

`_prepare_order_read_context` now pairs the existing Town/Overworld read scopes
around synchronous preflight, closing both before every authoritative order.
Recap construction and presentation signature reads use independent post-mutation
scopes. All original action categories, rule calls, recaps, cache invalidation,
resolution routing, refresh and presentation remain. No cache survives input,
resource changes or a rule mutation. No autosave, army, price or RNG change.

Evidence root: `.artifacts/generated_full_match_quality_20260906/`. The unchanged
recorded save is `order_baseline_01/input_save.json`, SHA256
`5836ec4a150b3a57c2ae756f303a16b16aaed14a8a1cbea6a94f8a09aeb9bdb6`.
It contains normal Large seed `large-runtime-profile-10225`, four players,
Veilmourn/Orso, and real accumulated development. Three naturally affordable
recruitments use the actual button handler and wait for settled/usable controls.
State snapshots are captured outside timers.

Milliseconds; Linux Godot 4.6.2, headless CPU fixture, three samples per row:

| Run | p50 | p95 / max | Sum |
| --- | ---: | ---: | ---: |
| `order_baseline_01`, before editing | 8323 | 8361 | 24952 |
| `order_scoped_01`, first correction | 4223 | 4294 | 12702 |
| `order_reference_02`, exact old Town script from `e82ba449` | 8353 | 8433 | 25009 |
| `order_scoped_02`, repeat correction | 4204 | 4212 | 12612 |

The repeat pair reduces full control-ready waiting **49.6%**. Every one of four
complete serialized session trees and all recap fields match, including the
initial restored state. No gameplay fields are filtered. This is a matched
three-order result, not a universal speedup; roughly four seconds is still slow.

The controlled rendered pair at actual 1280x720 also passes complete state/recap
equality: `order_rendered_reference` p50 8482 ms, max 8548 ms, sum 25438 ms;
`order_rendered_current` p50 4507 ms, max 4547 ms, sum 13518 ms. Full usable waiting
falls **46.9%**. The current `town_after.png` was visually inspected: no performance
change to the screen composition is claimed. Floating-looking buildings and
stray resource numbers beneath the footer remain presentation-child defects.

Only the verified isolated Medium/Large test engines are paused during controlled
benchmark runs and resumed in protected cleanup. Their interrupted action spans
must not be used as uncontaminated full-match performance data. Ordinary suite
tests do not pause them. The profiler never pauses unrelated Godot processes.

## Validation so far

- `order_scopes_01` and final `order_scopes_final`: six authored faction fixtures, 29 enabled/disabled catalog
  samples, exact consequence/action equivalence, unknown IDs, detached payloads,
  nested/closed scopes, stale affordability rejection, changed stores and real
  recruitment all pass; zero engine errors. These stale-input fixtures are
  isolated tests, not injected progress in the complete matches.
- `order_domains_01`: all nine existing rendered reports pass: recruitment,
  market, study, hiring, transfer, response, specialty, artifact feedback and
  build/muster catalog, including their resolution/motion cases.
  `order_artifact_final_02` repeats artifact feedback after the last helper edit:
  all six commission/stow/equip, two resolutions and motion/missing-icon cases
  pass, save version 9, zero engine errors.
- The prior Town/AI optimization regression initially failed to extract its old
  reference because it predated the level argument. Its reference now disables
  only the optional sight-source input while preserving the current level.
  `order_existing_optimization_corrected.log`: all 36 scenario/faction controls,
  Town preflight and save-context checks pass. AI runtime semantics are unchanged.
- `order_validate_repo_final.log`: repository validation passes on both final
  Town and AI runtime corrections. Final platform results are recorded below.

## End Turn: exact support-radius projection implemented

`turn_baseline_01` restores the same unmodified save and drives three full actual
End Turns through rules, AI, autosave and settled scene routing. It passes with
zero engine errors. Full-action p50 is 9596 ms, p95/max 11958 ms (sum 30755 ms).
The retained AI profiles identify pre-build/post-raid task planning (approximately
2.9–3.0 seconds per turn across the two surviving empires), plus arrival and path
context work, as larger costs than the roughly 110 ms enemy-state normalization.
The isolated read probes narrow this further:

- `ai_navigation_read_probe_01`: context keys take only 2–4 ms; cold local/native
  surface construction costs approximately 150 ms. No speculative key rewrite.
- `ai_planner_read_probe_01`: actual navigation fields take only 4 ms, while
  resource-heavy target projections take 168–560 ms per origin even with warm
  fields. No pathfinding, transit or native-generation change.
- `ai_projection_read_probe_01`: 27 resource scores take 748 ms; their path calls
  total 0.5 ms and guard lookup 21 ms. `_linked_player_town_bonus` invokes
  `OverworldRules.town_logistics_state` for every player town for every resource,
  solely to read `support_radius`. That full report enumerates all sites, threats,
  escorts and deliveries; its radius is just the unchanged logistics-plan value.

`OverworldRules.town_logistics_support_radius` now reads that exact plan with the
same null/empty/uncontrolled-town behavior. `_linked_player_town_bonus` uses it;
nearest-town order, distance, recovery/capital bonuses and scoring remain intact.
The query reads current data every time, with no new cache or invalidation policy.

`ai_radius_02`: **289 checks pass**, including six faction fixtures, exact old
linked-town bonuses and ordered candidate dictionaries, radius boundaries, owner/
role/default changes, ties and the real Large origins; complete sessions remain
unchanged. The reference extracts the four original scoring functions from
`e82ba449` into a disposable probe; no alternate AI policy. The initial attempt
failed engine parsing due to cyclic type inference; an explicit `int` annotation
corrects it, and the passing rerun has zero engine errors.

`turn_radius_01` performs the same three complete real End Turns: p50 **7510 ms**,
max **9028 ms**, sum **23675 ms** versus 30755 ms, **23.0% less full-action waiting**.
All four complete session JSON trees match the original baseline, with no ignored
gameplay fields. Rules, opponents, replans, RNG, autosaves and scene refresh remain.
The independent repeat `turn_radius_02` also passes all four full-state controls:
p50 **7438 ms**, max **8871 ms**, sum **23311 ms**, **24.2% less waiting** than the
same original control. These turns remain multi-second; this is not overall
responsiveness acceptance.
`radius_ai_domains` under `.artifacts/full_play_runtime_20260905/` passes all five
existing memory/live-task/state-preservation/path-reuse/assault-grouping reports.

## Platform checkpoint

`order_linux_export` and `order_windows_export` pass release export, native
sidecar and startup checks. `order_linux_generated` and Windows `generated-flow`
both enter a generated map and player Town; no runtime errors in these flows.
Both PCKs measure **248438472 bytes**, **1561528 bytes** below the unchanged
250000000-byte ceiling. Source masters and unrelated retained reports remain
excluded. Windows execution is Wine, not physical Windows/GPU certification.
No native library or generated-map semantics changed. Repository validation and
`git diff --check` pass; prior unrelated legacy failures remain documented in the
gameplay report and are not reclassified as successes.

## Overworld scenery-index reuse: implemented

`OverworldMapView._rebuild_static_object_indexes` rebuilt all generated decorative
body records whenever resource claims, Town control or encounters changed. Live
Medium11 click profiles spent about 340 ms in object-index construction. The
unchanged recorded Medium Day-43 save contains 753 decorative placements producing
2380 body cells; Large08's Day-8 save has 1953 placements and 6309 cells. These
painted cells do not change merely because the player claims a resource.

The view now retains its three scenery indexes independently of the live Town,
resource, artifact and encounter indexes. Its signature includes session identity,
map dimensions, view level, terrain, complete ordered object records and the
relevant art mappings. Changed scenery invalidates the drawn state layer too;
manifest reload explicitly invalidates even unchanged asset ids. Null/reset,
replacement sessions and forced rebuilds remain supported. The original body
construction loop, source ids, overlap ordering, masks and raster choices are
unchanged. This does not add a session/save cache, alter art or modify generation,
pathing, interaction rules, AI or saves.

`tests/overworld_scenery_index_regression.py` compares all ten complete index
dictionaries against the exact old owner from `ddd8d6ad`, not merely counts or
screenshots. Explicit boundary mutations are detached renderer fixtures, not
actions in an accepted match. Final `scenery_index_medium_release` and
`scenery_index_large_release` each pass **95 checks**, exit 0, zero engine errors
and unchanged source saves. Coverage includes ordinary interaction state,
complete object metadata, terrain, masks, overlap, placement order, manifest
candidate order and reload, standalone mappings, dimensions, level switching,
forced rebuilds, session replacement and null/reset. The original-owner baseline
`scenery_index_before` fails 15 of its 64 checks, exposing wasted rebuilds and
partial-input invalidation. It is retained as a failing diagnostic.

Selected final `set_map_state` timings, milliseconds; single headless comparisons,
not full input latency:

| Saved case / update | Old owner | Current owner |
| --- | ---: | ---: |
| Medium resource claim | 160.397 | 22.642 |
| Medium Town control | 158.093 | 23.479 |
| Medium encounter resolution | 153.119 | 22.796 |
| Medium artifact claim | 151.333 | 24.791 |
| Large resource claim | 444.025 | 53.899 |
| Large Town control | 425.811 | 56.294 |
| Large encounter resolution | 423.390 | 54.842 |
| Large artifact claim | 427.709 | 52.682 |

All eight interaction updates make zero decorative-body construction calls,
versus 753/1953 before. Full-input hashing has a cost: unchanged Medium refresh is
16.430 vs 10.312 ms, Large 39.341 vs 34.046 ms; cold Medium load is 147.195 vs
110.943 ms, Large 458.791 vs 336.448 ms. This is an interaction-refresh optimization,
not a cold-load or idle-rendering improvement.

Rendered controls use ordinary `OverworldShell` pointer-selection/activation
handlers, real visible unguarded claims and settled presentation at 1280x720 with
reduced motion. Both variants restore the same unmodified save. Medium travels
from `(35,32)` to Waystone Cache `native_h3maped_93c0f05a_object_1154` at `(48,29)`;
Large travels from `(41,74)` to Aetherglass Lens House
`native_h3maped_c2520619_object_2308` at `(40,74)`. No coordinates, movement,
resources, fog or battle results are injected. Complete resulting state and all
ten indexes match the old owner; the optimized view makes zero body rebuilds.

Three sequential matched rendered pairs per size (`scenery_movement_medium`,
`_medium_02`, `_medium_03`; `_large_02`, `_large_03`, `_large_04`) pass, with no
engine errors or changed source saves. Full usable-command p50 is **1443 to
1295 ms** on Medium and **1646 to 1058 ms** on Large. Summed waiting across the
three pairs is **12.4%** and **33.6%** lower respectively. These are two specific
resource commands, always reference then current, while the independent live
Medium match continues. They are not randomized-order, isolated-machine or
whole-game benchmarks; no idle FPS, cold-entry or complete-match speedup is
claimed. The repeated no-capture runs avoid storing redundant images.

The retained `scenery_movement_medium` and `scenery_movement_large_02` before and
collected PNGs are byte-identical between owners. Collected views were opened and
visually inspected at both sizes: scenery, fog/minimap, all seven army slots and
the command/system footer are unchanged and remain visible. One existing defect
is now explicit: the owned-hero movement label still displays the opening amount
(26/26 Medium, 15/15 Large) after actual movement becomes 13/26 and 14/15. It
appears in both owners, is not fixed here and needs a separate UI refresh change.
The first Large movement fixture found no eligible hardcoded pickup; it failed
without actions. Adding the existing, visible and claim-feasible Lens House to
the test's candidate list permits the accepted real-action comparison; no game
content or selection rules changed.

Source save hashes remain Medium
`553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59`
and Large `f30453a639d1bae75839292979f05a71b626fb952a20e6eacd0422a9a625545d`.
Old/current view SHA-256:
`dad5b56e605f3965b67448510b3af6e1218e31bb2c132a47835073f5dbf719db` /
`2cffb1dcdbafbd7481ab55f27b19193c076358db8f50ad039c7c9f942a5c4533`.
Current production digest is
`548b7bfc61eb325e6de2837368414c27e27244ced9414c60bf57d207050af379`.

Fresh `scenery_linux_release` and `scenery_windows_release` pass export, native
sidecar and startup checks, plus real packaged generated-map/Town entry
(`generated-entry` and `generated-flow`). Both PCKs are **248454200 bytes**, with
**1545800 bytes** remaining below the unchanged ceiling. Windows execution uses
Wine, not physical Windows. The established checkers/assertions were unchanged;
fresh binaries and isolated user data/Wine prefixes were disposable in RAM under
disk pressure. Logs, reports and visual evidence remain; no older artifacts or
caches were deleted. Identical PNGs from this checkpoint share disk blocks while
retaining all eight filenames and exact bytes.

Existing regression evidence is
`.artifacts/full_play_runtime_20260905/scenery_existing_release_02/report.json`:
**7/7 pass** (distinct map objects, decorative sprites, placeholder-art resolution,
movement input ownership, full-route movement, fog and generated-map profile),
with zero runtime errors. `scenery_consumed_release_02/report.json` passes all
**25** actual collection/collision/save checks, including overlapping scenery,
permanent sites and retained native transit bodies. All **12** full-match Python
acceptance tests, `python3 tests/validate_repo.py` and `git diff --check` pass.
No existing domain assertions were relaxed. The disposable suite launcher first
rejected two names outside its allowlist; its next invocation mistakenly repeated
`--only` and ran just the last report. Neither is treated as seven-report evidence.
The final launcher supplies one `--only` list and retains the complete passing
seven-row report; only temporary user-data locations differ from established
checks. The initial, separately passing collection check is also retained.

## Limits at the earlier scenery checkpoint

Medium `medium_match_07` stopped legitimately as a **failed diagnostic**, not a
terminal outcome, at Day 54: fourteen days without exploration/interaction
progress. Its actions repeatedly revisit artifact targets but land on controlled
resource-site actions; the remaining movement is insufficient to reach the chosen
hostile town. Subsequent source-backed exact-target and guard-approach corrections
are documented in `docs/generated-full-match-quality-report.md`; the failed
prefix remains diagnostic, not retroactive acceptance. Large `large_match_08`
had completed a legal Day-14 defeat after enemy-town conquest, 15 battles
and 201/201 legal capacity observations. Medium `medium_match_11` was still live
on its recorded launch owners; neither that live prefix nor the controlled
three-turn fixture establishes complete-match responsiveness.

Full-match wall time also includes Python-owned driver's synchronous GDScript
policy work. The recorded Medium Day-43 Town choice computed 15 unused encounter
approaches before returning its already-prioritized owned Town (about 28 seconds
in the isolated comparison). This is test-policy overhead, not player movement
latency or idle rendering performance. Driver-only removal and exact-state
controls belong to the gameplay report; do not attribute that gain to the game
or use the concurrently running match's FPS as an uncontaminated renderer score.
The later outcome checkpoint's unchanged-runtime Linux/Windows export and
generated-entry evidence is also identified there; the platform figures above
describe this earlier responsiveness checkpoint, not the newest package.

Complete Medium/Large terminal outcomes, selected presentation corrections and
final both-platform validation are requirements of the parent goal. See
`docs/generated-full-match-quality-report.md` for gameplay fixes and explicitly
retained unrelated legacy failures.

## Commander refresh follow-up

The scenery comparison exposed stale player-visible movement/stockpile text and
full-refresh roster focus loss. `OverworldShell` now refreshes those small current
surfaces on route-only requests, preserves unchanged roster/army-control nodes,
and shares one detailed forecast across authored status/readiness tooltips.
Generated compact movement still skips detailed forecasts and hidden panels.
Exact prior-shell gameplay/save, actual input, focus and visible-text tests are
recorded in the gameplay report. No standalone HUD or whole-game timing gain is
claimed from this correction; the independent live match and validation workers
ran concurrently. Its fresh Linux/Windows PCKs are 248456120 bytes.

The original Medium11 did not complete: its actual three-hour supervision limit
ended nonterminal on Day 67. Its hash/history-verified normal autosave continuation
is separate provenance, not a timing reset or accepted outcome. Read-only Day-93
inspection found the generated objective kind had no live evaluator, despite all
Town ownership and encounter resolution. Commit `f7db06e8` subsequently corrected
that runtime interpretation. Exact-checkpoint Medium continuation now reaches
earned Day-97 victory and complete terminal save/resume; the playthrough child
is completed. Its proof and limits remain in the gameplay report, not a new
whole-game performance claim.

## Shared internal logistics reads — 2026-09-07

Current child: `performance-generated-full-match-actions-20260906`, still
in progress. Production changes are confined to `OverworldRules.gd` and the
demonstrated menu lifecycle error described below. No art, native generation,
content, balance, save version, action ordering or autosave policy changes.

### Root cause and behavior

`TownShell` already bounds preflight, recap, refresh and presentation reads with
synchronous scopes. However, `town_logistics_state` cached only its public
entry. Internal development, recovery and front calculations called
`_town_logistics_state` directly, repeatedly enumerating all resource sites.
The same cache now belongs to that shared private entry. Its full-town key
separates projected building previews and now includes runtime object identity
to separate live and historical snapshots sharing a persisted session id.
Cache results remain detached;
the cache is discarded at the same scope boundary. No scope crosses a gameplay
mutation or gains a longer lifetime. Unscoped rules still calculate from current
state on every call. The extracted `_compute_town_logistics_state` calculation
body is byte-identical to the old private calculation at `f7db06e8`.

The rendered Large Day-8 baseline's first recruit spent 572.748 ms constructing
the recap, 591.132 ms constructing presentation consequences and 1188.074 ms
refreshing Town. On the final owner those inclusive readings are 103.524,
106.265 and 556.880 ms. These nested buckets explain the fix; they must not be summed as
independent full-action latency.

### Matched current-build actions

All timings below used Godot 4.6.2 on Linux 6.8.0-111-generic. Town captures are
1280x720 rendered llvmpipe with accessibility explicitly disabled; End Turn is
headless CPU/rules/save/scene settlement, not a rendered frame-latency result.
These action benchmarks ran serially without another validation engine. Three
ordinary actions per case include callback completion, animation/input blocker
settlement and usable controls; policy selection and full-state serialization
are outside that timed interval. Every before/after case preserves all four
complete session JSON trees, action/day identity and the exact source save.
Recruitment also preserves every recap field.

| Case | Before p50 / p95-max (ms) | After p50 / p95-max (ms) | Before / after total (ms) |
| --- | ---: | ---: | ---: |
| Large Day-8 recruitment | 3950.583 / 4024.117 | 1914.935 / 1931.266 | 11853.324 / 5752.976 |
| Medium Day-43 recruitment | 1497.282 / 1513.505 | 1180.369 / 1193.005 | 4412.622 / 3508.756 |
| Large Day-8 three End Turns | 8675.236 / 8886.774 | 8603.749 / 8767.143 | 25758.310 / 25303.556 |

The selected final recruitment totals improve **51.5% Large / 20.5% Medium**. This is
one matched three-action sample per size, not a broad hardware confidence
interval. End Turn is effectively unchanged; its 1.8% aggregate difference is
not a meaningful speed claim. The Large baseline still spends roughly 5.2–6.3
seconds in actual turn rules and 1.6–2.4 seconds in autosave. Those owners and
broader loop responsiveness remain open; nothing was deferred or skipped.

Retained evidence under `.artifacts/generated_full_match_quality_20260906/`:

- `loop_refresh_town_large_before` → `logistics_town_large_release`.
- `logistics_town_medium_before` → `logistics_town_medium_release`.
- `loop_refresh_turn_large_before` → `logistics_turn_large_release`.
- Each case has `report.json`, exact `input_save.json`, four complete state
  files and runtime/profile logs. Rendered Town cases also have inspected
  `town_before.png` / `town_after.png` captures.

Large input is the actual `large_match_08` Day-8 slot2, SHA256
`f30453a639d1bae75839292979f05a71b626fb952a20e6eacd0422a9a625545d`;
Medium is actual `medium_match_11` Day-43 slot2, SHA256
`553ceb3ea972412cd72341ff627fa73c6864f9bcbfb6cc428923ebec5712de59`.
Both full-match histories remain unchanged. Baselines use production tree
`e354b91fbee615d76bdbe5a0dcc92655a8cbb8859f2074d7b4ea11e4f3af1ec1`
at `f7db06e8`. Final tested production tree is
`70f0652f3f1dd209e79066f0f4825b40e90a23ffec7e56130e45078f8c8b452e`;
current `OverworldRules.gd` SHA256 is
`06f1c8a85df48e4ece35238b9cfb925f4d4d9d42f6f30fc8758f9c19b3610363`.
The tree uses the complete-match runner's sorted runtime source/content hashing
method. TownShell itself is unchanged; its per-run script hash alone does not
identify the changed core owner. The final Town profiler also captures relevant
core/menu owner hashes at launch. Earlier `*_after` timing pairs used intermediate
tree `e619bd7d0b26e617cf5ba96106f2c70222fbb6186e4e549d6707cf0dc8f73325`
before the historical-snapshot identity guard (53.9%/17.9% recruit improvements).
Those intermediate results remain retained, not substituted for final-owner
measurements.

### Focused proof and discovered menu error

`tests/town_logistics_read_scope_regression.py` extracts the exact old calculation
from `f7db06e8`, rather than comparing two aliases of the new cached calculation.
The old code fails seven positive private-cache-use checks while all full result
comparisons pass (`logistics_scope_before_02`). Strengthened tests then reproduce
twelve stale-result failures for a historical snapshot with the same session id
and town but changed linked-site ownership (`logistics_nested_before`). Runtime
object identity in scope keys corrects that collision without changing saves.
Final code passes 1264 checks with real Large and 1201 with real Medium
(`logistics_scope_large_verified`, `logistics_scope_medium_verified`), each
including six-faction authored controls, detached results, projected-town keys,
actual linked-site controller changes, escort expiry, nested historical reads,
outer-scope preservation/reset and same-id restored-object replacement. The original
failed probe (`logistics_scope_before`) had an incorrect test-only static call
to `SessionData.from_dict`; it was stopped and retained, then repaired before
the valid failing production control. It is not evidence of a game parse error.
`logistics_order_scopes_release` also passes the existing six-faction, 29-action
preflight/freshness/success/rejection scope report.

The rendered authored full-play baseline reaches all 51 gameplay checkpoints,
including victory and resume, but **fails validation** with
`MainMenu._refresh_stage_accessibility: get_tree / data.tree is null` during
launch. A deferred callback can start after the menu leaves the tree; testing
the returned tree for null is too late because `get_tree()` already logs an
engine error. The menu now checks membership before that call and retains the
existing post-frame membership check and all live accessibility refreshes.
`tests/menu_stage_accessibility_lifecycle_regression.py` reproduces two original
errors and passes after the correction, covering before-entry, live settings
focus, removal during the frame wait and a deferred call after removal.
Artifacts: `logistics_menu_before` and `logistics_menu_after`.

The repository source assertion now explicitly requires both ordered guards,
instead of matching the first bare `return`; none of its hierarchy/refresh/frame
requirements were removed. The initial failed repository log is retained as
`logistics_validate_repo.log`; `logistics_validate_repo_02.log` passes. The suite
launcher adds three existing Town response/capital/development reports without
altering their assertions. Twelve complete-match Python acceptance tests pass.

### Integrated validation and retained limits

The final `logistics_full_play_release` run under
`.artifacts/full_play_runtime_20260905/` passes all 51 authored menu/Overworld/
Town/tactical-battle/Quick-Resolve/casualty/outcome/save/resume checkpoints with
zero runtime errors. Its `matched_control_report.json` compares **50 complete
session trees** against the pre-change run, all equal, plus all ordered identities
for 17 battle refreshes, seven battle entries, ten Town refreshes, three End Turns
and 37 movement events. The first Main Menu checkpoint has no active session.
The earlier `logistics_full_play_after` comparator mistakenly requested 51 state
files; its failed count assertion is retained alongside the corrected 50-state
comparison. Neither final nor intermediate full-play timing ratios are accepted
performance gains: independent functional suites/export checks ran concurrently.
The isolated action measurements above are the performance evidence.

Eight existing focused reports pass on final code in `logistics_domains_release`:
Town layout/five dialogs, recruitment UI, recruitment cue, route-response dispatch,
capital identity, live AI task execution, End Turn confirmation and deferred save
summary payloads. The earlier complete ten-report sweep
`logistics_domains_isolated` is **8/10**, not all-pass. Both failures are the known
Moonbite Reedshrine 30-turn development deadline. All 32 Town rare-build
save/resumes, same-day guards and resume targets pass; 31/32 meet the deadline.
The separate development matrix passes all 224 seven-tier recruit cases but
fails that same town deadline. Its source owner during the long save matrix was
the intermediate cache implementation; final-owner proof for the failing cases
is independent below, not a claim that the entire long matrix was rerun.

`tests/town_logistics_legacy_balance_control.py` runs the unchanged Moonbite case
with the exact `f7db06e8` Overworld owner and final owner in disposable plain
projects, sharing existing art/imports/native libraries. Every consumer resolves
the selected owner at the real resource path; this is not a subclass whose
nested calls accidentally use current rules. `logistics_balance_owner_control`
and `logistics_development_owner_control` both produce identical complete old/new
reports, with preserved successful save/recruitment guards and the original
deadline failure. These controls establish a pre-existing content-budget limit,
**not** a passing development gate or permission to change balance. The old
diagnostic artifact is no longer present at its recorded path; current controls
replace reliance on its historical documentation.

The first ten-report supervisor (`logistics_domains_after`) exited 143 before a
final report while its test engine remained active. That exact orphaned process
group was stopped and the failed log retained. The suite was rerun with
`setsid --wait`; the isolated results above are authoritative. No test assertion
or runtime-error filter was relaxed to accept that attempt. A Python discovery
attempt with an absent `test_full_play*.py` pattern ran zero tests; it is not
test evidence. The actual complete-match acceptance module passes 12 tests.

Fresh `logistics_linux_release` and `logistics_windows_release` exports/startup/
generated-map-to-Town entry pass, including Windows native DLL loading under
Wine. Both PCKs are **248460992 bytes**, **1539008 bytes** below the unchanged
250000000-byte ceiling. The established package checkers run unchanged through
the retained RAM-backed disposable-export wrapper; only its own temporary files
are removed. Windows generated entry is headless Wine, not physical Windows/GPU
certification. Final repository validation is in
`logistics_validate_repo_release.log`; `git diff --check` also passes.

Inspected final 1280x720 Town captures, battle casualties and resumed outcome,
plus the packaged 1920x1080 Town entry, preserve controls and current statistics.
They still show the detached building sprites clearly. Seamless Town integration,
the Moonbite content limit and broader action/End-Turn responsiveness remain open.
The Phase 6 performance child and parent goal are not completed by this checkpoint.
