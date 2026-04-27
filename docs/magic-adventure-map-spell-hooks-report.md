# Magic Adventure Map Spell Hooks Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `magic-adventure-map-spell-hooks-10184`.

## Scope

This slice adds a bounded adventure-map spell contract for the currently authored overworld spells:

- `spell_waystride`
- `spell_trailglyph`
- `spell_beacon_path`

The supported behavior remains self-targeted movement recovery. `SpellRules.gd` now exposes adventure behavior metadata, self-hero target contracts, consequence previews, and a focused report helper. Existing overworld spell actions include the target and consequence contract payloads, and `OverworldRules.cast_overworld_spell(...)` attaches a spell-specific post-action recap after live casting.

## Evidence

Focused report scene:

`godot4 --headless --path /root/dev/heroes-like tests/magic_adventure_spell_hooks_report.tscn`

Expected report id: `MAGIC_ADVENTURE_SPELL_HOOKS_REPORT`.

The report proves loaded adventure behavior coverage for movement restoration, target selection against the active hero, bounded movement clamping, mana spend, public consequence text, live `OverworldRules` casting, and public-output checks for debug/score/internal leaks.

## Boundaries

No save migration, rare-resource activation, artifact integration, resource mutation, site-state mutation, scouting/map reveal spell, AI casting, animation work, broad UI rewrite, or scenario migration is included. Existing scenario fixture realities are preserved, and `wood` remains canonical.
