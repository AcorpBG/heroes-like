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
- `.artifacts/rmg_recovery/ghidra_private_state_terrain_writer_dump/`
- `.artifacts/rmg_recovery/seed58_existing_0x4a4c8e_parse/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_writer_trace_reparsed_cells/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_downstream_writer_trace_reparsed_cells/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49aa63_to_4a4c8e/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49a932_to_4a4c8e_lite/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49a85d_to_4a4c8e_lite/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49a962_to_4a4c8e_lite/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49abd6_to_4a8c15/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_49abd6_body_cells_to_4a8c15/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_interactive_4a80dc_return_to_4a4c8e/winedbg_interactive_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_piped_4a8260_route_call_sites_to_4a4c8e_full/winedbg_recovery_trace_ledger.json`
- `.artifacts/rmg_recovery/seed58_trace_analysis.json`
- `.artifacts/rmg_recovery/ghidra_downstream_state_dump/`
- `.artifacts/rmg_recovery/ghidra_downstream_helper_dump/`
- `.artifacts/rmg_recovery/ghidra_object_projection_helper_dump/`

## Generated Cell Layout

Recovered layout:

- Stride: `0x30`.
- `+0x04/+0x08`: object-reference dword vector begin/end observed by `0x49e1bf`.
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
- `+0xec4`: object record vector anchor observed by `0x4a54a7`.
- `+0xecc`: object record vector insertion/end pointer observed by `0x4a54a7`.
- `+0xed4`: optional handler pointer used by `0x49eb8d` for invalid bit26 candidate cells; vtable slot `+0x08` is called with the per-cell budget.
- `+0x10e4`: relation/vector begin pointer consumed after `0x4a4c8e`.
- `+0x10e8`: relation/vector end pointer consumed after `0x4a4c8e`.
- `+0x1110`: descriptor-type counter table indexed by descriptor `+0x1c` in `0x4a54a7`.

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

`0x49acf6` writes terrain/art and private per-cell flag bits. It:

- writes `cell+0x24 = (old & 0xffffc000) | (terrain_arg & 0x3f) | ((arg2 & 0xff) << 6)`;
- writes `cell+0x28` by clearing bit `15` and OR-ing `((arg3 & 1) | ((arg4 & 1) << 1)) << 15`;
- is called by `0x49ce64` after `0x49a072` reset in a full-grid stride-`0x30` loop.

`0x49a85d` is a clipped 3x3 bit27 neighborhood stamp. It uses the grid wrapper layout `+0x08` cell buffer, `+0x0c` width, `+0x10` height. For coordinate `(x, y, level)`, it computes:

`cell = grid+0x08 + 0x30 * (((level * height) + y) * width + x)`.

It calls `0x49a932(true)` for the center cell and then calls `0x49a932(true)` for every cell in the clipped rectangle `[x - 1, x + 2) x [y - 1, y + 2)` on that level. This intentionally revisits the center cell.

`0x49a932` is a bit27 writer guarded by `cell+0x2c bit0`:

- false argument clears bit27;
- true argument sets bit27 and clears bit26.

`0x49aa63` is a bit26 writer guarded by `cell+0x2c bit0`:

- false argument clears bit26;
- true argument sets bit26 and clears bit27.

`0x49a962` is the related bit26/bit27 neighborhood helper. It uses the same coordinate formula as `0x49a85d`. It calls `0x49aa63(true)` for the center cell, then scans the clipped 3x3 neighborhood. For each neighbor, it calls `0x49a932(false)` only when:

- bit22 in `cell+0x28` is clear;
- `0x49a1d8(cell)` returns true;
- terrain id `(cell+0x24 & 0x3f)` is not `8`.

