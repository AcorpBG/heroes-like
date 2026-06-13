# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-26
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy the referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.
- Test, report, audit, and export tooling should be Python-owned. GDScript should be reserved for live game/runtime behavior, not validation/report launchers.

## Current Tactical State

Current phase: **Phase 5 - Playable Alpha Baseline**.

- Current implementation slice: `rmg-small-generalization-hardening-10184` is in progress. The active work is native alignment to the recovered H3MapEd R1-R7 one-level land chain for supported Small/Medium maps. R1-R7 recovery is complete, but native parity remains incomplete until the eight alignment checkpoints below pass Python-owned private-state and final-payload comparisons. Checkpoints 1, 4, and 5 are complete; five checkpoints remain pending.
- Native RMG alignment checkpoints, in execution order:
  1. Final writeout authority: complete. Native final-writeout evidence now points at recovered `0x4ad1e3 -> 0x49b2b6 -> 0x4ad309/0x4ad3eb` tile/object stream evidence; current mismatches are attributed to pending earlier checkpoints, not package-draft parity.
  2. Private generated-cell grid: make pre-`0x4a4c8e` native generated-cell words match recovered private state before route/object consumers run.
  3. Reward/object identity: carry recovered source records/descriptors through selection and materialization instead of resolving final identity through proxy object ids.
  4. Metadata claim correction: complete. Exact/adopted phase claims that still have lower-level blockers are downgraded and must only be restored after comparison evidence passes.
  5. Route replay preconditions: complete. `0x4a8260` route replay remains diagnostic while upstream object-vector/generated-cell state is not exact, and diagnostic replay does not mutate the live generated-cell grid.
  6. Road vector/bit source: port recovered endpoint vector and generated-cell bit inputs before treating road topology as exact.
  7. Connection blockers/guards: replace synthetic package blocker/guard construction with recovered source-backed object payload, body, and control semantics.
  8. Decorative scoring/vector replay: replace proxy `0x49e1bf` scoring and manually seeded object snapshots with recovered relation/scoring and object-vector state.
