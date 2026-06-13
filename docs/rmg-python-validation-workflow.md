# RMG Python Validation Workflow

Task: #10184
Document role: tactical validation workflow

## Purpose

RMG correctness checks must not start Godot just to parse, compare, or export
native RMG evidence on memory-constrained hosts. Test/report/export control
stays in Python, and fresh native export must go through the standalone
no-Godot CLI boundary. The legacy Godot runner has been removed from
`tools/rmg_native_batch_export.py`; runtime/editor integration smokes must use a
separate explicit workflow on a host where engine launch is permitted.
The wrapper now also refuses to run while any Godot process is already active
on the host and records that refusal in `wrapper_manifest.json`. Full `.amap`
export is not a normal mode on this host yet: unless a caller passes the
diagnostic override `--allow-blocked-full-export-probe`, the wrapper refuses
before spawning the native process and tells the caller to use
`--phase-snapshot-only`.

Current blocker: the standalone CLI owns plain-C++ controlled-case
parsing/filtering and can write checkpoint-2 blocker phase snapshots for
supported Small/Medium one-level land cases. Those snapshots now include the
constructor-default generated-cell words (`0xffff7fbc`, `0x00000548`, and
bit25|bit27) and an `after_boundary_span_fill_owner_words` generated-cell
checkpoint under the same schema used by the Python private-state compare
tools. The post-boundary checkpoint materializes the recovered
`0x4a2777/0x4a325d` owner byte-2 writes over the generated-cell word `0x20`
defaults, while leaving later terrain/live-feedback mutations unclaimed.
Snapshots also include plain-C++ embedded-catalog template selection, selected
runtime-zone record summaries, link-seed extraction, `0x4a1f3b` coordinate
replay summaries, and
`0x4a3a03/0x4cc788/0x4ccb64/0x4ccdfc` source-node footprint summaries.
They also include a plain-C++ `0x4a2777/0x4a325d` boundary/span-fill owner-word
summary over the currently materialized source-node walks. They resolve the
recovered `0x49ecf2` generator mode for controlled cases that supply RMG setup
object `+0x44`; when the field is omitted, the CLI defaults it to recovered
H3MapEd setup initializer value `3` and emits explicit provenance fields. Setup
value `3` consumes one `0x4e7276` RNG call and uses `rng % 3` before template
selection. They also include the recovered `0x4a3b48` direction scan and
`0x49b452` same-level synthetic runtime-zone append replay for supplied or
defaulted setup modes, and `0x49b53d/0x4a3f27` terrain selection/writeout now
iterates the post-synthetic runtime-zone vector instead of dropping synthetic
owner cells. They do not prove pre-`0x4a4c8e` parity yet: same-run generated-cell
comparison still reports owner placement drift and later generated-cell word
mutations still need to be ported and compared. The checkpoint-2 comparator
now splits `word_0x20` failures into low-word score drift and high-word owner
drift so native work cannot hide the unported score field behind the broader
owner-byte mismatch. The CLI still intentionally fails closed for
`.amap` generation until the H3MapEd RMG generation core is split from Godot
`Dictionary`/`Array`/`String`, `RefCounted`, and `FileAccess` APIs into plain
C++ data structures.

## Default Loop

1. Rebuild the standalone native CLI after C++ changes:

```bash
cmake --build .artifacts/map_persistence_native_build --target rmg_native_batch_export_cli --parallel 2
```

For native RMG parity work this is the Linux standalone no-Godot inner-loop
build. Do not cross-build Windows DLLs on every probe. Run the Linux
GDExtension `.so` and Windows native builds only once the standalone CLI and
Python parity evidence are green for the boundary being changed.

2. Emit no-Godot phase snapshots for only the cases affected by the change:

```bash
python3 tools/rmg_native_batch_export.py \
  --out .artifacts/rmg_native_phase_snapshot_probe \
  --controlled-case medium_4p_seed10_hc4_setup0:medium:4:10:land:1:4:0:0 \
  --phase-snapshot-only --emit-phase-snapshot --print-manifest
```

This is the supported successful no-Godot trigger while the native RMG core
split is incomplete. A plain `python3 tools/rmg_native_batch_export.py --out
...` full-export attempt now fails before spawning the CLI with
`full_export_plain_cpp_core_not_available`. Use
`--allow-blocked-full-export-probe` only when intentionally testing that
blocked boundary. Do not add Godot flags or restore a Godot runner for parity
work on this host.

For checkpoint-2 phase snapshots, controlled cases may include the recovered
setup `+0x44` as the optional ninth field:

```bash
bin/rmg_native_batch_export_cli \
  --out .artifacts/rmg_native_cli_boundary_owner_gate_smoke \
  --controlled-case small_2p_seed58_setup3:small:2:58:land:1:1:1:3 \
  --controlled-case medium_4p_seed10_setup3:medium:4:10:land:1:1:3:3 \
  --phase-snapshot-only --emit-phase-snapshot --print-manifest
```

Expected snapshot shape for that focused smoke:

- Small 2p seed 58 with setup `3` resolves generator mode `0`, skips the
  synthetic branch, and runs boundary/span fill over the original runtime-zone
  vector. Its recovered owner-gated `0x4a2777` boundary replay skips 7 source
  edge writes, and its `after_boundary_span_fill_owner_words` checkpoint
  records 1296 owner-materialized generated cells and 5 non-negative owner IDs.
- Medium 4p seed 10 with setup `3` resolves generator mode `2`, scans 56
  `0x4a3b48` candidate directions, appends 8 `0x49b452` synthetic runtime
  zones, and runs boundary/span fill over the augmented 15-zone vector. Its
  recovered owner-gated `0x4a2777` boundary replay skips 33 source edge writes,
  and its `after_boundary_span_fill_owner_words` checkpoint records 5183
  owner-materialized generated cells and 15 non-negative owner IDs.

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

`tools/rmg_python_validation_gate.py` checks standalone no-Godot CLI freshness
by default: the CLI sources, embedded H3MapEd catalog data, and
`bin/rmg_native_batch_export_cli`. It intentionally does not use the old
in-engine runner scene, Godot-bound runner source, or GDExtension `.so` files as
freshness inputs for native RMG parity/export on this host. Add
`--include-windows-native-freshness` only for a final cross-platform checkpoint
after Linux parity is verified and a Windows standalone/package boundary exists.

## Boundary

Python owns owner `.h3m` parsing, native `.amap` package inspection, density,
road topology, town spacing, route closure, terrain blocker, production-gap
diagnostics, and export/test/report orchestration. Native C++ must own fresh RMG
generation/export through a standalone CLI before more parity probes run on this
host.

Do not add or run GDScript report/export launchers for RMG evidence. If an
`.amap` already exists, the validation/comparison step is a Python command.
