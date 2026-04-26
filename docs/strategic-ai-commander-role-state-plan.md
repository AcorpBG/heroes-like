# Strategic AI Commander Role State Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-state-planning-10184`.

## Purpose

Plan explicit commander-role state boundaries after the passed Mireclaw site-control proof and Embercourt Glassroad defense proof.

The core decision is that the next strategic AI gap is commander-role continuity for non-staged behavior. Current assignment, seizure, controller-flip, town-governor, and compact public event surfaces are enough for the proved staged site-control and defense cases. The next work should not tune coefficients or add defense-specific durable state just because future commander behavior needs a clearer owner.

This slice is documentation/planning only. It does not change AI behavior, production JSON, coefficients, scenario balance, durable event logs, save migration, full AI hero task state, defense-specific durable state, pathing/body-tile/approach behavior, renderer/editor behavior, generated PNG import, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare-resource activation, market caps, or River Pass balance.

## Evidence Baseline

Passed proof reports:

- `docs/strategic-ai-capture-countercapture-defense-proof-report.md` proves current Mireclaw `river-pass` signal-yard site control: `river_free_company` and `river_signal_post` order correctly when player-controlled, Free Company assignment and staged seizure emit compact public events, controller state flips to `faction_mireclaw`, and the full selector can still legitimately choose `riverwatch_hold`.
- `docs/strategic-ai-glassroad-defense-proof-report.md` proves current Embercourt `glassroad-sundering` defense/stabilization surfaces: `glassroad_watch_relay` and `glassroad_starlens` order correctly, `halo_spire_bridgehead` remains the accepted town-front sanity target, relay assignment and staged retake/controller flip work, Starlens exposes its stabilization profile, and Riverwatch town-governor garrison stabilization is visible.
- `docs/strategic-ai-strategy-config-audit-report.md` classifies current Embercourt/Mireclaw config as coherent enough to avoid immediate tuning. It explicitly names commander-role/task-state personality as missing evidence.
- `docs/strategic-ai-faction-personality-evidence-report.md` supports early Embercourt and Mireclaw pressure identities, but does not prove distinct commander doctrine beyond shared raid/rebuild surfaces.
- `docs/strategic-ai-foundation.md` already names the production target: real AI hero roles, active tasks, target ids, recovery, memory, movement, objective play, and event surfacing.

Current code inspection:

- `EnemyAdventureRules.gd` already carries useful commander continuity seeds: `status`, `active_placement_id`, `recovery_day`, `last_outcome`, deployments, wins, defeats, renown, `target_memory`, `army_continuity`, and embedded `commander_state`.
- `EnemyAdventureRules.assign_target(...)` records target assignment memory and current raid targets.
- `EnemyAdventureRules.choose_target(...)` can apply commander memory pressure to candidates, but it does not own a durable role/task contract.
- `EnemyTurnRules.gd` already normalizes enemy states with `commander_roster`, advances raids, reinforces active raids, and rebuilds commander hosts through town recruitment.
- `content/factions.json` already differentiates Embercourt and Mireclaw strategy weights, but has no explicit commander-role profile fields yet.

## Boundary Decision

Do not replace the current raid commander model in one step.

For the next stage, keep three layers separate:

| Layer | Current or future | Boundary decision |
| --- | --- | --- |
| Raid encounter fields | Current | Continue to own active spawned raid placement, movement toward a target, arrival, and seizure/contest resolution. |
| Commander roster continuity | Current compatibility state | Continue to own named commander identity, availability, recovery day, record/renown, target memory, and army continuity. |
| Commander role state | Future minimal state | Plan a narrow durable role/task boundary that can assign a commander to raid, defend, retake, recover, or rebuild without becoming full AI hero state yet. |

The future `commander_role_state` should be a small per-roster-entry state record, not a broad faction planner and not a replacement for eventual full AI hero state. It should answer these questions only:

- What role is this commander currently expected to perform?
- What target or front owns that role?
- Is the role still valid this turn?
- Which public/debug reason explains the role?
- What happens if the commander is defeated, stranded, rebuilt, or retasked?

## Minimal Future State Boundary

Proposed future record, nested under each `commander_roster[]` entry only after a later schema slice approves it:

```json
{
  "commander_role_state": {
    "schema_version": 1,
    "role": "raider",
    "role_status": "assigned",
    "assignment_id": "faction_mireclaw:day_4:river_free_company",
    "target_kind": "resource",
    "target_id": "river_free_company",
    "target_label": "Riverwatch Free Company Yard",
    "front_id": "riverwatch_signal_yard",
    "origin_kind": "town",
    "origin_id": "duskfen_bastion",
    "priority_reason_codes": ["persistent_income_denial", "recruit_denial"],
    "public_reason": "recruit and income denial",
    "debug_reason_ref": "report_only",
    "assigned_day": 4,
    "expires_day": 7,
    "continuity_policy": "persist_until_invalid",
    "fallback_role": "recovering",
    "last_validation": "valid"
  }
}
```

