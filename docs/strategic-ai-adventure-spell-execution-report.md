# Strategic AI Adventure Spell Execution Report

Status: implementation evidence.

Slice: `strategic-ai-adventure-spell-execution-10184`.

This slice changes live strategic AI behavior. Enemy commanders can now execute supported self-targeted overworld movement spells during raid movement when the spell materially improves route tempo toward the assigned objective.

Implemented behavior:
- Enemy commander spellbooks preserve authored overworld spells as well as battle spells.
- `EnemyAdventureRules.advance_raids(...)` evaluates commander adventure movement spells before normal path movement.
- Supported casts use `SpellRules.cast_overworld_spell(...)`, so mana cost, artifact/progression modifiers, validation, and movement consequences share the player spell path.
- Raid movement gains bounded extra steps from the cast result, capped by `RAID_ADVENTURE_SPELL_MAX_MOVEMENT_STEPS`.
- Commander mana and spellbook state persist back onto `enemy_commander_state`.
- Public AI events include `ai_adventure_spell_cast` without exposing score/debug internals.

Focused evidence:
- `MAGIC_AI_VALUATION_CASTING_HOOKS_REPORT` still proves battle spell valuation/casting and adventure spell valuation.
- The adventure executor case seeds an enemy raid that cannot reach `midway_shrine` with normal one-step movement, gives its commander `spell_trailglyph`, runs the live raid advancement path, and proves:
  - `ai_adventure_spell_cast` is emitted;
  - commander mana is spent;
  - the raid records `last_adventure_spell_id`;
  - bounded extra movement reaches the target tile.

Boundaries:
- No save migration.
- No broad strategic-AI production-ready claim.
- Targeted scouting/reveal execution is handled by the later `strategic-ai-scouting-spell-execution-10184` slice.
- No rare-resource spell costs, school mastery, or final magic balance claim.

Validation:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/magic_ai_valuation_casting_hooks_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_hero_task_live_turn_execution_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