- RMG recovery state: `docs/h3maped-rmg-full-recovery-blockers.md` records the fixed R1-R7 H3MapEd recovery ledger as 100% recovered for the scoped one-level land target. This is recovery authority only; it is not a native RMG parity claim.
- Current checkpoint-2 finding: refreshed Python-only Medium seed-10 compares in `.artifacts/rmg_native_checkpoint5_route_gating_current/private_state_compare_pre_0x4a4c8e_same_run.json`, `private_state_compare_after_terrain_live_feedback_same_run.json`, and `private_state_compare_after_object_vector_private_grid_same_run.json` now expose the owner surface directly. H3MapEd has 13 non-negative owner ids (`0..12`) for selected template `2SM4d(2)` with 10 source zones, while native has 9 non-negative owner ids. The exact branch condition behind the missing same-level owner surface is now source-backed: `0x4a3a9d` tests `level_index == 1 || generator+0x10b8 != 0`, and `generator+0x10b8` is written by `0x49ecf2` from constructor arg8 supplied by RMG setup object `+0x44` at `0x4adfe1`. Static recovery now pins that setup field path: `0x4adf88` initializes setup `+0x44` to `3`, then `0x4602c1` overwrites stack setup `[EBP-0x80]+0x44` from `[EDI+0xac]+0x10` before calling `0x4adfe1`. Native now refuses to mark the no-appended-zone footprint path exact unless that input is known and false. The implementation target for checkpoint 2 is the missing same-run RMG setup object `+0x44` capture plus `0x4a3b48` direction scan and `0x49b452` synthetic runtime-zone append replay before `0x4a4c8e`, not reward density, package adoption, or final writeout.
- Current guardrails: do not re-open H3MapEd reverse engineering for this slice unless Python/Ghidra/Wine evidence disproves the recorded recovery, do not add density scalars/gates/brute-force retries/final-map tuning, do not use GDScript for reports/exports, and do not launch Godot/headless Godot for native RMG export on this memory-constrained host. `tools/rmg_native_batch_export.py` now only supports the standalone no-Godot `bin/rmg_native_batch_export_cli` path; the legacy Godot runner has been removed from this wrapper. The no-Godot CLI now owns plain-C++ controlled-case parsing/filtering, checkpoint-2 phase snapshots with constructor-default generated-cell words, embedded-catalog template selection/runtime-zone records, link-seed extraction, `0x4a1f3b` coordinate replay summaries, and `0x4a3a03/0x4cc788/0x4ccb64/0x4ccdfc` source-node footprint summaries for supported Small/Medium one-level land cases, but still fails closed for `.amap` generation until the recovered H3MapEd RMG generation core is split from Godot `Dictionary`/`Array`/`String`, `RefCounted`, and `FileAccess` APIs into plain C++ data structures. Do not treat the initial generated-cell grid, template/runtime-zone summary, link-seed summary, coordinate replay summary, or source-node summary as pre-`0x4a4c8e` parity; boundary/span-fill owner materialization, same-level runtime-zone append, and later generated-cell mutations remain pending. Do not build Windows `.dll` outputs until Linux `.so` parity checks reach the final boundary.
- Paused/in-progress evidence slice: `strategic-ai-medium-long-run-seed-matrix-10184` remains paused/in-progress and is not the selected immediate work.
- Latest completed slice: `native-rmg-medium-h3maped-land-public-ui-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-runtime-adoption-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-phase-port-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-template-authority-10184`.
- Latest completed slice: `native-rmg-medium-h3maped-land-reference-corpus-10184`.
- Latest completed slice: `strategic-ai-rmg-medium-generalization-probe-10184`.
- Latest completed slice: `native-rmg-medium-runtime-generation-unblock-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-unblock-routing-10184`.
- Latest completed slice: `strategic-ai-medium-rmg-blocker-classification-10184`.
- Latest completed slice: `strategic-ai-baseline-staged-evidence-adoption-10184`.
- Latest completed slice: `strategic-ai-residual-diagnostic-hardening-10184`.
- Latest completed slice: `strategic-ai-staged-100-evidence-aggregation-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset0-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset98-count2-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset93-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset88-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset83-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset78-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset73-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset68-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset63-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset58-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset53-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset48-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset43-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset38-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset33-count5-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset30-count3-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset29-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset28-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset27-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset26-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset25-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset24-10184`.
- Latest completed slice: `strategic-ai-eight-week-shard-offset23-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset18-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset13-10184`.
- Latest completed slice: `strategic-ai-seed13-route-pressure-execution-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset8-10184`.
- Latest completed slice: `strategic-ai-production-shard-offset3-10184`.
- Latest completed slice: `strategic-ai-broader-handoff-generalization-10184`.
- Latest completed slice: `strategic-ai-tactical-pressure-march-10184`.
- Latest completed slice: `strategic-ai-natural-battle-handoff-matrix-10184`.
- Latest completed slice: `strategic-ai-generated-town-battle-handoff-proof-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-behavior-10184`.
- Latest completed slice: `strategic-ai-generated-battle-handoff-coverage-10184`.
- Latest completed slice: `strategic-ai-generated-regroup-target-integrity-10184`.
- Latest completed slice: `strategic-ai-headless-resource-task-persistence-10184`.
- Latest completed slice: `battle-ai-spell-conservation-tactical-order-10184`.
- Latest completed slice: `battle-ai-shared-spell-tactical-order-10184`.
- Latest completed slice: `strategic-ai-active-front-support-launch-10184`.
- Latest completed slice: `strategic-ai-active-raid-launch-budget-10184`.
- Latest completed slice: `strategic-ai-active-front-event-surface-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-sharding-10184`.
- Latest completed slice: `battle-ai-immediate-threat-targeting-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-roster-sync-10184`.
- Latest completed slice: `battle-ai-overkill-target-discipline-10184`.
- Latest completed slice: `battle-ai-recovery-target-filter-10184`.
- Latest completed slice: `strategic-ai-path-distance-field-efficiency-10184`.
- Latest completed slice: `battle-ai-side-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-rules-commander-payload-fallback-continuity-10184`.
- Latest completed slice: `battle-ai-tactical-order-payload-merge-continuity-10184`.
- Latest completed slice: `battle-ai-force-sync-payload-continuity-10184`.
- Latest completed slice: `battle-ai-outcome-payload-continuity-10184`.
- Latest completed slice: `battle-ai-normalized-payload-preservation-10184`.
- Latest completed slice: `battle-ai-rich-payload-spellbook-merge-10184`.
- Latest completed slice: `battle-ai-live-spell-template-cast-sync-10184`.
- Latest completed slice: `battle-ai-spell-template-spellbook-fallback-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-template-fallback-10184`.
- Latest completed slice: `strategic-ai-risk-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-commander-template-fallback-10184`.
- Latest completed slice: `battle-ai-spell-role-template-fallback-10184`.
- Latest completed slice: `battle-ai-commander-spell-role-valuation-10184`.
- Latest completed slice: `strategic-ai-spell-study-template-role-fallback-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-state-fallback-10184`.
- Latest completed slice: `battle-ai-battle-state-enemy-hero-fallback-10184`.
- Latest completed slice: `strategic-ai-path-surface-fingerprint-cache-10184`.
- Latest completed slice: `strategic-ai-indexed-path-search-10184`.
- Latest completed slice: `strategic-ai-path-distance-efficiency-10184`.
- Latest completed slice: `strategic-ai-long-run-progress-telemetry-10184`.
- Latest completed slice: `battle-ai-tactical-order-commander-payload-10184`.
- Latest completed slice: `battle-ai-spell-report-payload-bridge-10184`.
- Latest completed slice: `battle-ai-enemy-hero-payload-bridge-10184`.
- Latest completed slice: `battle-ai-commander-withdrawal-personality-10184`.
- Latest completed slice: `strategic-ai-long-run-configurable-matrix-10184`.
- Latest completed slice: `battle-ai-engaged-melee-attack-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-tiebreak-10184`.
- Latest completed slice: `strategic-ai-task-fit-spell-study-10184`.
- Latest completed slice: `battle-ai-lethal-spell-priority-10184`.
- Latest completed slice: `battle-ai-lethal-action-priority-10184`.
- Latest completed slice: `battle-ai-commander-buff-target-selection-10184`.
- Latest completed slice: `battle-ai-cleanse-recovery-urgent-filter-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-commander-fit-10184`.
- Latest completed slice: `battle-ai-damage-status-rider-targeting-10184`.
- Latest completed slice: `battle-strategic-ai-resistance-aware-spell-tuning-10184`.
- Latest completed slice: `strategic-ai-global-commander-task-assignment-10184`.
- Latest completed slice: `strategic-ai-post-recruit-surplus-mobilization-10184`.
- Latest completed slice: `strategic-ai-town-defense-commander-continuity-10184`.
- Latest completed slice: `strategic-ai-post-capture-town-support-continuation-10184`.
- Latest completed slice: `strategic-ai-neutral-town-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-surplus-garrison-mobilization-10184`.
- Latest completed slice: `strategic-ai-artifact-front-support-10184`.
- Latest completed slice: `strategic-ai-site-claim-recruits-10184`.
- Latest completed slice: `strategic-ai-opportunistic-town-resupply-10184`.
- Latest completed slice: `strategic-ai-opportunistic-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-active-town-runway-source-support-10184`.
- Latest completed slice: `strategic-ai-empire-build-arbitration-10184`.
- Latest completed slice: `strategic-ai-rare-resource-targeting-10184`.
- Latest completed slice: `strategic-ai-town-spell-study-10184`.
- Latest completed slice: `strategic-ai-spell-site-learning-10184`.
- Latest completed slice: `strategic-ai-personality-regroup-threshold-10184`.
- Latest completed slice: `strategic-ai-same-turn-launch-movement-10184`.
- Latest completed slice: `strategic-ai-midmove-hero-reaction-10184`.
- Latest completed slice: `strategic-ai-route-opportunistic-pickups-10184`.
- Latest completed slice: `strategic-ai-site-event-task-transition-10184`.
- Latest completed slice: `strategic-ai-duplicate-task-reservation-recovery-10184`.
- Latest completed slice: `strategic-ai-risk-regroup-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-target-selection-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-faction-scoped-hero-route-vision-10184`.
- Latest completed slice: `strategic-ai-player-hero-route-occupancy-10184`.
- Latest completed slice: `strategic-ai-post-move-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-multihero-spawn-occupancy-10184`.
- Latest completed slice: `strategic-ai-defensive-threat-known-hero-gating-10184`.
- Latest completed slice: `strategic-ai-convoy-interception-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-hero-front-support-sighting-gate-10184`.
- Latest completed slice: `strategic-ai-active-hero-target-known-gating-10184`.
- Latest completed slice: `strategic-ai-lost-hero-task-reconciliation-10184`.
- Latest completed slice: `strategic-ai-stale-hero-hunt-revalidation-10184`.
- Latest completed slice: `strategic-ai-ordinary-scouting-memory-10184`.
- Latest completed slice: `strategic-ai-persistent-exploration-task-board-10184`.
- Latest completed slice: `strategic-ai-neutral-town-known-world-gating-10184`.
- Latest completed slice: `strategic-ai-no-known-target-exploration-10184`.
- Latest completed slice: `strategic-ai-known-nonhero-target-gating-10184`.
- Latest completed slice: `strategic-ai-no-omniscient-empty-target-fallback-10184`.
- Latest completed slice: `strategic-ai-fresh-launch-commander-fit-10184`.
- Latest completed slice: `strategic-ai-known-world-memory-10184`.
- Latest completed slice: `strategic-ai-post-objective-raid-continuation-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-recruitment-prep-10184`.
- Latest completed slice: `strategic-ai-emergency-defense-launch-10184`.
- Latest completed slice: `strategic-ai-spell-aware-task-launch-10184`.
- Latest completed slice: `strategic-ai-resource-defense-battle-handoff-10184`.
- Latest completed slice: `strategic-ai-resource-defender-stationing-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-consolidation-10184`.
- Latest completed slice: `strategic-ai-live-commander-role-adoption-10184`.
- Latest completed slice: `strategic-ai-threat-recovery-reinforcement-10184`.
- Latest completed slice: `strategic-ai-nearby-threat-avoidance-10184`.
- Latest completed slice: `strategic-ai-commander-risk-tolerance-10184`.
- Latest completed slice: `strategic-ai-planned-launch-host-template-lock-10184`.
- Latest completed slice: `strategic-ai-post-regroup-target-resumption-10184`.
- Latest completed slice: `strategic-ai-commander-outcome-adaptation-10184`.
- Latest completed slice: `strategic-ai-defended-town-capture-stationing-10184`.
- Latest completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184`.
- Latest completed slice: `strategic-ai-planned-task-build-prep-10184`.
- Latest completed slice: `strategic-ai-recruitment-market-coverage-10184`.
- Latest completed slice: `strategic-ai-opportunistic-hero-intercept-10184`.
- Latest completed slice: `strategic-ai-destination-aware-recruitment-10184`.
- Latest completed slice: `strategic-ai-commander-personality-task-fit-10184`.
- Latest completed slice: `strategic-ai-site-contest-event-surfacing-10184`.
- Latest completed slice: `strategic-ai-planned-task-ready-launch-10184`.
- Latest completed slice: `strategic-ai-rmg-small-turn-health-10184`.
- Latest completed slice: `strategic-ai-defended-neutral-town-assault-10184`.
- Latest completed slice: `strategic-ai-neutral-town-expansion-10184`.
- Latest completed slice: `strategic-ai-resource-front-support-10184`.
- Latest completed slice: `strategic-ai-multi-origin-task-planner-10184`.
- Latest completed slice: `strategic-ai-coordinated-task-planner-10184`.
- Latest completed slice: `strategic-ai-long-run-seed-matrix-10184`.
- Latest completed slice: `strategic-ai-threat-arbitration-10184`.
- Latest completed slice: `strategic-ai-battle-task-outcome-lifecycle-10184`.
- Latest completed slice: `strategic-ai-risk-stall-withdrawal-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-support-grouping-10184`.
- Latest completed slice: `strategic-ai-town-defender-rotation-10184`.
- Latest completed slice: `strategic-ai-proactive-risk-regroup-10184`.
- Latest completed slice: `strategic-ai-post-move-assault-grouping-10184`.
- Latest completed slice: `strategic-ai-defense-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-target-aware-spawn-point-selection-10184`.
- Latest completed slice: `strategic-ai-town-rebuild-garrison-safety-10184`.
- Latest completed slice: `strategic-ai-regroup-garrison-aware-routing-10184`.
- Latest completed slice: `strategic-ai-regroup-failure-rebuild-10184`.
- Latest completed slice: `strategic-ai-unreachable-route-recovery-10184`.
- Latest completed slice: `strategic-ai-shared-support-task-reservations-10184`.
- Latest completed slice: `strategic-ai-support-overcommit-control-10184`.
- Latest completed slice: `strategic-ai-active-front-support-10184`.
- Latest completed slice: `strategic-ai-guarded-claim-resumption-10184`.
- Latest completed slice: `strategic-ai-guarded-object-claim-routing-10184`.
- Latest completed slice: `strategic-ai-encounter-arrival-risk-gating-10184`.
- Latest completed slice: `strategic-ai-hero-intercept-risk-gating-10184`.
- Latest completed slice: `strategic-ai-town-assault-risk-gating-10184`.
- Latest completed slice: `strategic-ai-commander-assault-consolidation-10184`.
- Latest completed slice: `strategic-ai-adventure-objective-progression-10184`.
- Latest completed slice: `strategic-ai-town-defender-lifecycle-10184`.
- Latest completed slice: `strategic-ai-town-defense-arrival-10184`.
- Latest completed slice: `strategic-ai-artifact-equipment-10184`.
- Latest completed slice: `strategic-ai-scouting-spell-execution-10184`.
- Latest completed slice: `strategic-ai-adventure-spell-execution-10184`.
- Latest completed slice: `strategic-ai-local-recruitment-support-10184`.
- Latest completed slice: `strategic-ai-regroup-task-board-10184`.
- Latest completed slice: `strategic-ai-hero-hunt-task-board-10184`.
- Latest completed slice: `strategic-ai-artifact-task-board-10184`.
- Latest completed slice: `strategic-ai-encounter-objective-task-board-10184`.
- Latest completed slice: `strategic-ai-task-retask-cancellation-10184`.
- Latest completed slice: `strategic-ai-spawn-saved-task-commander-selection-10184`.
- Latest completed slice: `strategic-ai-task-resumption-10184`.
- Latest completed slice: `strategic-ai-task-actor-lifecycle-10184`.
- Latest completed slice: `strategic-ai-task-lifecycle-reconciliation-10184`.
- Latest completed slice: `strategic-ai-persistent-hero-task-board-10184`.
- Latest completed slice: `battle-layout-smoke-followup-10184`, expanded by owner direction into the battle presentation runtime slice.
- Latest completed slice: `combat-mireclaw-packhunter-trait-trim-10184`.
- Previous completed slice: `combat-mireclaw-half-anti-ranged-shielding-10184`.
- Previous completed slice: `combat-mireclaw-t6-t7-hp-revert-10184`.
- Previous completed slice: `battle-benchmark-all-live-hero-matrix-10184`.
- Previous completed slice: `hero-roster-live-diversity-10184`.
- Previous completed slice: `combat-mireclaw-late-anti-ranged-counter-10184`.
- Previous completed slice: `combat-mireclaw-late-tank-buff-10184`.
- Previous completed slice: `combat-thornwake-week2-buff-10184`.
- Previous completed slice: `combat-thornwake-t6-ranged-balance-10184`.
- Previous completed slice: `combat-sunvault-t6-melee-balance-10184`.
- Previous completed slice: `magic-resistance-countercontrol-10184`.
- Previous completed slice: `battle-spell-valuation-counterplay-followup-10184`.
- Previous completed slice: `battle-spell-parity-counterplay-10184`.
- Previous completed slice: `magic-town-study-full-tier-access-10184`.
- Previous completed slice: `magic-spell-tier-power-bands-10184`.
- Paused slice: `combat-faction-pair-stat-tuning-10184` remains needs-tuning; broad stat tuning is paused while the owner-selected battle presentation runtime slice improves player-readable combat flow.
- Previous completed slice: `battle-benchmark-no-round-cap-10184`.
- Previous completed slice: `combat-feel-balance-pass-10184`.
- Earlier completed slice: `battle-fast-faction-benchmark-10184`.
- Earlier completed slice: `economy-native-rmg-required-source-support-10184`.
- `ops/progress.json` remains the operational source of truth for completed evidence, validation commands, and paused/superseded slice state.
- RMG test/report/export work is Python-owned. Do not add or run GDScript report/export launchers for RMG validation; GDScript remains for live in-game runtime behavior.

Latest economy/town evidence:
- Runtime-inclusive economy/town scorecard: 30/30.
- Deterministic economy/town scorecard: 15/15.
- Authored town development completion: day 28-30.
- Strict Small Native RMG package adoption report: passing for all nine live resource sources, generated town source routes, guarded rare-source pressure, player/enemy/neutral generated town runway pacing, and seven-tier town recruitment within 36x36 one-level land scope.
- Current player-balance finding: Brasshollow, Thornwake, and Veilmourn have the clearest economy identity; Embercourt, Mireclaw, and Sunvault still need deeper identity beyond rare-resource pressure.
- Current rare-cost model: every town uses all six rare resources in high-tier development. The faction signature rare remains highest pressure, one secondary rare is about half pressure, and each remaining rare is about one-third pressure.
- Authored rare-source breadth is paused for this balance slice. The owner-selected balance surface is Native RMG generated maps, not authored scenario/source placement.
- Strict Small generated-map economy evidence is scoped to 36x36 one-level land packages. It is authoritative for this balance slice, but not broad RMG economy approval for larger sizes, water, underground, or broad template families.

Current product focus:
- Keep building toward a playable alpha baseline.
- Prefer player-readable, live-loop improvements over adding new report gates.
- Current strategic AI target: build from the baseline KPI audit into production behavior. Live commander/raid target choices now write normalized `enemy_states[].hero_task_state`, reuse saved active tasks for later target selection, reserve exclusive targets across active task boards, complete captured resource and artifact tasks, reconcile saved tasks against current target ownership/existence, suspend or invalidate saved tasks whose commander actor is missing, recovering, or unable to deploy, reactivate suspended saved tasks once their commander is deployable again, make new raid spawning prefer deployable commanders with reachable saved tasks before falling back to roster rotation, preserve explicit cancelled history when a commander is retasked to a different objective, persist objective-front encounter targets as first-class durable tasks, close live battle tasks from actual combat outcomes instead of battle queueing, arbitrate competing ready battles by strategic value instead of nearest-only ordering, give Native RMG/generated skeletal enemy configs runtime strategic AI defaults for raid pressure, spawn points, and encounter pools, add an executable generated-map long-run seed-matrix runner, seed coordinated pre-deployment task plans, and keep all of that continuity without a save-version bump.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-expansion-10184` makes generated-map/skirmish AI empires identify and capture reachable empty neutral towns as expansion objectives instead of only attacking player towns and resource/object sites. This is a live behavior slice, not a broad report-only gate or a full production-readiness claim.
- Latest strategic AI completed slice: `strategic-ai-defended-neutral-town-assault-10184` extends neutral-town expansion from empty towns into defended neutral towns by routing ready AI assaults through the live town battle system, risk-gating weak hosts, capturing the town without applying player-collapse consequences to neutral defenders, and letting active retake armies override planned reservations for urgent player-captured town recovery.
- Latest strategic AI completed slice: `strategic-ai-rmg-small-turn-health-10184` makes supported strict-Small Native RMG AI turns execute in the baseline by default and makes generated-map raid deployment expose player-facing target-assignment threat events instead of only pressure summaries.
- Latest strategic AI completed slice: `strategic-ai-planned-task-ready-launch-10184` lets prepared saved commander tasks launch from readiness instead of waiting for generic raid pressure, while unplanned raids still obey pressure thresholds.
- Latest strategic AI completed slice: `strategic-ai-site-contest-event-surfacing-10184` makes resolved encounter/objective-site arrivals emit compact public `ai_site_contested` events instead of silently mutating encounter/task state.
- Latest strategic AI completed slice: `strategic-ai-commander-personality-task-fit-10184` makes the live task planner score targets per commander archetype, command stats, specialty focus, and battle traits so enemy heroes stop acting like interchangeable target consumers.
- Latest strategic AI completed slice: `strategic-ai-destination-aware-recruitment-10184` makes enemy town recruitment pick units for the chosen destination: garrison defense, active raids, commander rebuilds, and planned commander tasks now use different unit-priority profiles.
- Latest strategic AI completed slice: `strategic-ai-opportunistic-hero-intercept-10184` makes active non-defensive raids retarget nearby exposed player heroes when the intercept is reachable and passes existing hero-risk readiness, while preserving defense/support/objective/guarded-claim priorities.
- Latest strategic AI completed slice: `strategic-ai-recruitment-market-coverage-10184` makes enemy town recruitment use live town-market coverage for wood/ore unit costs, consuming market caps when gold-backed recruitment buys missing materials.
- Latest strategic AI completed slice: `strategic-ai-planned-task-build-prep-10184` moves same-turn commander task planning ahead of town construction and gives objective-supporting buildings an explicit planned-task preparation score/reason, so AI towns build toward live commander goals before recruiting for them.
- Latest strategic AI completed slice: `strategic-ai-neutral-town-post-capture-garrison-10184` makes empty neutral-town expansion transfer the capturing host into the new town garrison, station the commander as defender, and retire the field raid instead of leaving a bare ownership flip.
- Latest strategic AI completed slice: `strategic-ai-defended-town-capture-stationing-10184` makes AI commanders that win defended town assaults consolidate into the captured town as active defenders with survivor-garrison continuity instead of entering generic post-assault recovery.
- Latest strategic AI completed slice: `strategic-ai-commander-outcome-adaptation-10184` makes commander target-selection fit adapt from live outcome memory: repeated success at a target kind increases future task fit for that kind, while defeats reduce it, without a save-version bump or public debug leakage.
- Current strategic AI follow-up: use the new long-run progress telemetry to reduce the strict Small Native RMG enemy-turn bottleneck now measured inside `OverworldRules.end_turn`/enemy turn execution, then broaden the generated-map runner from focused smoke into the full 100-seed eight-week matrix and continue deeper generated-map army/economy timing, retreat/personality, Medium/generalized generated-map behavior, and live-client pacing review. Guarded object routing, encounter-arrival risk, hero-intercept risk, town-assault risk, defended-town capture stationing, adaptive commander outcome memory, coordinated pre-deployment task planning, task-board recruitment prep, multi-origin planning, resource-front support, neutral-town expansion, neutral-town post-capture garrisoning, Small generated-map turn health, planned-task ready launch, site contest event surfacing, commander personality task fit, destination-aware recruitment, recruitment market coverage, planned-task build preparation, and focused long-run smoke are not a full strategic AI release-readiness claim.
- Current battle-presentation target: battle resolution should emit a readable event stream for movement, strikes, shots, spell casts, damage, healing, status changes, resisted/immune outcomes, deaths, retaliation, morale/cohesion, and momentum; the battle scene should consume that stream with normal/fast/instant playback controls while keeping combat math unchanged.
- Use the fast battle-balance benchmark evidence to tune faction-pair combat spread now that fake round-cap outcomes have been removed, the public benchmark report uses side-neutral `side_a`/`side_b` terminology, and spell-enabled benchmark availability follows the same Native RMG week surface as army snapshots.
- Before more broad unit-stat nudges, strengthen the magic system as a strategic layer: spell availability, school coverage, field-magic access, and player-readable town/generated-map spell study should improve before trying to balance magic-focused heroes against raw-combat heroes.
- Latest magic follow-up: resistance and counter-control mechanics now run in live battle and in the fast benchmark before remaining spell-enabled benchmark outliers are treated as pure faction/unit imbalance.
- Campaign production remains deferred until explicitly selected in a later phase.

