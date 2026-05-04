# Native RMG HoMM3-re Reward Value Distribution Report

Date: 2026-05-04

## Scope

This slice continues the native C++ GDExtension RMG path after fill coverage and HoMM3-re obstacle source identity. Active generation remains `MapPackageService.generate_random_map()` through the main menu/scenario-select runtime path.

The implemented parity increment is value semantics, not exact HoMM3-re byte/object/art parity. Native `reward_reference` objects now derive value, tier, category, and provenance from each zone's catalog `treasure_bands`. Valuable reward guards now scale from the protected reward value and expose the relation in generated metadata.

## Implementation

- `src/gdextension/src/map_package_service.cpp`
  - Added translated zone treasure-band reward value profiles using low/high/density bands from `content/random_map_template_catalog.json`.
  - Added per-reward metadata: `zone_value_budget`, `zone_value_tier`, `reward_value_tier`, `reward_source_bucket`, HoMM3-re-like band low/high/density/source index, and zone reward index/target.
  - Promoted reward categories by tier: low bands become resource/build caches, medium bands become guarded caches, and major/relic bands become guarded artifact-cache proxies using original placeholder artifacts only.
  - Scaled site guard value from protected reward value: light/minor, medium, major, and relic bands use progressively stronger ratios.
  - Added guard/reward metadata: protected reward value/tier/category, protected zone budget/tier, guard/reward ratio, and relation source.
  - Medium rewards no longer emit distant fallback guards; major/relic rewards are guarded and checked by the report.

- `tests/native_random_map_homm3_re_reward_value_distribution_report.tscn`
  - Samples small, medium, large, and XL native generated packages.
  - Verifies value-bearing content coverage, reward values inside their selected bands, category/tier mix, guard/reward ratio and association, zone budget scaling, roads, object counts, fill coverage, HoMM3-re decoration source identity, and generated package conversion.

## Report Evidence

Command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_re_reward_value_distribution_report.tscn
```

Result: pass.

Sampled cases:

| Case | Size | Rewards | Reward categories | Max reward | Guarded valuable rewards | High-value rewards | Medium guarded/medium total |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |
| `frontier_spokes_v1` | 36x36 | 26 | build/resource caches | 1,600 | 0 | 0 | 0/0 |
| `translated_rmg_template_024_v1` | 72x72 | 88 | artifact, guarded, resource, build | 29,300 | 70 | 28 | 42/43 |
| `translated_rmg_template_042_v1` | 108x108 | 400 | artifact, guarded, resource, build | 25,300 | 244 | 135 | 109/172 |
| `translated_rmg_template_043_v1` | 144x144 | 726 | artifact, guarded, resource, build | 29,950 | 570 | 220 | 350/363 |

Regression checks from the same report:

- Road cells remained present in every case: 103, 155, 819, and 2009.
- Package conversion preserved object surfaces: package object counts were 110, 354, 1407, and 2424.
- HoMM3-re sourced decoration ratio stayed 1.0 in all sampled cases.
- Fill coverage remained non-barren: body coverage ranged from 0.2945 to 0.3611 on translated cases.

## Remaining Gaps

- This does not implement exact HoMM3-re object table selection, byte placement parity, compact H3M format parity, or copyrighted DEF/art import.
- Guard placement is still native proxy metadata/staged generation; gameplay adoption of guard stacks and object/pathing bodies remains owned by later gameplay/pathing slices.
- Value derivation uses catalog treasure-band fields and translated artifact documentation. It is a defensible native parity increment, not a full RMG reward algorithm clone.
