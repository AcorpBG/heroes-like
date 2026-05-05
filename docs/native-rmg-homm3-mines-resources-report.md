# Native RMG HoMM3 Mines Resources Report

Slice: `native-rmg-homm3-mines-resources-10184`
Status: implementation evidence

## Summary

This slice implements recovered Phase 7 mine/resource placement semantics in the native generator using original project content ids. It does not import HoMM3 names, art, DEF assets, maps, or text.

Implemented behavior:

- Seven recovered mine/resource categories are consumed in source order: timber/wood, quicksilver/mercury, ore, ember_salt/sulfur, lens_crystal/crystal, cut_gems/gems, and gold.
- Minimum source fields `+0x4c..+0x64` are scheduled before density source fields `+0x68..+0x80`.
- Each mine placement records source phase, source field offset/name/value, category index, original source-equivalent category, guard base value, zone id, terrain, and original-content proxy object id.
- Wood and ore in player-capable start zones retain a deterministic near-start placement bias.
- Every mine emits an adjacent/resource support record. Wood, ore, and gold also attempt adjacent pickup placement through existing runtime-supported resource pickup objects; rare categories remain explicit support records until those resource pickups are activated in content.
- The native output emits deterministic diagnostics for unsupported adjacent pickup categories, infeasible required placements, infeasible adjacent pickup cells, and placement materialization.

## Evidence

Focused report scene:

```text
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_mines_resources_report.tscn
```

The report validates:

- native capability `native_random_map_homm3_mines_resources`;
- exact seven-category order;
- exact minimum and density source offsets;
- minimum-before-density scheduling;
- all required mine placements for `translated_rmg_template_005_v1`;
- at least one mine placement for every recovered category;
- adjacent/resource support records for every mine;
- deterministic signature stability for identical seed/config and signature drift for changed seed.

## Boundaries

This slice intentionally does not implement Phase 10 treasure/reward band placement, broad object placement pipeline replacement, full monster/guard scaling, renderer art changes, save-schema adoption, or new rare-resource economy activation. Rare category adjacent resources are preserved as explicit support records and diagnostics when no original runtime pickup is active.
