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
on the host and records that refusal in `wrapper_manifest.json`. The shared
`tools/rmg_no_godot_guard.py` process guard is also wired into the Python
quick-validation and validation-gate commands, so native RMG validation fails
fast instead of parsing large artifacts while the engine is consuming memory.
`--phase-snapshot-only` remains diagnostic-only. Once the shared recovered
H3MapEd RMG core proves final payload parity for a controlled authority case,
`--emit-final-h3m-payload` writes the owned final H3M bytes and
`--emit-runtime-package` projects that same parity-owned payload into paired
`.amap`/`.ascenario` packages. Runtime package output is fail-closed unless the
same-run compare is complete, native object serialization matches, and no
recovered tile/object authority bytes were replayed. Native map JSON remains
disabled. Public runtime generation is enabled for the configured release
matrix and rejects unsupported shapes/strengths. That allowlist is not a
per-request proof of current parity or correct live adoption; see the audit
status below.

## Current Validation Status — 2026-09-05

The owner-directed audit in `docs/rmg-start-placement-and-h3maped-audit.md`
supersedes the blanket current completion claim below. Fresh unassisted native
payloads match 23 of 24 retained selected owner cases; Medium normal-water seed
10 differs, including private-state differences confirmed against a fresh
executable run. Runtime start placement, two-level adoption and player-slot
identity also have confirmed gaps. The entrance-boundary correction is tracked
in `docs/rmg-town-entrance-correction-report.md`; it does not complete the level,
player, transit or native-water work. The legacy Godot boundary report now passes
the corrected authored-pool bank and type-107 assertions, then fails a later
stale XLarge subtype-45 dwelling expectation. The full report is not passing.

Generation remains exposed through `MapPackageService`; this audit did not
change support gates or generation rules. Passing config normalization, native
selftests or package startup is not playable adoption or all-phase parity.
Python-owned `tools/rmg_start_placement_audit.py` and
`tools/rmg_retained_authority_audit.py` record these boundaries, with sample
limits and expected failing comparisons explicit in the audit report.

## Historical Completion Record — 2026-07-19

The July-19 record superseded the earlier blocker descriptions below, but is
not current validation after the September audit. It recorded the selected
release matrix as exact for all 24 workflows spanning
Small, Medium, Large, and XLarge sizes; one and two levels; and land,
normal-water, and Islands modes. Public `MapPackageService::generate_random_map`
uses authority-independent inputs and owns payload projection, paired
map/scenario documents, deterministic package-session identity, starts, town
bindings, object tile metadata, and guard/reward references for that matrix.
Unsupported shapes or monster strengths remain fail-closed. Linux and Windows
Debug/Release native outputs build, native self-tests pass on Linux and under
Wine, the Godot end-to-end runtime boundary passes, and repository validation
passes. This status does not claim configurations or allocator histories beyond
the selected supported matrix.

## Historical Blocker Record

The material below is retained as implementation history. Public runtime
generation is no longer disabled as these older entries describe. Current
parity/adoption gaps are stated in the September validation status above;
neither historical blockages nor historical completion statements override it.

