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
- The runner records the release PCK size without imposing a maximum content-size budget, per owner direction on 2026-09-09. The former 250 MB check and its boolean report field were removed; completeness, integrity and startup checks remain mandatory.
- Before inventory, size and boot checks, the runner uses the same verified
  `tools/compact_export_pck.py` operation as the production release builder.
  It removes only exported JSON formatting; source files and all non-JSON payload
  bytes remain untouched. The report retains `pck_json_compaction` integrity and
  size evidence. A raw direct Godot export has not yet passed this step.
- The runner builds an exact inventory from repository `art/*/source/**/*.import` metadata, then parses the exported PCK directory and requires both the development source-art metadata and imported source textures to be absent. Repository source files are preserved; runtime assets remain packaged and retain their existing resource identities.
- The runner verifies `libaurelion_map_persistence.linux.template_release.x86_64.so` is present beside the exported executable.
- The runner starts the exported binary with:

```bash
.artifacts/packaging_linux_export_smoke/export/heroes-like.x86_64 --headless --quit-after 20
```

- The runner writes `.artifacts/packaging_linux_export_smoke/report.json` with command summaries, warning/error tails, artifact sizes, ELF checks, native-library checks, boot evidence, artifact listing, and explicit non-claims.

## Validation Command

Validated no-size-budget checkpoint (2026-09-09):
`.artifacts/generated_full_match_quality_20260906/mireclaw_release_linux_no_cap_02/report.json`
passes with a 250525428-byte PCK. The generated-entry flow passes eight normal
daily Town builds; exact Mireclaw replays at 1280x720 and 2048x1079 each pass
4068 checks with unchanged saves/exports. Final rendered captures were inspected.
Full payload/input/provenance evidence: `docs/generated-full-match-art-repair-report.md`.

```bash
python3 tests/packaging_linux_export_smoke.py
```

Latest local result on 2026-05-23:

- `ok: true`
- `heroes-like.x86_64`: 71071768 bytes, executable, with valid ELF x86_64 header.
- `heroes-like.pck`: 287796284 bytes.
- `libaurelion_map_persistence.linux.template_release.x86_64.so`: exported beside the executable.
- Local headless binary boot returned 0 with no fatal boot patterns.

Latest source-art-exclusion result on 2026-08-24:

- `ok: true`; export and packaged headless boot return codes were both `0` with no fatal patterns.
- `heroes-like.x86_64`: 71071768 bytes, executable, with valid ELF x86_64 header.
- `heroes-like.pck`: 215251188 bytes, down from the 764036400-byte pre-slice release PCK.
- Exact PCK directory inspection found zero development source-art metadata entries and zero corresponding imported source textures; required runtime terrain/artifact identities remained present.
- `libaurelion_map_persistence.linux.template_release.x86_64.so`: exported beside the executable.

Validated 2026-09-07 art-headroom checkpoint: `town_pack_linux` under the generated
full-match quality artifact directory passes with a 246744064-byte compacted PCK,
including the separate rendered generated Town flow and three successive-day
builds. Full member/parser preservation and inspected captures are recorded in
`docs/generated-full-match-art-repair-report.md` (export-only headroom).

Future release packaging still needs clean-machine validation on Linux and Windows, native Windows hardware certification, native minidump/symbol policy, code signing, package signing, and release-channel packaging. Bounded abnormal-exit recovery into the local support bundle is now covered separately.
