# Immediate Goals

Task: #10184
Document role: owner-facing near-term goal sheet
Source docs: `project.md`, `PLAN.md`, `ops/progress.json`

## Purpose

This file names the next immediate goals clearly enough for implementation work to start without rereading long history. It is not a progress log and does not replace `PLAN.md` or `ops/progress.json`.

The current focus is Phase 5 - Playable Alpha Baseline. Campaign production remains deferred.

## Economy Balance Target

Current state:
- Authored town development currently uses a one-signature-rare model.
- That model made faction-specific bottlenecks visible, but it does not meet the new target.

Target state:
- Every authored town uses every rare resource in town-development costs.
- The faction signature rare remains the highest-pressure rare.
- One secondary rare carries about half the pressure of the signature rare.
- Each remaining rare carries about one-third the pressure of the signature rare.
- `gold`, `wood`, and `ore` remain the dominant common-resource development economy.
- Rare costs must create meaningful build decisions instead of being appended to arbitrary filler buildings.

Pressure guide if signature rare totals stay near the current 28-30 spend:
- signature rare: roughly 28-30 total pressure;
- secondary rare: roughly 14-15 total pressure;
- each remaining rare: roughly 9-10 total pressure.

## Goal 1 - Multi-Rare Town Cost Model

Progress slice: `economy-faction-identity-second-pass-10184`

Implement the new town cost model across authored town development:
- each town uses all six rare resources;
- each town keeps a clear signature rare bottleneck;
- each town gains one meaningful secondary rare;
- remaining rare costs appear at lighter pressure;
- common-resource pacing and day 28-30 town-development completion remain stable unless `PLAN.md` is explicitly updated.

Evidence required:
- town cost-curve reports show every rare resource used by every authored town;
- pressure totals match the target ratios closely enough to be explainable;
- deterministic and runtime-inclusive economy/town scorecards stay green;
- changes improve player-readable faction identity rather than just report shape.

## Goal 2 - Rare Source Access And Guarding

Progress slice: `economy-authored-rare-source-breadth-10184`

Make the new rare requirements playable through map control:
- every rare required by town development is reachable through active authored map play;
- rare access uses source placement, guarded routes, and controllable map pressure;
- player and enemy towns both have routes to the rare mix their development requires;
- the economy does not depend on free stockpile seeding or market shortcuts to hide missing sources.

Evidence required:
- active source-route reports cover all rare resources for player and enemy routes;
- guard pressure protects meaningful economic expansion points;
- economy/town scorecards remain green under the new rare-source layout.

## Goal 3 - Runtime, AI, And UI Adoption

Ensure the new economy model is visible and usable in live play:
- town UI exposes multi-rare bottlenecks clearly enough for planning;
- strategic AI can acquire and spend the required rare mix;
- generated-package support is updated only where strict Small validation proves it is needed;
- save/load remains stable unless a separate migration slice is explicitly selected.

Evidence required:
- runtime-inclusive economy scorecard passes;
- AI town development does not stall on unreachable rare mixes;
- town planning UI shows costs and shortages without debug-style panels.

## Goal 4 - Validation And Balance Evidence

Use existing reports first. Add new gates only when current reports cannot prove the player-facing behavior.

Required validation for the economy goals:

```bash
python3 tests/town_development_balance_report.py
python3 tests/town_development_cost_curve_report.py
python3 tests/economy_town_goal_scorecard_report.py
python3 tests/economy_town_goal_scorecard_report.py --include-runtime
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Success means:
- all authored towns use every rare resource;
- rare pressure ratios match the target;
- day 28-30 development pacing remains stable or any intentional change is documented in `PLAN.md`;
- active map routes support the required rare economy;
- runtime, AI, generated Small support, and UI behavior remain coherent.

## Non-Goals

- Do not start campaign production.
- Do not claim broad random-map-generator readiness from strict Small evidence.
- Do not replace gold/wood/ore pacing with all-rare pricing.
- Do not add gates that only make reports pass without improving player-readable economy behavior.
- Do not use free stockpile or market shortcuts as a substitute for source placement and guard pressure.
