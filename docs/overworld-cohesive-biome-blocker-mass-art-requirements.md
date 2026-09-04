# Overworld Cohesive Biome Blocker Mass Art Requirements

Task: #10232

Parent: `phase-6-production-alpha-layer`

## Problem

The exact blocker-cell coverage introduced by #10231 is functionally correct, but its generated-body pool also includes the full authored decorative-object catalog. Those assets were composed as distinct landmarks and often include self-contained square ground plates. Selecting them independently per body cell produces a visible checkerboard instead of continuous forest, ridge, mire, snow, or ash landscape.

## Required behavior

- Generated blocker body cells must use an original, dedicated, transparent raster palette whose perspective, upper-left lighting, scale, material rendering, and ground-contact treatment are coherent within each biome.
- Alpha silhouettes must remain irregular through the sprite edges; no opaque rectangular terrain plate, frame, procedural drawing, generic fallback, or debug shape may be visible in normal play.
- Neighboring exact body cells must be composed deterministically into visually continuous masses with restrained variation, stable clustering, and sufficient overlap to hide cell seams.
- Authored decorative objects retain their distinct manifest mappings. Generated-body presentation must not repurpose that broad identity catalog as a random mass palette.
- Every authoritative blocker body cell remains visually covered and keeps its exact coordinate, source placement identity, footprint, collision, action/pathing relationship, interaction behavior, save behavior, and deterministic package/session payload.
- Missing dedicated palette mappings fail focused validation rather than silently selecting authored landmarks or procedural stand-ins.
- Source masters, prompts, provenance, runtime atlas regions, imports, and package ownership follow the existing original-art pipeline. No copyrighted Heroes assets, names, DEFs, or copied pixels.

## Responsive and packaging requirements

- The same deterministic Medium generated map must be captured and visually inspected at 1920x1080 and 1280x720 with unobscured routes and controls.
- Linux and Windows exports must carry matching runtime art and remain below the unchanged 250,000,000-byte PCK ceiling.

## Validation

- Focused generated blocker report: exact body-cell coverage, dedicated-palette-only resolution, deterministic neighbor composition, alpha-edge/opaque-plate checks, zero procedural/fallback rendering, unchanged authority hashes.
- Existing overworld decorative/distinct/live-art, generated-map, movement/pathing, interaction, and save coverage.
- `python3 tests/validate_repo.py`, `git diff --check`, Linux export/package smoke, and Windows export/package smoke plus generated-map entry where supported.
- Manual visual inspection of both responsive captures, followed by Discord delivery through Proca.

## Non-goals

No RMG generation/topology/density/placement changes, gameplay or balance changes, save-schema changes, Town/Battle UI changes, unrelated art-family regeneration, package-limit changes, signing, publication, whole-game certification, or release-readiness claim.
