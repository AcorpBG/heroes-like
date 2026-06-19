# Native RMG Core Drift Against H3MapEd Recovery Ledger

Document role: focused drift audit for `src/gdextension/src/rmg_native_core.cpp` and `src/gdextension/include/rmg_native_core.hpp` against `docs/h3maped-rmg-end-to-end-behavior.md`.

This is an audit/marking document only. It does not claim implementation progress. It deliberately compares the active `rmg_native_core` adapter surface to the recovered H3MapEd end-to-end behavior, not to final-map counts, package reports, or prior proxy code.

## Verdict

`rmg_native_core` is not a native port of the recovered H3MapEd RMG chain. It is a no-Godot blocked wrapper around a partial support path:

- controlled-case parsing;
- optional setup/template catalog feed;
- coordinate/source-node/boundary/span-fill/TerrainPlacement support call into `h3maped_rmg_core`;
- blocked JSON emission.

That is useful as a fail-closed diagnostic wrapper, but it drifts from the recovery ledger anywhere a caller treats it as an entrypoint-to-writeout native generator.

## Drift Table

| ID | Severity | Ledger requirement | Current native surface | Drift |
| --- | --- | --- | --- | --- |
| D-001 | Blocking | Ordered spine starts at `0x4602c1`, runs through `0x4adfe1`, `0x4ac552`, private-state phases, `0x4ad1e3`, `0x49b2b6`, object/header writeout, and `0x4ae09a`. | `case_shared_h3maped_state_chain_blocked_json()` emits blocked JSON with `generation_output_written=false`, `runtime_generation_allowed=false`, and `native_rmg_end_to_end_parity_complete=false` (`rmg_native_core.cpp:774-815`). | No entrypoint-to-writeout generator exists in this file. |
| D-002 | Blocking | Source behavior starts from H3MapEd executable state, candidate/source setup, and generator private fields. | `ControlledCase` is a synthetic string schema: `id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]` (`rmg_native_core.cpp:472-525`, `rmg_native_core.hpp:10-25`). | Native input is not the recovered H3MapEd generator object/private-state entrypoint. |
| D-003 | Blocking | `0x4adfe1`, `0x49ecf2`, `0x49f0cd`, `0x4ac552`, and candidate-container state lead into runtime zones. | Native only calls `generator_setup_mode_49ecf2()` if setup `+0x44` is supplied and calls `template_selection_and_runtime_seed_inputs_4ac552_4a218c_4a1f3b()` as a catalog helper (`rmg_native_core.cpp:552-630`). | Candidate/source setup is not owned as a continuous recovered private-state chain. |
| D-004 | Closed for runtime link handoff | Template links preserve guard value, `wide`, and Border Guard payloads for later connection behavior. | `RuntimeLinkSeedInput4a218c` and `SharedRuntimeLinkInput` now carry `guard_value`, `wide`, and `border_guard`; `runtime_seed_inputs_from_template_records_4a218c_4a1f3b()` copies those fields from `TemplateLinkRecord4a1f3b`, and native converters/CLI explicit inputs preserve them (`h3maped_rmg_core.hpp`, `rmg_native_core.hpp`, `h3maped_rmg_core.cpp`, `rmg_native_core.cpp`, `rmg_native_batch_export_cli.cpp`). | The endpoint-collapse drift is closed for runtime link state. Downstream connection/blocker/guard materialization is still unimplemented and remains tracked under D-014. |
| D-005 | Blocking | Native must carry copied `0x4c` source records and descriptor/source identity through object selection. | `SharedRuntimeZoneSeedInput` carries zone id/index/bucket/player/base size plus town/terrain masks only (`rmg_native_core.hpp:27-39`). | Full source record fields `+0x18`, `+0x1c`, `+0x20/+0x24`, `+0x30/+0x34`, `+0x3c`, DEF/name-bearing identity, and descriptor/source crosswalk are absent. |
| D-006 | Blocking | Generated-cell state is stride `0x30` with object-reference vector `+0x04/+0x08`, projection words `+0x10/+0x14/+0x18`, validity byte `+0x2b`, flags `+0x2c`, and word fields. | `RecoveredOwnerGridPayload` stores only six dword arrays `+0x10/+0x1c/+0x20/+0x24/+0x28/+0x2c` plus counters (`rmg_native_core.hpp:106-175`). | The native payload is not the full generated-cell private record. It cannot represent object-reference vectors, `+0x14/+0x18`, or `+0x2b`. |
| D-007 | Closed for misleading surface | A pre-`0x4a4c8e` checkpoint requires source-order private-state ownership and comparison. | The partial owner-grid/TerrainPlacement export is now emitted as `partial_generated_cell_word_surface` with schema `rmg_native_partial_generated_cell_word_surface_v1`, checkpoint id `none_partial_owner_grid_terrainplacement_surface_not_pre_0x4a4c8e`, and status `partial_support_state_not_comparable_pre_0x4a4c8e_checkpoint`. | The JSON no longer claims to be a pre-`0x4a4c8e` checkpoint. Full generated-cell private-state ownership remains D-006/D-008/D-009. |
| D-008 | Blocking | Reset defaults are not valid substitutes for later relation/object/private-state mutations. | The partial word surface now marks `+0x10/+0x1c` and `+0x2c` as partial reset-derived sources, but it still exports hashes/records from reset-derived arrays before later recovered relation/object mutations run. | Native still exposes reset/default fields where the recovered ledger requires later source-order mutation before consumers. |
| D-009 | Blocking | Relation/candidate/action/occupied caller order must include `0x4a5767`, `0x49a318`, `0x4a59e2`, `0x49aa63`, `0x49a932`, `0x49abd6`, `0x49a85d`, `0x49a962`, `0x49cf34`, `0x4aa3e9`, and related inputs. | `generated_cell_mutation_phase_blockers()` only records three grouped missing strings (`rmg_native_core.cpp:144-149`) and does not execute these callers. | Native marks the block too narrowly and does not port the recovered caller order. |
| D-010 | Blocking | `0x49e1bf -> 0x49e700` placement scoring and `0x4a54a7` relation/control linkage are recovered R6 behavior. | No `0x49e1bf`, `0x49e700`, or live `0x4a54a7` relation/control caller exists in `rmg_native_core.cpp`; only missing-phase labels and counters are emitted. | Scoring/relation semantics are not native-owned. |
| D-011 | Blocking | Object identity must come from `objects.txt`, `rand_trn.txt`, copied `0x4c` source records, wrapper/source selectors, and descriptor/source crosswalk. | `rmg_native_core` has no object table loader, no copied source-record storage, no `0xe8` wrapper buckets, and no `0x4903e8` descriptor build joins. | Native cannot preserve final object identity through source records. |
| D-012 | Blocking | Town/castle and weighted materialization surfaces include `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x4a901a`, and `0x4a54a7`. | No town/castle or weighted materialization phase is present in `rmg_native_core.cpp`. | Native cannot place source-backed towns/castles or weighted objects. |
| D-013 | Blocking | Reward/guard projection chain R1 uses `0x540b14 -> 0x49c0a6 -> 0x4ad947 -> 0x4ad7f7` and successful `0x4aa9b7 -> 0x4aa3e9`. | No reward/guard projection, candidate vector, relation pointer join, or `0x4aa9b7 -> 0x4aa3e9` materialization exists in `rmg_native_core.cpp`. | Native cannot generate source-backed rewards/guards. |
| D-014 | Blocking | Endpoint/cursor and fallback behavior includes `0x4a5e73`, `0x4a606b`, `0x4a696b`, `0x4a7312`, `0x4a7605`, and `0x4a5e03`. | No endpoint vector/cursor state exists in `RecoveredOwnerGridPayload`; D-004 now preserves runtime link guard/wide/border-guard payloads, but no connection/fallback materialization code consumes them yet. | Native cannot port recovered connection blockers/guards from the current adapter state. |
| D-015 | Blocking | Roads/rivers/object-adjacency phase includes `0x4ab52a` family before final tile writeout. | No road/river phase or final tile overlay byte writer exists in `rmg_native_core.cpp`. | Native cannot reproduce recovered road/river tile bytes. |
| D-016 | Blocking | Final writeout requires `0x4ad1e3`, `0x49b2b6`, `0x4ad309`, `0x4ad3eb`, header/player/metadata stream writes, stream adapter/sink, and success return. | Native explicitly writes no generation output and no `.amap` (`rmg_native_core.cpp:789-793`). `CaseReport` still has inert `native_map_json_written` fields (`rmg_native_core.hpp:80-90`). | Native has no final tile/object/header writeout authority. |
| D-017 | Closed for misleading surface | The recovery ledger distinguishes H3MapEd recovery from native parity. | Blocked JSON now names the required source as `full_recovered_h3maped_entrypoint_to_writeout_private_state_chain` and says native owns only partial coordinate owner-grid and TerrainPlacement support. | The output no longer describes the partial callable path as the shared recovered private-state chain. |
| D-018 | Closed for misleading surface | Missing native-port phases include source records, descriptor identity, relation/scoring, town/object/reward/guard, endpoint/connection, roads/rivers, and writeout. | `next_required_native_core_slice` now points to `port_full_source_records_descriptor_identity_and_generated_cell_state_before_relation_object_consumers`, and the blocked-chain text lists D-001 through D-003 and D-005 onward as remaining required phases. | The next-slice marker no longer underreports the remaining drift after relation/object mutation. |
| D-019 | Closed for misleading surface | Terrain selection/repaint can only be trusted in the source-order chain and after comparison. | Native now emits non-empty `terrain_selection_parity_blockers` and `terrain_repaint_parity_blockers` explaining that terrain helpers execute on a partial owner-grid surface and remain untrusted for parity until upstream/downstream private state is owned and compared. | The surface no longer implies terrain selection/repaint parity through empty blocker arrays. |
| D-020 | Scope limit | The recovery ledger's fixed scope is direct one-level land evidence, with unsupported modes not claimed. | `supported_one_level_land_scope()` restricts the wrapper to supported Small/Medium one-level land (`rmg_native_core.cpp:136-142`, `199-201`). | This is not a bug by itself, but it means the file is not a broad H3MapEd RMG implementation. |
| D-021 | Blocking | Native parity must be proven by phase/private-state comparison to H3MapEd evidence. | Native emits FNV hashes of its own arrays, but does not compare them to H3MapEd private-state payloads in this file (`rmg_native_core.cpp:301-305`). | The core marks state shape, not parity. |