## Selectable Near-Term Work

Before starting any item, add or select a concrete slice in `ops/progress.json`, mark it `in_progress`, and keep validation evidence there.

Recommended next slices:
- `strategic-ai-long-run-seed-matrix-10184`: expand strategic AI validation from focused fixtures into multi-week generated-map seed matrices once task ownership is durable enough to measure.
- `strategic-ai-multi-origin-task-planner-10184`: make coordinated task-board planning evaluate all owned towns/spawn origins and persist the selected origin on planned tasks.
- `strategic-ai-same-turn-task-prep-10184`: make the live enemy turn plan commander objectives before town recruitment so same-turn recruitment can prepare newly planned tasks.
- `strategic-ai-planned-task-recruitment-prep-10184`: make town recruitment prepare durable planned commander objectives before those objectives spawn as active raids, with emergency garrison and true rebuild priority preserved.
- `combat-faction-pair-stat-tuning-10184`: tune unit stats, growth, and ability power from the full benchmark outlier rows to reduce deterministic faction-pair win-rate spread.
- `battle-spell-valuation-counterplay-followup-10184`: tune spell AI valuation and counterplay from the spell-enabled benchmark evidence, especially heavy control preference, before treating the new outlier set as pure unit-stat imbalance.
- `battle-layout-smoke-followup-10184`: continue battle layout smoke only if the prior manual stop left actionable evidence or a reproducible UI/runtime issue.
- `strategic-ai-quality-pass-10184`: selected for the baseline KPI harness/audit. Do not treat it as full strategic AI production readiness.
- `rmg-small-generalization-hardening-10184`: harden strict Small generated-map evidence without claiming larger sizes, water, underground, or broad template parity.
- `ux-polish-player-comprehension-10184`: improve onboarding, tooltips, town planning clarity, battle intent feedback, save/load confidence, and reduce debug-like seams.
- `packaging-platform-readiness-followup-10184`: continue clean Windows/Linux packaging and smoke-test hardening.
- `headless-balance-harness-next-10184`: expand automated balance harness depth before scaling content.

