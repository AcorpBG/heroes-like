# Strategic AI Town Governor Pressure Report Gate Review

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-town-governor-pressure-report-gate-10184`.

## Scope

This gate reviews the report-only town governor pressure surfacing implementation for existing enemy town build, recruit, garrison, raid reinforcement, and commander rebuild choices.

This review does not approve gameplay/code/content changes, production JSON migration, a durable AI event log, save migration, `content/resources.json`, wood id change, rare-resource activation, market-cap overhaul, full AI hero task state, broad strategic AI rewrite, behavior tuning, pathing/body-tile/approach adoption, renderer/editor/save behavior changes, generated PNG import, neutral encounter migration, or River Pass rebalance.

## Focused Report Results

Reran:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

Result: passed. The command printed `AI_TOWN_GOVERNOR_PRESSURE_REPORT` with `"ok": true`.

Meaningful output:

- Case `garrison`: Duskfen Bastion selected `building_slingers_post` / Slingers Post with public reason `feeds raid hosts`. Recruitment selected `unit_blackbranch_cutthroat`, count `9`, destination `garrison`, public reason `stabilizes garrison`, and decision rule `critical_garrison_gap`.
- Case `raid`: Duskfen Bastion again selected Slingers Post with public reason `feeds raid hosts`. Recruitment selected 9 Blackbranch Cutthroat, destination `raid`, public reason `feeds raid hosts`, and decision rule `active_raid_need`; the target raid was `report_duskfen_raid` against `river_free_company`.
- Case `commander_rebuild`: Duskfen Bastion selected Slingers Post and routed 9 Blackbranch Cutthroat to commander rebuild with public reason `rebuilds command`; the target commander was `hero_vaska` / Vaska Reedmaw and the decision rule was `commander_rebuild_required`.
- The report includes build score/debug components such as income, growth, quality, readiness, pressure, recovery, market, category, garrison need, raid need, cost, affordability, and final score in the report payload only.
- The compact derived event set is present: `ai_town_built`, `ai_town_recruited`, `ai_garrison_reinforced`, `ai_raid_reinforced`, and `ai_commander_rebuilt`.

Because the slice adds derived town-governor event types through the shared AI event-record helper, also reran:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Both passed with `"ok": true`.

The event surfacing report still shows compact assignment, pressure, seizure, contest, threat, and dispatch output for the River Pass examples. The economy pressure report still ranks `river_free_company` and `river_signal_post` above simple pickup targets when player-controlled, while the full selector can still choose `riverwatch_hold` when town pressure dominates.

## Public Surface Review

Pass.

The reviewed town-governor events use compact public fields: event type, faction, actor town, target, public importance, reason codes, public reason, summary, and debug reason. Public event records do not expose score-table fields such as `final_score`, `income_value`, `growth_value`, `pressure_value`, `category_bonus`, or `raid_score`.

Detailed build score and recruitment destination breakdowns remain in focused report/debug output. The public phrases are short and action-oriented: `feeds raid hosts`, `stabilizes garrison`, and `rebuilds command`.

The implementation remains report-only for this gate. It does not add these town-governor events to normal live-client UI surfaces, does not change visible turn-message composition, and does not add a text-heavy dashboard.

## Gate Decision

Pass.

The report-only boundary holds. The implementation explains the existing selected build and selected recruitment destination without a public score-table leak, without a durable event log, and without production content or gameplay migration.

## Live-Client Gate Decision

Manual live-client enemy-turn inspection can be deferred.

Rationale: this slice is report/debug surfacing only. The focused deterministic report covers the required Duskfen / Mireclaw build, garrison, raid reinforcement, and commander rebuild surfaces; the existing event and economy pressure reports still pass; and no live UI layout, visible enemy-turn pacing, arrival frequency, map pressure, pathing, renderer, save, or production content behavior changed.

Run a live-client enemy-turn gate later if a follow-up slice connects town-governor events to normal player-facing turn text, changes visible raid cadence or reinforcement strength, or alters map pressure enough to require composition/pacing validation.

## Recommended Next Slice

Recommended next slice: `strategic-ai-faction-personality-pressure-planning-10184`.

Rationale: the project now has report evidence for resource target pressure, compact event/threat reasons, and town governor build/recruit pressure. The next useful planning boundary is to compare Embercourt and Mireclaw as the first personality anchors and define which existing pressure surfaces count as evidence before any tuning.

Commander-role/roster planning remains important, but it should follow personality pressure planning unless AcOrP asks to prioritize explicit AI hero state first.

## Caveats

- This is deterministic report evidence, not a full live-client enemy-turn pacing proof.
- `debug_reason` remains present on event records for report/debug use. It is acceptable in this gate because it is compact prose and does not include score-table field names or component values.
- The build chooser was refactored to read its score from the shared breakdown helper; review found the formula and decision path consistent with the previous scoring path.
