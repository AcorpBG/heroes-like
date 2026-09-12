# Living overworld scenery

Owner-directed Phase 6 slice `animation-overworld-living-scenery-20260912`, derived from `project.md` and `PLAN.md`.

## Requirements and scope

- Subtle, independently phased canopy motion on inspected original tree rasters. Keep ground contact and rocks stationary; no bobbing whole blockers.
- Localized activity on suitable inspected building paintings: flowing mill water and glowing working kiln/forge openings. Keep buildings rigid. Do not invent moving machine parts where the flattened art cannot isolate them cleanly.
- Explicit asset-id metadata, original raster sampling only, no replacement geometry or new/generated assets. Unlisted objects remain honestly static.
- Preserve existing painter order, exploration/level filtering, clipping, footprints, interaction, RNG and save data. Respect reduced motion and high contrast.
- Animate on the GPU with cached viewport-local draw commands; no per-frame map scan or static cache rebuild. Release render resources with the view.

## Implementation and validation targets

`scenes/overworld/OverworldMapView.gd`, a cached draw-batch owner and scenery shader, `content/overworld_scenery_animation.json`, and Python-owned focused source/package tests. Inspect source assets and final small/wide rendered sequences. Test exact metadata resolution, stationary lower trunk/building regions, shader compilation, fog filtering, deterministic state purity, accessibility, order, cleanup and Large-map bounded cache behavior. Run the existing animation regression, `python3 tests/validate_repo.py`, `git diff --check`, and official Linux/Windows export smokes plus focused package gameplay checks. Finish only with real evidence, task-owned cleanup and a coherent pushed commit.

No RMG/native generation, topology, balance, new art families, Town UI, gameplay or save-schema changes. Shader animation of existing paintings is not new directional sprite-sheet art or animated workers.

## Implementation

Fourteen explicit raster mappings cover eight existing temperate/wet/cold tree variants and six building presentations: two mills plus unclaimed/claimed kiln and charcoal sites. Canopy/painted-smoke displacement is vertically anchored and independently phased by asset, tile and map level. Mill flow samples only blue water in its authored activity region; kiln fire brightens only existing warm pixels. Unlisted scenery remains static. No painted asset, ownership/state selector or gameplay object was replaced.

`OverworldSceneryBatch.gd` splits the existing viewport state commands around animated textures, preserving their exact painter order, existing silhouettes, fog and grounding. It pools child draw batches until the next state invalidation. `OverworldScenery.gdshader` uses the GPU clock; idle animation does not iterate objects or rebuild terrain/state commands. Settings update material motion flags. Atlas cell UVs and painted-bounds cropping are both explicitly normalized; disabled-shader captures are compared with the same original texture rendered without a shader. No generated art, new textures, simulation writes or save fields were introduced.

## Evidence

Root: `.artifacts/overworld_living_scenery_20260912/`.

- `source-final`: 437 checks pass at 1280x720. All 14 paintings resolve and change across sampled animation frames; lower tree grounding and building areas outside the activity masks remain unchanged. Disabled motion is pixel-stable; the original unshaded/cropped paintings pass a maximum 0.025 RGB-channel difference at sampled interior pixels in the shader-disabled/reference comparison.
- `reduced`: 401 checks pass at 1280x720 with the actual reduced-motion preference. Player travel snaps and ambient redraw requests remain zero. The gallery separately exercises active and disabled material paths as a diagnostic, not gameplay ignoring the preference.
- `linux-large-package`: 508 checks pass against the isolated final Linux PCK at 1920x1080, generated seed 10, 108x108 Large. Actual player orders, four AI turns, fog boundary filtering, skip/battle handoffs and full-state equality are retained from the existing animation regression. Hiding the explored map removes all animated object entries, and restoring fog restores normal rendering.
- Its representative viewport contains eight animated assets in 17 cached painter-order batches. 120 controlled idle ticks take 249 microseconds total, with no state-command/terrain generation change; five deliberate state rebuilds take 62096 microseconds total (about 12.4 ms each). These are component CPU samples on this software-rendering host, not a hardware FPS guarantee or a claim that AI/generation is faster.
- `windows-package`: 385 checks pass against the isolated Windows PCK under Wine. It exercises real player orders, the shipped presenter, all raster mappings, fog removal, settings and state purity. Windows headless deliberately has no GPU screenshot/pixel assertions; Linux/source captures cover shader rendering. No Windows hardware/GPU certification is claimed.
- Official `linux-export` and `windows-clean-export` startup/export smokes pass, including the Windows generated Overworld/Town flow. Both PCKs are 313217176 bytes with 5605 members; sets match and only `project.binary` differs. Scenery manifest, shader and compiled batch owner are identical across platforms.
- The pre-existing full animation regression also passes 345 checks (`.artifacts/overworld_animation_20260912/scenery-draft/report.json`). The existing generated-object visual-coherence and overworld-art validators and the new manifest validator pass directly. Full `python3 -B tests/validate_repo.py` passes (`/tmp/heroes-living-scenery-repo-complete-20260912.log`, service exit 0), after updating three exact source-call expectations to the new cached animation path; grounding, town-adjunct geometry and no-image-scan guards remain intact. `git diff --check` passes.

The previous Linux package from the preceding animation slice was compared member-by-member: only the compiled MapView and UID cache changed, with the four new scenery manifest/shader/batch members added and no members removed. All existing `art/` and `.godot/imported/` payloads are byte-identical, including textures and audio.

Small/wide gameplay and art-gallery frames were opened and visually inspected. `living-map.mp4` and `living-assets.mp4` are four-second, 24-fps sequences of actual rendered frames, using a controlled shader clock at normal animation speed. The former shows the generated map in context; the latter is explicitly an inspection gallery, not a fabricated gameplay screenshot. Original PNG keyframes and the pixel-control images remain alongside the reports.

Initial atlas-coordinate errors were caught by grounding/motion tests and corrected before acceptance; failed `source-draft` logs and representative images remain. An initial system-service Windows export lacked a login environment and could not locate export templates; the next trial accidentally included its temporary editor profile. That profile and superseded export were removed, and `windows-clean-export` restores exact package parity. These trials are not final acceptance. An early repository process ended with status 143 before reporting; subsequent staged validation runs exposed three legacy source-text guards, which were updated without changing the already-tested runtime/packages.

Cleanup removed 738454016 bytes of task-owned superseded exports, screenshot intermediates, encoded-frame intermediates and the misplaced temporary editor profile. `cleanup-receipt.json` lists exact targets. Final packages, clips, keyframes, logs/reports, source/provenance, caches, saves and preserved Wine user data remain; the four pre-existing unrelated untracked paths are untouched.

## Reproduction

`python3 -B tests/overworld_living_scenery_regression.py --label <fresh-label> --render --resolution 1280x720`; add `--reduced-motion` for accessibility. For generated Large set `MENU_TURN_GENERATED=1 OVERWORLD_ANIMATION_MAP_SIZE=large` and use 1920x1080. `SCENERY_RECORD=1` captures 96 clock-controlled frames each for map/gallery (encode at 24 fps and clean redundant intermediates afterward).

The packaged wrapper uses the established `--platform`, `--binary`, `--pack`, `--label`, `--resolution` and fresh Windows `--wine-prefix` arguments. Run `python3 tests/validate_repo.py`, both official export-smoke scripts, and `git diff --check`. The slice does not certify every asset as animated, mechanical wheel/worker animation, the prior unrelated guarded-site legacy report, or whole-product release readiness.

Status: completed 2026-09-12. This closes the selected living-scenery slice, not whole-game animation or release readiness.