Controlled Medium seed-10 setup-1 package projection is proven,
but public `MapPackageService::generate_random_map` still lacks a production
input path that does not require externally supplied same-run authority, and
final parity is not proven across the supported Small/Medium seed/setup/player
matrix. `--phase-snapshot-only` writes a blocked shared-chain marker:
`rmg_native_batch_export_cli_shared_h3maped_state_chain_blocked_v1`.
That marker records `live_generation_surface_present=false` and runtime
generation disabled. The marker now feeds runtime-zone seeds and links from the
recovered H3MapEd template catalog through the shared core only after the
recovered `0x49ecf2` setup step is known. When a controlled case supplies
source-backed `setup_object_0x44`, the marker resolves `generator_mode_0x10b8`;
ordinary modes pass through directly, while sentinel value `3` consumes one
`0x4e7276` RNG call, stores `rand % 3`, and hands the post-setup RNG state to
template selection. The setup-known path executes the shared recovered
coordinate-to-owner-grid chain and reports `shared_coordinate_owner_grid_chain`
counts when the rest of the inputs are present. When that setup field is absent,
the marker records `input_status=missing_exact_runtime_zone_seed_link_inputs`
with `rmg_setup_object_0x44_before_0x49ecf2_template_selection` as a missing
input; it does not assume template selection starts from the raw seed. Explicit
`--shared-runtime-zone-seed`, `--shared-runtime-link`,
`--shared-rng-state-after-template-selection`, and
`--shared-generator-mode-0x10b8` remain available for focused diagnostics. The
Python wrapper no longer accepts `--shared-runtime-input-snapshot`; stale phase
snapshots cannot be mined for runtime-zone/link inputs.
The duplicate phase/native-map reconstruction body has been deleted from
`src/gdextension/src/rmg_native_core.cpp`; that source file now only owns
controlled-case parsing/filtering and blocked shared-chain marker output. The
standalone native-core public header does not declare reconstructed
phase/native-map writers, and the CLI no longer calls the native-map JSON
writer. A direct `--native-map-json-only` or `--emit-native-map-json` invocation
is refused by the Python wrapper with `native_map_json_public_api_removed`.
Native map JSON remains refused. Parity-gated `.amap`/`.ascenario` generation
uses the owned H3M payload projection and does not reintroduce the old
proxy/reconstruction path. Public package/session generation remains blocked
outside the controlled authority case. The old proxy/reconstruction port is
archived as
`src/gdextension/src/archived_h3maped_small_rmg_legacy_proxy_20260618.cpp`, its
proxy catalogs are archived as
`src/gdextension/src/archived_h3maped_small_rmg_embedded_data_legacy_proxy_20260618.cpp`,
and neither is linked into native targets. The GDScript compatibility shim also
returns a blocked result instead of running its old foundation generator, no
longer carries private `_generate_*` reconstruction helpers, no longer exposes
the archived reconstruction blocker helper, and no longer advertises disabled
native RMG placement/provenance schema ids. The old Godot
`RmgNativeBatchExportRunner` class/header/source and
`tools/rmg_native_batch_export_native.tscn` launcher have been removed; native
RMG export tooling must use the standalone no-Godot CLI only, and that CLI
currently fails closed until the exact recovered chain owns output. The
package-session bridge no longer reads `native_proxy_*` package fields. The
active-source `MapPackageService` file has been replaced with a slim package
service plus fail-closed RMG normalization/identity/blocked responses; the old
reconstruction helper entrypoints and `AURELION_ENABLE_ARCHIVED_NATIVE_RMG_RECONSTRUCTION`
escape hatch have been removed, and the default Linux GDExtension and no-Godot
CLI builds must not expose their old helper symbols. These are removal/fail-closed guardrails, not
successful generation or parity evidence.
The shared core currently owns recovered primitive state: the H3MapEd RNG,
Small/Medium one-level-land scope checks,
water-mode codes, strict scope labels, size-score calculation, the recovered
generated-cell reset `0x49a072 -> 0x499ea3` for words
`+0x10/+0x1c/+0x20/+0x24/+0x28/+0x2c`, the recovered `0x49acf6`
terrain/art/private-flag word mutation, the low-level boundary helpers for
`0x4a2b33` clipping, `0x4a261a` deterministic line writing, `0x4a2413`
randomized line writing, owner-word application, and `0x4a325d` span fill, plus
a typed `boundary_cycles_from_source_handoffs_4a2777` /
`materialize_boundary_source_handoffs_4a2777_4a325d` handoff API that accepts
recovered source-node finalized fields and selected source-record `+0x10/+0x14/+0x18` seeds, then
materializes selected connector, border wrap/final segments, rectangle fallback,
generator `+0x3f4` boundary-vector append records, generated-cell owner-word
mutations, and recovered `0x4a325d` seed relocation/span-fill into the shared
grid shape. Exact recovered descriptor/source-cycle/seed producer ownership and
final payload generation are still blocked until those recovered phases feed
that same shared core as live payload and pass same-run private-state comparison.

The shared core now also owns a typed, Godot-free producer surface for the
upstream seed/link inputs: `player_slot_assignment_4ac62a_4ac6ec()` materializes
the recovered source-owner to player-color mapping shape, and
`runtime_seed_inputs_from_template_records_4a218c_4a1f3b()` filters typed
template zone/link records into runtime-zone seeds and endpoint links. The
selftest covers this producer-to-coordinate-to-owner-grid flow without reading a
prior phase snapshot. This is still not public generation authority: exact
same-run template selection/catalog records must feed the typed producer and
same-run private-state comparison must pass before map output is enabled.