`0x49abd6` stamps object/vector footprints into generated-cell state. Runtime seed-58 trace shows five calls before `0x4a8c15`, all returning through `0x4a54d6`. The internal `0x49ac6b` call-site trace records exactly five body-cell writes through `0x49a932(true)`, at generated-cell flats `184`, `666`, `604`, `975`, and `1059`. These five flats are the seed-58 pre-`0x4a4c8e` bit22 cells and also retain bit27.

`0x4a80dc` chooses a route/line cut point. It receives an output pointer, start coordinate, target coordinate, and level. The target coordinate may be off-map; runtime traces show values like `(-2, 38)` and `(68, -32)`. Static reconstruction shows a Bresenham-style line walk from start toward target. After the first two steps, for each in-bounds interior point, it scans a clipped 3x3 neighborhood for bit27. When it finds bit27, it writes the previous coordinate to the output pointer and returns that pointer. If it reaches an out-of-bounds point first, it writes the current candidate coordinate.

The `0x4a8260` route container helpers are recovered as 8-byte coordinate container primitives:

- `0x4072b5` inserts one or more 8-byte coordinate records into a dynamic vector whose begin/end/capacity pointers live at `ecx+0x04/+0x08/+0x0c`. It reallocates through `0x5044b1` when the existing capacity is insufficient, copies records before and after the insertion point, then updates begin/end/capacity.
- `0x40bb15` appends one 8-byte coordinate record by calling `0x4072b5` with insertion position `vector+0x08` and count `1`.
- `0x4ae501` inserts one 8-byte coordinate record at a caller-provided vector position and returns the inserted-position pointer adjusted for possible reallocation.
- `0x4afaea` erases one 8-byte coordinate record from a vector by shifting later records left and decrementing the end pointer by `8`.
- `0x4ae64c` allocates a 16-byte doubly linked list node with previous/next pointers at `+0x00/+0x04`.
- `0x4ae5a8` inserts a linked-list node after a caller-provided node, copies an 8-byte coordinate payload into `node+0x08/+0x0c`, increments the list count at `ecx+0x08`, and writes the new node pointer through the caller output pointer.
- `0x4ae5e6` removes a linked-list node, relinks previous/next, frees the node through `0x5044da`, decrements the list count at `ecx+0x08`, and writes the previous node pointer through the caller output pointer.

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

The interactive phase trace fixes the earlier piped-debugger limitation and proves the seed-58 bit26 boundary path:

- `0x4a8c15` enters from return address `0x004ac778`.
- `0x4a8c15` calls `0x4a8260`, return address `0x004a8c25`.
- Inside `0x4a8260`, H3MapEd calls `0x49aa63` exactly `490` times before `0x4a4c8e`.
- All `0x49aa63` calls return through `0x0049a992`.
- All traced `0x49aa63` stack arguments are `true`.
- The `490` calls target `490` unique generated-cell flats, min `3`, max `1291`.
- The next phase-boundary event is `0x4a4c8e`, return address `0x004a8c2c`.

That matches the already dumped seed-58 `0x4a4c8e` entry bit26 count (`490`). This is a recovered source-backed boundary for `0x49aa63` on seed 58.

The interactive route-stamp trace proves the seed-58 `0x49a85d` route path:

- `0x4a8260` calls `0x49a85d` exactly `340` times before `0x4a4c8e`.
- All calls return through `0x004a8594`.
- The `340` calls contain `238` unique center coordinates, all on level `0`.
- Replaying `0x49a85d` clipped 3x3 stamps from those centers produces `3,029` stamp events over `756` unique generated-cell flats.
- Those stamped flats cover `357` of the final `407` pre-`0x4a4c8e` bit27 cells.
- `50` final bit27 cells are outside the recovered `0x49a85d` stamp coverage; the `0x49a962` replay below explains why they survive.
- `399` stamped flats are not final bit27 cells, consistent with later clearing by `0x49aa63`/other writers.
- The recovered `0x49a85d` stamp coverage does not intersect the final bit26 cells.

The interactive `0x49a962` trace proves the seed-58 boundary clear path:

- `0x4a8260` calls `0x49a962` exactly `490` times before `0x4a4c8e`.
- The `490` calls contain `490` unique center coordinates, all on level `0`.
- Each center calls `0x49aa63(true)`, matching the `490` final pre-`0x4a4c8e` bit26 cells.
- Replaying the recovered `0x49a962` rule clears `889` unique flats from the initialized bit27 surface.
- The replay leaves exactly `407` bit27 cells, matching the dumped H3MapEd `0x4a4c8e` entry grid.
- The previously unexplained `50` bit27 cells outside `0x49a85d` route-stamp coverage are now explained by the same replay: `4` are skipped because bit22 is set and `39` are skipped because `0x49a1d8` would return false; none are due to terrain id `8`, and none are outside the replayed remaining-bit27 set.
- The `0x49abd6` body-cell trace separately proves that object footprints directly write only five body cells, not fifty surrounding cells.

The interactive `0x4a80dc` trace records `52` route-line helper entry/return pairs before `0x4a4c8e`, with `51` unique returned coordinates. These are the line-cut inputs used by the route list logic that ultimately feeds `0x49a85d`.

The piped `0x4a8260` route call-site trace recovers the seed-58 route insertion/stamp stream up to `0x4a4c8e`:

- The trace records `2,027` ordered events; the first `0x4a4c8e` event is index `2026`.
- Route-vector insert call sites fire `1,686` times total: `0x4a8491`, `0x4a849d`, `0x4a84a9`, and `0x4a84b5` fire `416` times each, while `0x4a863e` and `0x4a864a` fire `11` times each.
- Those insertions contain `361` unique coordinate pairs.
- The same trace records all `340` `0x4a858f -> 0x49a85d` stamp calls, with `238` unique stamp coordinates.
- The traced `0x4a858f` stamp coordinate order exactly matches the direct `0x49a85d` trace.
- The `11` `0x4a863e`/`0x4a864a` insertion pairs match the `0x4a80dc` return-distance gate: exactly `11` of the `52` route-line helper pairs have squared distance from start to returned cut point greater than or equal to `25`.

The companion interactive `0x49a932` trace remains intentionally bounded:

- The lite trace records `0x4a8c15`, `0x4a8260`, then `2,999` `0x49a932` events before hitting the configured `3,000` event cap.
- Return addresses in that bounded sample are `0x0049a91d` (`2,690`), `0x0049a88d` (`303`), and `0x0049ac70` (`5`).
- The traced calls use true stack arguments in the parsed events.
- The stream revisits cells heavily: `2,998` parsed generated-cell flats but only `702` unique flats.
- It did not reach `0x4a4c8e` before the cap.

Static reconstruction and the complete `0x49a962` caller trace explain why event tracing `0x49a932` directly is the wrong unit for this phase: the high-volume pre-boundary stream is dominated by repeated `0x49a85d` 3x3 stamps from the route/line generation inside `0x4a8260`, plus caller-side clears from `0x49a962`. The recovered caller-side replay now accounts for the seed-58 pre-`0x4a4c8e` bit26 and bit27 surfaces.

## Downstream Ghidra Dump

The downstream Ghidra artifact `.artifacts/rmg_recovery/ghidra_downstream_state_dump/` was generated with the repository `H3MapEdRmgDump.java` script against:

`0x49cf34,0x49eb8d,0x4a54a7,0x4a5767,0x4a606b,0x4a746b,0x4aa3e9`.

Ghidra identified all seven target functions and eight caller dumps, but the decompiler did not complete for these targets. The artifact is therefore call-graph/reference/instruction evidence, not clean recovered C source. Current source-backed facts from the dump:

- `0x49cf34` is called by `0x4aa354` and `0x4adb72`. Its references show calls to `0x49d7c3`, `0x49d2c7`, `0x49a1d8`, `0x49aa63`, `0x49a932`, `0x49d2e0`, `0x49d69d`, and `0x49d6e0`.
- `0x49eb8d` is called by `0x4ac552` and `0x4af910`. Its static control flow is now recovered as three ordered full-grid passes over generator fields `+0x14/+0x18/+0x1c/+0x20`. Pass 1 counts cells where `(GeneratedCell+0x28 >> 26) & 1` is set. If the count is zero, it exits without mutation. Otherwise pass 2 computes `budget = 0x4374c / count`, scans z/y/x in level/height/width order, and handles each bit26 cell: valid cells according to `0x49a1d8` call `0x49e700(x, y, level, budget)`, while invalid cells call the optional `generator+0xed4` handler vtable slot `+0x08` with the same budget when the handler exists. Pass 3 scans all cells again and calls `0x49a932(true)` when bit27 is clear and `0x49a1d8` is true. Runtime coordinate/count replay remains pending.
- `0x4a54a7` is the object-footprint commit and local projection shell referenced through data slot `0x540cc0`. Static recovery shows it reads the generator pointer in `ecx`, the generated-cell wrapper at `generator+0x0c`, the object record stack arg, candidate x/y/level stack args, the generator object vector anchored at `+0xec4`, the relation table at `+0x10e4`, and direction tables `0x5a2658..0x5a2698`. It calls `0x49abd6` first to stamp the object footprint, inserts the object record into the generator object vector through `0x42d8d8`, increments `generator+0x1110[descriptor+0x1c]`, conditionally increments relation-table counters using a non-negative high-byte index read from descriptor-side `+0x20`, clears a low word at an addressed `+0x20` word before local projection, builds two local dword vectors, filters/sorts them through `0x4ae20e`, `0x4ae23e`, `0x4cce95`, and `0x430b35`, and inserts selected dwords through `0x4ccecb`. Exact semantic names for the local vectors, relation-table entries, and generated-cell `+0x20` low-bit projection remain replay-pending.
- `0x4a5767` is the cell-occupancy reset and relation-local object-anchor normalization shell called by `0x4a8c15`, `0x4a746b`, and `0x4ac552`. Static instruction recovery shows it reads the generator pointer in `ecx`, the generated-cell buffer/dimensions at `generator+0x14/+0x18/+0x1c/+0x20`, and the relation pointer vector at `generator+0x10e4..+0x10e8`. It first scans every generated-cell record, calls `0x4a59e2(cell, 0x7d00, 0, -1)`, forces the `cell+0x1c` low word to `0x7d00`, and copies a local triple into `cell+0x10/+0x14/+0x18`. It then walks each relation pointer, copies relation `+0x20..+0x2f` as four scan-bound dwords, copies relation `+0x10..+0x1b` as a 12-byte coordinate/range triple, and compares relation `+0x0c` with `8`. Inside the relation bounds it computes generated-cell pointers from `(level, y, x)`, gates on generated-cell `+0x20` byte2 matching the relation index, terrain id at `+0x24`, object-reference vector occupancy at `+0x04/+0x08`, bit27 at `+0x28`, `0x49a1d8`, and `cell+0x1c` low word. The shell calls `0x49a932(true)` when its first scan does not find a candidate, calls `0x49a318` with the generator grid wrapper at `generator+0x0c`, and calls `0x4a5a23(generator, coordinate triple, false)` during the second valid occupied-cell scan before another `0x49a318` projection call. Exact semantic names for the relation fields, `0x4a59e2`, `0x49a318`, `0x4a5a23`, and ordered runtime replay remain pending.
- `0x4a606b` is called by `0x4a61bc` and calls `0x49aa63` and `0x49a932` in a connection-region generated-cell writer path.
- `0x4a746b` is called twice by `0x4a7605`; it calls `0x4a5767`, `0x4a5e73`, and `0x49aa63`.
- `0x4aa3e9` is called by `0x4aa9b7` and calls `0x49d2c7`, `0x49a1d8`, `0x49a932`, and `0x49aa63`.

