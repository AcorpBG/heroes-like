# Map/Scenario Persistence GDExtension Skeleton

This folder is the selected native extension home for the map/scenario package API.

The current native slice exposes only inert typed stubs. `MapDocument`,
`ScenarioDocument`, and `MapPackageService` are real Godot GDExtension classes, but
package read/write/conversion/migration/hash behavior intentionally returns stable
`not_implemented` reports. No map package files are authoritative, no saves are
migrated, and no runtime content path adopts these stubs unless a focused
smoke/report instantiates them directly.

The native RMG foundation API is also intentionally narrow. `MapPackageService`
can normalize a minimal random-map config, compute a deterministic foundation
identity, and return generated metadata through `generate_random_map(config)`.
The first parity child slice adds a deterministic native terrain-grid record with
stable terrain codes, biome mapping, dimensions, tile counts, and signatures.
The next child adds deterministic foundation zones and player start anchors with
normalized player constraints, team metadata, zone bounds, owner-grid records, and
stable zone/start signatures.
The current child adds deterministic foundation route graph, road overlay, river,
and waterline records with start coverage and reachability proof fields. Objects,
towns, guards, validation/provenance parity, package conversion, and runtime
session adoption remain `not_implemented`; the existing GDScript
`RandomMapGeneratorRules.gd` stays authoritative for gameplay until a later
parity/adoption slice.

## Dependency Pin

`godot-cpp` is an in-repo git submodule at `third_party/godot-cpp`, pinned to the
official upstream 4.6 API binding tag `10.0.0-rc1`:

```text
58d1de720b8ffe9f8ffcdfe3a85148582cfd2e74
```

The repo targets Godot 4.6.2. Upstream `godot-cpp` does not currently publish a
`godot-4.6.2-stable` tag; this pin is the official `godot-cpp` tag whose
`gdextension/extension_api.json` is generated from Godot 4.6 stable. The
GDExtension manifest declares `compatibility_minimum = "4.6"` for the repo's
Godot 4.6.2 runtime.

Initialize the dependency in a fresh checkout with:

```sh
git submodule update --init --recursive
```

## Native Build

Build the Linux debug GDExtension library from the repo root:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .artifacts/map_persistence_native_build --parallel 2
```

This is the `template_debug` library the editor and headless smokes load. It is
optimized (`RelWithDebInfo`, also the default when no build type is given)
because an unoptimized build makes map generation two to three times slower. Use
`-DCMAKE_BUILD_TYPE=Debug` only when stepping through the code in a debugger.
Each build tree compiles one godot-cpp flavour: `template_release` for `Release`
and `MinSizeRel`, `template_debug` otherwise. Set
`-DAURELION_GODOTCPP_TARGET=template_debug` or `template_release` to choose it
explicitly; the library name always follows the flavour it links.

Build the Linux release library with a separate build directory:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_release -DCMAKE_BUILD_TYPE=Release
cmake --build .artifacts/map_persistence_native_build_release --parallel 2
```

The Linux builds write Godot-loadable libraries to:

```text
bin/libaurelion_map_persistence.linux.template_debug.x86_64.so
bin/libaurelion_map_persistence.linux.template_release.x86_64.so
```

Linux editor/headless smokes load the `linux.editor.x86_64` manifest entry, which
points at the Debug shared library. A Debug build is sufficient for the focused
Godot smokes; Release remains needed for export/template validation.

On Windows, use the helper from a Command Prompt or Developer Command Prompt:

```bat
scripts\build_map_persistence_windows.bat
```

By default it:

- initializes or updates `third_party/godot-cpp`;
- configures MSVC with `-G "Visual Studio 17 2022" -A x64`;
- builds the optimized debug DLL (`RelWithDebInfo` against `template_debug`) and
  the Release DLL (against `template_release`), each in its own build tree;
