"""Record the coordinator's actual source review, without runtime acceptance."""
import produce as p


def main():
    S = p.SOURCE_DIR
    p.write(S/'ranged_h3_v2'/'visual_review.json', {
        'status': 'qualified_source_pending_runtime',
        'reviewer': 'coordinator',
        'examined': 'All124 original RGB chronologically; all124 alpha on alternating dark/light backgrounds; all124 fixed-native128 in each facing; original-size20,24,28,36 equipment/grip/recoil details.',
        'findings': 'Two wheels, three planted star-foot stabilizers, single original operator, round mirror and intact blue/amber launcher tips retained. Crank winding leads into operator backward absorption and mounted launcher recoil, then recovery. No baked projectile, flash, detached tip or extra operator. Matte retains shafts and star feet without a plate halo.',
        'selection_reason': 'Source12..48 is the complete first mechanical compression/recoil/recovery cycle. Later source48..78 repeats the action and is excluded; no splice, duplicate, reverse, interpolation or retiming.',
        'release_source_frame': 24,
        'review_limits': 'Chronological original-frame review is not claimed as continuous video playback. Actual native Godot Strike/Shoot/contact, import, map and reduced-motion review remains required before publication.',
    })
    p.write(S/'ranged_h3_v2'/'selection.json', {
        'source_frames': list(range(12,49)),
        'frame_msec': 42,
        'contact_frame': 12,
        'review_note': 'First complete original mechanical recoil cycle12..48 at source24fps (42ms); release starts at source24, leaving12 anticipation and24 subsequent recoil/recovery frames. Original inert launcher tips retained; runtime owns projectile. Dedicated ranged source, pending actual Godot runtime acceptance.',
    })
    p.write(S/'move_h3_v2'/'visual_review.json', {
        'status': 'rejected_at_original_RGB_review',
        'reviewer': 'coordinator',
        'examined': 'All124 original RGB chronologically; original-size0,30,60,90 wheel/axle/operator details.',
        'defect': 'The two wheel spoke disks stay near their original orientation, with small shape oscillation, while the operator cranks and leans. Sustained wheel rolling is still absent. Folded stabilizers alone do not make dedicated travel.',
        'selection': [],
        'alpha_native_acceptance': 'Not performed or claimed for already rejected movement footage.',
        'reassessment': 'The original four rolling key paintings strongly change the crank operator but barely change spoke orientation. Replace sparse operator-only cues with newly authored original rotational wheel key poses; preserve camera, carriage, operator and fixed axle/ground registration. Do not repeat only prompt/seed changes or substitute sprite warps.',
        'preservation': 'All videos, latents, original guides, full semantic matte pixels and provenance retained. No live catalog, gameplay or saves changed.',
    })
    print('RANGED_FIRST_CYCLE_SOURCE_QUALIFIED37; MOVEMENT_REJECTED_WHEEL_ROTATION_REQUIRES_NEW_GUIDES', flush=True)


if __name__ == '__main__':
    main()
