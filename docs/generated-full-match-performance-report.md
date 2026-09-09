# Full-match responsiveness — 2026-09-06

Current disposition, 2026-09-09: the completed responsiveness child's source
owners remain unchanged through the all-faction presentation boundary. The
selected parent and presentation child are now complete; see
`docs/generated-full-match-quality-completion.md`. The dated measurements and
limits below remain unchanged, including approximately 7.4-second Large turns.

Phase 6 child `performance-generated-full-match-actions-20260906`, under
`quality-generated-full-match-20260906`. Requirements:
`docs/generated-full-match-quality-requirements.md`. **Completed for the selected
responsiveness criteria** on 2026-09-07; the final audit is below. Earlier
in-progress checkpoint notes remain historical. This is not game-wide latency
approval, presentation completion or release readiness.

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

## Request-local AI path preparation — 2026-09-07

Child `performance-generated-full-match-actions-20260906` remains in progress.
This checkpoint removes repeated reads in `EnemyAdventureRules.gd` and
`OverworldRules._native_passage_endpoint_safety`. It does not change pathing,
native generation, terrain rules, AI policy, art, balance, save schema or the save
writer. The original complete Medium victory/Large defeat evidence is unchanged.

### Measured cause and implementation

One path-context request computed identical world fingerprints twice on a warm
hit, three times for a cold one-level native map, and four for two levels. It now
computes the same base key once and derives the unchanged level suffix. Existing
cache keys, capacities and lifetimes remain unchanged; direct private entry
points still compute their own fresh identities. There is no new cross-request
fingerprint cache.

The old Large terrain scan repeatedly resolved the same terrain definitions for
all 11664 cells, taking roughly 47–55 ms. A scan-local dictionary now calls the
same authoritative passability rule once per raw terrain id. The result is
discarded on return; aliases, unknown ids and future separate scans retain their
original behavior. The actual three-turn diagnostic sees eight terrain ids per
scan. Query-level timings are explanatory, not full-action performance claims.

The same Large save has 24 native portals. Real End Turns perform 340/440/336
entrance safety checks; the middle turn spent 771.043 ms in that inclusive owner
and 1363.493 ms in 43 total blocker-index builds. Some safety checks rebuilt the
strict actor-excluded index already computed by the local AI path surface.
That exact index is now copied **before** any observer-specific doorway/body
removal and shared by level only within the synchronous request. If the local
surface was cached, the safety check builds its own strict index lazily. It is
not stored in either path cache. Guard, terrain, army, hero, town, resource and
artifact rejection logic remains unchanged; direct callers without the optional
request-owned indexes retain an independent calculation. In particular, the
doorway-cleared movement mask is never accepted as an entrance safety mask.

### Complete rendered End Turns

Both pairs execute three ordinary End Turns from unchanged actual saves, including
confirmation, AI, full autosaves, scene settlement and usable controls. All four
complete session JSON trees match each original control with no excluded gameplay
fields. State capture and screenshots are outside the timed interval. Runs were
serial without another test engine; Godot 4.6.2, Linux, X11, llvmpipe LLVM 20.1.2,
actual 1280x720 and accessibility disabled. This is one three-action sample per
size, not hardware certification or a confidence interval.

| Case | Before p50 / p95-max (ms) | Current p50 / p95-max (ms) | Before / current total (ms) |
| --- | ---: | ---: | ---: |
| Large Day 8–11 | 8784.296 / 9239.056 | 7830.387 / 7890.240 | 26321.787 / 23012.062 |
| Medium Day 43–46 | 3531.854 / 3719.006 | 3340.381 / 3610.815 | 10510.694 / 10185.168 |

Large total waiting falls **12.6%**; Medium's **3.1%** difference is not accepted as
a meaningful speed improvement. **Both runs miss the harness's unchanged 15%
full-action speed gate and therefore have `ok: false` / supervisor exit 1**, even
though their engines exit zero, all gameplay-state comparisons pass and no
runtime errors occur. These failed performance gates are retained, not relabeled
as passes. The earlier fingerprint/terrain-only Large version improved 8.6% and
also failed that gate. The current Large rule work still takes 4.26–4.84 seconds,
autosave 1.60–2.39 seconds, plus callback preparation and scene/input settlement.
Responsiveness acceptance is unfinished; do not describe End Turn as fixed.

All `path_keys_*` labels below are under
`.artifacts/generated_full_match_quality_20260906/` unless another root is given:

- `path_keys_turn_large_before` → `path_keys_turn_large_shared_after`.
- `path_keys_turn_medium_rendered_before` → `path_keys_turn_medium_after`.
- `path_keys_turn_large_after`: intermediate 8.6% result.
- `path_keys_turn_large_diagnostic` and `path_keys_turn_large_endpoint_diagnostic`:
  instrumented actual turns, each with all four complete states equal. Diagnostic
  counters run in disposable plain projects sharing art/imports, never in shipped
  scripts. Their timings are not rendered speed evidence.
- `path_keys_turn_medium_before`: older headless control, not mixed into the
  rendered timing pair. The first requested 1920x1080 Medium control was clamped
  by the small virtual display to **1280x720**; its actual backend is recorded and
  that is the resolution used above. The runner now provides a larger virtual
  display and fails if actual rendered dimensions differ from the request.

Inputs retain the exact Day-8/Day-43 hashes documented in the preceding section.
Original owners are commit `65fb7fcb6ccd5f9bb017c185c82e161e7216ad87`.
Current `EnemyAdventureRules.gd` SHA256:
`36c93abf4a7c081834103aefe99b38bee426c1b347a5b92f584806dab968f0e5`;
current `OverworldRules.gd` SHA256:
`6588c9c6b1e7216c337df8cff7d3d06291682ca72d4c2cc9707ebe0225c39c09`.
`SaveService.gd` remains unchanged at
`a19fe021dcfbf6bcf3cd3a251d467c3e9540404431ae6d8efe0d7de4529da95f`.

