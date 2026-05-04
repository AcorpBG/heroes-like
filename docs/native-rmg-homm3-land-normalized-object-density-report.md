# Native RMG HoMM3 Land-Normalized Object Density Report

Date: 2026-05-04
Slice: `native-rmg-homm3-land-normalized-object-density-10184`

## Scope

This report compares the owner-attached HoMM3 H3M against native C++ owner-like output after the land/water shape fix. It measures object and category density per 100 land tiles, category mix, roads per 100 land tiles, and package object/surface counts.

The active runtime path remains native `MapPackageService.generate_random_map()`. Generation is not routed through `scripts/core/RandomMapGeneratorRules.gd`. No HoMM3 art, DEF, map package, `.amap`, or `.ascenario` asset is imported or committed.

## Owner Baseline

Source: `/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz`

- H3M version: 28
- Size: 72x72
- Land/water: 1,948 land / 3,236 water
- Placed object instances: 496
- Road tiles: 184
- Category counts: 252 decoration/impassable, 110 reward/resource, 61 guard, 8 town, 65 other parseable object

Owner density per 100 land tiles:

- Total objects: 25.462
- Decoration/impassable: 12.936
- Reward/resource: 5.647
- Guard: 3.131
- Town: 0.411
- Other object: 3.337
- Road tiles: 9.446

## Native Result

Native owner-like case:

- Seed: `1777897383`
- Template/profile: `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1`
- Size/water: `homm3_medium`, islands
- Land/water: 2,316 land / 2,868 water
- Generated/package objects: 488 generated, 488 package objects
- Road tiles: 240
- Category counts: 241 decoration/impassable, 136 reward/resource, 104 guard, 7 town, 0 other object
- Package surfaces: 1,833 body tiles, 1,821 block tiles, 658 visit tiles
- Guard/reward package adoption: pass, 88 rewards, 64 valuable rewards, 47 guarded valuable rewards, 0 unguarded high-value rewards

Native density per 100 land tiles:

- Total objects: 21.071, 0.828x owner
- Decoration/impassable: 10.406, 0.804x owner
- Reward/resource: 5.872, 1.040x owner
- Guard: 4.491, 1.434x owner
- Town: 0.302, 0.735x owner
- Other object: 0.000, 0.000x owner
- Road tiles: 10.363, 1.097x owner

## Implemented Improvement

The post-land/water baseline still had a material decoration/impassable gap: native had 344 total objects and decoration/impassable density was only 0.330x owner after land normalization.

The bounded C++ change adds a compact decoration-density supplement only for the 72x72 owner-like islands profile. It preserves reward/resource, guard, town, road, package adoption, and source metadata behavior while increasing parseable decoration/impassable instances. Decorative obstacles now clear non-interactive approach tiles, which prevents compact non-visitable objects from unnecessarily expanding protected island land.

Resulting movement:

- Total object count improved from 344 to 488 against owner 496.
- Total density improved from 0.588x to 0.828x owner.
- Decoration/impassable density improved from 0.330x to 0.804x owner.
- Land stayed within the land/water gate at 2,316 tiles, still much closer to owner than the pre-land/water 4,900-land output.

## Remaining Gaps

This is not full HoMM3-re parity. Native still has no equivalent for the owner H3M's 65 `other_object` category instances, exact object-table selection and binary H3M placement are not matched, and original HoMM3 art/assets are not imported. Guards are denser than owner after normalization, but this slice did not reduce guards because guard/reward package adoption and protected-value behavior are active product constraints.

## Validation

Focused report:

`GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_land_normalized_object_density_report.tscn`

Adjacent focused gates run during implementation:

- `tests/native_random_map_homm3_land_water_shape_report.tscn`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.tscn`
