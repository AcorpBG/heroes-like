# Generated Terrain Class Replacement Workflow

Document role: requirements and workflow guardrail for replacing remaining runtime terrain classes after the accepted `grastl` integration.

## Scope

This workflow covers the remaining HoMM3 local prototype terrain classes that still need original generated runtime replacements:

- `dirttl`: 46 frames
- `lavatl`: 79 frames
- `rocktl`: 48 frames
- `rougtl`: 79 frames
- `sandtl`: 24 frames
- `snowtl`: 79 frames
- `subbtl`: 79 frames
- `swmptl`: 79 frames
- `watrtl`: 33 frames

The runtime target shape should mirror `art/overworld/runtime/terrain_tiles/generated/grastl/`: `frames_64/` for accepted runtime frames, `source_sheets/` for 1024 atlases and provenance sheets, `previews/` for review contact sheets, and `experiments/` only for rejected or exploratory material.

## Required Flow

1. Pack the original reference class frames into a 1024x1024, 16x16, 64-pixel-cell atlas with unused cells forced to magenta.
2. Use that atlas only as visual/reference provenance for a `gpt-image-2` 1024 candidate. The generation step is outside deterministic repo tooling and must not be called by repository scripts.
3. Validate the candidate deterministically before runtime ingestion: exact 1024x1024 dimensions, exact class frame count, no magenta padding inside used cells, unused cells magenta or normalized to magenta, no obvious gridline/padding edges, and every accepted cut frame exactly 64x64.
4. Cut accepted candidates into `frames_64/00_00.png` through the class count.
5. Generate compact previews/contact sheets for visual review.
6. If validation or preview review exposes seams, gridlines, padding, or edge halos, perform an aggressive repair pass before runtime integration. Do not hide repair failures by weakening runtime validation.
7. Commit accepted work per coherent batch or terrain class so provenance, frame cuts, previews, and runtime wiring remain reviewable.

## Deterministic Tooling

Use `tools/generated_terrain_atlas_tool.py` for deterministic file work only:

- `pack-reference --all --dry-run` verifies reference counts and output targets.
- `pack-reference --all --force` writes source/provenance atlases and previews.
- `cut-generated --class <class> --atlas <candidate.png> --runtime-output` validates and cuts a candidate into the class `frames_64/` directory.

The tool must not generate imagery, call network services, or overwrite an existing output path unless `--force` is passed.

## Non-Goals

- No runtime replacement frame ingestion until generated candidates exist and pass validation.
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or unrelated renderer redesign.
- No legal claim that local prototype reference frames are shippable assets; they remain reference/provenance only.