Do not select:
- campaign/scenario production breadth unless the owner explicitly changes priority;
- broad RMG parity claims from strict Small evidence;
- final art direction, final audio, or release packaging claims from generated/runtime placeholder layers;
- new validation gates that merely make reports pass without improving player-readable game behavior.

## Magic Availability And Strategic Influence Target

The immediate magic slice should improve what players can learn and do with magic without pretending that magic-focused heroes and raw-combat heroes are balanced yet.

Target shape:
- the live authored spell catalog should stay above a 100-spell floor before balance work treats magic variety as credible;
- every live magic school should have broad authored spell presence, with at least a dozen schema-valid spells per school;
- overworld magic should have at least 20 authored spells across movement and scouting support;
- spell tiers must carry real numeric meaning: tier 1 spells are cheap and limited, tiers 2-3 are useful/strong midgame tools, tier 4 spells are major swings, and tier 5 spells are expensive very-strong effects;
- tier scaling should apply to mana costs, damage and power scaling, wounded bonuses, buff/control duration, modifier magnitude, recovery, movement restoration, and scouting radius;
- every authored town should reach tier 5 spell study through its full development tree without extending the existing town-development day target;
- every authored spell should be reachable through fully developed town study access, not left as catalog-only content;
- Native RMG/generated spell rewards should include tier 1-5 candidates across all schools, even though town development remains the primary full-catalog access path;
- town study should expose faction school access plus Old Measure access by spell tier instead of relying only on short hand-authored per-town lists;
- town study should expose more than faction-flavored battle buffs/damage, especially field scouting and route tools;
- Native RMG/generated reward pools should include multiple spell-access candidates instead of only Beacon Path;
- new field effects must mutate bounded strategic state directly, not just add another report surface;
- no rare-resource spell-cast costs, caster-unit system, school mastery, or final magic-vs-might balance claim is part of this work.

