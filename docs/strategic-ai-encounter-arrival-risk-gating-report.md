# Strategic AI Encounter Arrival Risk Gating Report

Status: implementation evidence for `strategic-ai-encounter-arrival-risk-gating-10184`.

## Implemented Behavior

- `EnemyAdventureRules.advance_raids(...)` now passes enemy config into arrival resolution so arrival retasks can emit normal public-safe AI target events.
- `encounter_arrival_ready_report` compares the arriving host against the target encounter guard strength and the host's desired raid strength before allowing encounter resolution.
- `_encounter_guard_strength` reads placement-specific `enemy_army` first and falls back to the authored encounter army group.
- `redirect_encounter_objective_for_risk` keeps underpowered encounter-objective hosts from clearing or contesting the site. It redirects them to a reachable same-faction regroup town with `encounter_risk_regroup`, or stages them at the front with `encounter_risk_staging` if no regroup town is reachable.
- Saved encounter task continuity remains active while the host regroups or stages; the task is completed only after a ready host actually clears or contests the encounter.
- `ai_active_front_support_target_selection_plan` lets a new deployable commander recognize an active same-faction front that is waiting for support and deliberately target that front instead of selecting an unrelated raid objective.
- Active-front support planning now accounts for already-committed support strength and refuses support-chain targets, preventing multiple commanders from dogpiling the same front after the open strength gap is already covered.
- Active-front support task persistence now uses `stabilize_front` with a shared-front reservation, so reinforcing commanders do not steal the leader's exclusive objective reservation or block saved objective-task reuse.
- `group_nearby_raids_for_town_assault` now also consolidates adjacent same-faction commander support on shared encounter fronts, so objective/guarded encounter pressure can become one stronger host instead of isolated small raids.

## Focused Evidence

`AI_HERO_TASK_ENCOUNTER_OBJECTIVE_REPORT` now covers both sides of the behavior:

- `objective_front_encounter_assigns_reuses_and_closes_task`: a strong Vaska host reaches `causeway_levee_cutters` through live `advance_raids(...)`, resolves the guarded objective, and completes the active encounter task.
- `weak_encounter_objective_regroups_before_clear`: a Vaska host that is above the generic raid regroup floor but below the Reed Totemists guard requirement does not resolve the objective, keeps the encounter task active, records `encounter_risk_regroup`, emits `ai_target_assigned`, and sets a future `encounter_arrival_delay_until_day`.
- `active_front_support_groups_for_encounter_objective`: Sable receives an `active_front_support` assignment to reinforce Vaska's `causeway_levee_cutters` front, then the normal raid advancement path emits `ai_raid_grouped` and merges Sable's host into Vaska's encounter-objective army.
- The same case verifies `overcommit_plan_empty_after_support`: once Sable's committed host covers the front's open support gap, a third commander no longer receives another active-front support assignment for that same front or for Sable's support column.
- The same case verifies `support_task_class: stabilize_front`, `support_reservation_scope: shared_front`, and `leader_saved_plan_preserved: true`, proving support assignments remain durable without invalidating the leader's objective task.

No save migration is introduced; `SAVE_VERSION` remains unchanged.

## Boundary

No full strategic AI quality claim. This slice closes concrete production behavior holes: guarded encounter objectives no longer give weak AI raids free progress on arrival, and active encounter fronts can now request live support from another commander. Broader release-ready AI still needs long-run generated-map evidence, stronger multi-week planning, broader front coordination, retreat timing review, and manual live-client pacing checks.