### Correctness and integration evidence

`tests/ai_path_context_read_regression.py` loads complete independent old/current
AI and Overworld owners. Both real Medium and Large cases pass **1023 checks**
(`path_keys_shared_medium_verified`, `path_keys_shared_large_verified`), including
six authored factions; cold/warm/direct reads; actor/controller/day/consumption/
army/hero changes; exact cache keys, every mask/link/field and complete state;
all catalog terrain ids, aliases, unknown ids, malformed rows and later scans;
reciprocal two-level travel; an actor occupying a doorway; overlapping blockers;
and invalid contracts. Positive counts prove one fingerprint per request and at
most one strict actor-excluded index per level. The doorway fixture reduces three
old index constructions to two while preserving both accepted travel and rejected
overlap. No new strict index appears in the cached output.

`path_keys_probe_before` reproduces 60 duplicate-fingerprint failures on original
code with no gameplay mismatches. An intermediate expanded test populated only
the current fixture's cross-level distance cache, causing four comparison failures
(`path_keys_probe_after`). Correcting that test to populate each independent
owner's own context produces the passing final proof; it was not a runtime bug.

Thirteen existing AI/path/movement/fog/End-Turn/transactional-save reports pass in
`.artifacts/full_play_runtime_20260905/path_keys_domains/report.json`. Expected
autosave-failure injections remain explicitly classified by their existing exact
prefixes, not suppressed as arbitrary engine errors. Under
`.artifacts/rmg_start_audit_20260905/`, `path_keys_native_caves` passes all eight
reciprocal trips, source-adjacency/player/AI/safety/save checks and inspected
surface/underground captures.

The first `path_keys_native_large_portals` report passes gameplay but fails its
legacy source-comparison helper: the helper stripped `native_transit` from new
objects even when current saved source rows contained it. Direct comparison
finds **no differences in any complete source object**; terrain and map/player
identity also match. The helper now omits additive identity/transit fields only
when absent from that particular historical reference. Current saved sidecars
must match in full. Three new current/legacy/mixed/mutated-reference tests retain
all older assertions; twelve transit-validation Python tests pass. The original
failed report remains retained. This is validation compatibility, not a native
generation or transit-contract change.

The fresh `path_keys_native_large_portals_verified` report passes all three source
controls, 24 valid portal records, both present portal-shape representatives
(`45:1`, `43:2`), real AI approaches/advance, exact travel and production saves.
This is explicitly representative-shape gameplay coverage, not every portal
endpoint/destination journey. No source changed during validation.

`path_keys_turn_large_final_diagnostic` preserves all four complete states and
exactly the same 340/440/336 safety calls. Strict blocker-index constructions fall
from 21/43/25 to 19/25/17. Counts establish eliminated repetition without omitted
checks. Its headless timings overlap platform validation and cannot pass the
rendered speed gate, regardless of its numeric ratio. The runner now records
`functional_ok` and the speed gate separately and refuses instrumented speed
acceptance; it does not lower the unchanged 0.85 maximum ratio.

`.artifacts/full_play_runtime_20260905/path_keys_full_play` passes all 51 authored
menu/movement/Town/tactical-battle/Quick-Resolve/casualty/victory/save/resume
checkpoints with zero runtime errors. `matched_control_report.json` compares all
50 complete session trees against `logistics_full_play_release`, all equal, plus
the same 17 battle refresh, seven battle entry, ten Town refresh, three End Turn
and 37 movement identities. Functional suites and exports ran concurrently;
these full-play timing ratios are not accepted speed evidence. Its recorded HEAD
is the pre-commit base; the tested runtime owners are the hashes above, unchanged
through final platform validation. Inspected casualty and resumed-victory images
retain the correct losses, surviving armies, results and usable controls.

`path_keys_linux_release` and `path_keys_windows_release` pass fresh exports,
startup and generated-map-to-owned-Town entry, including the Windows native DLL
under Wine. Both PCKs are **248463808 bytes**, **1536192 bytes** below the unchanged
250000000-byte ceiling. The existing package checkers run unchanged through the
RAM-backed disposable-output wrapper; retained reports/screenshots remain on disk.
Only that wrapper's own temporary outputs were removed. Windows Wine/headless
entry is not physical Windows/GPU certification. The inspected packaged Linux
1920x1080 Town still visibly has detached building sprites: Town integration is
not fixed by this checkpoint.

The 12 full-match Python acceptance tests and 12 transit-validation tests pass.
`path_keys_validate_repo.log` and `path_keys_validate_repo_final_source.log` pass
repository validation. `path_keys_validate_repo_tracking_final.log` also passes
after checkpoint tracking is updated; PLAN synchronization reports zero missing
slice ids, the active queue remains one in-progress child, and `git diff --check`
passes. The performance child and parent remain explicitly in progress.

`path_keys_medium_1080_verified` passes three actual rendered turns at
**1920x1080**, with the same four complete states as the 1280x720 control. Its
backend mismatch correctly prevents a speed claim. The final 1280x720 Large and
1920x1080 Medium captures were visually inspected: commands, roster and minimap
remain available and unclipped. Hard terrain seams and thin rectangular artifacts
around some Medium-map props still warrant presentation investigation; this is
not visual-polish acceptance.

Reproduction commands (fresh labels, exact saves listed above):

