# Packaging Windows Export Smoke Report

Slice: `windows-binary-export-smoke-20260523-10184`

## Scope

This slice adds a repeatable local Windows packaged-artifact smoke gate. It exports the existing `Windows Release` preset into a scoped `.artifacts` directory, then inspects the produced executable, sidecar PCK, and Windows native GDExtension DLL placement.

This does not claim Windows runtime execution, Wine runtime execution, installer readiness, clean-machine smoke coverage, or release readiness.

## Implemented Gate

- Added `tests/packaging_windows_export_smoke.py` as the focused Windows export runner.
- The runner exports `.artifacts/packaging_windows_export_smoke/export/heroes-like.exe` with:

```bash
godot --headless --path . --export-release "Windows Release" .artifacts/packaging_windows_export_smoke/export/heroes-like.exe
```

- The runner verifies the exported executable exists, is larger than the minimum binary-size floor, and has Windows `MZ` plus `PE` headers.
- The runner verifies `.artifacts/packaging_windows_export_smoke/export/heroes-like.pck` exists and is larger than the minimum package-size floor.
- The runner verifies `aurelion_map_persistence.windows.template_release.x86_64.dll` is present beside the exported executable.
- The runner writes `.artifacts/packaging_windows_export_smoke/report.json` with command summaries, warning/error tails, artifact sizes, header checks, native DLL checks, artifact listing, and explicit non-claims.

## Validation Command

```bash
python3 tests/packaging_windows_export_smoke.py
```

Latest local result on 2026-05-23:

- `ok: true`
- `heroes-like.exe`: 104539648 bytes, with valid `MZ` and `PE` headers.
- `heroes-like.pck`: 287755204 bytes.
- `aurelion_map_persistence.windows.template_release.x86_64.dll`: exported beside the executable.

Future release packaging still needs actual Windows runtime execution on Windows, installer/export-preset hardening, clean-machine validation, settings persistence verification under Windows packaged binaries, crash/error capture, code signing, and release-channel packaging.
