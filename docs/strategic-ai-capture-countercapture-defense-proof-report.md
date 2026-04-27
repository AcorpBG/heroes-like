# Strategic AI Capture Counter-Capture Defense Proof Report

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-site-control-proof-report-10184`.

## Scope

This report proves the narrow Mireclaw `river-pass` signal-yard site-control path selected in `docs/strategic-ai-capture-countercapture-defense-proof-plan.md`.

Primary site: `river_free_company`.

Companion site: `river_signal_post`.

This slice added focused Godot report scaffolding only. It did not tune coefficients, change AI behavior, edit production JSON, add durable event logs, migrate saves, implement full AI hero task state, change pathing/body tiles/approach behavior, alter renderer/editor behavior, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, rebalance River Pass, import generated PNGs, push, or open a PR.

## Focused Report

Command:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
```

Result: passed. The command printed `AI_SITE_CONTROL_PROOF_REPORT` with `"ok": true`.

## Meaningful Output

With `river_free_company` and `river_signal_post` staged as player-controlled persistent sites, the focused resource ordering from Mireclaw origin `{x: 7, y: 1}` is:

1. `river_free_company`
2. `river_signal_post`
3. `river_sanctum`
4. `north_wood`
5. `midway_shrine`
6. `eastern_cache`

`river_free_company` carries public reason `recruit and income denial` with reason codes including `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`.

`river_signal_post` carries public reason `income and route vision denial` with reason codes `persistent_income_denial`, `route_vision`, and `player_town_support`.

The full `choose_target(...)` sanity check still chooses:

- `target_kind`: `town`
- `target_placement_id`: `riverwatch_hold`
- `target_debug_reason`: `town siege and objective pressure`

This is accepted and recorded. The proof does not force resource targets globally above the town-front selector.

## Assignment And Seizure

The focused assignment event for Free Company is:

- `event_type`: `ai_target_assigned`
- `target_id`: `river_free_company`
- `public_reason`: `recruit and income denial`
- `public_importance`: `high`
- `reason_codes`: includes `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`
- `state_policy`: `derived`

The staged current-system raid arrival flips Free Company control:

- before: `player`
- after: `faction_mireclaw`

The resulting seizure event is:

- `event_type`: `ai_site_seized`
- `target_id`: `river_free_company`
- `public_reason`: `recruit and income denial`
- `public_importance`: `high`
- `reason_codes`: includes `site_seized`, `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`
- `state_policy`: `durable_state_reference`
- summary includes compact logistics denial wording: `denies its logistics route`

The current `_secure_resource_target(...)` effects are visible in the report:

- pressure before: `0`
- pressure after: `1`
- treasury before: `{}`
- treasury after: `{"gold": 80}`

## Public Surface Check

The public leak check passed for the assignment and seizure events.

Public events did not expose score-table keys such as `base_value`, `persistent_income_value`, `recruit_value`, `denial_value`, `assignment_penalty`, or `final_priority`.

Detailed score fields remain in the report/debug `top_resource_targets` rows, which is intentional for this proof. They are not present in compact public event records.

## Validation

Passed:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
```

## Caveats

- This is deterministic proof scaffolding, not a live-client enemy-turn pacing transcript.
- The raid arrival is staged at the target to prove current seizure/controller-flip behavior directly.
- `southern_ore` remains a named simple-pickup comparator but is not present in the reachable focused ordering from this origin.
- No coefficient defect was found, so bounded coefficient tuning is not the next slice.

## Gate Decision

Pass.

Current systems prove the selected Mireclaw River Pass signal-yard site-control path: player-owned `river_free_company` and `river_signal_post` are high-value denial targets, Free Company outranks Signal Post for the expected recruit-plus-income reason, a Mireclaw raid can seize Free Company and flip its controller, compact assignment/seizure events carry the expected reasons, and public events do not leak score-table fields.

## Recommended Next Slice

Recommended next slice: `strategic-ai-glassroad-defense-proof-planning-10184`.

Rationale: the site-control proof did not expose a coefficient defect, so tuning should remain deferred. The next best AI foundation slice is to plan a bounded Embercourt Glassroad defense/stabilization proof around `glassroad_watch_relay` and `glassroad_starlens`, using the current compact public/debug event vocabulary while checking whether defense-specific behavior needs explicit state.
