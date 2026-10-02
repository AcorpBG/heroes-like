# Rootvault Barkhulks production sources

Solo H3 production preserves eight reviewed idle paintings and replaces six
battle actions. Two root arms and two rear root legs, a concentric heartwood
chest disk, amber eye/knots, moss and branching crown define the original unit.
The support gesture is physical; this melee creature receives no ranged weapon.

`prepare.py` records original guides and their anatomical scales. A fixed
960x640 canvas, .5 extraction scale and [480,576] ground anchor retain body size.
Corpse contact is registered once; frames are not stabilized or normalized.

`run_generation.py sample <takes>` retains original sampler latents;
`run_generation.py decode <takes>` releases the large models and decodes those
same latents. Preserve videos, exact prompts/workflows/seeds/guides, histories
and all124 original decoded RGB hashes per take. `segment.py <takes>` uses
pinned local BiRefNet soft alpha at original coordinates, preserving opaque
source RGB and unmixing only soft plate edges. `matting_model.json` identifies
model/code hashes. No environment modification is needed.

After full chronological and enlarged review, selection.json records original
indices, timing, contacts and reasons. `produce.py build <take>` and `assemble`
rebuild handoffs. Selected clips remain pending until native and actual battle
playback review succeeds. `run_native_review.py` and `run_mirrored_native.py`
retain focused simulation, save, timing and grounding assertions.
`capture_clock.py` records the actual draw region for screenshot observation
without modifying game timing. `verify_delivery.py` proves original pixels and
anchors, preserved idle/map art and unchanged other231 units. Imported atlas
pixels are checked separately. No full suite or manual game run is implied.

Original art, lossless footage, latents, guides, prompts, provenance, saves and
caches remain; task-owned review images/logs/profiles and byte-verified duplicate
outputs are disposable. Removed unselected mattes can be rebuilt from originals.