Allowed initial role values:

| Role | Meaning | First evidence use |
| --- | --- | --- |
| `raider` | Presses a player town, hero, site, artifact, or encounter through current raid movement. | Mireclaw Free Company / Signal Post denial. |
| `defender` | Protects an AI-owned town or high-value site by staying local, reinforcing, or intercepting. | Future non-staged Glassroad relay/front defense. |
| `retaker` | Prioritizes recapturing a recently player-controlled or faction-critical site. | River Pass and Glassroad current retake proofs. |
| `stabilizer` | Supports a town/site/front after capture through garrison/recovery/town-governor pressure. | Starlens and Riverwatch governor surfaces. |
| `recovering` | Holds a defeated or depleted commander out of assignment until recovery/rebuild is ready. | Existing recovery/rebuild surfaces. |
| `reserve` | Available but not currently committed. | Existing available commander roster. |

Values deliberately not included yet:

- No `scout`, `collector`, `main_army`, `courier`, `objective_runner`, spell user, artifact hunter, or full route planner roles until full AI hero state planning resumes.
- No path arrays, movement point budgets, fog memory, spell plans, artifact equipment plans, or tactical intent payloads.
- No defense-specific durable site state such as `site_defended_until_day`; role state may target a defensive front, but site controller/response state remains the authoritative world state.

## Role Boundary By Behavior

### Non-Staged Assignment

Future role state should record that a commander was assigned to a role and target before movement, not infer it only from a staged proof fixture.

Minimum boundary:

- `role`
- `target_kind`
- `target_id`
- `assigned_day`
- `public_reason`
- `priority_reason_codes`
- `continuity_policy`

The active raid encounter can still carry `target_kind`, `target_placement_id`, goal coordinates, and arrival state. The role state should be the commander's continuity owner, while the encounter stays the map actor.

### Defense

Defense should not get bespoke durable state yet.

Minimum boundary:

- `role: "defender"` or `role: "stabilizer"`
- `target_kind: "town"` or `"resource"`
- `front_id`
- `origin_id`
- `expires_day`
- `last_validation`

The role is valid only while the target/front still matters. If the player leaves, the site flips, or a town-front threat changes, the role can become `reserve`, `raider`, or `retaker` on the next planning pass.

### Raid

Current raids already work as active map actors. Role state should not duplicate every encounter field.

Minimum boundary:

- Commander role says why this commander is raiding.
- Raid encounter says where the raid is and how it moves.
- Target memory says what the commander has repeatedly pressured.
- Public event records explain assignment and major outcomes.

### Recovery And Rebuild

Existing recovery and army continuity are good enough to keep.

Future role state should only normalize the semantic transition:

- defeated or shattered host: `role: "recovering"`, `role_status: "cooldown"` or `"rebuilding"`.
- rebuilt host: `role: "reserve"` until a new assignment is made.
- scarred but deployable host: role can persist if target remains valid, but validation must expose the risk in debug/report output.

### Commander Continuity

Continuity should be anchored to `roster_hero_id`.

Stable facts:

- identity, record, renown, target memory, and army continuity belong to the roster entry.
- active encounter placement is a transient deployment reference.
- a future role state should remain attached to the roster entry across active, recovering, and reserve states until invalidated or superseded.

### Personality Pressure

Do not add faction-wide commander doctrine fields yet.

Near-term personality should be expressed through:

- existing faction strategy weights,
- role selection reports,
- public reason codes,
- town governor reinforcement choices,
- commander memory and recovery/rebuild pressure.

Future schema questions can decide whether faction data needs `preferred_commander_roles`, `role_bias`, or `retask_tolerance`. That should wait until report fixtures prove the current weights cannot explain Embercourt versus Mireclaw role choices.

## Schema Questions To Resolve Later

Before production schema implementation, answer these in a separate schema planning slice:

- Should `commander_role_state` live directly on `commander_roster[]`, or should `enemy_states[].commander_roles` be an id-keyed side table?
- Is `assignment_id` required, and can it be derived deterministically from faction/day/roster/target instead of saved?
- Does `front_id` need authored content support, or can early fronts be derived from town/site/objective ids?
- Should `role_status` be a simple enum (`assigned`, `active`, `invalid`, `cooldown`, `rebuilding`) or inferred from existing `status`, `active_placement_id`, and `army_continuity`?
- How much of `public_reason` should be saved versus recomputed from reason codes and current target data?
- How should role state survive scenario scripts that spawn raids without a roster commander?
- What is the minimum migration rule for old saves with commander roster entries but no role state?
- How should role state handle multiple active raids when a faction has fewer available named commanders than spawned encounters?
- Should future full AI hero state absorb this record unchanged, or should it become an adapter from old saves?