## Economy Rare-Resource Target

The current economy identity pass moves towns away from a one-signature-rare model. Balance evidence for map-source access must be based on Native RMG generated packages for this slice, not authored scenario maps.

Target cost-pressure model for every town template:
- Every rare resource should appear in at least one town-development cost.
- The town faction's signature rare resource should remain the highest-pressure rare and should still define the core late-game faction bottleneck.
- One secondary rare resource should create about half as much pressure as the faction signature rare.
- Each remaining rare resource should create about one-third as much pressure as the faction signature rare.
- `gold`, `wood`, and `ore` should remain the dominant common-resource development shape; multi-rare costs should not turn the economy into all-rare-only pricing.
- Rare-resource use should create meaningful player choices in different building categories, not just append small costs to arbitrary filler buildings.
- Native RMG generated-package support, guarded access, AI town development, and player-facing town UI must be updated with the cost model so every required rare can be acquired through play.

Example pressure interpretation if a faction's signature rare target remains near the current 28-30 total spend:
- faction signature rare: roughly 28-30 total pressure;
- secondary rare: roughly 14-15 total pressure;
- each remaining rare: roughly 9-10 total pressure.

Implemented target at this point:
- signature rare: 28-30 total pressure depending on existing faction-specific upgrade costs;
- secondary rare: 14 total pressure;
- each remaining rare: 9 total pressure;
- all six rare resources appear in high-tier unit-building costs for every faction ladder.

