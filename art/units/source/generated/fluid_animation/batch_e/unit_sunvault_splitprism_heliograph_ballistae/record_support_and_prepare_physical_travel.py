"""Preserve support footage; test actual root travel after frozen wheel takes."""
import copy
import json
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'cast_h3_v3/visual_review.json', dict(
        status='qualified_source_pending_runtime', reviewer='coordinator',
        examined='All124 original RGB chronologically; enlarged alpha16..111 on dark/light; all124 fixed native128 poses in each facing.',
        findings='The operator bends elbows and torso gradually20..36, works the original handle in a lowered support stance36..82 and stands back through83..96. Helmet, cape, two arms, two legs and attached hand grips remain coherent. The chassis, three planted supports, mirror, both wheels and both rods retain their attitude without the abrupt whole-carriage replacements seen in take2. No generated spell ring or projectile.',
        selection_reason='16..100 retains smooth entry, manual support gesture and full recovery;85 consecutive originals at42ms.',
        review_limits='Chronological frame inspection, not continuous video playback or manual game testing. Actual native runtime, imported pixels and reduced motion remain required.'))
    p.write(S/'cast_h3_v3/selection.json', dict(
        source_frames=list(range(16,101)), frame_msec=42,
        review_note='85 original operator support/handle gesture poses; no forced chassis jump. Source-qualified; runtime pending.'))
    p.write(S/'move_h3_v4/visual_review.json', dict(
        status='rejected_at_original_RGB_review', reviewer='coordinator',
        examined='All124 original RGB chronologically in eight pages.',
        defect='Removing interior guides did not repair near-stationary blue spokes. The operator cycles, but both wheels remain effectively fixed. This is not an accepted rolling animation.',
        alpha_native_acceptance='Not performed or claimed after RGB rejection.', selection=[],
        reassessment='The in-place constraints are ineffective for this mechanism. Generate a genuinely rolling leftward carriage with first/last positions450px apart on a1280x704 canvas. Wheels must roll counterclockwise as the carriage travels left. After observing genuine rolling, trace the original anatomical wheel contacts to remove only root translation for engine-driven travel; preserve one global anatomical scale, original frame pixels and all observed articulation. No per-frame bounding-box normalization or generated motion in extraction.',
        preservation='All source video, latent,124 RGB hashes/mattes, references and generation settings retained.'))
    key=S/'rolling_rim_rotation_key_v1'
    p.write(key/'generation.json', dict(
        tool='built-in image_gen', tool_output='exec-6ad85098-49d5-4cc6-bdef-c8a67d6e130f.png',
        original_sha256=p.sha(key/'original.png'), prompt_sha256=p.sha(key/'prompt.txt'),
        reference=dict(path=(S/'move_h3_v4/guide_0_rgba.png').relative_to(p.ROOT).as_posix(),sha256=p.sha(S/'move_h3_v4/guide_0_rgba.png')),
        status='not_used_as_video_guide',
        observation='The requested quarter-turn is not unambiguous. The ivory sidewall still appears primarily on the visible left-facing thickness; this is not proof of rotating a distinct painted rim sector. Red fringe is also visible. Retain original but do not select it.'))
    c=copy.deepcopy(json.loads((S/'move_h3_v4/config.json').read_bytes()))
    first=c['references'][0]
    last=copy.deepcopy(first)
    last['name']='rolling_original_leftward_destination'
    last['guide_offset']=[-450,0]
    c.update(canvas=[1280,704],anchor=[875,576],seed=2026100391,
        references=[first,last],guides=[],last=1,correction_of='move_h3_v4',
        prompt='An original ivory, gold and cobalt fantasy siege cart with TWO large blue spoked wheels on one gold axle. One armored blue-caped operator cranks the rear handle, two solid original crystal rods and one round mirror remain attached. THREE original star-foot stabilizers are folded UP off the ground. In this shot the cart actually ROLLS LEFT across the image from its supplied right-side starting position to its supplied left-side destination. Both entire cart wheels rotate continuously counterclockwise in their own original wheel planes as they roll left; every spoke and rivet passes through successive angles, around stable gold hub centers. Keep original wheel diameter, spoke count, inclined circular shape and perspective. The operator repeatedly works the handle with both hands, elbows and knees bending and cape following naturally. Keep the launcher and mirror inactive and the three supports folded. Follow one continuous physical rolling trajectory for the entire video, no sliding with stationary spokes and no sudden pose substitution. Fixed elevated three-quarter tactical camera looking LEFT; the camera never tracks, rotates or zooms. Plain pale blue-gray background throughout, no scenery, text, extra operators, limbs, wheels, particles, rays, flashes or projectiles.',
        control_reassessment='Allow original physical leftward root travel; correct rolling direction; later extraction requires personally reviewed anatomical contact trace, not variable silhouette normalization.',
        visual_review='pending original video; original rolling endpoint source already personally reviewed',selection='not_selected')
    folder=S/'move_h3_v5'
    folder.mkdir(exist_ok=True)
    assert not (folder/'sampling_submission.json').exists()
    p.write(folder/'config.json',c)
    p.prepare(folder,c)
    p.verify(folder,c)
    print('SUPPORT85_SOURCE_QUALIFIED; MOVE4_REJECTED; PHYSICAL_TRAVEL5_PREPARED',flush=True)


if __name__=='__main__':
    main()