The helper-layer Ghidra artifact `.artifacts/rmg_recovery/ghidra_downstream_helper_dump/` was generated against:

`0x49d7c3,0x49d2e0,0x49d69d,0x49d6e0,0x49e700,0x49a318,0x4a5a23,0x4a5e73`.

It identifies the next helper layer:

- `0x4ccecb` is the 4-byte record vector insert primitive, parallel to the 8-byte coordinate insert helper `0x4072b5`. `0x40bb26` wraps it to append one dword at vector end.
- The reward/guard wrapper uses generated-cell buffer/dimensions at `+0x08/+0x0c/+0x10`, bounds at `+0x18/+0x1c/+0x20/+0x24`, a selected-member dword vector anchored at `+0x28`, and a candidate-coordinate vector anchored at `+0x38`.
- `0x49d2e0` is called by `0x49cf34` and `0x49d471`. It reads the object descriptor through arg1, candidate coordinates from the stack, wrapper grid fields at `ecx+0x08/+0x0c/+0x10`, and direction tables at `0x5a2658` / `0x5a2680`. It returns false when bit22/object adjacency/terrain rules reject the candidate and true when the candidate passes those checks. Exact descriptor field names remain replay-pending.
- `0x49d69d` is called by `0x49cf34`. It appends arg1 to the wrapper's selected-member dword vector anchored at `+0x28`, then stamps arg2/arg3/level-0 through `0x49abd6`.
- `0x49d6e0` is called by `0x49cf34`, `0x4aa1db`, `0x4adb72`, and `0x4ad947`. It initializes wrapper bounds to `0x7d00/0xffff8300` sentinels, scans generated cells through `0x49a1d8`, and updates bounds for cells that are invalid, have bit22 set, or have bit27 clear.
- `0x49d7c3` is called by `0x49cf34` and reward/guard setup callers. When the wrapper candidate-coordinate vector is empty, it finds the first valid bit27 cell with bit22 clear, traces the contour using the `0x5a2658` direction table, and appends 8-byte coordinates into the vector anchored at `+0x38`.
- The focused object-projection helper dump `.artifacts/rmg_recovery/ghidra_object_projection_helper_dump/` covers `0x49e1bf`, `0x41e951`, `0x49ba89`, `0x4a9e40`, and `0x49eb6d`.
- `0x41e951` is an object descriptor bitset lookup. It reads the bitset at `ecx+0x04`, computes bit index `47 - 8*y - x`, and returns whether that bit is set. It calls `0x42f2ec` if the computed index is outside the expected `0..47` range.
- `0x49eb6d` maps `(x, y, level)` to a generated-cell pointer using wrapper fields `+0x08/+0x0c/+0x10`: `cell = buffer + (((level * height) + y) * width + x) * 0x30`.
- `0x49ba89` constructs an object record with vtable `0x540a74`, descriptor pointer at `+0x04`, increments descriptor refcount at `descriptor+0x08`, and initializes record `+0x08/+0x0c/+0x10` to `-1`. The later projection meanings of those initialized fields remain replay-pending.
- `0x49b89c` is an object-record mask/score cache builder. It is idempotent on record byte `+0xe4`, reads the descriptor through record `+0x00`, walks descriptor dimensions `+0x34/+0x38`, calls the descriptor mask helpers `0x41e915` and `0x41e951`, and fills a record-local dword table beginning at `+0x18`. Exact score-table semantic names remain replay-pending.
- `0x4a9e40` selects an object descriptor from a bucket vector at `+0x38/+0x3c`, filters candidate descriptor fields `+0x20`, `+0x24`, and bitset `+0x18`, then chooses one descriptor by `0x4e7276 % candidate_count`. Exact selector argument names and descriptor class values remain replay-pending.
- `0x49a6f9` is called by `0x49aa93`, `0x49d2e0`, and `0x4aa603`. It is an object-descriptor footprint acceptance gate: it reads descriptor dimensions at `+0x34/+0x38`, walks the candidate footprint through generated-cell validity, owner, terrain, optional bit26, and `0x41e951` mask tests, and returns rejection as true. Exact descriptor field names beyond dimensions and terrain policy branches remain replay-pending.
- `0x49e700` is called by `0x49eb8d`. It iterates the terrain-object descriptor table `0x54092c..0x5409e0`, rejects invalid candidate cells and terrain type `9`, filters object type ranges by map level count, scans local footprint offsets through `0x41e951`, calls `0x49e1bf` for scoring/emission feasibility, accumulates accepted weights, then creates/projects one weighted decorative object and clears bit26 around the chosen footprint unless `GeneratedCell+0x2c` bit0 suppresses mutation. Exact object record allocation/projection fields remain replay-pending.
- `0x49e1bf` is the decorative object scoring and emission-feasibility helper called by `0x49e700`. Static recovery shows it reads the generator generated-cell grid through `+0x14/+0x18/+0x1c`, the candidate object record and descriptor, candidate x/y/level stack args, descriptor dimensions `+0x34/+0x38`, descriptor masks `+0x04/+0x14/+0x3c`, generated-cell words `+0x24/+0x28/+0x2b`, and the `GeneratedCell+0x04/+0x08` object-reference vector. It builds stack-local footprint records with flags `0x1/0x2/0x4`, records terrain-class hits in ten buckets, scans neighbor cells through a scratch rectangle, sets temporary object-reference flags at `+0x14..+0x18`, appends flagged object references through `0x40bb26`, adjusts the score through descriptor score tables prepared by `0x49b89c`, clears those temporary flags, and returns a candidate score or one of the observed rejection values `-1`, `-5000`, or a low terrain-weight total below `-1000`. Exact semantic names for the descriptor score tables and the object-reference flag classes remain replay-pending.
- `0x49a318` is called by `0x4a5767` and `0x4a89da`; it is part of the object-anchor/high-owner projection path.
- `0x4a5a23` is called by `0x4a5767` and `0x4a61bc`; it reaches allocation/object-selection helpers including `0x4a9e40`, `0x5044b1`, and `0x49ba89`.
- `0x4a5e73` is called by `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, and `0x4a746b`; it reaches endpoint/allocation helpers including `0x5044b1`, `0x49ba89`, and `0x4a7312`.

## Current Unrecovered Gap

The full end-to-end state is not yet recovered.

The seed-58 pre-`0x4a4c8e` route call-site stream, the route coordinate helper contracts, and the bit26/bit27 surface are now caller-side replayed or statically recovered. Ghidra reference dumps and static helper recovery now identify the downstream generated-cell writer call graph, candidate-vector helpers, reward/guard wrapper fields, generated-cell addressing, object mask lookup, the object record constructor, the object-record mask/score cache builder, the object-descriptor selector, the object-descriptor footprint gate, the bit26 decorative candidate budget pass, the decorative candidate filler shell, the decorative object scoring/emission-feasibility shell, and the object-footprint commit/local projection shell. The full generator state chain is still incomplete. The missing piece is a complete ordered replay of all generated-cell and object/vector phases, including `GeneratedCell+0x20/+0x24/+0x28/+0x2c` and the object/vector structures that feed them, especially the downstream call paths through:

- `0x49cf34`
- `0x49eb8d` runtime coordinate/count replay around `0x49e700` and the optional `+0xed4` handler
- `0x49e1bf`
- `0x4a54a7` local vector/relation-table/generator-cell `+0x20` projection replay
- `0x4a5767` relation-record field semantics, helper semantics, and ordered runtime replay
- `0x4a606b`
- `0x4a746b`

Until that ordered replay matches the H3MapEd `0x4a4c8e` entry grid, native RMG remains blocked for source-backed parity fixes.