## Report Surfaces

The next report work should be planned before schema implementation.

Recommended report marker for a later report implementation: `AI_COMMANDER_ROLE_STATE_REPORT`.

Report-only surfaces should include:

- per-faction commander roster summary,
- active commander and active encounter linkage,
- proposed role per commander,
- current target and target memory,
- role validity result,
- recovery/rebuild status,
- expected next transition,
- public reason phrase,
- report-only debug reason,
- leak check showing public role events do not expose score tables.

Suggested report cases:

1. `mireclaw_free_company_retaker`
   - `river-pass`, `faction_mireclaw`, player owns `river_free_company`.
   - Expected proposed role: `retaker` or `raider` targeting `river_free_company`.
   - Public reason: `recruit and income denial`.

2. `mireclaw_signal_post_companion`
   - `river-pass`, player owns `river_signal_post`.
   - Expected proposed role: `retaker` or `raider` targeting `river_signal_post` when Free Company is unavailable or already covered.
   - Public reason: `income and route vision denial`.

3. `embercourt_glassroad_relay_defender`
   - `glassroad-sundering`, `faction_embercourt`, relay/starlens staged as contested.
   - Expected proposed role: `retaker`, `defender`, or `stabilizer` depending on controller and threat state.
   - Public reason: relay uses `income and route vision denial`; Starlens may remain `route pressure` until metadata improves.

4. `commander_recovery_blocks_assignment`
   - Any focused fixture with a recovering or shattered commander.
   - Expected proposed role: `recovering`; no active assignment unless another available commander exists.

5. `commander_memory_continuity`
   - Repeated pressure on the same target should carry target memory into the proposed role explanation without forcing coefficient tuning.

The first report planning slice should not implement these reports yet. It should define exact fixture setup, expected fields, and pass/fail criteria.

## Validation Strategy

For this planning slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

For the future report fixture planning slice:

- No runtime behavior changes.
- Define fixture cases against current `river-pass` and `glassroad-sundering` content.
- Require existing AI focused reports as evidence references, not rerun targets unless a report implementation follows.
- Keep score tables debug/report-only and public output compact.

For the future report implementation slice, add focused Godot coverage only after report fixture planning is complete:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Manual live-client gate stays deferred unless a future slice changes visible enemy-turn pacing, turn text, raid cadence, arrival frequency, map pressure, pathing, save state, production scenario content, or UI composition.

## Save And Migration Risks

Do not add save migration in the next slice.

Risks to record before any schema work:

- Existing saves may already contain `enemy_states[].commander_roster[]` with normalized records but no role state.
- Current active raids may contain embedded `enemy_commander_state`; role state must not desync from those embedded records.
- Scenario scripts can spawn encounters without a roster commander. A migration must not require every spawned raid to have a role owner.
- Recovery day and army continuity already have durable meaning. A new role status must not contradict them.
- Saving public reason text can create stale text after content renames or reason-vocabulary changes. Prefer reason codes plus recomputation unless a bounded event log is explicitly approved later.
- Full AI hero task state will eventually need migration. The minimal commander-role state should be designed as an adapter-friendly stepping stone, not a dead-end schema.

## Staged Proof Order

Recommended order after this planning slice:

1. `strategic-ai-commander-role-report-fixture-planning-10184`
   - Plan exact deterministic fixture cases and report payloads for commander role proposals using River Pass and Glassroad proof states.
   - No code, no schema, no save migration.

2. `strategic-ai-minimal-commander-role-state-schema-planning-10184`
   - Decide exact field location, enums, normalization defaults, compatibility behavior, and migration policy.
   - Still no runtime behavior adoption.

3. `strategic-ai-commander-role-report-implementation-10184`
   - Add report-only helpers and focused Godot coverage if the fixture plan is accepted.
   - No target ordering or coefficient changes.

4. `strategic-ai-commander-role-state-fixture-implementation-10184`
   - Add fixture-only or report-only state normalization if needed.
   - Do not write production saves or make live behavior depend on it yet.

5. `strategic-ai-live-client-gate-planning-10184`
   - Plan a manual enemy-turn gate only after role reports or state adoption affect visible turn playback, arrival frequency, or player-facing threat composition.

Full AI hero task state, pathing/body-tile/approach adoption, defense-specific durable state, durable event logs, and production save migration remain later work.

## Completion Decision

Commander-role state planning is complete as a boundary document.

Recommended next current slice: `strategic-ai-commander-role-report-fixture-planning-10184`.

Rationale: the state boundary is now clear enough to plan report fixtures, but not clear enough to implement schema or save migration. A report fixture plan should turn the passed site-control and Glassroad proofs into exact commander-role cases before any field is added to production state.