## Short Form

The native wrapper currently reaches only this subset:

`controlled case -> optional 0x49ecf2 -> optional recovered catalog 0x4ac552 helper -> 0x4a218c/0x4a1f3b/0x4a19ed -> 0x4a3a03/0x4cca55 -> 0x4a2777/0x4a325d/0x4a3710 -> 0x49b53d/0x4a3f27/TerrainPlacement support -> blocked JSON`.

It does not own:

- H3MapEd UI/entrypoint/private generator object setup;
- complete candidate/source containers;
- full copied source records and descriptor identity;
- full stride-`0x30` generated-cell records;
- relation/scoring/object caller order;
- town/castle placement;
- reward/guard projection and attachment;
- endpoint/cursor/connection fallback materialization;
- road/river overlay writeback;
- final tile/object/header stream writeout;
- same-run private-state comparison.

## Marking For Next Implementation

Do not start from final-map deltas. The first implementation drift to fix is the earliest source-order drift that blocks later phases:

1. Replace synthetic controlled-case state with the recovered `0x4602c1 -> 0x4adfe1 -> 0x49ecf2 -> 0x49f0cd -> 0x4ac552` private-state setup path, or explicitly name any input that cannot be represented.
2. Done for the runtime-link handoff: preserve full runtime link payloads (`guard_value`, `wide`, `border_guard`) into runtime/link state instead of reducing links to endpoints. The downstream connection materialization consumer remains D-014.
3. Preserve full copied `0x4c` source records and descriptor/source identity through runtime zones and object selection.
4. Expand generated-cell state to real stride-`0x30` records, including object-reference vectors, `+0x14/+0x18`, and `+0x2b`, before claiming a checkpoint.
5. Port relation/scoring/object caller order before route/object/package consumers.
6. Only then add town/object/reward/guard/connection/road/final-writeout phases in recovered order.
