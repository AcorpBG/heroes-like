# Economy Capture Resource Loop Proof Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: economy-capture-resource-loop-proof-planning-10184.

## Purpose

Plan one narrow live-client proof that the current economy can support a real player loop: scout, fight, capture or claim useful sites, receive resource value over turns, spend in town, recruit, save, resume, and continue toward River Pass objectives.

This plan does not approve production JSON migration, validator/test implementation, runtime economy/pathing/AI/editor/renderer/save behavior changes, new resource registry work, `wood` to `timber` migration, rare-resource activation, market-cap overhaul, generated PNG import, asset import, or broad balance work.

## Selected Target

Use `river-pass` as the proof target.

Reason: River Pass is the manually proven scenario, small enough for one session, and already contains the exact surfaces needed for a first economy loop without schema migration:

- Player town: `riverwatch_hold` using `town_riverwatch`.
- Enemy town: `duskfen_bastion` using `town_duskfen`.
- Starting resources: `{"gold": 1500, "wood": 4, "ore": 3}`.
- Persistent daily gold sites: `river_signal_post` and `river_free_company`.
- Current common-resource pickups: `north_timber`, `southern_ore`, `eastern_cache`.
- Existing low/medium fights that gate or pressure route choices: `river_pass_ghoul_grove`, `river_pass_hollow_mire`, and `river_pass_reed_totemists`.
- Current script pressure on day 2 and day 3, which creates timing pressure without needing new AI.

## Proof Path

Primary path name: Riverwatch signal-yard economy proof.

Scenario path:

| Step | Existing id | Existing behavior to observe |
| --- | --- | --- |
| Start | `river-pass` | Begin with Lyra near Riverwatch and resources `1500 gold`, `4 wood`, `3 ore`. |
| Town baseline | `riverwatch_hold` / `town_riverwatch` | Inspect current build and recruit choices before collecting anything. |
| First pickup | `north_timber` / `site_timber_wagon` at `1,0` | Claim `wood +2`, `gold +150`; confirms current `wood` live id remains active. |
| First capture | `river_signal_post` / `site_ember_signal_post` at `2,3` | Claim `gold +50`, capture persistent control, observe `control_income {"gold": 20}` after day advance. |
| First route fight | `river_pass_ghoul_grove` / `encounter_ghoul_grove` at `3,1` | Clear low fight as scouting/risk confirmation before deeper route commitment. |
| Main capture | `river_free_company` / `site_riverwatch_free_company_yard` at `0,4` | Claim `gold +80`, capture persistent control, receive `control_income {"gold": 40}`, `claim_recruits {"unit_river_guard": 5, "unit_ember_archer": 3}`, and later `weekly_recruits {"unit_river_guard": 1}` if the week boundary is reached. |
| Ore branch | `river_pass_hollow_mire` plus `southern_ore` / `site_ore_crates` at `6,4` | Clear medium fight and claim `ore +2`, `gold +100`; confirms fight versus resource timing. |
| Optional cash branch | `eastern_cache` / `site_waystone_cache` at `7,0` | Claim `gold +400` if the player needs a cash bridge. |
| Required pressure | `river_pass_reed_totemists` / `encounter_reed_totemists` at `4,0` | Clear before day 3 when possible to prevent the current `reed_totem_host_rallies` pressure hook from escalating. |
| Town spend | `riverwatch_hold` | Choose one build/recruit path based on collected resources and captured income. |

The proof should not require every optional branch. It should prove that at least one captured persistent income site plus one common-resource pickup changes a town decision in a way the player can understand.

## Resource And Capture Expectations

Use only current resources:

- `gold`: starting stock, town income, pickup rewards, site claim rewards, persistent control income, unit costs, and building costs.
- `wood`: current live id for Timber, used by existing town buildings and pickup rewards. Do not introduce `timber`.
- `ore`: current construction resource, used by existing town buildings and pickup rewards.
- `experience`: may appear as non-stockpile reward from `midway_shrine` or scripts, but it is not part of this proof's stockpile loop.

Capture states to observe:

