# Embercourt town building overlap repair

Owner-directed Phase 6 slice `bugfix-embercourt-town-building-overlaps-20260911`, completed 2026-09-11, derived from project.md and PLAN.md.

Reproduce the reported buildings covering the river and main town building in Embercourt. Identify exact asset/placement owners from live composition, then correct confirmed layer geometry/grounding without hiding buildings or changing gameplay. Keep alpha hit regions aligned through cover cropping and preserve development/upgrade visibility, original asset provenance, town identities, construction costs and save behavior. Prefer reusing existing appropriate original art; new art only if placement cannot produce an acceptable composition.

Targets: `content/town_building_scene_art_manifest.json`, Embercourt entries in `content/town_building_scene_layouts.json` if necessary, and focused Python-owned Godot composition/input tests. No other-faction redesign, economy/balance, save migration, native RMG, or broad cleanup. Validate before/after rendered individual/developed cases, main-building and layer input, unchanged gameplay state, source small/wide, Linux/Windows packages, `python3 tests/validate_repo.py`, `git diff --check`, and completion cleanup. A screenshot/building-name clarification has been requested to match the exact owner observation; independent confirmed overlaps may be fixed meanwhile.

## Confirmed cause and correction

Actual Riverwatch Town renders showed Beacon Court covering the civic hall roof, Bowyer Lodge and its Beacon Range upgrade crowding the hall's west roof/entrance, and Quartermaster's Depot projecting into the upstream channel behind the Muster court. These are independently reproduced defects; the owner did not supply an exact screenshot/building identity for this report.

`TownStageView._town_building_scene_entries` takes the exact faction art manifest's normalized bounds and ground anchor in preference to legacy layout-plot geometry. Drawing and alpha-shaped building buttons already share `_project_normalized_source_rect`; there was no divergent UI transform to patch. Corrected five Embercourt manifest rows only:

- Bowyer Lodge/Beacon Range: 80% of previous size, same shared upgrade anchor on the right-bank quay west of the hall.
- Quartermaster's Depot: 80% size, grounded in the far-left village street, outside the river.
- Beacon Court: 60% size, its own terrace east of the hall.
- Stone Store: 60% size, farther east so the relocated Court does not create a new collision; both remain above Wayfarers Hall and below compact command controls.

All original source/trimmed/runtime rasters, hashes, prompts, building IDs, construction data and save schema remain unchanged. Legacy layout coordinates are deliberately unchanged because exact scene-art bounds are authoritative. Earlier manifest curation notes describe historical acceptance; this report supersedes their placement acceptance for these five rows. Legitimate waterfront infrastructure remains over the water. No other-faction or broader art-quality completion is claimed.

## Focused evidence

Root: `.artifacts/embercourt_town_overlap_20260911/`.

- `before/`: visually inspected pre-fix base, individual Bowyer/Court/Depot and developed captures. The early developed fixture omitted starting buildings; final developed fixtures include starting plus catalog buildings, so individual images are the exact before/after comparison.
- `negative-control/report.json`: restoring four original rectangles in the view alone triggers seven expected civic-hall/river guard failures. This is an intentional failing regression control, not a shipping failure.
- `final-wide/` (2048x1079) and `final-small-complete/` (1280x720): 717 checks each pass; developed screenshots visually inspected. Six render-only fixtures cover base, individual problem layers, fully developed town, and Bowyer upgrade replacement. Corrected layers preserve image aspect and opaque/transparent pixel hit ownership through viewport cropping. Existing button signals open the exact building information and the main hall opens the construction ledger; rendering/dialog routes leave the full session dictionary unchanged.

Fixtures explicitly set building inventories to exercise composition. They do not claim a new paid-growth playthrough or disk save/load test. Production changes affect only rendering metadata, not construction, progression or persistence code. Focused interaction evidence covers alpha hit testing, focus availability and existing signal routing, not a new end-to-end physical mouse/navigation suite.

Reproduce source: `python3 -B tests/embercourt_town_overlap_regression.py --label <new-label> --render --resolution 2048x1079` (also 1280x720). Negative control: prefix `EMBERCOURT_OVERLAP_BASELINE=1`, omit `--render` if captures are unnecessary. Package probe: `python3 -B tests/packaged_embercourt_town_overlap_regression.py --platform linux|windows --binary <export-binary> --pack <export-pck> --label <new-label>`; Linux accepts `--render`, Windows requires a fresh task-owned `--wine-prefix`.

`packaged-linux/` (rendered, 1280x720) and `packaged-windows/` (headless Wine) pass the same 717 checks with the exact current manifest and SHA-locked compiled Town owners; the Linux developed screenshot was visually inspected. Windows evidence is not physical-GPU certification. Official `linux/report.json` and `windows/report.json` pass, including Windows startup and generated-map/Town construction/info entry. `package-parity.json` records 5599 identical member names, 5598 byte-identical shared payloads and the established platform-specific `project.binary` exception. Each package is 313201864 bytes. A first all-byte comparison rejected that expected platform config difference; the established platform-aware comparison passes.

Completion cleanup removed the superseded `final-small/` and `placement-check/` capture directories (about 16 MB, reproducible), and managed Wine cleanup removed disposable prefixes while retaining their user data. Before/after screenshots, negative control, final reports/exports, art provenance, caches and unrelated untracked files were preserved. `python3 -B tests/validate_repo.py` passed (exit 0, `repository-validation.log`); `git diff --check` passed. The narrow placement slice is complete, not a claim of whole-game release readiness.
