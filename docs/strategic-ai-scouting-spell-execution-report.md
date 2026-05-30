# Strategic AI Scouting Spell Execution Report

Status: implementation evidence.

Slice: `strategic-ai-scouting-spell-execution-10184`.

This slice changes live strategic AI behavior. Enemy commanders can now execute supported self-targeted overworld scouting spells before target assignment when there are unscouted actionable targets inside the reveal radius.

Implemented behavior:
- `EnemyAdventureRules.advance_raids(...)` gives raids without a valid target one bounded scouting-spell opportunity before target selection.
- Scouting casts use `SpellRules.cast_overworld_spell(...)`, so mana cost, validation, and spellbook mutation share the player overworld spell path.
- Enemy knowledge is written to `enemy_states[].known_world_memory.scouted_targets` as compact target records with expiry.
- Target scoring gives a bounded `enemy_scouting` priority/reason-code bonus to currently scouted targets.
- Commander mana and spellbook state persist back onto `enemy_commander_state`.
- Public AI events reuse `ai_adventure_spell_cast` and surface the scouting action without score/debug leakage.

Focused evidence:
- `MAGIC_AI_VALUATION_CASTING_HOOKS_REPORT` now includes `scouting_executor`.
- The scouting executor case seeds an enemy raid with `spell_survey_chain`, nearby and distant resource targets, and no valid current target.
- The live raid turn proves:
  - `ai_adventure_spell_cast` is emitted;
  - commander mana is spent;
  - `last_adventure_scout_spell_id` records `spell_survey_chain`;
  - `known_world_memory.scouted_targets` records `resource:midway_shrine`;
  - target assignment selects the freshly scouted resource target and carries the `enemy_scouting` reason code.

Boundaries:
- No save migration.
- No full enemy fog-of-war parity claim.
- No broad strategic-AI production-ready claim.
- No player-facing UI memory browser.
- No campaign-specific AI scripting.

Validation:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/magic_ai_valuation_casting_hooks_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_hero_task_live_turn_execution_report.tscn
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