- Before visit: site is visible or discovered but not owned/claimed.
- After claim/capture: site is owned by player or counted as controlled by player through current state.
- Next day: `river_signal_post` and `river_free_company` contribute daily gold through existing `control_income`.
- Later week boundary, if reached: `river_free_company` weekly recruit behavior is visible or its absence is recorded as a failure/gap.
- After save/resume: owned sites, resolved encounters, resources, day, town state, and recruit additions remain intact.

## Town Decisions

Riverwatch choices to inspect and record:

| Choice | Current cost | Proof question |
| --- | ---: | --- |
| `building_market_square` | `gold 1000` | Is a pure-gold economy build available immediately, and does choosing it delay army growth? |
| `building_bowyer_lodge` | `gold 1200`, `wood 2` | Does `north_timber` make a wood-gated military build feel reachable? |
| `building_watch_barracks` | `gold 1400`, `ore 2` | Does preserving or claiming ore change the defensive/military choice? |
| `building_stone_store` | `gold 900`, `ore 2` | Does an ore-consuming income/support choice compete with later military spending? |
| `building_lantern_archive` | `gold 1100`, `wood 1` | Does a cheaper wood spend compete with direct army growth? |
| `building_river_granary_exchange` | `gold 2200`, `wood 1`, `ore 2` | Does captured daily gold plus pickups make a higher economy target plausible later, without market changes? |

Recruit choices to inspect and record:

- `unit_river_guard`, cost `gold 60`.
- `unit_ember_archer`, cost `gold 85`, especially if received through `river_free_company`.
- Any stronger unit unlocked by the chosen building should be recorded, but not required for proof success.

The manual notes should record the actual before/after resources, chosen build, recruited stacks, and the player reason for delaying or taking each branch.

## Save And Resume Observation Points

Manual proof should create or verify snapshots at these points:

1. Pre-capture baseline: after opening `river-pass`, before claiming `river_signal_post` or `river_free_company`.
2. Post-capture income: after claiming `river_signal_post` and/or `river_free_company`, then advancing one day.
3. Fight plus resource: after clearing `river_pass_hollow_mire` and claiming `southern_ore`, or after recording that the branch is too costly.
4. Town spend: after building or recruiting at `riverwatch_hold`.
5. Resume check: return to main menu, resume latest or selected save, and verify day, resources, owned/controlled sites, resolved encounters, town build state, recruit pools, and objective progress.

If the live client cannot expose any of those facts without developer interpretation, the implementation slice should first improve the narrow summary surface that exposes the missing fact. It should not add a large report panel over the map or town.

## Manual Proof Checklist

- Launch the live client from `project.godot` or use the existing routed harness only as supporting evidence.
- Select `river-pass` at normal difficulty.
- Record starting resources and Riverwatch available orders.
- Claim `north_timber`.
- Capture `river_signal_post`; advance one day and record whether gold income changes.
- Capture `river_free_company`; record claim recruits and daily gold income.
- Clear `river_pass_ghoul_grove` or record why it was skipped.
- Decide whether to clear `river_pass_hollow_mire` to reach `southern_ore`.
- Choose one Riverwatch build or recruit path and record the resource reason.
- Save to a manual slot from overworld or town.
- Return to the main menu, resume that save, and verify the same economy state.
- Continue far enough to confirm the proof path still leaves the scenario winnable or record the blocker.

## Minimal Implementation Slice

Recommended next slice: `economy-capture-resource-loop-live-slice-10184`.

First preference: prove the path using current authored data and current systems, changing only documentation/manual proof notes.

If the path is blocked, the implementation slice may make only minimal, current-schema changes:

- Improve compact live-client surfacing for existing resource-site output, ownership, claim rewards, daily income, recruit claims, and town affordability.
- Adjust only the selected River Pass proof path when absolutely necessary, using existing `gold`, `wood`, `ore`, existing scenario/site fields, and existing town/recruit/build systems.
- Prefer scenario-local changes over shared `resource_sites.json` or `towns.json` changes. If a shared site or town record must change, the implementation notes must justify why a scenario-local proof cannot work.
- Add a short manual proof report after the live run.

The implementation slice must not change:

- No production JSON migration or new schema.
- No `content/resources.json`.
- No `wood` to `timber` canonical migration.
- No rare-resource activation.
- No market-cap overhaul or rare-resource market buying.
- No resource registry adoption by runtime.
- No runtime save schema migration.
- No strategic AI rewrite or new AI economy planner.
- No pathing, body-tile, approach, renderer, editor, generated asset, or PNG import work.
- No broad River Pass rebalance, campaign retune, or Ninefold economy work.
- No validator/test implementation unless a later task explicitly approves it.

## Validation Commands

Run these for the planning slice and the following live implementation slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Optional supporting commands for later live proof, not required by this planning slice:

```bash
python3 tests/run_live_flow_harness.py --scenario river-pass --difficulty normal
godot4 --path .
```

## Report Expectations

Current compatibility report expectations for this planning baseline:

- Default validator passes.
- Economy report remains compatibility mode with stockpile resources `gold`, `ore`, and `wood`; `experience` remains non-stockpile; `wood` remains the live id and Timber target/canonical decision remains advisory; rare-resource buying remains false; errors remain `0`.
- Economy report warning count is currently `163`; do not reduce it by migrating production JSON during this proof planning.
- Overworld object report remains compatibility mode; current output shows `46` map objects, `48` resource sites, `127` scenario site placements, `48` encounter placements, `177` warnings, and `0` errors.
- Neutral encounter report remains compatibility mode; current output shows `48` direct placements, `3` lifted object-backed records, `542` warnings, and `0` errors.
- Runtime adoption flags for resource registry, object pathing occupancy, and neutral encounter object behavior remain inactive.

Warning counts may move only if a later implementation slice makes an explicitly approved narrow change. Errors should remain `0`.

## Success Criteria

Planning success:

- This document identifies one exact proof path and its content ids.
- `PLAN.md` and `ops/progress.json` set the next current slice to the live implementation/proof path.
- `ops/acorp_attention.md` records that GitHub auth remains blocked and that the next work is the selected implementation slice.

Live proof success for the next slice:

- A player can understand why `river_signal_post` and `river_free_company` matter.
- Captured persistent sites produce observable value after day advance.
- `north_timber` and/or `southern_ore` affect a Riverwatch build or recruit decision.
- At least one fight/capture decision changes the route or timing.
- Save/resume preserves resources, controlled sites, resolved fights, town spend, and objective progress.
- The scenario remains plausibly completable after the economy choices.

## Failure Criteria

- The player cannot tell whether a persistent site is captured or producing income.
- Daily income cannot be observed after capture and day advance.
- Resource pickups do not influence any town or recruit choice.
- The proof path relies on rare resources, hidden grants, market flattening, or developer-only interpretation.
- Save/resume loses site ownership, resolved encounter state, resources, town spend, or recruit changes.
- The UI solves missing economy clarity by covering the main screen with large text panels.

## Rollback

For this planning slice, rollback is only:

- Remove this document.
- Revert the `PLAN.md`, `ops/progress.json`, and `ops/acorp_attention.md` planning updates.

For the next implementation slice, rollback should be equally narrow:

- Revert the focused live-client surfacing or River Pass current-schema tuning.
- Keep production content migrations, resource registry work, save migrations, pathing/editor/renderer changes, and generated assets untouched.

## Follow-Up Decision Tree

- If the live proof passes: run `economy-capture-resource-loop-manual-gate-10184` and record the manual report, then plan `strategic-ai-economy-pressure-planning-10184`.
- If the proof fails because the UI does not surface current facts: do a narrow surfacing slice for existing site output, owner, income, shortfall, and recruit info.
- If the proof fails because River Pass data cannot create a meaningful choice: do a tiny River Pass current-schema tuning slice, still using only `gold`, `wood`, `ore`, and existing fields.
- If the proof fails because save/resume loses state: fix the save/resume bug before economy expansion.
- If the proof fails because pathing/object placement blocks the route: pause economy implementation and plan the required object/pathing/editor adoption slice.
- If the proof passes but feels too shallow: do not add rare resources immediately. First record the manual gate, then decide whether the next depth comes from AI pressure, town affordability surfacing, or a second current-resource site path.
