# H3MapEd RMG Private-State Recovery

Document role: source-backed recovery ledger for the H3MapEd generated-cell private state.

This document records Ghidra-backed facts only. It is not a native RMG fix and it must not be used as permission to tune final map density. Native behavior changes still require phase/private-state replay parity.

## Current Recovery Scope

Canonical binary:

- `.artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe`
- SHA-256: `f1ab1565fdfb7581cf67ca18a5349bf26fce59f696ea33061f941d80fcc069be`

Generated artifacts:

- `.artifacts/rmg_recovery/ghidra_private_state_dump/`
- `.artifacts/rmg_recovery/ghidra_private_state_expanded_dump/`
- `.artifacts/rmg_recovery/seed58_existing_0x4a4c8e_parse/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_writer_trace_reparsed_cells/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_downstream_writer_trace_reparsed_cells/winedbg_recovery_trace_ledger.json`

## Generated Cell Layout

Recovered layout:

- Stride: `0x30`.
- `+0x20`: score/owner word consumed by the `0x4a4c8e` family.
- `+0x24`: terrain/art word; low 6 bits are terrain id.
- `+0x28`: generated-cell bit-state word.
- `+0x2b`: byte tested by `0x49a1d8` for validity bit `0x02`.
- `+0x2c`: private flags; bit `0x01` suppresses `0x49a932` and `0x49aa63`.

The grid wrapper seen by `0x49a072` uses:

- `+0x08`: generated-cell buffer.
- `+0x0c`: width.
- `+0x10`: height.
- `+0x14`: level count.

The generator object seen by `0x4a4c8e` / `0x4a8c15` uses:

- `+0x14`: generated-cell buffer.
- `+0x18`: width.
- `+0x1c`: height.
- `+0x20`: level count.
- `+0x10e4..+0x10e8`: relation/vector range consumed after `0x4a4c8e`.

## Recovered Functions

`0x499e65` constructs one generated-cell record and calls `0x499ea3`.

`0x49a072` resets the full generated-cell grid. It reads the wrapper buffer and dimensions, then calls `0x499ea3` for `width * height * level_count` records while advancing by `0x30`.

`0x499ea3` is the generated-cell initializer. It:

- clears `cell+0x2c` bit `0`;
- writes `cell+0x10 = 0xffffffff`;
- writes `cell+0x1c = 0x7fbc7fbc`;
- writes `cell+0x20 = 0xffff7fbc`;
- writes `cell+0x24 = (old & 0xc0000548) | 0x00000548`;
- writes `cell+0x28 = (old & 0x01000000) | 0x0a000000`.

So the initializer intentionally sets bit25 and bit27. The pre-`0x4a4c8e` H3MapEd state having only 407 bit27 cells is caused by later mutation phases, not by a different initializer.

`0x49a1d8` is a generated-cell validity predicate. It returns true only when:

- `cell+0x2b & 0x02` is non-zero;
- `(cell+0x24 & 0x3f) != 9`.

`0x49a932` is a bit27 writer guarded by `cell+0x2c bit0`:

- false argument clears bit27;
- true argument sets bit27 and clears bit26.

`0x49aa63` is a bit26 writer guarded by `cell+0x2c bit0`:

- false argument clears bit26;
- true argument sets bit26 and clears bit27.

`0x49abd6` stamps object/vector footprints into generated-cell state. Runtime seed-58 trace shows five calls before the bounded trace stopped, all returning through `0x4a54d6`; inside it, valid target cells call `0x49a932`.

`0x4a8c15` is a post-terrain generated-cell phase driver. Ghidra shows this order:

1. `0x4a8260`
2. `0x4a4c8e`
3. per-cell scan that can call `0x49a962`
4. relation-vector loop over `generator+0x10e4..+0x10e8` calling `0x4a4913`
5. `0x4a5767`
6. `0x4a4fc5`
7. `0x4a79a3`

## Seed-58 Runtime Correlation

At H3MapEd `0x4a4c8e` entry, the dumped 36x36 generated-cell grid has:

- bit22: `5`
- bit25: `1236`
- bit26: `490`
- bit27: `407`
- owner byte3: `-1` for all 1296 cells

The bounded writer trace found:

- `0x499ea3`: first 64 events, return `0x499e8f`, flat cells `0..63`.
- downstream excluding `0x499ea3`: 112 events.
- `0x49a932`: 107 events.
- `0x49abd6`: 5 events.
- return addresses: `0x49a91d` 91 times, `0x49a88d` 11 times, `0x4a54d6` 5 times, `0x49ac70` 5 times.

That ties the observed bit27 reduction to `0x49a932` callers, especially `0x49a85d`, `0x49a962`, and the `0x49abd6` footprint path.

## Current Unrecovered Gap

The full end-to-end state is not yet recovered.

The missing piece is a complete ordered replay of all pre-`0x4a4c8e` callers that mutate `GeneratedCell+0x20/+0x24/+0x28/+0x2c`, especially the call paths through:

- `0x4a8260`
- `0x49a85d`
- `0x49a962`
- `0x49cf34`
- `0x49eb8d`
- `0x4a54a7`
- `0x4a5767`
- `0x4a606b`
- `0x4a746b`

Until that ordered replay matches the H3MapEd `0x4a4c8e` entry grid, native RMG remains blocked for source-backed parity fixes.
