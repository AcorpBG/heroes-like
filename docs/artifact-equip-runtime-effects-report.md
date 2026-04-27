# Artifact Equip Runtime Effects Report

Slice: `artifact-equip-runtime-effects-10184`
Date: 2026-04-27

## Summary

This slice connects equipped artifact bonuses to current safe runtime surfaces and adds focused proof coverage for them.

Implemented evidence:

- `ArtifactRules.artifact_equip_runtime_report(...)` reports equipped artifacts, aggregate bonuses, live contexts, current slot boundary, and inactive runtime policies without exposing debug/score fields.
- `tests/artifact_equip_runtime_effects_report.gd` equips Trailsinger Boots, Quarry Tally Rod, Warcrest Pennon, and Bastion Gorget through the current equipment management surface.
- The focused fixture proves equipped artifacts affect:
  - adventure movement and scouting through `HeroCommandRules`;
  - battle attack, defense, and initiative through the current `BattleRules` hero command payload path;
  - daily common-resource income through `OverworldRules.end_turn`;
  - supported Beacon movement spell modifiers through `SpellRules`.

## Runtime Boundary

The current live equipment surface supports one active trinket slot even though the target design calls for two. The report marks the second trinket slot as not live rather than faking support.

Still outside this slice:

- save migration or `SAVE_VERSION` changes;
- live source/drop execution changes;
- set bonus runtime activation;
- artifact AI valuation behavior;
- rare-resource activation;
- broad equipment or artifact UI overhaul.

`wood` remains the canonical common resource id.
