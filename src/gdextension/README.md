# Map/Scenario Persistence GDExtension Skeleton

This folder is the selected native extension home for the map/scenario package API.

The current native slice exposes only inert typed stubs. `MapDocument`,
`ScenarioDocument`, and `MapPackageService` are real Godot GDExtension classes, but
package read/write/conversion/migration/hash behavior intentionally returns stable
`not_implemented` reports. No map package files are authoritative, no saves are
migrated, and no runtime content path adopts these stubs unless a focused
smoke/report instantiates them directly.

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

The build writes the Godot-loadable library to:

```text
bin/libaurelion_map_persistence.linux.template_debug.x86_64.so
```

The `.gdextension` manifest is `src/gdextension/map_persistence.gdextension` and
points Godot at the generated `res://bin/` library. Build directories should stay in
`.artifacts/` so Godot does not scan CMake output as project content.

## Smoke Validation

Focused native load smoke:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tests/map_package_api_skeleton_report.tscn
```

Passing output includes:

```text
MAP_PACKAGE_API_SKELETON_REPORT ... "binding_kind":"native_gdextension" ... "native_extension_loaded":true ...
```

The GDScript files in `scripts/persistence/` remain compatibility shims for fallback
or API comparison, but the focused report treats native load as the required happy
path.
