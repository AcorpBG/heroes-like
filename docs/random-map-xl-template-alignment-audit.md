# Random Map XL Template Alignment Audit

Date: 2026-04-30

## Evidence

- Current catalog: `content/random_map_template_catalog.json`
- Current import summary: `content/random_map_template_import_summary.json`
- Current selection/runtime code: `scripts/core/ScenarioSelectRules.gd`, `scripts/core/RandomMapGeneratorRules.gd`
- HoMM3 extracted evidence: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`, `rmg-template-summary.csv`, `random-map-template-grammar.md`
- Parity audit context: `docs/random-map-homm3-parity-gap-audit.md`, `docs/random-map-final-homm3-parity-regate-audit.md`

The aborted density-scaling diff at `/root/.openclaw/workspace/tasks/10184/artifacts/rmg-xl-density-audit/aborted-kind-dune-random-map-generator.diff` was reviewed only as a bad example. No global object-count multiplier was applied.

## Size Score 16 Matrix

`size_score=16` corresponds to a 144x144x1 Extra Large land request. The current catalog has several templates that are technically valid for that score, but only the larger translated HoMM3 topologies are suitable for XL gameplay tests.

| Template | Source family | Zones | Links | Player range | Neutral towns | Min mines | Suitability for XL runtime tests |
|---|---:|---:|---:|---:|---:|---:|---|
| `frontier_spokes_v1` | local compact | 7 | 9 | 3-3 | 0 | 0 | Not suitable; compact topology. |
| `border_gate_compact_v1` | local compact | 7 | 9 | 3-3 | 0 | 0 | Not suitable; caused compact XL counts. |
| `four_corners_ring_v1` | local compact | 8 | 10 | 4-4 | 0 | 0 | Not suitable; compact topology. |
| `translated_rmg_template_002_v1` | Ring | 16 | 29 | 2-8 | 0 | 48 | Suitable as medium/large translated baseline. |
| `translated_rmg_template_003_v1` | Dragons | 33 | 40 | 2-6 | 0 | 31 | Strong XL candidate. |
| `translated_rmg_template_004_v1` | Gauntlet | 24 | 25 | 3-6 | 0 | 36 | Strong XL candidate. |
| `translated_rmg_template_007_v1` | Worlds at War | 17 | 18 | 2-5 | 0 | 25 | Suitable, but smaller than best XL topology. |
| `translated_rmg_template_008_v1` | Meeting in Muzgob | 17 | 16 | 2-8 | 0 | 24 | Suitable, but sparse links. |
| `translated_rmg_template_010_v1` | Dwarven Tunnels | 18 | 22 | 2-4 | 0 | 29 | Suitable, player range is narrower. |
| `translated_rmg_template_037_v1` | 8MM6 | 26 | 40 | 2-8 | 6 | 45 | Strong XL candidate. |
| `translated_rmg_template_041_v1` | 6LM10 | 25 | 48 | 2-6 | 10 | 46 | Strong XL candidate. |
| `translated_rmg_template_042_v1` | 6LM10 | 25 | 46 | 2-8 | 10 | 48 | Strong large/XL candidate. |
| `translated_rmg_template_043_v1` | 8XM12 | 33 | 68 | 2-8 | 12 | 62 | Best current XL default: large connected topology and broad player range. |
| `translated_rmg_template_044_v1` | 8XM8 | 48 | 52 | 2-8 | 8 | 56 | Not default; extracted graph is disconnected. |

Other translated templates also accept `size_score=16`, but their topology is closer to compact/small templates and they are weaker evidence for an Extra Large gameplay test.

## Root Cause

The XL runtime symptom was template/profile selection, not hidden downscale or missing global density scaling. `homm3_extra_large` requests were still routed through `border_gate_compact_v1` / `border_gate_compact_profile_v1` in player-facing defaults and focused reports, so the 144x144 materialization carried compact topology counts.

## Fix Direction

Extra Large now defaults to `translated_rmg_template_043_v1` / `translated_rmg_profile_043_v1`. Medium and Large also have translated defaults, while Small preserves the compact default. Focused XL reports assert the 8XM12 topology instead of only checking dimensions.

Replay provenance now stores the source faction pool for generated-map replay. The previous provenance stored the post-assignment faction order, so restore-time regeneration shuffled an already shuffled pool and changed the generated scenario id.

Player-count setup now derives valid counts from the selected catalog template's `players.total` range and fixed start-slot capacity instead of the legacy player-facing `[2, 3, 4]` list. Compact local templates still expose their compact range (`border_gate_compact_v1` remains `3` players), while translated XL template `translated_rmg_template_043_v1` exposes and normalizes valid `2..8` player requests.

## Validation Evidence

- `random_map_template_filtering_assignment_report.tscn`: passed with `extra_large_topology` = template 043, profile 043, `size_score=16`, `zone_count=33`, `link_count=68`.
- `random_map_player_count_range_report.tscn`: passed with compact player counts `[3]`, XL player counts `[2, 3, 4, 5, 6, 7, 8]`, and accepted XL generator selection/player assignment counts `[5, 6, 7, 8]`.
- `random_map_player_setup_retry_ux_report.tscn`: updated to assert player-count selector/config ranges without forcing a full XL materialization in the menu report.
- `random_map_playable_materialization_runtime_report.tscn`: passed with 144x144 materialization, template 043, profile 043, 33 zones, 68 links, 16 towns, 95 mines, 21 dwellings, 136 guards, 68 rewards, and 1824 object instances.
