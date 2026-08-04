# Packaging Windows Export And Runtime Smoke Report

Slices: `windows-binary-export-smoke-20260523-10184`, `packaging-windows-wine-runtime-smoke-10184`

## Scope

This gate exports the existing `Windows Release` preset into a scoped `.artifacts` directory, inspects the executable, sidecar PCK, and Windows native GDExtension DLL placement, then launches the packaged executable in a fresh isolated Wine prefix. The report schema is `packaging_windows_export_smoke_v2`.

The Wine run proves packaged startup, PCK-backed Boot/MainMenu resource initialization, and loading of the Windows release GDExtension DLL. It does not claim clean native Windows execution, DirectInput or controller validation, hardware graphics/audio behavior, installer readiness, clean-machine smoke coverage, signing, or release readiness.

## Implemented Gate

- Added `tests/packaging_windows_export_smoke.py` as the focused Windows export runner.
- The runner exports `.artifacts/packaging_windows_export_smoke/export/heroes-like.exe` with:

```bash
godot --headless --path . --export-release "Windows Release" .artifacts/packaging_windows_export_smoke/export/heroes-like.exe
```

- The runner verifies the exported executable exists, is larger than the minimum binary-size floor, and has Windows `MZ` plus `PE` headers.
- The runner verifies `.artifacts/packaging_windows_export_smoke/export/heroes-like.pck` exists and is larger than the minimum package-size floor.
- The runner verifies `aurelion_map_persistence.windows.template_release.x86_64.dll` is present beside the exported executable.
- The runner removes and recreates `.artifacts/packaging_windows_export_smoke/wine-prefix`, then launches the exported executable headlessly with dummy audio and the compatibility renderer.
- The Wine 9 harness sets `WINEDLLOVERRIDES=dinput8=` because Wine's builtin DirectInput path crashes this Godot executable before project startup. This bypass is confined to the harness and means DirectInput or controller validation is not claimed.
- Runtime output must contain `Godot Engine v`, `Boot.scn`, `MainMenu.scn`, and `aurelion_map_persistence.windows.template_release.x86_64.dll`; fatal Godot, resource, GDExtension, or Wine page-fault output fails the gate.
- The runner shuts down its isolated Wine server and writes `.artifacts/packaging_windows_export_smoke/report.json` with export and runtime command summaries, marker results, artifact sizes, header checks, native DLL checks, artifact listing, and explicit non-claims.

## Validation Command

```bash
python3 tests/packaging_windows_export_smoke.py
```

The original static-export result on 2026-05-23 was:

- `ok: true`
- `heroes-like.exe`: 104539648 bytes, with valid `MZ` and `PE` headers.
- `heroes-like.pck`: 287755204 bytes.
- `aurelion_map_persistence.windows.template_release.x86_64.dll`: exported beside the executable.

Latest v2 local result on 2026-08-02:

- `ok: true`; export and Wine runtime return codes were both `0`.
- `heroes-like.exe`: 104539648 bytes, with valid `MZ` and `PE` headers.
- `heroes-like.pck`: 185227072 bytes.
- Windows release GDExtension DLL: 4255232 bytes and observed in Wine loader output.
- Godot startup, `Boot.scn`, `MainMenu.scn`, and native DLL markers were all present; no fatal runtime pattern matched.
- Runner: Wine 9.0 with an isolated `win64` prefix and `dinput8=` override.

The v2 gate additionally requires a successful isolated Wine boot. Future release packaging still needs clean native Windows execution, clean-machine validation, settings persistence verification under native Windows packaged binaries, controller and hardware validation, native minidump/symbol policy, code signing, and release-channel packaging. Bounded abnormal-exit recovery into the local support bundle is now covered separately.
