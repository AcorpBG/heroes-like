# Strategic AI Artifact Equipment Report

Status: implementation evidence.

Slice: `strategic-ai-artifact-equipment-10184`.

This slice changes live strategic AI behavior. Enemy commanders that secure artifact targets now claim the artifact through `ArtifactRules.claim_artifact(...)` instead of only adding the relic id to faction-level captured-artifact state.

Implemented behavior:
- `EnemyAdventureRules._secure_artifact_target(...)` claims the secured artifact for the active raid commander.
- Valid empty-slot artifacts auto-equip through the shared artifact equipment rules.
- Commander artifact state persists on `enemy_commander_state`.
- `sync_commander_state_to_roster(...)` stores the equipped artifact payload in `enemy_states[].commander_roster`.
- Commander-state rebuilding now preserves `artifacts`, so normalization does not drop equipped relics.
- Artifact pickup emits `ai_artifact_secured` as a public AI event without exposing score/debug internals.

Focused evidence:
- `AI_HERO_TASK_ARTIFACT_OBJECTIVE_REPORT` still proves artifact task assignment, saved-task reuse, invalidation, and completion.
- The same report now proves the live equipment consequence:
  - `warcrest_ruin` is collected by Mireclaw;
  - `artifact_warcrest_pennon` is equipped in Vaska's `banner` slot;
  - `ArtifactRules.artifact_equip_runtime_report(...)` reports `battle_attack` and `battle_initiative` bonuses;
  - the commander roster persists the equipped banner;
  - `ai_artifact_secured` passes the public event boundary;
  - `SAVE_VERSION` stays unchanged.

Boundaries:
- No save migration.
- No set-bonus activation.
- No random artifact drop table execution.
- No broad strategic-AI production-ready claim.
- No final artifact balance claim.

Validation:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_hero_task_artifact_objective_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/ai_hero_task_live_turn_execution_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