- verifies the expected DLLs in `bin\`;
- checks `godot --version` before smokes and requires Godot 4.6.2;
- runs the focused native package and native RMG foundation Godot smokes when
  Godot is available.

Windows editor/headless smokes load the `windows.editor.x86_64` manifest entry,
which points at the Debug DLL. A `--debug-only` build is sufficient for the
focused Godot smokes; Release remains needed for export/template validation.

Known gap: only `map_package_api_skeleton_report` still matches the current
native API. The eight `native_random_map_*` smokes in the helper's list check
capability names that `d866370d9` retired in June 2026 (for example
`native_random_map_foundation_stub`), so they fail on any current build and
`--require-test` cannot pass until that list is replaced. Validate a rebuild
with the skeleton smoke, `bin/h3maped_rmg_core_selftest`, and a byte-identical
regeneration of a known generated map on both platforms.

Use the corrected Godot 4.6.2 Windows executable explicitly when it is not the
default `godot` on `PATH`:

```bat
scripts\build_map_persistence_windows.bat --godot "C:\Path\To\Godot_v4.6.2-stable_win64.exe"
```

Useful options:

```bat
scripts\build_map_persistence_windows.bat --debug-only
scripts\build_map_persistence_windows.bat --release-only
scripts\build_map_persistence_windows.bat --skip-test
scripts\build_map_persistence_windows.bat --require-test
scripts\build_map_persistence_windows.bat --godot "C:\Path\To\Godot_v4.6.2-stable_win64.exe"
scripts\build_map_persistence_windows.bat --mingw
scripts\build_map_persistence_windows.bat --allow-other-godot-version
```

If Godot is not on `PATH`, the helper still treats a successful build as a pass
unless `--require-test` is provided. With `--require-test`, missing Godot or
any focused smoke failure fails the helper. When Godot is available and smokes
are not skipped, the helper prints `%GODOT_EXE% --version` output and requires it
to include `4.6.2`. For exceptional local testing with another Godot version,
pass `--allow-other-godot-version`. If `--release-only` is used without
`--skip-test`, the smokes still require an existing Debug DLL because Godot
editor/headless loads the `windows.editor.x86_64` entry.

Run the focused smokes manually with Godot 4.6.2 after adding it to `PATH` or
using its executable name directly. Point `APPDATA` at a temporary folder first so
the smokes cannot touch real saves or settings; the helper does this itself:

```bat
Godot_v4.6.2-stable_win64.exe --headless --path . tests\map_package_api_skeleton_report.tscn
Godot_v4.6.2-stable_win64.exe --headless --path . tests\native_random_map_homm3_re_object_table_proxy_report.tscn
Godot_v4.6.2-stable_win64.exe --headless --path . tests\native_rmg_end_to_end_runtime_boundary_report.tscn
```

The underlying MSVC commands are:

```powershell
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_msvc -G "Visual Studio 17 2022" -A x64 -DAURELION_GODOTCPP_TARGET=template_debug
cmake --build .artifacts/map_persistence_native_build_windows_msvc --config RelWithDebInfo --parallel 2
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_msvc_release -G "Visual Studio 17 2022" -A x64 -DAURELION_GODOTCPP_TARGET=template_release
cmake --build .artifacts/map_persistence_native_build_windows_msvc_release --config Release --parallel 2
```

Visual Studio builds every `--config` from the same godot-cpp flavour, so the
debug and release DLLs need separate build trees.

MinGW-w64 is also supported when `g++` is on `PATH`:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_mingw -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .artifacts/map_persistence_native_build_windows_mingw --parallel 2
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_mingw_release -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release
cmake --build .artifacts/map_persistence_native_build_windows_mingw_release --parallel 2
```

A Linux host can cross-compile with mingw-w64 if `x86_64-w64-mingw32-g++` is installed:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_cross \
  -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
  -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build .artifacts/map_persistence_native_build_windows_cross --parallel 2
```

The Windows builds write Godot-loadable libraries to:

```text
bin/aurelion_map_persistence.windows.template_debug.x86_64.dll
bin/aurelion_map_persistence.windows.template_release.x86_64.dll
```

The `.gdextension` manifest is `src/gdextension/map_persistence.gdextension` and
points Godot at the generated `res://bin/` libraries for Linux and Windows x86_64.
It includes `*.editor.x86_64` entries for editor/headless execution and keeps
`*.debug.x86_64` / `*.release.x86_64` entries for export/template builds. Build
directories should stay in `.artifacts/` so Godot does not scan CMake output as
project content.

## Rules Library (aurelion_rules)

`src/gdextension/rules/` is the native rules engine (owner decision 2026-10-20,
`docs/native-rules-engine-transition.md`). It is its own CMake project, so a rules
change never rebuilds the map generator:

- `core/`, `include/aurelion_rules/`: the rules core, plain C++17 with `std::` only,
  built once as the static library `aurelion_rules_core`.
- `gdextension/`: the GDExtension `aurelion_rules` (class `AurelionRules`, manifest
  `src/gdextension/rules.gdextension`, entry `aurelion_rules_init`), which converts
  packed arrays at the boundary and calls the core.
- `selftest/`: `rules_selftest`, which runs the core without Godot against golden
  vectors that carry their own inputs and against a pinned sweep digest. The same
  digest must come out of MSVC, GCC and MinGW (run under Wine).

`AurelionRules.get_build_info()` returns `api`, `source_tree` (the git tree id of
`src/gdextension/rules` the binary was built from; it equals
`git rev-parse HEAD:src/gdextension/rules` when the binary matches the sources),
`godot_cpp`, `compiler` and `flavour`. GDScript reaches the class through
`scripts/core/NativeRules.gd`. Tools that need it call `NativeRules.available()` and
stop with an error when it is missing.

A checkout that gets a new `.gdextension` file must register it once with
`godot --headless --path . --import`. Until then `.godot/extension_list.cfg` does not
list it, the class is missing, and `tools/core_suite.py` fails its native check.

Both flavours use `/O2 /Ob2 /fp:precise` (MSVC) or `-O2 -ffp-contract=off` (GCC), and
never fast-math or `-march=native`. The debug flavour differs only in the godot-cpp
template it links. Build both with:

```sh
python tools/build_native.py windows            # MSVC here, then bin/rules_selftest.exe
python tools/build_native.py linux              # GCC and MinGW on the Linux build server
python tools/build_native.py linux --part all   # also rebuild and strip the map library
```

`linux` copies the working tree's sources and the pinned godot-cpp to a new `/tmp`
directory on the build server, builds there at nice 19, runs the self-tests, strips
every ELF output, copies `bin/` back, checks each file's sha256, and deletes the
remote directory. Debug info never goes into git. PDBs and the split Linux debug
files go into the symbol store per build id: `HEROES_NATIVE_SYMBOLS`, by default
`heroes-like-native-symbols` next to the main checkout. That holds
`windows/<pdb>/<GUID><age>/<pdb>` (a Microsoft symbol store),
`linux/.build-id/xx/<rest>.debug` (point gdb's `debug-file-directory` at `linux/`),
and `index.jsonl`. Each build prunes the store to the last five builds per binary.

Exports leave out the debug libraries, PDBs, `rules_selftest` and the rules sources
(`export_presets.cfg`).

In a worktree without the godot-cpp submodule, both CMake projects use the main
checkout's `third_party/godot-cpp` when it is at the pinned commit
(`cmake/AurelionGodotCpp.cmake`). `GODOT_CPP_ROOT` overrides this.

## Release Candidate Build

Run the complete clean-source Linux and Windows release-candidate path from the
repository root after committing tracked changes:

```sh
python3 tools/build_release_candidate.py --version 0.1.0-rc1
```

The driver rebuilds the release map and rules GDExtensions and native self-tests, runs the
Linux self-test directly and the Windows self-test under Wine, parses the Godot
project, runs repository validation, then delegates export, installer creation,
provenance binding, and final verification to `tools/package_release.py`.
Outputs and the machine-readable `release-candidate-result.json` are written
under `.artifacts/release-candidate/` by default. The same driver is the only
build entrypoint used by `.github/workflows/release-candidate.yml`; that workflow
retains verified artifacts but does not publish or sign a release.

## Smoke Validation

Focused native load smoke:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/map_package_api_skeleton_report.tscn
```

Focused native RMG smoke (object-table translation, then generation, packages and
sessions across the supported release matrix):

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/native_random_map_homm3_re_object_table_proxy_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/native_rmg_end_to_end_runtime_boundary_report.tscn
```

Passing output includes:

```text
MAP_PACKAGE_API_SKELETON_REPORT ... "binding_kind":"native_gdextension" ... "native_extension_loaded":true ...
```

The GDScript files in `scripts/persistence/` remain compatibility shims for fallback
or API comparison, but the focused report treats native load as the required happy
path.