## Battle Balance Benchmark Target

The selected battle-balance slice is a fast Python benchmark, not a final combat tuning claim. It should use current content and port the live battle math closely enough to make faction matchup iteration cheap before wider tactical tuning.

Required benchmark shape:
- pure Python, no Godot runtime for normal benchmark runs;
- live `content/*.json` faction, unit, hero, spell, town, and building data;
- hero spellbooks should include starting battle spells plus Native-RMG week-tier town-study battle spells from faction school access; authored representative-town build timing must not shape the faction matrix;
- reports should expose per-week spellbook coverage and actual spell-cast summaries by school, tier, effect, and faction;
- ordered non-self faction matrix for all six factions;
- deterministic seed count, with `--quick`, `--seeds`, `--weeks`, `--json`, and `--gate` options;
- week 1 army snapshots: initial starting growth plus one recruited week capped at T1-T3;
- week 2 snapshots: initial starting growth plus week-one T1-T4 and week-two T1-T5 recruitment;
- week 3 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three T1-T7 recruitment;
- week 4 snapshots: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three/week-four T1-T7 recruitment with fully developed growth for final full-tier ticks;
- JSON report rows for win rates, average rounds, action mix, casualties by tier, battle consequences, pair summaries, week summaries, and outliers.

Initial target bands:
- faction-pair dominant win rates should land within 45-55% before the combat-balance goal is complete;
- ordered faction rows, outcomes, casualties, and week side-bias summaries should use `side_a`/`side_b`, not scenario ownership labels;
- army snapshots should use Native RMG-suitable faction/unit growth rather than authored representative-town build logs;
- side bias should stay low;
- no fake stalemate outcome should exist in benchmark data; emergency simulation guard hits are structural failures;
- average rounds should remain readable, and later-week battles should take more turns on average than early battles.

