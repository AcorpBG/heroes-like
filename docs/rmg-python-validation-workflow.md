# RMG Python Validation Workflow

Task: #10184
Document role: tactical validation workflow

## Purpose

RMG correctness checks should not start Godot just to parse or compare `.h3m`
and `.amap` files. Godot remains necessary when the native generator must
produce fresh packages or when a runtime/editor surface is being tested.

## Default Loop

1. Rebuild the native extension after C++ changes:

```bash
cmake --build .artifacts/map_persistence_native_build --parallel 2
```

2. Export only the cases affected by the change:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_probe --case xl_islands_2levels,xl_water_2levels
```

3. Validate and compare with Python:

```bash
python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_probe --allow-partial-native-batch --skip-timing-summary
python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_probe --allow-partial-native-batch --summary
```

Use `tools/rmg_fast_audit.py --compare` for single-case inspection when a
specific owner/native delta needs details.

## Full Gate

A full Godot export is a checkpoint gate, not the normal investigation loop.
Run it before committing broad generator policy changes, or when the changed
logic can affect every size/water/level profile:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_full
python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_full --require-timing-summary
python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_full --summary
```

## Boundary

Python owns owner `.h3m` parsing, native `.amap` package inspection, density,
road topology, town spacing, route closure, terrain blocker, and production-gap
diagnostics. Godot owns native generation/export, package adoption, editor
loading, scene/runtime smoke tests, and visual/play inspection.
