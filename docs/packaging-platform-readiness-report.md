# Packaging Platform Readiness Report

Slice: `packaging-platform-readiness-20260523-10184`

## Scope

This slice adds a focused packaging/platform readiness gate for the current production foundation. It does not claim release readiness, installer completion, or smoke-tested packaged artifacts on clean Windows/Linux machines.

## Implemented Gate

- Added `export_presets.cfg` with Linux and Windows release presets.
- Export outputs target `build/linux/heroes-like.x86_64` and `build/windows/heroes-like.exe`.
- Presets export all resources while excluding local/development material: `.git/*`, `.godot/*`, `.artifacts/*`, `tmp/*`, and `*.dll.a`.
- The Godot report validates native GDExtension manifest coverage for Linux and Windows editor/debug/release entries.
- The report checks that referenced Linux `.so` and Windows `.dll` artifacts exist and are non-empty.
- Runtime persistence paths remain package-safe through `user://config/settings.cfg` and `user://debug/heroes_profile.jsonl`.
- Project boot metadata remains pinned to `res://scenes/boot/Boot.tscn`, app name `heroes-like`, and `res://icon.svg`.

## Validation Command

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/packaging_platform_readiness_report.tscn
```

The report intentionally does not require installed Godot export templates. It validates repository readiness for Linux/Windows export configuration and native artifact wiring before future packaged-build smoke tests.