The first benchmark should report outliers as tuning evidence. Do not tune away failures blindly just to make the initial benchmark look green.

## Magic Resistance And Counter-Control Target

The current magic slice turns resistance and counter-control from artifact/theme metadata into live battle mechanics.

Target shape:
- units define bounded `spell_resistance_pct`, `control_resistance_pct`, `spell_school_resistance_pct`, and `status_immunity_ids`;
- T1-T3 units have no general natural resistance, T4-T5 gain light spell resistance, T6-T7 gain stronger spell and control resistance, and faction-school units gain modest own-school resistance;
- hero knowledge contributes bounded incoming spell/control resistance through battle payloads;
- artifacts can add live spell, control, and school resistance bonuses, starting with Choir Tuning Fork;
- cleanse/countermagic spells grant temporary immunity to the statuses they cleanse;
- spell damage is mitigated but still lands for at least one damage, while status/control riders can be resisted or blocked by immunity;
- mana is consumed even when the target resists or is immune;
- guard/status control tiles and tactical status effects remain engagement metadata, not a replacement for body blocking or damage resolution;
- Battle AI and the fast benchmark value expected resisted damage and control success chance instead of assuming all spells land fully;
- the fast benchmark reports resisted spells, immunity blocks, prevented damage, and top resisted spell ids.

