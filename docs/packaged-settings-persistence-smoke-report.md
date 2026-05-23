# Packaged Settings Persistence Smoke Report

Slice: `packaged-settings-persistence-smoke-20260523-10184`

## Scope

This slice adds a focused packaged-settings smoke gate. It exports a real external `Linux Release` PCK, starts a report scene from that PCK with Godot `--main-pack`, writes settings through `SettingsService`, reloads them from `user://config/settings.cfg`, and restores any pre-existing local settings file afterward.

This does not claim binary export readiness, installer readiness, Windows packaged smoke coverage, clean-machine smoke coverage, settings UX redesign, or release readiness. It is local PCK evidence that the packaged resource set can execute the settings persistence path under `user://`.

## Implemented Gate

- Added `tests/packaged_settings_persistence_report.tscn` and `tests/packaged_settings_persistence_report.gd`.
- Added `tests/packaged_settings_persistence_smoke.py` to export `.artifacts/packaged_settings_persistence_smoke/heroes-like.pck`.
- The smoke launches:

```bash
godot --headless --main-pack .artifacts/packaged_settings_persistence_smoke/heroes-like.pck --scene res://tests/packaged_settings_persistence_report.tscn --quit-after 120 -- --report-json=.artifacts/packaged_settings_persistence_smoke/scene_report.json
```

- The packaged scene verifies `SettingsService.SETTINGS_FILE == "user://config/settings.cfg"`.
- The scene writes master volume, music volume, presentation mode, resolution, large text, and reduced motion values, then clears in-memory settings and reloads them from the config file.
- The scene records direct `ConfigFile` values and reloaded `SettingsService` values.
- The scene restores the original local settings file if one existed, or removes the temporary settings file when none existed.
- The Python runner fails on export failure, scene failure, missing report, failed restore, or fatal boot patterns such as `SCRIPT ERROR`, `Parse Error`, `ERROR:`, `Failed loading resource`, `No loader found`, or `Cannot open file`.

## Validation Command

```bash
python3 tests/packaged_settings_persistence_smoke.py
```

Future release packaging still needs installed binary export templates, Linux and Windows executable export smoke tests, installer/export preset hardening, clean-machine validation, and crash/error reporting policy.
