# Magic AI Valuation And Casting Hooks Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `magic-ai-valuation-casting-hooks-10184`.

## Scope

This slice adds bounded AI valuation evidence for current spell behavior metadata:

- `BattleAiRules.gd` now builds enemy commander spell candidates from `SpellRules.battle_spell_behavior(...)` and scores the supported battle families: damage, control, recovery, cleanse, and buff.
- `BattleAiRules.battle_spell_choice_report(...)` exposes a public-safe report of candidate families, runtime hooks, value bands, and the selected spell without raw score fields.
- `EnemyAdventureRules.adventure_spell_valuation_report(...)` values the current self-targeted movement spells against a strategic route/objective context. It remains valuation-only because there is not yet a safe enemy adventure-map spell executor.

## Evidence

Focused report scene:

`godot4 --headless --path /root/dev/heroes-like tests/magic_ai_valuation_casting_hooks_report.tscn`

Expected report id: `MAGIC_AI_VALUATION_CASTING_HOOKS_REPORT`.

The report proves enemy battle spell selection consumes behavior metadata for damage, control, recovery, cleanse, and buff candidates; confirms the live enemy decision path chooses the same spell as the public-safe battle report; and proves adventure movement spell valuation can recommend a cast when restored movement reaches a resource-site objective. Public report payloads are checked for debug/score/internal leaks.

## Boundaries

No save migration, rare-resource activation, artifact integration, economy rebalance, animation work, broad AI rewrite, coefficient tuning sweep, enemy adventure-map spell execution, or scenario migration is included. Existing scenario fixture realities are preserved, and `wood` remains canonical.
