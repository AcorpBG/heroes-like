# Economy Capture Resource Loop Manual Gate Review

Status: passed for the current-systems proof.
Date: 2026-04-26.
Slice: `economy-capture-resource-loop-manual-gate-10184`.

## Gate Decision

Manual gate result: pass.

The recorded Riverwatch signal-yard proof is sufficient current-systems evidence for this slice. It demonstrates a working capture/resource/town-spend loop in `river-pass` without production JSON, runtime code, harness, save migration, pathing, renderer, editor, AI, resource registry, market, rare-resource, generated asset, or River Pass rebalance work.

An exact routed live-client transcript for this sequence is not required now. The proof report already records the exact path, before/after state, resource deltas, day-advance income, town spend, recruitment, save/resume preservation, and scenario viability. Building a new exact routed harness would be additional harness/test implementation rather than the highest-leverage next step. Defer it until a regression, AcOrP request, or later player-facing gate needs repeatable transcript coverage for this exact economy route.

## Evidence Reviewed

Primary report: `docs/economy-capture-resource-loop-live-proof-report.md`.

The report records these pass points:

- Starting `river-pass` economy uses current stockpile ids: `1500 gold`, `4 wood`, `3 ore`.
- `north_wood` changes resources to `1650 gold`, `6 wood`, `3 ore`, confirming the current live `wood` id remains active while player-facing text can still say Wood.
- `river_signal_post` grants `50 gold`, becomes collected by `player`, and contributes persistent income. The next day includes `Field sites yield 20 gold`.
- `river_free_company` grants `80 gold`, joins `+3 Ember Archer` and `+5 River Guard`, becomes collected by `player`, and combines with the signal post for `Field sites yield 60 gold` on the following day.
- `river_pass_ghoul_grove` and `river_pass_hollow_mire` resolve route and objective state, add resources, and affect scenario progress. The battle outcomes were forced for proof inspection, so this is economy-state evidence, not a tactical balance claim.
- `southern_ore` adds `100 gold` and `2 ore`; optional `eastern_cache` adds `400 gold`.
- Riverwatch converts the captured/picked-up economy into `building_bowyer_lodge`, then `unit_ember_archer` recruitment.
- Save/resume preserves day, resources, town ownership/build state, recruits, army, collected sites, resolved encounters, and overworld resume state.
- Scenario remains viable after the proof path: status `in_progress`, objective summary `2/4`, no triggered defeat risks, Riverwatch still player-owned, resources and army strengthened, and Duskfen/Reed Totemists still available as normal remaining objectives.

## Caveats

This gate does not prove full economy balance, full tactical balance, full strategic AI pressure, full River Pass completion through this exact route, rare-resource readiness, market redesign, or production resource migration.

Known caveats accepted for this gate:

- Battle wins against Ghoul Grove and Hollow Mire were forced through current battle resolution rules to inspect post-fight economy state.
- The proof does not claim a fresh tactical difficulty pass.
- The proof does not finish the whole scenario; it records that the route remains plausibly completable.
- Weekly recruit behavior was not required because daily capture income, immediate recruit joins, town build, recruitment, and save/resume already prove the selected loop.
- Current `wood` remains the live resource id; `wood` canonical migration remains deferred.
- Persistent income is currently gold-only for this path; broader multi-resource economy work remains future staged migration.

## Follow-Up Decision

Move next to `strategic-ai-economy-pressure-planning-10184`.

Reason: economy proof data now exists for the same map-control surfaces the future opponent should value: persistent income sites, resource pickups, fight-gated branches, town spend/recruit decisions, and scenario pressure. A narrow UI surfacing fix is not recommended from this report because the proof did not show a surfacing blocker that prevents the loop from being recorded or understood. If AcOrP later wants an exact transcript, do a narrow routed/manual transcript slice only, not broad economy migration.

Keep these boundaries in place for the next slice:

- No production JSON migration.
- No new resource registry or wood id change.
- No rare-resource activation.
- No market overhaul.
- No runtime economy/pathing/editor/renderer/save behavior changes.
- No generated PNG or asset import.
- No broad River Pass rebalance.

## Validation Plan

Run:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```
