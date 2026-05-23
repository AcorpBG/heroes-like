# Packaging Pack Export Smoke Report

Slice: `packaging-pack-export-smoke-20260523-10184`

## Scope

This slice adds a repeatable local packaged-artifact smoke gate. It creates a real external PCK with the existing `Linux Release` export preset, then boots that PCK through Godot `--main-pack`.

This does not claim binary export readiness, installer readiness, Windows packaged smoke coverage, clean-machine smoke coverage, or release readiness. Godot binary export templates are reported separately because they are not required for `--export-pack`.

## Implemented Gate

- Added `tests/packaging_pack_export_smoke.py` as the focused smoke runner.
- The runner exports `.artifacts/packaging_pack_export_smoke/heroes-like.pck` with:

```bash
godot --headless --path . --export-pack "Linux Release" .artifacts/packaging_pack_export_smoke/heroes-like.pck
```

- The runner verifies the PCK exists and is larger than the minimum package-size floor.
- The runner boots the generated PCK with:

```bash
godot --headless --main-pack .artifacts/packaging_pack_export_smoke/heroes-like.pck --quit-after 30
```

- The runner fails on nonzero export/boot return codes, timeouts, or fatal boot patterns such as `SCRIPT ERROR`, `Parse Error`, `ERROR:`, `Failed loading resource`, `No loader found`, or `Cannot open file`.
- The runner writes `.artifacts/packaging_pack_export_smoke/report.json` with command summaries, warning/error tails, PCK size, binary export template availability, and explicit non-claims.

## Validation Command

```bash
python3 tests/packaging_pack_export_smoke.py
```

The current gate is intentionally local and Linux-PCK focused. Future release packaging still needs binary export template installation, Linux and Windows executable export smoke tests, installer/export preset hardening, clean-machine validation, settings persistence verification under packaged binaries, and crash/error reporting policy.
