# RMG Python Validation Workflow

Task: #10184
Document role: tactical validation workflow

## Purpose

RMG correctness checks must not start Godot just to parse, compare, or export
native RMG evidence on memory-constrained hosts. Test/report/export control
stays in Python, and fresh native export must go through the standalone
no-Godot CLI boundary. The legacy Godot runner is retained only behind
`--allow-godot` plus `RMG_NATIVE_BATCH_EXPORT_ALLOW_GODOT=1` for explicit
runtime/editor integration smokes on hosts where engine launch is permitted.

Current blocker: the standalone CLI intentionally fails closed until the
H3MapEd RMG generation core is split from Godot `Dictionary`/`Array`/`String`,
`RefCounted`, and `FileAccess` APIs into plain C++ data structures.

## Default Loop

1. Rebuild the native extension after C++ changes:

```bash
cmake --build .artifacts/map_persistence_native_build --parallel 2
```

For native RMG parity work this is the Linux `.so` inner-loop build. Do not
cross-build Windows DLLs on every probe. Run the Windows native builds only once
the Linux `.so` export and Python parity evidence are green for the boundary
being changed.

2. Try the no-Godot export boundary for only the cases affected by the change:

```bash
python3 tools/rmg_native_batch_export.py --out .artifacts/rmg_native_batch_export_probe --case xl_islands_2levels,xl_water_2levels
```

This command currently reports `blocked` until the native RMG core split is
implemented. Do not add `--runner godot --allow-godot`, and do not set
`RMG_NATIVE_BATCH_EXPORT_ALLOW_GODOT=1`, for parity work on this host.

3. After a no-Godot export exists, validate and compare with Python in one pass:

```bash
python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_probe --allow-partial-native-batch --summary
```

Use `tools/rmg_fast_audit.py --compare` for single-case inspection when a
specific owner/native delta needs details.

`tools/rmg_quick_validation.py` is the default tight-loop command because it
parses owner `.h3m` and native `.amap` evidence once, then emits both the
correctness gate and the production-gap comparison. Use
`tools/rmg_python_validation_gate.py` when you explicitly want the standalone
syntax-compile gate, and `tools/rmg_production_gap_audit.py` when you only need
the broader readiness checklist.

## Full Gate

A full native export is a checkpoint gate, not the normal investigation loop.
Run it before committing broad generator policy changes, or when the changed
logic can affect every size/water/level profile:

```bash
python3 tools/rmg_native_batch_export.py --out .artifacts/rmg_native_batch_export_full
python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_full --require-timing-summary
python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_full --summary
```

The full gate is unavailable on this host until the no-Godot native export path
produces packages without the engine.

`tools/rmg_python_validation_gate.py` checks Linux native binary freshness by
default. Add `--include-windows-native-freshness` only for a final
cross-platform checkpoint after Linux parity is verified.

## Boundary

Python owns owner `.h3m` parsing, native `.amap` package inspection, density,
road topology, town spacing, route closure, terrain blocker, production-gap
diagnostics, and export/test/report orchestration. Native C++ must own fresh RMG
generation/export through a standalone CLI before more parity probes run on this
host.

Do not add or run GDScript report/export launchers for RMG evidence. If an
`.amap` already exists, the validation/comparison step is a Python command.
