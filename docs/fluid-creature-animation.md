# Fluid creature animation

Owner request, 2026-09-23: expand the animation improvement to every live unit that falls short, including base creatures, town upgrades and neutrals. This supersedes the original 72-upgrade-only scope of the active goal. The whole live roster currently contains 232 creatures.

## Completion standard

- Idle: 8-12 distinct coherent poses with visible articulated breathing, arms/equipment or anatomy-appropriate movement. Eight existing poses alone do not establish visual acceptance.
- Movement: at least eight poses with a readable gait, flight, crawl or other suitable locomotion, stable ground/body reference and no teleporting limbs.
- Attack and relevant ranged/cast/support actions: 8-12 poses with anticipation, contact/release and recovery, preserving equipment and matching the actual attack type. A noncaster's support cue must remain a physical gesture rather than invented spellcasting. A melee-only unit does not require an invented ranged weapon.
- Hit: 4-6 distinct recoil/recovery poses. Defense: at least four dedicated guard/brace transition poses.
- Death: 8-12 poses forming a continuous collapse, ending in a grounded persistent corpse. The corpse may reuse the last death frame; death must not reuse the hit clip as its entire sequence.
- No duplicate-frame padding, ping-pong reuse counted as new artwork, whole-sprite bobbing/warping, crossfades alone, or idle aliases counted as completed movement/attack/cast/defense. Preserve qualifying existing sequences after inspection.
- Original paintings must retain creature identity, camera, equipment, anatomy, body size and surface style across frames. Preserve original sources, prompts and reference lineage. Small cropping/packing/alpha preparation is production tooling, not replacement artwork.
- Playback must give the new poses time to appear and synchronize attack contact, reactions, travel and death. Normal/Fast/reduced-motion modes must remain readable. Animation stays presentation-only and must not change simulation RNG, occupancy or saved gameplay.

## Production and ownership

`art/units/source/generated/fluid_animation/production.json` contains the current `assignments` partition for all 232 IDs. The owner's expanded limit is 20 subagents: nineteen artists with 12-13 disjoint units each, plus one playback/pipeline agent. These assignments supersede the original four 58-unit batches; source paths retain their original batch names for provenance. Artists own only their assigned unit directories and handoffs. The coordinator owns shared data merges, final acceptance, planning, wiki updates and Git. Use existing units/manifest references rather than inventing new creature designs.

The shared hero-spell route presents the active stack in `cast_support_anchor` even for noncasters. Every creature therefore needs an appropriate physical support gesture; only actual casters should depict casting, and only ranged units require a ranged weapon/release sequence.

Start with representative complete sequences and inspect them as motion before broad production. Source originals are generated through the built-in image tool and retained in the repository. Save exact prompts with byte-preserved hashes and generation output/reference paths. Review at real battle and map sizes, not only enlarged source sheets.

Store each unit's sources under its assigned batch directory. A durable `handoff.json` describes the unit ID, source image paths, exact frame rectangles, anatomical ground anchors, clip names and ordering, shared scale/reference size and timing recommendations. Runtime atlas preparation must preserve normal inherited Windows file permissions and bound texture dimensions; Linux paths and metadata must stay portable.

## Validation and retention

Use focused clip/manifest, actual playback, grounding, reduced-motion/Fast and simulation/save checks. No full repository suite. A minimum frame count or a passing structural check is not visual acceptance. Document unfinished identities/clips honestly. Original asset masters, provenance, recipes, saves, backups and caches remain; remove task-owned temporary render previews, logs and probe profiles after inspection. Push coherent validated runtime/content slices to main, preserving unrelated existing work.
