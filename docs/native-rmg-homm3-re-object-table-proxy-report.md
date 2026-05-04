# Native RMG HoMM3-re Object Table Proxy Report

Date: 2026-05-04

## Scope

This slice continues the native C++ GDExtension RMG path after reward value
distribution. Active generation remains `MapPackageService.generate_random_map()`
through the main menu/scenario-select runtime path.

The implemented increment is source/proxy semantics for reward-bearing object
selection. It does not claim exact HoMM3-re object-table, art, byte, or placement
parity.

## Implementation

- Added `content/homm3_re_reward_object_proxy_catalog.json`, a metadata-only
  catalog derived from the HoMM3-re object catalog/type metadata artifacts and
  mapped to original authored proxy objects/artifacts.
- Native `resource_site`, `mine`, `neutral_dwelling`, and `reward_reference`
  records now carry HoMM3-re source kind, catalog id/path/schema, object type id,
  type name, subtype, source row, DEF-reference name, reward/object table bucket,
  semantic category, native proxy object/family/category, and
  `homm3_re_art_asset_policy = provenance_only_original_proxy_art`.
- `reward_reference` selection now uses the proxy catalog by generated kind,
  reward tier, source bucket, resource/category hint, and deterministic ordinal
  hashing. Minor, medium, major, and relic bands map to different original proxy
  families instead of a single placeholder family.
- No HoMM3 copyrighted art, DEF files, generated `.amap`, or generated
  `.ascenario` packages were imported.

## Report Evidence

Command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_re_object_table_proxy_report.tscn
```

Result: pass.

Sampled cases:

| Case | Size | Rewards | Reward source ids | Reward buckets | Native proxy objects | Tiers |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `frontier_spokes_v1` | 36x36 | 26 | 8 | 8 | 7 | minor |
| `translated_rmg_template_042_v1` | 108x108 | 400 | 14 | 14 | 12 | minor/medium/major/relic |
| `translated_rmg_template_043_v1` | 144x144 | 726 | 14 | 14 | 12 | minor/medium/major/relic |

Broad sample evidence:

- Reward object source catalog ids represented: 14.
- Reward table buckets represented: 14.
- Native proxy objects represented: 12.
- Reward value tiers represented: minor, medium, major, relic.
- HoMM3-re sourced decoration ratio stayed 1.0 in all sampled cases.
- Road cells remained present: 107, 820, and 2041.
- Package conversion preserved generated surfaces: package object counts were
  118, 1425, and 2354.

## Remaining Gaps

- This is exact-ish source identity and proxy selection, not exact HoMM3-re
  object-table algorithm parity.
- DEF names are provenance labels only; no HoMM3 DEF/art assets are imported or
  rendered.
- Guard/object gameplay adoption remains staged metadata in the native package
  generation surface.
