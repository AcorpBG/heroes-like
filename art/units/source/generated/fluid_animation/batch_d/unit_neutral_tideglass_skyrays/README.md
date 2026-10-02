# Tideglass Skyrays production sources

Solo MiniMax H3 production preserves the eight reviewed existing idle phases
and replaces flight, melee ram, broadside release, recoil, guard, resonator
support and grounded collapse. Original near/far crescent wings, pointed face,
bell harness, dorsal fins and trailing ribbons guide separate action videos.

`prepare.py` records the exact original pixels, source scales and ground
anchors. The existing corpse guide's physical lowest pixels define its ground
contact rather than its old transparent padding. All extracted video frames
retain one fixed .5 scale and one anchor; no frame stabilization, interpolation,
reverse duplication or pose normalization is used.

`stage_video.py` preserves the original sampling latent, releases the text
encoder/denoiser and decodes the unmodified video in a separate VAE-only pass.
Original FFV1 RGB videos, per-frame hashes, MP4, latents, prompts, guides,
workflow/model settings and submission histories are retained. Generation and
structural checks alone do not confer visual acceptance.

`move_h3_v1` is rejected: the model replaced its magenta plate with teal
between endpoint guides, too close to translucent wing colours for safe
extraction. Its originals and submitted references remain. The corrected v2
recipes use a measured blue key plate. Unsubmitted duplicate v1 planning
guides were verified against v2 and removed; `draft_cleanup.json` records this.

`selection.json` in each selected take records exact original source indices,
action timing, reduced-motion poses and observed contact frames. `delivery.json`
records accepted takes and the retained idle. Rebuild removed unselected matte
intermediates with `segment.py <take>`, then `select_reviewed.py` and
`produce.py assemble` without generating new H3 footage. `segment_initial.py`
preserves the exact first extraction implementation recorded for flight;
`segment_v2.py` preserves the second recipe used for the other v2 actions.

Melee v2 clipped raised wing tips and snapped at its legacy contact guide;
v3's intermediate guide forced a second lunge and flare. Both are rejected.
Guide-free v4 is accepted only for its selected opening/final action intervals:
original frames 0-22 join a matching raised-wing pose at82, followed by the
wing-driven head strike/contact89 and recovery. Repeated events and particles
in23-81 are excluded, with original footage retained. `corrected_selections.json`
records this edit; no source pixels were erased or motion interpolated.
Guard v2 skipped its fold transition; v3 supplies the continuous partial-to-full
wing canopy and held stance. Additional upper canvas space preserves wing tips
without changing source scale or anatomical registration.

The source's idle paintings and map idle pixels/timing must remain exact. Both
the battle atlas and horizontal map strip stay within 4096px. Publication uses
the shared selected-clip publisher; gameplay rules, saves and other units stay
unchanged. Unit-specific native normal/reflected/ranged review drivers and
source/import checks are retained; disposable previews/profiles/logs are removed.
`capture_clock.py` observes the actual completed draw once per frame, avoiding
a second screenshot-only yield while retaining all authored-pose assertions.

Background extraction uses `segment.py` with pinned official BiRefNet-matting weights and an isolated timm wheel on H:. See `matting_model.json` for checkpoint/code hashes and each take's `segmentation_recipe.json` for the precise soft-matte recipe. No packages were installed into the existing ComfyUI environment. Original videos and latent tensors remain unchanged. First chroma attempt and blue correction both changed plate colours; no unsafe relaxed chroma threshold is used.

`install_matting.py` recreates the pinned model and isolated dependency cache.
Set `HEROES_MATTING_ROOT` to choose another location; Linux defaults to
`~/.cache/heroes-like/matting`, Windows to the H: production directory. The
current extraction/render validation ran on Windows; no Linux run is claimed.