```text
python3 -B tests/ai_path_context_read_regression.py --label <fresh> --save <medium-or-large-save> --require-key-once
python3 -B tests/generated_end_turn_profile.py --label <fresh> --save <exact-save> --rendered --compare <matching-control>
python3 -B tests/generated_end_turn_profile.py --label <fresh> --save <large-save> --instrument-ai-path-reads --compare <control>
python3 -B tools/rmg_native_transit_validation.py --label <fresh> --render --resolution 1280x720
python3 -B tools/rmg_native_transit_validation.py --label <fresh> --portal-case large_profile --representatives-only --baseline-session <large-save>
python3 -B tests/full_play_runtime_profile.py --label <fresh> --flow skirmish --resolution 1280x720 --accessibility disabled
python3 -B tests/full_play_profile_compare.py <full-play-control> <full-play-current> --expected-states 50
python3 -B tests/validate_repo.py
python3 -B tests/packaging_linux_export_smoke.py
python3 -B tests/packaging_windows_export_smoke.py
git diff --check
```

Next measured candidates remain complete End Turn AI/save work and repeated saved
resume-recap reads. This full-play run records 137 in-session save-surface builds,
47.558 seconds inclusive, including 34.422 seconds in stored resume recaps. Those
are cumulative nested UI timings, not one action or a claim that save writes take
that long. Any next optimization must preserve every displayed value, external
file freshness, normalization, transaction safety and complete saves. The broader
goal, 15% End Turn gate, seamless Town integration, known Moonbite development
deadline and release/hardware certification remain open.

## Verified stored-summary recap reuse — 2026-09-07

Current child: `performance-generated-full-match-actions-20260906`, still in
progress. This is a SaveService presentation-read optimization, not faster AI,
a different save format, omitted normalization or a completed quality goal.

### Cause and bounded implementation

The clean, serial rendered `recap_cache_full_play_before` control completes all
51 menu-to-victory/manual-save/resume steps on `cdda0ba6`. Its 137 save-surface
builds spend 47.521 seconds inclusive, including 34.662 seconds reconstructing
stored resume recaps. This is cumulative UI work, not one save-write delay.
The existing slot cache retains inspected summaries but repeatedly normalizes
their unchanged worlds and rebuilds risk/progress context for the same text.

`SaveService.gd` now retains derived recap text privately on that existing cache
entry. Reuse requires complete equality with its inspected summary, the same
file-signature verification already used by summary reads, and the current
`ContentService` revision. Reloading authored content or registering/removing/
clearing transient drafts changes the revision. Replacing, invalidating or
clearing the slot entry drops the derived value. No extra world copy or new
unbounded cache is retained. Public summary dictionaries and saved payloads are
unchanged; named/large deferred summaries keep the old early-return path without
an extra file hash. Changed or uncached caller dictionaries still perform the
original full calculation and cannot contaminate the canonical entry.

The existing signature policy is unchanged: existence, modified time and size
for legacy slots, plus actual-byte SHA256 for named saves. This does not claim
to fix same-size/same-timestamp external edits of legacy slot files, nor the
pre-existing distinction between runtime-created and disk-created summary detail.
The writer, recovery/rollback, full saves, live recap reads, gameplay state,
native generation, art and save schema are untouched.

### Focused control development

`tests/save_stored_recap_regression.py` loads complete independent old/current
SaveService scripts; wrappers only count context materialization. The first
control mixed a runtime-created old summary with a disk-created current summary
even though both scripts were identical. That invalid oracle is retained as
`recap_cache_probe_before`, not attributed to a runtime regression. Aligning both
owners on the same cold disk inspection leaves only 38 expected redundant-work
failures (`recap_cache_probe_before_aligned`); all text/state comparisons pass.

The first implementation leaves one test count wrong after discarding a corrupt
candidate: recovery correctly preserves the exact live file and its valid cache,
so reuse is appropriate. The corrected assertion additionally proves unchanged
live bytes. That intermediate report remains `recap_cache_probe_after`. The
subsequent real Medium check passes 522 checks with exact public recap/surface
and full-state equality. Final coverage adds a genuinely changed authored
objective label and requires the visible next decision to change and restore.

The strengthened probe's first launch (`recap_cache_large_final`) had a missing
explicit type in test-only GDScript. Its verified isolated engine was stopped,
the declaration corrected, and the failed report retained. Final focused runs
`recap_cache_large_content_verified` and `recap_cache_medium_content_verified`
pass 542 and 544 checks respectively, with no runtime errors. They include six
factions, detached Town/Battle/Outcome states, complete live save surfaces,
changed payloads, reset/replacement/deletion, genuine content-label changes,
transient draft changes, same-size named-file edits, transaction artifacts and
the actual Large Day-8/Medium Day-43 saves. These detached display fixtures are
not claimed as played battles or generated terminal outcomes.

### Matched rendered full play

`recap_cache_full_play_before` and `recap_cache_full_play_after` under
`.artifacts/full_play_runtime_20260905/` are serial, uncontended test-engine runs:
Godot 4.6.2, Linux/X11 software rendering, 1280x720, accessibility disabled,
identical deterministic session identity, legal actions and instrumentation.
Both complete all 51 checkpoints; `matched_control_report.json` proves all 50
complete session trees and all ordered movement/battle/Town/turn identities equal.
Neither log has script/native errors or leaked-RID messages.

