# Strategic AI Commander Role Report Gate Review

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-report-gate-review-10184`.

## Scope

This gate reviews the report-only `AI_COMMANDER_ROLE_STATE_REPORT` output before any commander-role schema writes, save migration, durable event logs, defense-specific durable state, coefficient tuning, full AI hero task state, or live commander-role behavior adoption.

This review does not approve production JSON edits, behavior tuning, durable events, save migration, `commander_role_state` writes, live commander-role selection, full AI hero movement/task implementation, pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, market-cap overhaul, or River Pass rebalance.

## Focused Report Results

Reran:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
```

Result: passed. The command printed `AI_COMMANDER_ROLE_STATE_REPORT` with `"ok": true` and `schema_status: "report_fixture_only"`.

Meaningful output:

- `mireclaw_free_company_retaker`: Vaska Reedmaw receives a `retaker` proposal for `river_free_company`; Free Company is resource rank 1, the public reason is `recruit and income denial`, and the full selector can still choose `riverwatch_hold`.
- `mireclaw_free_company_raider`: the same target can be represented as `raider` under denial-only fixture state without coefficient tuning.
- `mireclaw_signal_post_companion`: Sable Muckscribe receives a companion `raider` proposal for `river_signal_post`; Signal Post is resource rank 2 behind Free Company, with public reason `income and route vision denial`.
- `embercourt_glassroad_relay_defender`: Caelen Ashgrove receives a `defender` proposal for AI-controlled `glassroad_watch_relay` when the player front threatens it. This remains a report-only defense view and does not create site-specific durable defense state.
- `embercourt_glassroad_relay_retaker`: the same relay becomes a `retaker` target after player capture, with Glassroad Watch Relay resource rank 1 and the full selector still able to choose `halo_spire_bridgehead`.
- `embercourt_glassroad_stabilizer`: Seren Valechant receives a `stabilizer` proposal for AI-controlled `glassroad_starlens`; the supporting evidence includes the existing `Relight Shrine` response profile.
- `commander_recovery_blocks_assignment`: recovering Vaska is blocked with `role: recovering`, `role_status: cooldown`, while available Sable can still receive a Free Company `retaker` proposal.
- `commander_memory_continuity`: Vaska's Free Company target memory appears in report/debug continuity without leaking raw memory counters to the public event.

The recursive public leak check inspected 8 public role events and passed. Public events stayed compact: event ids, actor/target ids and labels, public importance, reason codes, one public reason phrase, summary, compact debug reason, and `state_policy: "derived"`. Score-table fields, fixture annotation names, and raw memory counters remained out of public events.

## Gate Decision

Pass.

The report-only evidence is sufficient to keep the following deferred:

- `commander_role_state` schema writes.
- Save migration or `SAVE_VERSION` changes.
- Durable AI event logs.
- Defense-specific durable state such as site defense locks.
- Coefficient tuning.
- Full AI hero task/movement implementation.
- Live commander-role behavior adoption.

The report proves the planned boundary: current commander roster continuity, active encounter linkage, resource pressure scoring, town-front sanity checks, compact public role events, and fixture-only annotations can express the selected commander roles for review. It does not prove enough to adopt live commander-role behavior or saved role state yet, which is why those remain deferred.

## Deferral Rationale

Schema writes and save migration remain premature because every reviewed role state is still derived with `schema_status: "report_fixture_only"`. The minimal schema plan is useful, but the gate found no current need to persist role state before a live behavior slice has a stricter transition contract.

Durable event logs remain premature because the public role events are compact derived records and the reviewed surfaces do not need historical replay, UI timelines, or save-backed event continuity.

Defense-specific durable state remains unnecessary because the Glassroad defender, retaker, and stabilizer cases are expressible through current ownership, fixture threat/recently-secured annotations, resource target views, and compact event vocabulary. No blocker requires `site_defended_until_day` or equivalent state.

Coefficient tuning remains deferred because the reviewed target ordering is coherent: Free Company ranks above Signal Post for Mireclaw signal-yard pressure, Glassroad relay ranks first when player-controlled, and town-front selectors can still legitimately dominate the full target choice.

Live commander-role behavior remains deferred because this is deterministic report evidence, not a live enemy-turn pacing, arrival-frequency, save/resume, pathing, or UI composition proof.

## Recommended Next Slice

Recommended next slice: `strategic-ai-commander-role-adoption-sequencing-planning-10184`.

That slice should be planning-only. It should compare the next narrow strategic AI step among:

- derived live-turn transcript/report surfacing for commander role decisions;
- minimal `commander_role_state` write/read adoption;
- full AI hero task-state sequencing;
- pausing commander roles until broader strategic AI hero movement is ready.

The planning slice should define exact adoption gates, rollback, validation, and non-change boundaries before any implementation. It should not write schema, migrate saves, add durable logs, tune coefficients, add defense-specific durable state, or switch live commander behavior.

## Caveats

- Defender and stabilizer roles are report views over current content and fixture annotations, not live defense AI.
- Detailed score rows remain in `supporting_evidence.resource_score_breakdown`, which is acceptable for focused report/debug output only.
- The report is not a substitute for a later live-client enemy-turn gate once role state affects visible pacing, movement, arrival frequency, save data, or player-facing turn text.
