# Packaging Linux Export Smoke Report

Slice: `packaging-linux-binary-export-smoke-20260523-10184`

## Scope

This slice adds a repeatable local Linux packaged-binary smoke gate. It exports the existing `Linux Release` preset into a scoped `.artifacts` directory, then inspects the produced executable, sidecar PCK, Linux native GDExtension shared-library placement, and local headless startup.

This does not claim installer readiness, clean-machine smoke coverage, package signing, distribution channel metadata, or release readiness.

## Implemented Gate

- Added `tests/packaging_linux_export_smoke.py` as the focused Linux export runner.
- The runner exports `.artifacts/packaging_linux_export_smoke/export/heroes-like.x86_64` with:

```bash
godot --headless --path . --export-release "Linux Release" .artifacts/packaging_linux_export_smoke/export/heroes-like.x86_64
```

- The runner verifies the exported executable exists, is larger than the minimum binary-size floor, has executable permission bits, and has an ELF x86_64 header.
- The runner verifies `.artifacts/packaging_linux_export_smoke/export/heroes-like.pck` exists and is larger than the minimum package-size floor.
- The runner verifies `libaurelion_map_persistence.linux.template_release.x86_64.so` is present beside the exported executable.
- The runner starts the exported binary with:

```bash
.artifacts/packaging_linux_export_smoke/export/heroes-like.x86_64 --headless --quit-after 20
```

- The runner writes `.artifacts/packaging_linux_export_smoke/report.json` with command summaries, warning/error tails, artifact sizes, ELF checks, native-library checks, boot evidence, artifact listing, and explicit non-claims.

## Validation Command

```bash
python3 tests/packaging_linux_export_smoke.py
```

Latest local result on 2026-05-23:

- `ok: true`
- `heroes-like.x86_64`: 71071768 bytes, executable, with valid ELF x86_64 header.
- `heroes-like.pck`: 287796284 bytes.
- `libaurelion_map_persistence.linux.template_release.x86_64.so`: exported beside the executable.
- Local headless binary boot returned 0 with no fatal boot patterns.

Future release packaging still needs clean-machine validation on Linux and Windows, native Windows hardware certification, native minidump/symbol policy, code signing, package signing, and release-channel packaging. Bounded abnormal-exit recovery into the local support bundle is now covered separately.
