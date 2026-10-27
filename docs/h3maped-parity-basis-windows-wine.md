# H3MapEd parity basis: Windows vs Wine, seeds 137 and 211

Document role: recovery evidence, the native fix it led to, and an owner-decision
record (2026-10-09). Evidence, traces, maps and tools:
`.artifacts/rmg_recovery/support/windows_h3maped_parity_basis_20261009/README.md`.
Tool source: `tools/rmg_h3maped_win32_trace/h3trace.c`.

## Question

`map8_unguarded_route_20261009` saved the seed-patched GOG `h3maped.exe` (SHA-256
`4480fba1...`, same LODs) on Windows 10 for six seeds and got maps that differ from
the Wine references, which the native port reproduces, in roads, flags and
obstacle/reward objects. Which platform is the parity target?

## Finding: no platform difference under controlled input

Driven by window messages from `h3trace` (scratch copy, debugger attached after
startup), Windows H3MapEd matches the Wine references semantically (tile bytes and
object multiset) for all eight seeds tried: 58, 3451295931 (map 8, matched against
native), 1, 73, 2, 28, 137 and 211. Seed 58 also matches without a debugger, over
three generations in one process, with OK pressed four different ways, with the
dialog set by posted clicks and keys, and with 64 KiB of zero or random bytes
written below the generator entry stack.

The earlier Windows maps were made with desktop mouse/keyboard control. They match
up to the first reward pick of `0x4aab7e`, then differ.

## Desktop-run divergence: uninitialized generator `+0xf5c`

Recovered with a traced desktop replay (`h3trace --pid`, evidence section 5). The
generator object is a stack local, and its setup (`0x49ecf2`) writes `+0xf58` but
never `+0xf5c`. For these maps none of the eight `+0xf5c` writers runs, so the field
keeps whatever earlier calls left at that stack address. The value depends on how
File > New was invoked, because each path puts the generator at a different depth.

| how New is opened | generator | `+0xf5c` | map |
| --- | --- | --- | --- |
| Ctrl+N (desktop) | `0x19dfa8` | 0 | the old "Windows" maps |
| File menu (desktop) | `0x19e05c` | `0x011d6fc0` | = Wine |
| toolbar New (desktop) | `0x19dacc` | `0x011be0d0` | = Wine |
| posted `WM_COMMAND` | `0x19e05c` | `0x01xxxxxx` (varies) | = Wine |
| Wine (Alt+F, N) | | `0x7a1befdf` | Wine references |

`+0xf5c` is read by the Keymaster's Tent candidate value at `0x49cd9b`, through the
`0x4a9f1c` candidate loop. The tent (vtable `0x540ca0`, type 10) is eligible only if
`+0xf5c` equals its colour subtype. It is also read by the Border Guard endpoint
`0x4a5e73`, which these Small maps don't reach. When the value is 0, colour-0
tents enter the reward candidate sets and change the weighted picks.

Writing 0 to `+0xf5c` at generator entry in a message-driven run reproduces all six
desktop maps exactly. Any value outside 0..7 gives the Wine maps. Native models
the field with Wine's observed stale value `0x7a1befdf`. Set to 0 instead, native
reproduces five of the six desktop maps. Seed 2, the only one where a tent is
actually placed, stops at `0x4ad1e3_ordered_payload_final_zero_sentinel_missing`.
The tent's projection branch (`0x540b00` -> `0x49c019` -> `0x4adb72`/`0x4adef7`)
and its writeout are not ported.

Owner decision, 2026-10-27: keep. The Ctrl+N variant is not modelled.

The two options were:
- Keep: the Wine/menu/toolbar behaviour (no Keymaster's Tents, current native,
  60/72 references exact).
- Model Ctrl+N: `+0xf5c` = 0, so colour-0 tents can appear. This needs the
  `0x540b00`/`0x49c019`/`0x4adb72`/`0x4adef7` tent projection branch and its
  writeout ported first.

Other Ctrl+N stack garbage (1..7, other UI histories) would select other colours.
That is undefined behaviour in H3MapEd, not a platform difference.

## Seeds 137 and 211: native defects with private-state proof

Both seeds reproduce on Windows exactly as under Wine; native diverges.

- Seed 137. The first difference is the second `0x4a9f1c` reward pick. Native
  values creature Pandora's Boxes 5% high, so Magog x30 and Gog x45 exceed the
  zone band. The cause is the terrain-pressure table built by `0x4aadd2` from
  relation owners whose byte `+0x3c` is set. H3MapEd sets that byte only at
  `0x4a95a4`, the success path of `0x4a93a2`, and the constructor `0x49b4cd`
  zeroes it. The trace shows that store hitting owners 0, 1 and 5 only. Native's
  `0x4a8db2` replay also copies the shared type-98 source pair's success byte into
  `owner.byte_0x3c`, which marks owner 4 (Inferno, town placement failed).
- Seed 211. The first difference is obstacle pick 63: native lacks one
  `AVLlk3s0.def` candidate because it placed a second Crystal pile at (20,14).
  H3MapEd's `0x49aa93` rejects that pile at `0x49ab87..0x49abac`. The entry cell
  has bit 22, the occupying object (first cell reference) is type 53, and type
  53's flag byte 2 in `0x598300` is 0. Both native ports of `0x49aa93` skip this
  check whenever the candidate's own type has flags 2 and 1.

## Fix (landed 2026-10-09)

`native-rmg-owner-success-and-entry-occupant-20261009` makes both changes in
`src/gdextension/src/h3maped_rmg_core.cpp`. The `0x4a8db2` replay no longer
writes `owner.byte_0x3c`; it still updates the shared pair, and the owner gets the
byte only from the `0x4a93a2` success route. Both `0x49aa93` ports call
`projection_cell_occupant_allows_entry_0x49aa93`, which checks the occupant's
type.

Validation:
- The semantic sweep goes from 57/72 to 60/72 references exact: Small 137 (by
  the owner fix), Small 211 and Medium compare seed 17 (by the occupant check).
  No other reference changed exactness, cell count or object count.
- `h3maped_rmg_core_selftest` passes on Windows (MSVC) and Linux (GCC 13.3).
- All 72 reference payloads are byte-identical between the Windows and Linux
  builds.
- On Windows (Godot 4.6.2), `map_package_api_skeleton_report`,
  `native_random_map_homm3_re_object_table_proxy_report` and
  `native_rmg_end_to_end_runtime_boundary_report` pass. Linux Godot smokes
  were not run.
- All Windows and Linux native binaries in `bin/` are rebuilt from the same
  source.
