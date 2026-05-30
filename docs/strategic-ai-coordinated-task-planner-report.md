# Strategic AI Coordinated Task Planner Report

Slice: `strategic-ai-coordinated-task-planner-10184`

## Result

Enemy factions now run a live coordinated commander planner after active raids refresh their assignments and before new raid hosts spawn.

The planner:
- evaluates every owned enemy town and configured spawn point as possible planning origins;
- records the selected origin on each planned task;
- ranks reachable towns, resources, artifacts, neutral encounters, and exposed heroes using existing target valuation;
- assigns available, deployable commanders to distinct planned tasks;
- writes those tasks into `enemy_states[].hero_task_state`;
- uses exclusive reservations so idle commanders do not duplicate the same target;
- lets existing spawn-point and commander-selection logic prefer saved planned tasks;
- activates the saved task when a raid host is deployed and assigned.

## Evidence

Focused live behavior test:

`tests/ai_hero_task_strategic_planner_report.gd`

The River Pass case starts with no active Mireclaw raids, marks multiple player-held resource fronts, runs the planner, verifies distinct planned tasks for multiple commanders, then spawns a raid and verifies that the spawned commander activates one of the planned task targets.

The multi-origin case adds a second Mireclaw town near `north_wood` and verifies the planned `resource:north_wood` task records that local town as its origin instead of defaulting to Duskfen on the far side of the map.

## Non-Claim

This closes a real pre-deployment planning gap. It is not a full strategic AI production-ready claim. Remaining work still includes broad generated-map long-run evidence, Medium/generalized RMG behavior, deeper economy/army timing, richer retreat judgment, and live-client pacing review.
