# Cinderpot Hurlers fluid animation

Completed seven replacement actions from local MiniMax H3 videos: move38, punch36, throw45, recoil24, guard16, support23 and collapse41, totaling223 selected original frames. The existing eight-pose idle and overworld pixels/timing are preserved.

All992 original phases from eight takes were reviewed chronologically, with enlarged anatomy/equipment and native Godot battle/map renders. The first collapse was rejected for a hue-cycling background. The green-background correction retains the full fall and grounded corpse. The throw separates a fully detached pot across empty columns in three frames so runtime owns projectile flight.

The punch contact is held100ms after an initial focused playback check exposed a skipped42ms impact. Final validation:769 candidate and783 imported-live Windows checks, zero failures; isolated import passes. All223 published poses match source pixels and anchors; other231 creature records and map rows remain unchanged. Atlas1916x3748 uses28,724,672 RGBA bytes. No full suite, Linux execution, continuous-video playback or manual game playtest is claimed.

Preserve the existing eight-frame articulated idle and overworld strip. The original hooded skirmisher retains orange trim, leather wraps, belt-mounted clay pots, two arms and two legs. Melee is an empty-handed punch; ranged is one clay-pot throw; support is a physical readiness gesture.

`prepare.py` records immutable original guide crops, anatomical anchors, fixed scale and exact prompts. The older 224px ready artwork is registered to the 205px accepted idle using a fixed 0.915 factor for all older action paintings. This is reference registration, never per-frame normalization. The original opaque foreground magenta chroma maximum is 10, retained by the matte.

`run_batch.py` samples in pairs, preserving sampler latents before releasing the denoiser/text encoder and decoding with the VAE alone. `produce.py` verifies decoded RGB pixels, removes the measured flat key background and builds selected handoffs. `verify_delivery.py` checks original and published pixels separately from visual acceptance. Models and settings are recorded in `runtime_profile.json`.

Review must cover the complete original sequence, anatomical and equipment details, loops, throw ownership, action boundaries and native Godot battle/map scale. Continuous video playback and manual playtesting are not implied by ordered-frame or native-phase review. Original videos, latents, guides and provenance remain even for rejected takes.