| Measured span | Before | After |
| --- | ---: | ---: |
| Save-surface reads | 137 | 137 |
| Stored contexts constructed | 181 | 20, plus 161 exact text reuses |
| Stored recap work, cumulative | 34661.679 ms | 3842.586 ms |
| Whole save-surface work, cumulative | 47520.904 ms | 15098.184 ms |
| Save-surface p50 / p95 / maximum | 347.829 / 772.401 / 976.977 ms | 59.290 / 405.168 / 1004.818 ms |
| Complete scripted flow duration | 309261 ms | 270769 ms |

Stored recap work drops 88.9%; total save-surface work drops 68.2%. The complete
flow is 12.4% shorter in this one pair, including the same animations, saves,
capture points and scene waits. This is not a hardware-independent percentage or
statistical confidence claim. Nested spans must not be summed as wall time.
The worst cold save-surface read remains about one second. Other equal-identity
events are essentially unchanged: movement -2.0%, battle refresh/entry, Town
refresh and End Turn roughly +1.0–1.1%. This optimization helps summary-heavy
menu/outcome reads; it does not establish faster movement, battles or Large AI.

Final production sources throughout the after/full-domain runs:
`SaveService.gd` SHA256 `036bed3c5bf3f857d7ba36814b854d8e6007370985fe19c36062e95f90a9d2bf`;
`ContentService.gd` `dd7dbd54f0806fa1ff6f4553fe1bb8bc2d93619789fe1b38c1b934b60ac73932`.
The before owner's hashes are recorded by the focused reports. Both full-play
reports name the pre-commit HEAD `cdda0ba6`; only the after uses these changed
source hashes. No runtime source changed during either run.

### Integrated validation and remaining work

Ten affected save/transaction/failure-route/campaign/casualty domain reports pass
in `recap_cache_domains/report.json`; the exact expected injected write-failure
messages remain classified separately from unexpected errors. The existing
generated-Large explicit-save matrix also passes in
`recap_cache_large_surface_verified/report.json`. Its initial failure is retained
in `recap_cache_large_surface_before`: the old test incorrectly treated the two
new derived-text fields as immutable storage authority. The Python suite adapter
validates their shape, excludes only those fields from four canonical-authority
snapshots, and retains every original summary/file/session/transaction assertion.
Its distinct-slot case now requires exactly one context build, three context
consumers and one text-cache hit. No counter is fabricated and no gameplay/save
assertion is waived. The complete old-owner focused tests independently compare
the actual derived text, not merely its shape.

`recap_cache_large_turns` (1920x1080) and `recap_cache_medium_turns` (1280x720)
under `.artifacts/generated_full_match_quality_20260906/` pass three ordinary
turns, full autosaves and all four exact saved states against retained controls.
They ran alongside package checks and are **functional**, not isolated speed
evidence; the Large reference is also a different resolution. Their optional
15% speed gates remain false. Do not replace the outstanding End Turn target
with this checkpoint's menu gain. The existing content-index regression passes
all 2828 row identities/reset controls in `content_lookup/recap_cache_final`.

The original named-file UI regression passes all four live Save routes, more than
three independent files, Unicode/case identity, overwrite/cancel/recovery and
main-menu restore in `recap_cache_named_files_dbus`. Its one logged invalid-save
JSON error is the deliberate same-size corruption at
`tests/named_save_files_regression.py:62`; no other engine/script/RID errors occur.
The first attempt, `recap_cache_named_files`, aborts in the host's AccessKit
initialization without a session bus. Repeating the unchanged assertions under
`dbus-run-session` succeeds with the default accessibility backend. Only artifact
paths were redirected to fresh directories; old evidence was not overwritten.

Linux and Windows release smokes (`recap_cache_linux_release` /
`recap_cache_windows_release`) pass exports, native-library loading, startup and
packaged generated-map/Town entry. Both PCKs are **248464928 bytes**, leaving
1535072 bytes below the unchanged 250000000-byte ceiling. The established
checkers ran through the existing RAM-backed wrapper; only their newly owned
temporary exports/Wine prefixes were removed. Reports/captures and prior evidence
remain. Windows execution is Wine, not physical Windows/GPU certification.

Inspected captures: full-play `outcome_resumed` and
`main_menu_after_battle_return` at 1280x720; both named-save dialogs at 1280x720
and 1920x1080; both actual generated `turn_after` views; packaged
`generated_player_town_entered` at 1920x1080. Save controls remain usable with
the same text. Existing Town buildings still look detached over water, and
Overworld prop-edge rectangles/terrain seams remain; this is not art acceptance.

Repository validation, 12 Python acceptance tests, PLAN sync/queue checks and
`git diff --check` pass. Reproduce the focused checks with
`python3 -B tests/save_stored_recap_regression.py --label <fresh> --save <actual-save> --require-reuse`;
the full loop and comparison with `tests/full_play_runtime_profile.py` and
`tests/full_play_profile_compare.py --expected-states 50`; the eleven existing
reports with `tests/full_play_validation_suite.py`; generated turns with
`tests/generated_end_turn_profile.py --rendered --compare <retained-control>`;
and both established `tests/packaging_*_export_smoke.py` checks.

This is a validated runtime checkpoint. The performance child and parent goal
remain in progress: Large AI/full-save latency, the unmet End Turn speed gate,
Town integration, prop/terrain presentation, the known Moonbite deadline and
broader release/hardware limits remain open. Continue measured complete-action
work without skipping simulation, normalization or transactional saves.

## Direct authoritative blocker-mask reads — 2026-09-07

Selected within the same in-progress responsiveness child. The remaining Large
profile attributes roughly 0.5–0.8 seconds per turn to constructing occupancy
indexes. `_build_blocked_tile_index` resolved each resource's content definition
before `_resource_node_blocks_body_tiles` checked its package mask; nonempty
masks were then decoded again by `_map_object_world_body_tiles`. In the actual
Large Day-8 save, all 670 resource placements have array-valued package masks.
Content definitions cannot affect that branch of the original calculation.

