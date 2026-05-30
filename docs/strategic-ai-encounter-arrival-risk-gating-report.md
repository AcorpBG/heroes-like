# Strategic AI Encounter Arrival Risk Gating Report

Status: implementation evidence for `strategic-ai-encounter-arrival-risk-gating-10184`.

## Implemented Behavior

- `EnemyAdventureRules.advance_raids(...)` now passes enemy config into arrival resolution so arrival retasks can emit normal public-safe AI target events.
- `encounter_arrival_ready_report` compares the arriving host against the target encounter guard strength and the host's desired raid strength before allowing encounter resolution.
- `_encounter_guard_strength` reads placement-specific `enemy_army` first and falls back to the authored encounter army group.
- `redirect_encounter_objective_for_risk` keeps underpowered encounter-objective hosts from clearing or contesting the site. It redirects them to a reachable same-faction regroup town with `encounter_risk_regroup`, or stages them at the front with `encounter_risk_staging` if no regroup town is reachable.
- Saved encounter task continuity remains active while the host regroups or stages; the task is completed only after a ready host actually clears or contests the encounter.

## Focused Evidence

`AI_HERO_TASK_ENCOUNTER_OBJECTIVE_REPORT` now covers both sides of the behavior:

- `objective_front_encounter_assigns_reuses_and_closes_task`: a strong Vaska host reaches `causeway_levee_cutters` through live `advance_raids(...)`, resolves the guarded objective, and completes the active encounter task.
- `weak_encounter_objective_regroups_before_clear`: a Vaska host that is above the generic raid regroup floor but below the Reed Totemists guard requirement does not resolve the objective, keeps the encounter task active, records `encounter_risk_regroup`, emits `ai_target_assigned`, and sets a future `encounter_arrival_delay_until_day`.

No save migration is introduced; `SAVE_VERSION` remains unchanged.

## Boundary

No full strategic AI quality claim. This slice closes one concrete production behavior hole: guarded encounter objectives no longer give weak AI raids free progress on arrival. Broader release-ready AI still needs long-run generated-map evidence, stronger multi-week planning, smarter army consolidation, retreat timing review, and manual live-client pacing checks.