The shared core now preserves source-node payload metadata across
`boundary_cycles_from_source_handoffs_4a2777` and applies the recovered
`0x4a2777` owner gate before source-edge writes: an edge with
`next_pair_payload <= zone_word` is skipped instead of being written as a normal
connector segment. `bin/h3maped_rmg_core_selftest` verifies payload preservation,
owner-gated connector suppression, and continued span fill from the selected source-record
seed without starting Godot or exporting a map. This is an internal shared-core
behavior change only; public CLI and runtime generation remain blocked until the
exact same-run `0x4a3a03 -> 0x4cca55` producer feeds these handoffs as live
payload and the private-state comparison passes.

The source-cycle handoff no longer collapses `0x4cca55` descriptor nodes to
finalized x/y only. `BoundaryCyclePoint4a2777` now carries descriptor link
indexes, raw `+0x00/+0x04` coordinates, and finalized `+0x1c/+0x20`
coordinates through `boundary_cycles_from_source_handoffs_4a2777()` and
materialization. The no-Godot Small seed-11 setup0 smoke remains blocked/no
output and reports 5 source handoffs, 24 descriptor-indexed handoff points, 24
raw-coordinate handoff points, 5 source-record seeds, 0 missing source-record
seeds, and 5 span-fill zones. This is source-chain preservation only, not
checkpoint-2 parity completion.

The blocked shared-chain checkpoint now emits all six generated-cell words for
the pre-`0x4a4c8e` surface: reset-owned `word_0x10`, `word_0x1c`,
`word_0x24`, `word_0x28`, and `word_0x2c` from `0x49a072 -> 0x499ea3`, plus
owner-grid `word_0x20` from the shared `0x4a2777 -> 0x4a325d` materializer.
The checkpoint also emits `word_0x10_hash_fnv1a64`,
`word_0x1c_hash_fnv1a64`, and `word_0x20_hash_fnv1a64` for quick compare
triage. This is still blocked evidence, not export authority.

The shared core also now owns the recovered `0x4a3a03 -> 0x4ccb64 -> 0x4cca55`
source-node footprint producer as
`build_source_node_footprints_4a3a03_4ccb64_4cca55()`. The producer materializes
the descriptor table and per-zone source walks from runtime-zone coordinates,
including descriptor link indexes, raw/finalized coordinates, payloads, and
next-pair owner metadata. `bin/h3maped_rmg_core_selftest` covers producer output
and producer-to-boundary-materializer handoff. This does not authorize map
export: the no-Godot/live path must still consume the shared producer as live
owner-grid payload and pass same-run private-state comparison before public
generation is unblocked.


The `0x4a2777 -> 0x4a325d` handoff now treats the selected `0x4a3a03` source-record entry as the seed authority: active source exposes `source_record_vector_index_4a3e9c` and `source_record_seed_0x10`, not `runtime_zone_seed_0x10`. The coordinate seed preserves the original template source-record index in `source_record_vector_index_4a3e9c`; filtered zones are not relabeled with compacted runtime positions. Missing source-record seeds are reported and do not span-fill through reconstructed fallback coordinates.

The shared core now also exposes
`materialize_boundary_owner_grid_from_runtime_zone_footprints_4a3a03_4cca55_4a2777_4a325d()`,
which composes recovered runtime-zone boundary inputs through the source-node
producer, `0x4a2777` source handoff conversion, and `0x4a325d` span fill in one
shared owner-grid chain. Selected source-record seeds are explicit inputs, and the result
keeps missing input/seed conditions observable instead of filling them with
synthetic coordinates. The selftest verifies this composed path produces
generated-cell owner words. This remains below public generation authority until
exact same-run runtime-zone boundary inputs feed the shared chain and the
private-state comparison passes.

The shared core now also exposes
`coordinate_seed_and_materialize_owner_grid_4a218c_4a1f3b_4a19ed_4a3a03_4cca55_4a2777_4a325d()`,
which runs coordinate seeding, boundary input construction, source-node
footprint production, source-cycle handoff conversion, and owner-grid/span-fill
materialization in one source-order C++ entrypoint. The boundary phase consumes
the RNG state produced by coordinate seeding. The selftest covers this composed
path from typed template source records through runtime-zone seed/link inputs and
generated-cell owner words without starting Godot. This remains below public
generation authority until the no-Godot/live path feeds exact same-run
template/catalog records and the private-state comparison passes.

The coordinate seed also now carries the recovered `0x4a218c`
`generator+0x10b8` pruning input into the `0x4a1f3b` candidate-prune helper:
mode `0` uses divisor `5`, mode `1` uses divisor `6`, and any other mode uses
divisor `7` over
`min(min_source_base_size * map_width, min_source_base_size * map_height)`.
The focused no-Godot setup-mode smoke covers setup `0` as mode `0` divisor `5`
and setup sentinel `3` as randomized mode `2` divisor `7`. This is supporting
checkpoint-2 alignment only; the blocked marker remains blocked and does not
authorize map output.

