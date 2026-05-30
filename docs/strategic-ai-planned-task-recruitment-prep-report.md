# Strategic AI Planned Task Recruitment Prep Report

Status: implementation slice completed and validated.

## Scope

This slice makes town recruitment react to the durable commander task board before a task becomes an active raid. The prior coordinated planner could reserve distinct objectives and spawn from those reservations, but the town governor only sent recruits to local garrisons, active raid hosts, or damaged commander rebuilds.

## Implementation

- Added a `planned` recruitment destination in `EnemyTurnRules`.
- Moved coordinated task-board planning earlier in the live enemy empire cycle, after town builds and before recruitment, so newly planned objectives can affect same-turn recruitment.
- Kept the later pre-spawn task-board planning pass as an idempotent reconciliation point after active raid advancement.
- Added planned-task scoring from saved reachable commander tasks:
  - actor must be an available deployable commander;
  - saved task must be planned or reserved, unexpired, and reachable from the recruiting town;
  - score uses task priority, target weight, priority target bonus, prep need, and distance.
- Added `ai_commander_prepared` compact event output.
- Extended commander roster reinforcement so planned prep can initialize continuity from the faction raid baseline and add recruits above the baseline, instead of weakening future raid spawns.
- Preserved existing priority order:
  - critical garrison safety still wins first;
  - no-available-commander rebuild still wins before planned prep;
  - active raid reinforcement still wins when it has stronger field need.

## Focused Evidence

`tests/ai_planned_task_recruitment_prep_report.gd` proves:

- a full live enemy turn with no starting task board emits task planning before same-turn recruitment and prepares one of the newly planned commanders;
- safe Duskfen recruitment chooses `planned_task_preparation` for a saved commander task before any active raid exists;
- recruited units increase the selected commander's army continuity;
- `ai_commander_prepared` is emitted;
- an empty critical garrison still chooses `critical_garrison_gap` while exposing planned-task pressure in the decision payload.

## Non-Goals

This is not a full strategic AI production-readiness claim. The full 100-seed eight-week generated-map matrix, Medium generated-map generalization, deeper economy timing, retreat/personality tuning, and live-client pacing review remain open.
