# Reedsnare Kin H3 original motion

Published six reviewed actions: movement 21, attack 25, defense 16, hit 17,
physical support 19 and death 23 original frames (121 total); the final death
frame is the persistent corpse. All eight prior idle paintings, 240ms timing and
the overworld PNG remain byte-exact. Other 231 unit entries are unchanged.

Identity: human swamp hunter in olive leather, yellow reed fringe, brown wrapped
boots and brown topknotted hair; two arms/two legs; one two-pronged trapping pole
held in both hands, attached weighted rope loop, rope coil on image-left hip.
The successful guides use saturated green. Original opaque guide pixels have a
maximum green-channel excess of 16/255; extraction protects a 32-unit foreground
band so olive clothing remains opaque and unchanged. Magenta attempts produced
background hue cycling and are retained as rejected originals.

Original older action paintings use one fixed 1.05 guide scale to match the newer
223-pixel idle body against their 213-pixel ready painting. All old action guides,
including crouch/corpse, use that same factor. Extracted video uses fixed scale 0.8
and anchor [480,480]; no per-frame normalization or synthetic articulation.

Use stage_video.py for saved-video-latent sampling, explicit model/cache release
and VAE-only decoding. Local H3, 960x544, 124 frames at 24fps, 20 res_multistep/simple
steps, 256/64 spatial and 16/4 temporal VAE tiles. Preserve original latent/video,
prompts, guides, model/workflow settings and exact selected frame provenance.
Visual review is autonomous; chronological/enlarged/native checks are distinct
from continuous playback and a manual game playtest. Focused checks only.

Validation: 187 combined candidate checks, 201 imported-live checks and 24 initial
movement checks passed, plus isolated Godot import. Every chronological source
frame, enlarged grips/alpha and all native 128px reference phases were reviewed.
Atlas: 3440x3640, 50,086,400 RGBA bytes. No full suite or manual game playtest.

Accepted takes are listed in delivery.json. Original rejected videos/latents and
review reasons remain alongside accepted sources. cast_v2 uses cast_v1 original
frame 43 as its raised-pole guide; its source matte and extraction recipe remain.
Rebuild removed matte derivatives with produce.py process <take>. Rebuild handoffs
with produce.py build <take>, then produce.py assemble. stage_video.py is for new
versioned takes; retained originals do not require the disposable Comfy copies.
