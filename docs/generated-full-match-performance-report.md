# Full-match responsiveness — 2026-09-06

Phase 6 child `performance-generated-full-match-actions-20260906`, under
`quality-generated-full-match-20260906`. Requirements:
`docs/generated-full-match-quality-requirements.md`. **In progress**, not complete
matches, game-wide performance approval or release readiness.

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

## Current limits

Medium `medium_match_07` stopped legitimately as a **failed diagnostic**, not a
terminal outcome, at Day 54: fourteen days without exploration/interaction
progress. Its actions repeatedly revisit artifact targets but land on controlled
resource-site actions; the remaining movement is insufficient to reach the chosen
hostile town. The placement/driver routing cause still needs isolation. Large
`large_match_05` continues. Do not count the failed Medium run or controlled
three-turn fixture as completed-match acceptance.

Complete Medium/Large terminal outcomes, selected presentation corrections and
final both-platform validation remain requirements of the parent goal. See
`docs/generated-full-match-quality-report.md` for gameplay fixes and explicitly
retained unrelated legacy failures.
