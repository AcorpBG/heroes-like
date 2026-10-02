# Sunscale Lanternmoths production sources

Solo MiniMax H3 production preserves the eight visually reviewed original idle
paintings and replaces seven deficient actions. The original four blue/gold
mineral wings, six insect legs, two feather antennae, furry thorax and faceted
amber abdomen define this ranged creature. Its support cue remains an innate
wing/antenna/foreleg signal; the game owns detached projectile rendering.

`prepare.py` records original source pixels, scales and anatomical anchors.
Every action uses a 960x640 canvas with one fixed .5 extraction scale and
anchor [480,576]. The terminal original corpse guide registers physical ground
contact once; video frames are never stabilized or individually normalized.
Guides do not resize collapsed poses to standing height.

`run_generation.py sample <takes>` preserves sampled latents before unloading
the encoder/denoiser. `run_generation.py decode <takes>` decodes those exact
latents in a separate VAE-only pass. Originals, workflow settings, prompts,
seeds, guide hashes, submission histories and all original RGB frame hashes
remain as source provenance. Sampling or structural checks do not approve art.

`segment.py <takes>` uses pinned local BiRefNet-matting and an isolated timm
wheel to extract soft alpha at unchanged original coordinates. It retains all
opaque source RGB, protects legitimate thin legs/antennae and unmixes only
soft edges from the measured plate. `install_matting.py` and
`matting_model.json` identify the pinned model/code/dependency hashes.
`HEROES_MATTING_ROOT` selects another cache location; Linux defaults to
`~/.cache/heroes-like/matting`, Windows to the H: production directory.
No Linux runtime validation is implied by Windows checks.

Selected per-take source indices, timing and contacts are recorded only after
chronological/enlarged review. `produce.py build <take>` rebuilds the selected
handoff; `produce.py assemble` combines the reviewed takes. Removed unselected
matte intermediates can be rebuilt from retained lossless original footage.
Original videos, prompts, guides, provenance, saves and caches remain intact.

Unit-specific offscreen native/reflected/ranged drivers retain all authored
timing, simulation and save assertions. `capture_clock.py` samples each completed
draw once, avoiding screenshot-only double waits.
The preview-only observer also records the exact atlas region selected during
the real board draw, avoiding a later clock sample crossing short-pose boundaries
while reading back the GPU. It never substitutes or freezes game playback.
`verify_delivery.py` checks
source pixels/anchors, imported layout, other231 unit rows and exact preserved
idle/map pixels/timing. New clips remain pending until actual visual and focused
candidate/live checks pass; no full repository suite or manual game run is used.
