# Roadwardens H3 animation

Six dedicated battle actions are published from 157 reviewed original H3 frames. The eight articulated original idle poses, their anchors and 240 ms timing, and the original overworld idle catalog/strip are preserved exactly. Existing legacy `move_v1.png` and two prompts one directory above are unrelated pre-existing sources and remain untouched.

One anatomical scale of 1.0 for original pose references, fixed 0.5 extraction, 960x544 guides and ground anchor [480,490]. Source anchor is each original cell [256,248]. Both grips on the single long rigid bill-hook polearm, mustard cloak, kettle helmet and bronze road tokens are retained. Original pose 21 supplies ready and pose 24 supplies the upright physical support gesture. The old overhead pose 6 is not used because its shaft/arm arrangement is ambiguous.

| Action | Original frames | Frame duration | Production behavior |
| --- | ---: | ---: | --- |
| Move | 20 | 60 ms | One reciprocal gait cycle, both hands retaining the polearm |
| Attack | 40 | 40 ms | Preparation, two-handed thrust, guided contact and recovery; contact index 18 |
| Defend | 15 | 40 ms | Knees bend into a held guard |
| Hit | 18 | 40 ms | Grounded backward recoil and recovery |
| Support | 27 | 50 ms | Physical polearm salute for a noncaster; contact index 15 |
| Death | 37 | 45 ms | Kneel, side fall and grounded corpse; final frame supplies dead state |

`delivery.json` selects exact chronological source intervals and deliberately shortens long holds. No reversed frames, duplicate padding or interpolated motion is used. Attack v1 has unwanted collision sparks in frames 28-32 and 41-47; only its clean preparation 16-27 and extension 33-40 are used. Attack v2 removes a verified six-pixel disconnected background speck from the original guide, but its ready-to-thrust transition snaps at 57-58. Only its clean contact and recovery from frame 60 onward are used. The assembled joins (v1 27-to-33 and v1 40-to-v2 60) were inspected enlarged and at native scale. Rejected intervals remain in the preserved original videos.

Focused Windows validation: 223 candidate and 237 published checks pass. All 157 selected frames match their original pixels and anchors; all 166 candidate/live clip poses match, 77 handoff provenance hashes verify, and the other 231 creature records are unchanged. Seven immutable generation configurations and 15 original guide hashes verify. The atlas is 3936x3528, within the existing 4096 limit. Native battle phases and both overworld idle samples were inspected. The renderer emitted the existing Windows certificate-store and GLES3 MSAA diagnostics; no focused assertions failed. No full suite or Linux run was performed.

Exact prompts, guides, workflows, seeds, original video/latent/RGB hashes and all failed takes are retained. Chronological original-frame and native phase review does not claim continuous video playback or a manual playtest. Unselected reproducible mattes, verified Comfy output duplicates and temporary review/test files are removed after publication; source videos and tooling rebuild them.