The runtime now checks the same authoritative presence rule and decodes that
mask once. Missing/non-array masks retain the original content-backed path.
Empty/malformed arrays, consumed versus persistent sites, native ownership
tokens, overlaps, actor/level filtering, tile values and insertion order are
unchanged. No cache or new retained state is introduced. No source mask, map
placement, native generation/link, gameplay, art, save schema or writer changes.

Reference: commit `34396ac4029725dc8f66e23324986e908a9a5e15`, OverworldRules SHA256
`6588c9c6b1e7216c337df8cff7d3d06291682ca72d4c2cc9707ebe0225c39c09`.
Current OverworldRules:
`8a7738f064982bbfb287936962641aa41602069064aaefd503b22f1db14acbdf`.
It is the only changed production owner; all other runtime hashes remain at the
stored-recap checkpoint. The exact Large and Medium save hashes are retained in
every focused/turn report, unchanged from their actual match checkpoints.

`tests/overworld_blocked_mask_regression.py` loads complete independent original
and current scripts. `blocker_masks_positive_control` has 128 expected work-count
failures with identical old/current owners; every state, tile and ownership
comparison already passes. `blocker_masks_large_verified` and
`blocker_masks_medium_verified` each pass **1484 checks**, with no engine errors.
Coverage includes six factions, all 422 current map-object definitions via direct
and site fallback lookup, all 377 resource-site definitions plus two missing-id
controls, explicit empty/invalid/negative/duplicate masks, consumed/permanent/
repeatable states, immediate mask mutation, native/town/scenery/actor overlaps,
resolved armies, levels and complete real saved sessions. Fixtures are detached
tests, not modifications to live generated packages.

In the measured Large surface scan, original/current results contain the same
7458 tile entries: content resolutions fall **670 to zero**, payload decodes
3376 to 2729, and authoritative presence checks stay 670. Wrapper timings
42.780 to 31.892 ms explain the removed work only; they are not whole-action
speed evidence. The unchanged complete path-owner regression additionally
passes 1023 checks in `blocker_masks_path_large`, including masks, links, selected
fields/steps, cache freshness, reciprocal levels and occupied/invalid passages.

### Rendered complete turns

Serial, uncontended test-engine runs on the same Linux/X11 Godot 4.6.2 software
renderer (llvmpipe LLVM 20.1.2), three real turns per row, complete autosave and
usable controls included. Captures and state serialization are outside timers.
Evidence root: `.artifacts/generated_full_match_quality_20260906/`.

| Run | Resolution | p50 ms | p95 / max ms | Sum ms |
| --- | --- | ---: | ---: | ---: |
| `blocker_masks_large_before` | 1920x1080 | 8087.349 | 8205.566 | 23921.683 |
| `blocker_masks_large_compared` | 1920x1080 | 7785.031 | 7903.969 | 23149.008 |
| `blocker_masks_medium_before` | 1280x720 | 3380.725 | 3535.384 | 10285.964 |
| `blocker_masks_medium_compared` | 1280x720 | 3380.028 | 3623.837 | 10213.014 |

Large cumulative waiting decreases **3.2%** in this pair; Medium's 0.7% is not a
meaningful improvement. All four complete state trees match per size, along with
day sequence, input-save identity and rendering backend. Both processes exit
cleanly with zero runtime errors. **Both reports intentionally remain `ok:false`
because the required 15% speed gate is unmet; `functional_ok:true` is separate.**
This is a small runtime optimization, not completion of the End Turn objective.

The initial `blocker_masks_large_after` / `blocker_masks_medium_after` invocations
incorrectly supplied a report filename to the directory-valued `--compare`
option. Their game runs finished but Python comparison failed before report
creation; logs/captures/states remain retained and are not the accepted pair.
The profiler now documents and rejects an invalid comparison directory before
launch or output creation. The same invalid invocation exits 2 immediately;
corrected fresh runs above preserve all original timing/state gate assertions.

Both final `turn_after.png` images were visually inspected. Fog/minimap, owned
roster, current movement and bottom commands remain usable. The Medium prop-edge
black rectangles and hard terrain seams, and Large footer truncation, remain
visible pre-existing presentation defects; no visual improvement is claimed.

### Integrated validation

`blocker_masks_domains/report.json` under
`.artifacts/full_play_runtime_20260905/` passes all 13 requested movement/input,
complete-route, fog, AI memory/defense/task/recruitment/raid, transactional-save,
End Turn failure-recovery and casualty reports. Only the six deliberately
injected `end_turn_autosave_failed` messages are expected; no unexpected runtime
errors occur. `blocker_masks_full_play` completes all 51 rendered menu-to-victory/
resume checkpoints. Its `matched_control_report.json` proves all 50 complete
saved states and ordered action identities equal to `recap_cache_full_play_after`.
It ran alongside domain/native validation: profile output is retained, but this
run is **functional evidence, not a new matched full-loop speed claim**.

Under `.artifacts/rmg_start_audit_20260905/`, `blocker_masks_native_caves` passes
eight reciprocal journeys, exact AI destinations, real approaches, occupancy
rejections, source geometry and production-save/fog checks. The underground
1280x720 capture was inspected. `blocker_masks_native_large_portals` passes both
representative shapes (`45:1`, `43:2`), seven gameplay/save checks per shape,
native contract validation and the recorded Large baseline-source comparison.
Representative coverage is not a claim of every possible endpoint journey;
no native source changes occurred during either run.