The selected-payload handoff slice removed one native proxy substitution from
the diagnostic source-walk path: after `0x4cca55`, native no longer replaces
the selected `0x4a3a03` `generator+0x10e4..+0x10e8` payload entry with
`model.nodes[located].payload`. The selected payload now remains the seed/owner
payload for `0x4a325d`, and boundary/span diagnostic consumers iterate that
active payload vector directly instead of a runtime-zone proxy list. The
descriptor locator stays diagnostic until the exact recovered descriptor buffer
and generator `+0x3f4` boundary vector own the live payload.

The boundary-vector diagnostic event labels must also follow recovered append
calls, not branch labels from the reconstructed native path. The selected
clipped endpoint is recorded at the recovered `0x40bb15` call site `0x4a2990`;
wrap/continuation appends are recorded at `0x4a2adc`; the final clipped endpoint
append is recorded at `0x4a2b1e`. These labels are diagnostic only until the
same recovered state chain owns the payload and generated-cell grid.

The live GDExtension entrypoint follows the same blocked-authority rule. For
supported Small/Medium one-level land H3MapEd scopes,
`MapPackageService::generate_random_map` returns
`aurelion_native_rmg_exact_state_chain_runtime_block_v1` directly and cannot call
`h3maped_small_rmg::validator_gated_generation_result` because the old port is no
longer linked. `normalize_random_map_config` and `random_map_config_identity`
defer H3MapEd template selection without calling `h3maped_small_rmg::selection_identity`.
Runtime H3MapEd scope/status checks call the shared `h3maped_rmg_core` helpers
directly instead of routing through `h3maped_small_rmg::supports_*`, and the
unsupported runtime fallback returns a local blocked payload instead of calling
the archived Small-port fallback. The public `MapPackageService`
`inspect_h3maped_small_rmg_port` and negative-validator APIs are no longer
declared, bound, advertised, or stubbed; the old proxy implementation remains
only an explicitly archived historical recovery/source artifact.

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

This is the supported no-Godot diagnostic trigger while the native RMG core
split is incomplete, but it is not a passing implementation checkpoint. A
plain `python3 tools/rmg_native_batch_export.py --out ...` full-export attempt
now fails before spawning the CLI with
`full_export_plain_cpp_core_not_available`. Do not add Godot flags, restore a
Godot runner, or add a full-export probe override for parity work on this host.

Native map JSON remains blocked. Paired `.amap`/`.ascenario` output is allowed
only through `--emit-runtime-package` after the shared recovered H3MapEd RMG
core proves same-run final payload parity without authority replay. Do not use
the standalone CLI as a substitute for public generation; use
`--phase-snapshot-only` only for blocked diagnostics and keep
`MapPackageService::generate_random_map` fail-closed until authority-independent
inputs and the supported parity matrix are implemented.

For checkpoint-2 phase snapshots, controlled cases may include the recovered
setup `+0x44` as the optional ninth field:

```bash
bin/rmg_native_batch_export_cli \
  --out .artifacts/rmg_native_cli_boundary_owner_gate_smoke \
  --controlled-case small_2p_seed58_setup3:small:2:58:land:1:1:1:3 \
  --controlled-case medium_4p_seed10_setup3:medium:4:10:land:1:1:3:3 \
  --phase-snapshot-only --emit-phase-snapshot --print-manifest
```

Expected snapshot shape for that focused smoke: the snapshot schema must be
`rmg_native_batch_export_cli_shared_h3maped_state_chain_blocked_v1`; it must not
contain `plain_cpp_*` sections, and it must record
`live_generation_surface_present=false`. If `setup_object_0x44` is not supplied,
`shared_coordinate_owner_grid_chain.executed` must be false with
`rmg_setup_object_0x44_before_0x49ecf2_template_selection`,
`rng_state_after_template_selection`, `generator_mode_0x10b8`, and runtime seed
inputs missing. If `setup_object_0x44` or exact explicit inputs are
provided, `shared_coordinate_owner_grid_chain.executed` may be true, but map
output must remain disabled until same-run private-state comparison passes.

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
Both quick validation and the validation gate record `godot_process_guard`; if
the guard fails, the command writes its report and exits before artifact parsing
or comparison work begins.

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
