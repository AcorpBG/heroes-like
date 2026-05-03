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
identity, and return an empty generated `MapDocument` stub through
`generate_random_map(config)`. Full terrain/object/road/town generation remains
`not_implemented`; the existing GDScript `RandomMapGeneratorRules.gd` stays
authoritative for gameplay until a later parity/adoption slice.

## Dependency Pin

`godot-cpp` is an in-repo git submodule at `third_party/godot-cpp`, pinned to the
`godot-4.2.2-stable` tag:

```text
98c143a48365f3f3bf5f99d6289a2cb25e6472d1
```

The project currently declares Godot 4.2 features in `project.godot`. Targeting the
4.2.2 stable binding keeps the extension compatible with the repo's declared Godot
minor while allowing later Godot 4 runtimes to load it through GDExtension's
forward-minor compatibility.

Initialize the dependency in a fresh checkout with:

```sh
git submodule update --init --recursive
```

## Native Build

Build the Linux debug GDExtension library from the repo root:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build -DCMAKE_BUILD_TYPE=Debug
cmake --build .artifacts/map_persistence_native_build --parallel 2
```

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

On Windows, use the helper from a Command Prompt or Developer Command Prompt:

```bat
scripts\build_map_persistence_windows.bat
```

By default it:

- initializes or updates `third_party/godot-cpp`;
- configures MSVC with `-G "Visual Studio 17 2022" -A x64`;
- builds Debug and Release;
- verifies the expected DLLs in `bin\`;
- runs the focused Godot smoke when `godot` is on `PATH`.

Useful options:

```bat
scripts\build_map_persistence_windows.bat --debug-only
scripts\build_map_persistence_windows.bat --release-only
scripts\build_map_persistence_windows.bat --skip-test
scripts\build_map_persistence_windows.bat --require-test
scripts\build_map_persistence_windows.bat --godot "C:\Path\To\godot.exe"
scripts\build_map_persistence_windows.bat --mingw
```

If Godot is not on `PATH`, the helper still treats a successful build as a pass
unless `--require-test` is provided. Run the focused smoke manually after adding
Godot to `PATH`:

```bat
godot --headless --path . tests\map_package_api_skeleton_report.tscn
```

The underlying MSVC commands are:

```powershell
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_msvc -G "Visual Studio 17 2022" -A x64
cmake --build .artifacts/map_persistence_native_build_windows_msvc --config Debug --parallel 2
cmake --build .artifacts/map_persistence_native_build_windows_msvc --config Release --parallel 2
```

MinGW-w64 is also supported when `g++` is on `PATH`:

```sh
cmake -S src/gdextension -B .artifacts/map_persistence_native_build_windows_mingw -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Debug
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
  -DCMAKE_BUILD_TYPE=Debug
cmake --build .artifacts/map_persistence_native_build_windows_cross --parallel 2
```

The Windows builds write Godot-loadable libraries to:

```text
bin/aurelion_map_persistence.windows.template_debug.x86_64.dll
bin/aurelion_map_persistence.windows.template_release.x86_64.dll
```

The `.gdextension` manifest is `src/gdextension/map_persistence.gdextension` and
points Godot at the generated `res://bin/` libraries for Linux and Windows x86_64.
Build directories should stay in `.artifacts/` so Godot does not scan CMake output
as project content.

## Smoke Validation

Focused native load smoke:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/map_package_api_skeleton_report.tscn
```

Focused native RMG foundation smoke:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/native_random_map_foundation_report.tscn
```

Passing output includes:

```text
MAP_PACKAGE_API_SKELETON_REPORT ... "binding_kind":"native_gdextension" ... "native_extension_loaded":true ...
```

The GDScript files in `scripts/persistence/` remain compatibility shims for fallback
or API comparison, but the focused report treats native load as the required happy
path.