Both release smokes, `blocker_masks_linux_release` and
`blocker_masks_windows_release`, pass export, native library load, startup and
packaged generated-map/Town entry. PCKs are **248464880 bytes** on both platforms,
1535120 below the unchanged 250000000-byte ceiling, with source/development art
excluded. The established RAM-backed wrapper removes only its new temporary
exports/Wine prefixes; retained evidence and unrelated files remain untouched.
Windows execution uses Wine and is not physical Windows/GPU certification.
The full-play `outcome_resumed` and Linux packaged `generated_player_town_entered`
captures were inspected; the latter still exposes detached-looking Town buildings.

Repository validation, 24 Python acceptance/native-reference tests, PLAN sync/
queue checks and `git diff --check` pass. Reproduce the new focused test with
`python3 -B tests/overworld_blocked_mask_regression.py --label <fresh> --save <actual-save> --require-mask-reuse`;
path controls with `tests/ai_path_context_read_regression.py --require-key-once`;
complete turns with `tests/generated_end_turn_profile.py --rendered --compare <run-directory> --require-improvement`;
the 13 domains and full play with the existing `tests/full_play_*` runners;
native journeys with `tools/rmg_native_transit_validation.py`; and the unchanged
Linux/Windows export checkers. All labels/output paths must be fresh.

This checkpoint removes demonstrated redundant runtime work, but the unchanged
15% full-turn gate remains unmet. Keep the child and parent in progress. Next:
remaining AI task/target preparation and full-save latency; retain the Town/
prop/terrain defects, pre-existing Moonbite deadline and hardware/release limits
as open requirements, not completed work.

## Exact single-entry commander projection — 2026-09-07

Selected within the same in-progress responsiveness child. Two diagnostics on
the unchanged Large Day-8 save (`task_reads_large_diagnostic` and
`roster_callers_large_diagnostic`) preserve all four complete states against the
blocker-mask reference. Full commander normalization runs 218–263 times per turn;
111–129 calls come from `build_raid_commander_state`, which consumes only one
entry. Those calls account for 593–686 ms of inclusive instrumented time per
turn. Task/target preparation and path-context work remain substantial; resource
score calculation alone is not the dominant remaining owner. These headless
diagnostics explain work, not rendered player-facing speed, and overlapping
inclusive timings must not be summed.

`EnemyAdventureRules.gd` now shares the unchanged roster-entry normalization body
between complete rosters and an exact single-entry projection used by raid
construction. The projection first verifies the same faction catalog membership.
Raw roster duplicates, active raid/Town/resource precedence, recovery deadlines,
record/role/memory/progression/mana/artifact/army fields and controller identity
retain their original calculation. Automatic commander selection still evaluates
the complete roster. Every read observes current inputs; no retained cache,
mutation omission or cross-action reuse is added. AI policy, action ordering,
native generation, occupancy, content/art and save schema/writer are unchanged.

The only changed production owner is EnemyAdventureRules: reference commit
`597ea8503c42ca59ad2954c4748bc8a48ac06b1e`, source SHA256
`36c93abf4a7c081834103aefe99b38bee426c1b347a5b92f584806dab968f0e5`;
current source SHA256
`073737993044e139a05d60e0956e09a1da484b73c51611a5e14b064985457637`.
Other production owners remain at the blocker-mask checkpoint. The unchanged
real Large and Medium save identities are recorded in every focused/turn report.

`tests/ai_commander_entry_projection_regression.py` loads complete independent
original/current owners, not inherited static-method substitutes. It compares
complete rosters, projected entries, raid commanders, caller inputs and every
session value. Coverage includes every faction hero, unknown/automatic/null
cases, duplicate/malformed rosters, live fallback, recovery expiry, content reload,
active/defender mutation and precedence, resolved raids, same-faction opponent
controllers, and every actual saved AI hero/raid. Session snapshots deeply detach
all mutable fields; whole-state equality is not replaced with selected-field checks.

`commander_entry_positive_control` reproduces 398 expected redundant-work failures
plus one fixture failure: the synthetic Town defender lacked the enemy-state
record required by the existing front authority. Restoring that legitimate fixture
record yields `commander_entry_positive_control_aligned`: 1160 checks, 316 expected
work failures and zero unexpected/engine errors before the runtime edit. All old/
current output comparisons already pass. Both attempts remain retained.
`commander_entry_large_verified` passes **1447 checks** and
`commander_entry_medium_verified` **1286**, without engine errors. A real saved
Embercourt raid candidate now builds two commander states rather than twelve
(one normalized selected entry plus the existing raid seed), with identical output.

### Serial rendered complete turns

Three real End Turn handlers per row, including full autosaves and usable input.
Runs are serial, without other test engines, on Linux/X11 Godot 4.6.2 and llvmpipe
LLVM 20.1.2. Captures/state serialization remain outside action timers. Evidence
root: `.artifacts/generated_full_match_quality_20260906/`.

| Run | Resolution | p50 ms | p95 / max ms | Sum ms |
| --- | --- | ---: | ---: | ---: |
| `commander_entry_large_before` | 1920x1080 | 7768.994 | 8078.772 | 23108.479 |
| `commander_entry_large_compared` | 1920x1080 | 7332.438 | 7377.353 | 21530.795 |
| `commander_entry_medium_before` | 1280x720 | 3372.734 | 3556.278 | 10271.240 |
| `commander_entry_medium_compared` | 1280x720 | 2870.381 | 2941.390 | 8633.250 |