Non-goals:
- do not claim final magic-vs-might or faction battle balance from this slice;
- do not add caster-unit spellbooks, rare-resource spell-cast costs, or school mastery;
- do not add broad new report gates beyond one focused resistance/counter-control runtime report.

## Slice Status Model

Each executable slice should map to one `ops/progress.json` entry with:
- `id`: stable slice id ending in `-10184`.
- `phase`: project phase.
- `purpose`: why the slice exists.
- `sourceDocs`: source requirements or evidence docs.
- `implementationTargets`: expected files/systems/content/tooling/report surfaces.
- `baselineChecks`: generic health checks required before completion.
- `sliceEvidence`: focused proof that the slice requirement was met.
- `completionCriteria`: objective completion bar.
- `nonGoals`: explicit boundaries when scope is risky.

Valid operational statuses:
- `pending`: planned, not started.
- `in_progress`: active implementation or review.
- `blocked`: cannot proceed; blocker must be named.
- `completed`: implementation and validation meet criteria.
- `docs_ready`: requirements/design/report exists; implementation is not complete.
- `paused`: intentionally delayed until selected again.
- `pending_after_implementation`: review/gate slice waiting for implementation output.
- `superseded`: replaced by a later accepted slice/path.

## Work Selection Gates

Before starting any worker:
1. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`.
2. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`.
3. Confirm or create the selected slice with source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

State: complete unless document/process drift reappears.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

State: complete as proof history. Reopen only for regressions or explicit owner direction.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

State: foundation evidence is broad but not product completion. Completed implementation/report evidence lives in `ops/progress.json` and `docs/`.

### Phase 3 - HoMM3-Style Random Map Generator Rework

Goal: translate HoMM-style random-map structure into original content and systems.

Current boundary:
- Strict Small 36x36 one-level land package/session evidence exists.
- The H3MapEd recovery ledger is prerequisite evidence only. It does not mean the native generator has achieved true end-to-end RMG parity.
- Immediate RMG work is native adoption/porting from the recovered private-state replay, followed by Python-owned native-vs-H3MapEd comparison for land-only Small/Medium outputs.
- Larger sizes, water, underground, broad template families, final reward ecology, and true native end-to-end parity remain incomplete.
- Native/generated package adoption evidence must remain scoped and must not be presented as broad RMG production readiness or as a recovery-ledger completion proxy.

### Phase 4 - Headless AI Agent Balance Harness

Goal: run scenarios, economy loops, battles, AI turns, and balance checks faster than manual UI play.

State: meaningful harness/report foundations exist. Further work should make balance changes cheaper and more player-relevant, not merely add pass/fail surfaces.

### Phase 5 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Current emphasis:
- economy and town development are strongly validated but still need deeper faction identity;
- battle and strategic AI need quality and balance passes;
- UX should prioritize player comprehension over debug/report visibility;
- Native RMG generated Small-map source support and guard pressure are the selected economy balance surface;
- authored rare-source breadth is deferred until authored-map work is explicitly selected again.

Exit criteria remain:
- multiple scenarios/skirmish setups work end-to-end;
- at least two factions are meaningfully playable and distinct;
- town, battle, overworld, save/load, AI, economy, and UI loops hold together under repeated play;
- major UX surfaces are understandable without debug/report panels.

### Phase 6 - Production Alpha Layer

Goal: expand alpha into a production-shaped game slice.

Do not enter broadly until Phase 5 playable-alpha evidence is stable and owner-approved.

### Phase 7 - Broad Production Breadth

Goal: expand into a broad original fantasy strategy package with the systemic breadth, density, and replayability expected from classic Heroes-style strategy games.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or the owner explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape:
- `project.md` contains durable strategy and current strategic focus.
- `PLAN.md` contains compact tactical state, selection rules, and near-term slice candidates.
- `ops/progress.json` contains operational status, detailed evidence, validation history, and completed-slice records.
