# Native RMG HoMM3 Guards Rewards Monsters Report

Slice: `native-rmg-homm3-guards-rewards-monsters-10184`
Status: implementation evidence

## Summary

This slice implements recovered Phase 10 reward bands plus monster/guard semantics in the native generator using original project content ids. It uses recovered behavior and structure only; no HoMM3 creature, artifact, spell, skill, art, DEF, map, or text content is imported.

Implemented behavior:

- Reward references now expose Phase 10 source metadata for the three low/high/density triplets at `+0xa0..+0xc0`.
- Reward-band diagnostics report invalid or unsupported bands explicitly while preserving low/high value bounds for selected valid bands.
- The recovered monster strength formula is shared by connection guards and protected-object guards, including the sample bases `1500`, `3500`, and `7000`.
- Monster selection honors `match_to_town`, explicit allowed faction masks, and deterministic fallback diagnostics, then maps to original `content/units.json` unit ids.
- Guard records carry source strength mode, global strength mode, effective mode, allowed faction masks, original unit stack records, protected reward relation metadata, and unsupported parity boundaries.
- Connection `Value` records preserve raw value and scaled value; `Wide` and border-gate behavior from the prior connection slice remain intact.

## Evidence

Focused report scene:

```text
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_guards_rewards_monsters_report.tscn
```

Observed focused run:

- `guard_count`: 106
- `site_guard_count`: 103
- `match_to_town_guard_count`: 18
- `explicit_mask_guard_count`: 88
- `reward_count`: 110
- `valid_reward_band_count`: 30
- deterministic signature stable for identical seed/config and changed for a changed seed

The report validates the recovered strength sample table, reward values within selected low/high bands, materialized original-unit guard stacks, allowed faction-mask matches, and the guard/reward/monster summary schema.

## Boundaries

This slice intentionally does not implement decorative object filler, exact private object-table candidate scoring, HoMM3 creature rosters/names/art, Border Guard companion/keymaster vectors, renderer art changes, save-schema adoption, or broad combat/economy rebalance.