Large cumulative waiting improves **6.8%** in this pair, still missing the required
15% gate (`ok:false`, `functional_ok:true`). Medium improves **15.9%**, passing
that unchanged gate in this pair. All four complete states, day sequences, input
save identities and backends match per size; both engines exit cleanly without
runtime errors. This is not a multi-machine or whole-game responsiveness claim.
Large turns remain multi-second and this child remains in progress.

Both final `turn_after.png` captures were visually inspected. Fog/minimap, owned
rosters, current movement and input controls remain intact. Medium prop-edge
rectangles/hard terrain seams and the Large truncated footer persist; no visual
improvement or presentation acceptance is claimed here.

### Integrated validation

`commander_entry_path_large` passes the existing **1023** complete original path/
mask/link/freshness checks. Under `.artifacts/full_play_runtime_20260905/`,
`commander_entry_domains` passes all **18** requested reports: movement/input,
full routes, fog, AI memory/defense/task/recruitment/raid behavior, save transactions,
End Turn failure recovery, casualties, commander role state/adoption/transcripts,
spawn selection and emergency commander fit. Only six deliberately injected
`end_turn_autosave_failed` messages are expected; no unexpected runtime errors.
The Python suite now admits the five existing commander reports without changing
their assertions. The emergency-fit harness uses its original `status:pass` plus
exact subsystem identity instead of an absent `ok` field; all other markers and
exit/error checks remain unchanged.

`commander_entry_full_play_isolated` completes all **51** rendered menu-to-victory/
resume checkpoints. Its `matched_control_report.json` compares every one of the
**50** full state trees and ordered action identities to `blocker_masks_full_play`.
This run overlaps functional domain/native validation; retained profile values
are **not** a new matched full-loop speed claim. The first
`commander_entry_full_play` launcher exited 143 while its detached child was still
running. The exact owned orphan process group was stopped and the logs/partial
captures retained; no completed-play claim is made for that attempt. The fresh
session-isolated run above exits normally with zero runtime errors. The resumed
victory capture at 1280x720 was visually inspected.

Under `.artifacts/rmg_start_audit_20260905/`, `commander_entry_native_caves` passes
eight reciprocal journeys with 20 travel/AI/occupancy/save/fog checks per journey;
its underground 1280x720 capture was inspected. `commander_entry_native_large_portals`
passes the two representative shapes (`45:1`, `43:2`), seven gameplay/save checks
per shape, native contract validation and the retained Large baseline-source
comparison. No native source changes occur during either run. This is bounded
journey coverage, not exhaustive endpoint or H3MapEd parity certification.

`commander_entry_linux_release` and `commander_entry_windows_release` pass the
established export, native-library, startup and packaged generated-map/Town-entry
checks. Both PCKs measure **248465456 bytes**, 1534544 below the unchanged
250000000-byte ceiling; source/development art stays excluded. The unchanged
RAM-backed wrapper removes only its new disposable exports/Wine prefixes, not
retained evidence or unrelated files. Windows execution is via Wine, not physical
Windows/GPU certification. The Linux generated Town capture at 1920x1080 was
visually inspected: detached-looking buildings remain an open presentation issue.

Repository validation, **24** Python acceptance/native-reference tests, PLAN sync/
queue checks and `git diff --check` pass. Reproduce focused controls with
`python3 -B tests/ai_commander_entry_projection_regression.py --label <fresh> --save <actual-save> --require-projection`;
path controls with `tests/ai_path_context_read_regression.py --require-key-once`;
serial turns with `tests/generated_end_turn_profile.py --rendered --compare <reference-directory> --require-improvement`;
full play/state comparisons and the 18 named domains with `tests/full_play_*`;
native journeys with `tools/rmg_native_transit_validation.py`; and the established
Linux/Windows export smokes. All output labels must be fresh.

Keep parent and responsiveness child in progress. Remaining work includes Large
AI task/target preparation and full-save latency, the selected Town/prop/terrain
presentation defects, the pre-existing Moonbite deadline and broader release/
hardware acceptance. The Medium speed result does not close those requirements.

## 2026-09-07 combined committed End Turn control

Fresh serial rendered controls compare `65fb7fcb6ccd5f9bb017c185c82e161e7216ad87`
with `85599aae0f0baa26ada6415a761da1875372f193`. Every production difference at
those revisions is replaced: `ContentService.gd`, `SaveService.gd`,
`EnemyAdventureRules.gd` and `OverworldRules.gd`. This measures their combined
effect, not a sum of individual percentages and not a speedup from the subsequent
stockpile UI correction. The actual-handler driver, three full turns, AI, full
autosaves and usable-input boundary are unchanged. Linux/X11, Godot 4.6.2,
llvmpipe LLVM 20.1.2; no concurrent test engine during these timings.

| Case / resolution | Before p50 / max ms | After p50 / max ms | Before / after sum ms | Less waiting |
| --- | ---: | ---: | ---: | ---: |
| Large / 1920x1080 | 8883.777 / 9459.333 | 7369.400 / 7417.939 | 26981.987 / 21656.637 | 19.7% |
| Medium / 1280x720 | 3665.261 / 3705.874 | 2914.390 / 2938.285 | 10800.145 / 8611.307 | 20.3% |

`combined_optimizations_large_verified` and `combined_optimizations_medium_verified`
under the existing full-match artifact root both pass the unchanged 0.85 maximum
wait ratio. Four complete state trees per size, days, input save hashes and
backend match; source/retained save bytes remain unchanged, with zero runtime
errors. Full states are retained as `.json.gz` without field exclusions; captures
were visually inspected. They preserve fog/minimap/roster/input and retain the
known prop/terrain and pre-stockpile-fix presentation defects.

