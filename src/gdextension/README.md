# Map/Scenario Persistence GDExtension Skeleton

This folder is the selected native extension home for the map/scenario package API.

Slice 1 intentionally exposes only inert typed stubs. The live headless smoke uses the
GDScript compatibility classes in `res://scripts/persistence/` because this repository
does not yet vendor `godot-cpp` or define a native build toolchain. The C++ files here
mirror that public API so the next native slice can replace the compatibility layer
without changing the design-level method names.

Current build status:

- Native source skeleton: present.
- Godot-visible compatibility binding: `scripts/persistence/MapPackageService.gd`.
- Native binary: not produced in Slice 1.
- Required native dependency for future build: Godot 4 `godot-cpp` matching the target
  engine series.

No package files are authoritative, no saves are migrated, and no runtime content path
loads these stubs unless a focused smoke/report instantiates them directly.
