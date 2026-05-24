# Packaging Release Bundle Manifest Gate Report

Slice: `packaging-release-bundle-manifest-gate-20260524-10184`

## Scope

This slice adds a deterministic post-export release-bundle manifest gate for the current local Linux and Windows smoke artifacts. It inspects the output folders produced by `tests/packaging_linux_export_smoke.py` and `tests/packaging_windows_export_smoke.py`, requires their JSON reports to be successful, and then validates the exact distributable sidecar files.

This does not claim installer readiness, clean-machine smoke coverage, Windows runtime execution, code signing, package signing, distribution channel metadata, or release readiness.

## Implementation

- Added `tests/packaging_release_bundle_manifest_report.py`.
- The report schema is `packaging_release_bundle_manifest_v1`.
- Linux `Linux Release` bundle requirements:
  - `heroes-like.x86_64`
  - `heroes-like.pck`
  - `libaurelion_map_persistence.linux.template_release.x86_64.so`
- Windows `Windows Release` bundle requirements:
  - `heroes-like.exe`
  - `heroes-like.pck`
  - `aurelion_map_persistence.windows.template_release.x86_64.dll`
- The gate fails if bundle folders contain unexpected files or forbidden release-bundle content such as `.git`, `.godot`, `.artifacts`, `tmp`, `*.dll.a`, `.import`, `.pdb`, debug native artifacts, or import/library sidecars.
- The report writes `.artifacts/packaging_release_bundle_manifest_report/report.json`.

## Validation

Run order:

```bash
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
python3 tests/packaging_release_bundle_manifest_report.py
```

The manifest gate is intentionally a post-export hygiene check. It strengthens local packaged-artifact evidence by preventing dev, import, and debug files from silently becoming part of a release-candidate folder, but future production release work still needs installer packaging, clean-machine validation on Linux and Windows, signing, distribution metadata, support workflow decisions, and true release readiness review.