The first `combined_optimizations_large` control completed turns but emitted a
missing `icon.svg` error in its isolated fixture; it is not a pass. The corrected
fixture includes the unchanged project icon/import and uses a fresh label.
`normalization_cache_large_diagnostic` independently confirms cached/current
normalization signatures equal for all three real Large turns and all four
states equal the commander control. The first save registers the generated
scenario, later saves already use the existing fast path. Instrumented/headless
timings are not performance acceptance; no normalization change was warranted.

Reproduce with `python3 -B tests/generated_end_turn_compact_pair.py --label <fresh>
--save <actual-save> --reference <exact-40-character-commit> --resolution <size>`.
The final helper derives all changed `.gd`/`.tscn` owners rather than hardcoding
these four; it copies both source directories so old scene writes cannot follow
shared symlinks. Unsupported art/native/content/config differences, added/deleted
owners and dirty/untracked production fail preflight. Seven focused Python tests
pass for those boundaries; this generalization does not change the measured
driver or retrospectively claim a new post-UI timing run.

Disk-pressure retention: completed `commander_entry_large_before` and
`commander_entry_large_compared` `state_00` through `state_03` JSON files and their
two profiler-owned `input_save.json` copies are now lossless gzip files at the
same paths plus `.gz`; SHA256 before compression equals decompressed SHA256 for each.
Decompress for legacy raw-JSON readers. No checkpoint content, screenshots,
actual input saves, caches, RMG evidence or unrelated artifacts were deleted.
Large remains multi-second and broader responsiveness/presentation acceptance
remains open despite passing this bounded combined improvement gate.

## 2026-09-07 responsiveness completion audit

This closes already implemented work against the original PLAN criteria, not
because a report exists and not by treating the blocked art requirement as done.
No production source changed during this audit. Current game revision is
`4d171105a2793eb18e0201bc47c348912c3d8942`; the only production changes since the
previous `85599aae` full-play/platform checkpoint are the validated stockpile
scene/component. Core, native, art and content files are unchanged.

Fresh `generated_end_turn_compact_pair.py` runs use the exact pre-path reference
`65fb7fcb6ccd5f9bb017c185c82e161e7216ad87`, replacing all six changed production
scripts/scenes, not a selected subset. Runs are serial on Linux/X11 Godot 4.6.2,
llvmpipe LLVM 20.1.2, with no competing test engine; the actual-handler driver,
full simulation, saves and usable-control boundary are unchanged.

| Evidence under the full-match artifact root | Before p50 / max ms | Current p50 / max ms | Before / current sum ms | Less waiting |
| --- | ---: | ---: | ---: | ---: |
| `closure_endturn_large_4d171105` (1920x1080) | 8846.637 / 9551.420 | 7377.901 / 7501.516 | 27011.903 / 21738.812 | 19.5% |
| `closure_endturn_medium_4d171105` (1280x720) | 3485.196 / 3642.629 | 2848.275 / 2999.894 | 10559.343 / 8624.894 | 18.3% |

Both unchanged 15% gates pass; each compares four complete state trees, identical
days/backend and unchanged source/save bytes, with zero runtime errors. Full
gzip state snapshots, source hashes and captures remain retained. Final captures
were inspected: current fog, roster, movement and fitting resource controls are
intact; the known art defects remain. These repeat measurements validate existing
improvements, not an additional speed gain from this audit.

The other original completion criteria were checked against real evidence:

- Dominant owners and matched full-action improvement: inspected the current
  Town synchronous read-scope/support-radius owners and the retained
  `logistics_town_large_release` / `logistics_town_medium_release` reports.
  Their four states/actions/recaps/save/backend comparisons all pass; measured
  recruitment improvement is 51.5% / 20.5%. The serial stored-recap full-loop
  pair reduces total save-surface work 68.2%, without promising faster combat.
- Freshness and complete decisions/state: retained logistics scope reports pass
  1264 Large / 1201 Medium checks, including six-faction and nested/stale-source
  controls; recap reports pass 542 / 544. Eighteen final commander/domain reports
  pass. Re-ran the existing comparator over the actual retained raw full-play
  states and profiles for `commander_entry_full_play_isolated` and
  `recap_cache_full_play_after`: all 50 full state trees per pair and ordered
  action identities match, both reference/current flows completed, and both
  reference logs and current runs have no runtime errors. No fields were omitted.
- Complete matches and platforms: re-read the accepted Medium11 continuation03
  and Large08 reports (earned Day97 victory / legal Day14 defeat, capacity
  histories complete, zero acceptance failures). Their documented multi-version
  provenance is unchanged. Current-source `stockpile_fit_linux_release` and
  `stockpile_fit_windows_recovered` reports pass at 248466896-byte PCKs; these
  existing export/generated-entry results are reused, not reported as new
  exports. Windows is Wine execution, not hardware certification. All 31 Python
  acceptance/native-reference/preflight tests pass again.

Final `python3 -B tests/validate_repo.py`, JSON parsing, referenced-artifact
existence checks and `git diff --check` pass. The repository log is retained at
`.artifacts/generated_full_match_quality_20260906/responsiveness_closure_repo.log`.
The heroes-progress PLAN dry-run finds no missing slices; its current/next query
selects blocked presentation, with playthrough and responsiveness completed.

The performance child is complete for these defined selected-action criteria.
Large p50 remains about 7.4 seconds, cold save surfaces can approach one second,
and the historical Moonbite deadline is an unchanged balance limit, not a passed
development gate. Further latency reduction, exhaustive configurations and
hardware certification are not claimed. The full-match parent is still unfinished:
Town scene-matched building art and Overworld cutout/terrain quality require the
pending owner art-scope decision. This audit must not be called a new game fix.
