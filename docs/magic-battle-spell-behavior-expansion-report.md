# Magic Battle Spell Behavior Expansion Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `magic-battle-spell-behavior-expansion-10184`.

## Scope

This slice expands the existing battle spell runtime beyond generic damage and stat buffs with a bounded behavior contract:

- `spell_cinder_burst` now has a priority-damage wounded-target bonus.
- `spell_briar_bind` is a Root control spell that applies a target status without direct damage.
- `spell_graft_mend` is a Root recovery spell that restores active-stack health and applies a short ward.
- `spell_prism_bastion` is a Lens countermagic ward that cleanses harry/stagger pressure and applies a short ward.

`SpellRules.gd` now exposes battle behavior metadata/report helpers and resolves the new behavior types. `BattleRules.gd` applies the new recovery and cleanse resolution types through stack health/effect hooks. `BattleAiRules.gd` recognizes the new spell behavior families for bounded enemy casting evaluation.

## Evidence

Focused report scene:

`godot4 --headless --path /root/dev/heroes-like tests/magic_battle_spell_behavior_report.tscn`

Expected report id: `MAGIC_BATTLE_SPELL_BEHAVIOR_REPORT`.

The report proves loaded behavior coverage for `damage_enemy`, `control_enemy`, `recover_ally`, and `cleanse_ally`; verifies Cinder Burst's wounded-target bonus; applies Briar Bind, Graft Mend, and Prism Bastion through battle effect/recovery/cleanse hooks; and checks public spell action surfaces for debug/score/internal leaks.

## Boundaries

No save migration, rare-resource activation, artifact integration, adventure-map magic, animation work, broad UI rewrite, or economy rebalance is included. Existing scenario fixture realities are preserved, and `wood` remains canonical.
